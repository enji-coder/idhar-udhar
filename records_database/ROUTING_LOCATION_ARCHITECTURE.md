# IDHAR UDHAR — ROUTING & LOCATION ARCHITECTURE

**Type:** Phase 7 implementation architecture  
**Date:** 2026-08-25  
**Does not modify:** `MASTER_SYSTEM_ARCHITECTURE.md`, PostgreSQL schema, Flutter, Admin UI  

Master §§13, 15, 33.1, 39 remain the rule authority. This file describes the running NestJS routing foundation and rider last-known location seam.

Production Redis GPS ingest is **not** deployed. Flutter map rendering is **not** this phase.

---

## Simple business meaning

The customer gives pickup and drop coordinates. The server asks a routing provider for **road distance**. FareEngine turns that distance into money.

The customer cannot type `distance_km = 1` and force a cheap fare.

Rider GPS pings update a last-known location in memory (Redis later). They are not written to PostgreSQL.

---

## RoutingProvider

```text
Fare / Order
     ↓
RoutingService
     ↓
RoutingProvider
     ↓
mock  |  Google Routes API adapter
```

Order and Fare modules do not call Google APIs.

Interface: `route({ points }) → RoutingResult`

`RoutingResult` (no financial fields):

| Field | Meaning |
|---|---|
| `provider` | `mock` or `google` — never mixed up |
| `distance_meters` | Positive integer |
| `estimated_duration_seconds` | Estimate only. Not a delivery promise |
| `origin` / `destination` | First and last points |
| `waypoint_count` | Intermediate stops (drops after pickup except last) |
| `calculated_at` | When the provider answered |
| `encoded_polyline` | Optional metadata. Not stored |

Geometry is not mandatory. Polyline is never persisted.

---

## Configuration

| Variable | Meaning |
|---|---|
| `ROUTING_PROVIDER` | `mock` (default) or `google` |
| `GOOGLE_MAPS_API_KEY` | Required when provider is `google` |
| `ROUTING_TIMEOUT_MS` | HTTP timeout (development default 10000) |
| `LOCATION_STORE` | `memory` only in this phase |

`ROUTING_PROVIDER=google` without a key **fails at startup**. It does **not** fall back to mock.

Never hardcode keys. Never log keys.

---

## Mock provider

`provider = mock`. Deterministic. No internet.

Distance is rounded haversine × **1.25** (a documented mock road factor). That factor is not a Google result and not a locked product rule.

Tests can script: unavailable, malformed, missing/negative distance, invalid duration.

---

## Google provider

Adapter talks to the current Google **Routes API**:

`POST https://routes.googleapis.com/directions/v2:computeRoutes`

- `optimizeWaypointOrder: false` — stop sequence is never reordered
- Intermediates are drop stops in stored sequence
- `travelMode: DRIVE` is a **technical default**, not a locked two-wheeler product rule
- Field mask: duration, distanceMeters, optional encoded polyline

Rejected without fabricating values:

- missing / zero / negative / non-integer distance
- invalid duration
- empty routes
- non-JSON
- provider error envelopes
- HTTP 429 / 5xx / 4xx

---

## Routing flow

```text
Customer coordinates on order_stops
        ↓  validate lat/lng
RoutingService (sequence order, no optimization)
        ↓
validated road distance
        ↓
FareEngine (PostgreSQL NUMERIC formula)
        ↓
fare_quotes
        ↓
confirm → immutable order_fare_snapshots
```

Meters convert to km with 3 fractional digits using integer division (`1234` m → `1.234` km). IEEE-754 is not the money authority.

---

## Multi-stop routing

Existing rule: 1 PICKUP + 1–3 DROPS. Sequence on `order_stops` is authoritative.

```text
P → D1 → D2 → D3
```

stays that order. No shortest-path reorder. No invented stop fee.

---

## Distance → fare

`POST /v1/orders/:id/quote` body must **not** include `distance_km`. Extra fields are rejected (`VALIDATION_ERROR`).

FareEngine still computes:

```text
distance_charge = round(per_km × distance_km, 2)
trip_fare       = max(initial_minimum, base + distance_charge + waiting + surge + toll + parking)
tax             = 0
```

85/15 still uses confirmed Trip Fare. GST stays ₹0. Rounding unchanged.

---

## Provider failure

Do not use zero, random, straight-line-as-final, stale, or fake Google data.

Return:

- `ROUTING_PROVIDER_UNAVAILABLE` (503) — network / vendor down / unconfigured google key at call time
- `ROUTING_INVALID_RESPONSE` (502) — malformed / missing distance / invalid duration
- `INVALID_COORDINATES` (400) — lat/lng out of range

The caller may retry. The order stays `CREATED` until a valid quote exists.

---

## Rider location

```text
Rider GPS
   ↓
POST /v1/rider/location
   ↓
LocationService (session rider_profile_id only)
   ↓
LocationStore
   ↓
memory now → Redis later
```

Request: `latitude`, `longitude`, `timestamp`, optional `accuracy_meters`, `heading`, `speed`.

Client `rider_profile_id` is ignored / rejected as an extra field. Identity comes from the rider session.

Response is honest: `store = memory`, `durable = false`. This is **not** permanent GPS storage.

GET `/v1/rider/location` returns the process-local last fix for the authenticated rider.

No notification on GPS pings. No notification on route calculations.

---

## Redis seam

Master §39: Redis is the hot last-GPS direction.

This phase:

- `LocationStore` interface is the seam
- `LOCATION_STORE=memory` is implemented
- `LOCATION_STORE=redis` **fails at startup** with a clear message (not silently treated as memory)

Redis is not a required deploy for Phase 7.

---

## PostgreSQL GPS prohibition

Do **not** create:

- `rider_location_samples`
- `gps_samples`
- `route_history`
- any 1 Hz GPS history table

Hot last point is not a Postgres row. Retention days for a future breadcrumb table remain **NEEDS BUSINESS DECISION**.

`order_stops` already holds booked pickup/drop coordinates. Reuse them. No duplicate location tables.

---

## Security

- Never expose `GOOGLE_MAPS_API_KEY` in API responses or logs
- Never trust client distance, duration, or fare
- Validate provider JSON before use
- Rider location is session-scoped
- Admin `GET /v1/admin/orders/:id/route` recalculates from stored stops; it does not store geometry

---

## APIs

| Method | Path | Role |
|---|---|---|
| POST | `/v1/orders/:id/quote` | Customer — routed distance, returns `routing` metadata |
| GET | `/v1/admin/orders/:id/route` | Admin — live route metadata, not persisted |
| POST | `/v1/rider/location` | Rider |
| GET | `/v1/rider/location` | Rider (own last-known, non-durable) |

---

## Tests

Unit: coordinates, meters→km, mock routing, Google parser, Google HTTP adapter, config refusal of google-without-key and redis store.

E2E against live Postgres: quote uses mock road distance, client `distance_km` rejected, GST 0, 85/15 formula unchanged, pickup+1 and pickup+3 drop order preserved, provider unavailable, rider location session auth, no GPS history tables.

---

**End of ROUTING & LOCATION ARCHITECTURE**
