# IDHAR UDHAR — FARE ENGINE ARCHITECTURE

**Type:** Phase 3 implementation architecture  
**Date:** 2026-08-25  
**Does not modify:** `MASTER_SYSTEM_ARCHITECTURE.md`, PostgreSQL schema  

Master §15 remains the formula authority.

---

## Flow

```text
ACTIVE fare_config_versions + fare_config_version_rates
        ↓  POST /v1/orders/:id/quote
stored order_stops coordinates
        ↓  RoutingService → RoutingProvider (mock | google)
validated road distance (meters → km, 3 decimals)
        ↓
fare_quotes          (amounts immutable; tax CHECK = 0)
        ↓  POST /v1/orders/:id/confirm
order_fare_snapshots (immutable; copies quote + fare_config_version_id)
```

Client-supplied `distance_km` / duration / fare are rejected. They cannot force Trip Fare.

Historical orders never re-read live Admin rates. A later published version N+1 does not update snapshots.

`fare_quotes` has no `order_id` column (schema). Confirm binds a quote by matching authenticated customer, vehicle category, and stop count, and by rejecting expired quotes.

---

## Formula (locked)

Computed in PostgreSQL `NUMERIC` / `money_inr`, never IEEE-754 as authority:

```text
distance_charge = round(per_km × distance_km, 2)
trip_fare       = max(initial_minimum, round(base + distance_charge + waiting + surge + toll + parking, 2))
discount        = 0          (no promo engine in Phase 3; do not accept client discounts)
tax             = 0          (GST locked)
net_payable     = round(trip_fare − discount, 2)
rounding        = net_payable − (trip_fare − discount)
```

`waiting`, `surge`, `toll`, `parking` are copied from the active rate row. No invented multi-stop fee. Road distance comes from `RoutingService` (see `ROUTING_LOCATION_ARCHITECTURE.md`). FareEngine remains authoritative for money. The quote body must not include `distance_km`.

Trip Fare is the 85/15 base. Phase 3 does **not** compute 85/15 or write `order_finance_snapshots`. The snapshot preserves `trip_fare` for that later phase.

---

## Money in the API

JSON amounts are decimal **strings** (`"100.00"`) taken from `NUMERIC::text` and padded without `parseFloat`. Unit tests cover formatting only; e2e asserts the SQL result.

---

## TTL

`FARE_QUOTE_TTL_SECONDS` default 900. Exact production TTL is **NEEDS BUSINESS DECISION** (Master: short TTL, no locked minutes).
