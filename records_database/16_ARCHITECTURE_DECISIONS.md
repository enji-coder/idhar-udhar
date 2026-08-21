# ARCHITECTURE DECISION RECORDS

Blueprint only. No implementation in this run.

---

## ADR-001 — Primary database: PostgreSQL

**Decision:** PostgreSQL 16+ as system of record for customers, riders, orders, money, RBAC, reports facts.

**Reason:** Orders, wallets, commission snapshots, invoices, and RBAC need transactions, FKs, constraints, and SQL reporting. Expected 100k→millions of users and millions of orders.

**Alternatives:** Firebase/Firestore (poor multi-row money + ad-hoc Admin reports); MongoDB (weaker financial invariants); SQLite on device (not shared truth).

**Rejected:** Firebase as primary DB. Flutter convenience is not a reason. Firestore can still be unused; FCM may be used for push only.

**Migration:** Standard SQL migrations later. Existing Netlify Blobs vehicle catalog migrates into `vehicle_category`.

---

## ADR-002 — Redis beside Postgres

**Decision:** Redis for session/presence, unread counters, last GPS point, dashboard cache 5–10s, rate limits, pub/sub to WS nodes.

**Reason:** High-churn location and dashboard must not hit Postgres at 1 Hz × 100k riders.

**Alternatives:** Postgres UNLOGGED, or skip cache (won’t scale live map).

**Later:** Cluster Redis when WS nodes > 1.

---

## ADR-003 — Object storage for files

**Decision:** S3-compatible bucket; Postgres stores metadata only.

**Reason:** KYC, POD, invoice PDFs are large and access-controlled.

**Rejected:** bytea in Postgres.

---

## ADR-004 — Backend as sole writer

**Decision:** One API (Node or similar) owns state machines. Apps are clients. Admin localStorage is not production.

**Reason:** Prevent Customer/Rider/Admin drift and client-side commission edits.

**Rejected:** Direct Supabase/Firebase from Flutter with RLS only (Admin RBAC + finance snapshots are complex; webhooks/workers still need a backend).

**Migration:** Replace `createEntityStore` with API calls without redesigning screens.

---

## ADR-005 — Real-time mix

**Decision:** WebSocket for live order/location/offers; FCM push for background; SSE/poll **aggregates** ~10s for Admin dashboard; REST for CRUD.

**Reason:** Product wants ~10s dashboard without scanning all orders; tracking needs sub-second-ish events.

**Rejected:** Poll everything 10s (battery, cost, stale races on accept).

---

## ADR-006 — Auth: OTP + admin password

**Decision:** Customer/Rider phone OTP (hashed challenges). Admin email/password hashed server-side + HttpOnly cookie/JWT. Refresh tokens hashed.

**Reason:** Matches apps. Admin already password-based.

**Rejected:** Storing OTP/session only on device.

---

## ADR-007 — Vehicle category master with stable UUIDs

**Decision:** One `vehicle_category` table. Apps send `vehicle_category_id`. Stop name matching (`Three Wheeler` vs `Auto`).

**Reason:** Admin already has VC-ids; Flutter still joins by name.

**Rejected:** Per-app lists; rename cascading by string (current `renameCategoryUsage`).

**Soft delete:** deactivate; hard delete only if unused (current Admin rule).

---

## ADR-008 — Unified order state machine + snapshots

**Decision:** Canonical statuses in 14_DATA_FLOW. Historical vehicle/address/rider/fare/finance copied onto the order.

**Reason:** Three apps use incompatible enums today. Settings changes must not rewrite old money.

---

## ADR-009 — Financial snapshots + settings versions

**Decision:** `payment_settings_version` + immutable `order_finance_snapshot` using the 85/15/50-of-commission formula.

**Reason:** Explicit business rule; Admin `attachFinanceSnapshot` already points this way.

**Rejected:** Recompute from live `iu_admin_settings`.

---

## ADR-010 — Notifications paginated

**Decision:** Per-user rows + cursor + Redis unread. Campaigns via workers.

**Rejected:** Loading full history; badge hardcoded in UI as source of truth.

---

## ADR-011 — Reporting aggregates

**Decision:** `daily_order_stats` maintained by workers; Admin overview hits aggregates.

**Rejected:** Browser-side reduce of all orders (`dashboardMetrics` current).

---

## ADR-012 — Queues/workers Day 1 (small)

**Decision:** Day 1: invoice PDF, email/SMS, push, fare not needed if sync, webhook retries, daily rollup. Use Redis streams or one SQS.

**Later:** separate report warehouse.

---

## ADR-013 — Scaling path

**Day 1:** one Postgres (managed), connection pool, indexes, cursor pagination, Redis, object storage, backups/PITR.  
**Later:** read replica for reports, partition events/notifications, archive orders > N years.

**Rejected now:** sharding, Kafka, multi-region (premature).

---

## ADR-014 — No Netlify deploy for this documentation

**Decision:** Records only under `records_database/`. Do not redeploy Admin.

---

## ADR-015 — Display IDs vs UUID

**Decision:** UUID PK; unique `display_id` formatted later (open: IU vs IU-AMD). Stop `milliseconds % 100000`.
