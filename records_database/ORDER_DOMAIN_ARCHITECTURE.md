# IDHAR UDHAR — ORDER DOMAIN ARCHITECTURE

**Type:** Phase 3 implementation architecture  
**Date:** 2026-08-25  
**Does not modify:** `MASTER_SYSTEM_ARCHITECTURE.md`, PostgreSQL schema, Flutter, Admin UI  

Master Architecture remains the authority for business rules. This file describes the running NestJS order/dispatch slice.

---

## Lifecycle

```text
Customer (session customer_profile_id)
  → POST /v1/orders          CREATED + stops + display_id + status event
  → POST /v1/orders/:id/quote   fare_quotes (active config, GST = 0)
  → POST /v1/orders/:id/confirm order_fare_snapshots + CREATED → SEARCHING
  → Admin POST /v1/admin/orders/:id/offers
                            SEARCHING → OFFERED (first pending offer)
  → Rider POST /v1/rider/offers/:id/accept
                            OFFERED → ASSIGNED (one winner)
  → Rider POST /v1/rider/orders/:id/status
                            happy path / failed-delivery path
```

Display ID is allocated only by `allocate_order_display_id(city_id)` in PostgreSQL (`IU-{CITY_CODE}-{10 digits}`). Clients never generate it. Ahmedabad is `cities.city_code = AMD`, not an application constant.

`customer_id` in the body is ignored/rejected. Ownership is always the authenticated session profile.

---

## State transitions

`OrderStateMachine` is the only place that approves edges. Controllers do not patch `canonical_status`.

Happy path (Master §14):

```text
CREATED → SEARCHING → OFFERED → ASSIGNED
→ EN_ROUTE_PICKUP → ARRIVED_PICKUP → PICKED_UP
→ IN_TRANSIT → NEAR_DROP → DELIVERY_ATTEMPT → DELIVERED
```

Failed delivery path is implemented as legal edges (no office-extra money in this phase).

Admin may cancel any non-terminal status. Customer may cancel `CREATED`, `SEARCHING`, and `OFFERED` only. Rider cancel is not enabled here (cancellation fee snapshot is a later finance phase).

Every successful transition:

1. compare-and-set `orders.canonical_status` (`UPDATE … WHERE canonical_status = from`)
2. insert append-only `order_status_events` (`ON CONFLICT (order_id, idempotency_key) DO NOTHING`)

Generic `POST …/status` cannot be used to confirm fare, create offers, or assign. Those use dedicated endpoints.

---

## Dispatch foundation

PostgreSQL only. No Redis, no GPS radius, no worker TTL loop.

Admin (or a future worker calling the same service method) creates `order_offers` rows (`PENDING`). Algorithm (broadcast vs sequential, SEARCHING auto-cancel) remains **NEEDS BUSINESS DECISION**. The order domain does not need to change when Redis is added later: keep “create offer / accept / reject / expire” as the seam.

Offer statuses: `PENDING | ACCEPTED | REJECTED | EXPIRED`. Unique `(order_id, rider_profile_id)`. Partial unique: at most one `ACCEPTED` per order.

Last pending reject/expire returns the order to `SEARCHING`.

Offer TTL is `OFFER_TTL_SECONDS` (development default 300). Dummy 27s is not production policy.

---

## Concurrency

Accept:

```text
BEGIN
  lock order FOR UPDATE
  lock offer FOR UPDATE
  if another rider already assigned → ORDER_ALREADY_ACCEPTED
  if offer not PENDING / expired / rejected → business error
  if rider ineligible (not approved, offline, COD-suspended, live trip) → reject
  UPDATE offer ACCEPTED
  EXPIRE other PENDING offers
  compare-and-set order ASSIGNED + rider_profile_id
  append status event
COMMIT
```

Losing rider receives `ORDER_ALREADY_ACCEPTED` (409). Same rider retry is idempotent (`idempotency_keys` scope `accept-offer`, key `rider_profile_id:offer_id`). Unique index `order_offers_one_accepted` is the last line of defence.

---

## Idempotency

`idempotency_keys` is insert-only (no UPDATE). Scope `create-order`: header `Idempotency-Key`, stored key `{identity_id}:{header}`, hash of canonical body. Same hash returns the stored payload. Different hash → `IDEMPOTENCY_CONFLICT`. Unique `(scope, key)` rolls back a racing duplicate insert, including the order row.

---

## Authorization

| Actor | May |
|---|---|
| Customer | Own create/list/get/quote/confirm/cancel (pre-assign) |
| Rider | Own pending/accepted offers; assigned order progress |
| Admin | Inspect any order; dispatch offer; assign; cancel |

---

## Out of scope (this phase)

Payment responsibility/plan/transactions, wallet, COD settlement, Redis dispatch, Google Maps routing, push, 85/15 finance snapshot, invoices, Flutter wiring.
