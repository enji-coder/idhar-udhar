# IDHAR UDHAR — IMPLEMENTATION STATUS

**Date:** 2026-08-25  
**Phase just completed:** Phase 9 — Admin Web UI + Nest `/v1` integration  
**Authoritative rules:** `MASTER_SYSTEM_ARCHITECTURE.md` (unchanged)  
**Companion docs:** `ADMIN_BACKEND_INTEGRATION_ARCHITECTURE.md`, `ADMIN_BACKEND_INTEGRATION_AUDIT.md`, `ADMIN_BACKEND_INTEGRATION_PLAN.md`, `FLUTTER_BACKEND_INTEGRATION_ARCHITECTURE.md`, `FLUTTER_BACKEND_INTEGRATION_AUDIT.md`, `ROUTING_LOCATION_ARCHITECTURE.md`, `NOTIFICATION_ARCHITECTURE.md`, `WALLET_COD_ARCHITECTURE.md`, `PAYMENT_FINANCE_ARCHITECTURE.md`, `ORDER_DOMAIN_ARCHITECTURE.md`, `FARE_ENGINE_ARCHITECTURE.md`, `AUTHENTICATION_ARCHITECTURE.md`

This file tracks implementation progress. It does not change locked business rules.

---

## Current snapshot

| Layer | Status |
|---|---|
| Locked business architecture | Unchanged |
| Local PostgreSQL schema | **Complete** (15 migrations) — **not modified in Phase 9** |
| Backend API | Phases 1–7 + Flutter CORS + **Admin directory / payments / earnings list endpoints** |
| Customer / Rider Flutter | Presentation clients on Nest `/v1` (**not modified in Phase 9**) |
| Admin web UI | **Presentation client** on Nest `/v1` for login, orders, riders, customers, payments, wallet/COD read, earnings, inbox |
| App ↔ API ↔ Postgres | Customer, Rider, and Admin read/write through `/v1` where APIs exist. Fare/85/15/wallet/COD remain server-side. |
| Redis / object storage / FCM / payment provider | Not started. Rider GPS is **in-memory**, not Redis. Worker remains PostgreSQL `SKIP LOCKED`. |

---

## Completed

### Phase 0–7

- Audit, schema, NestJS foundation, health, JWT/session, OTP identity, admin login, profiles.
- Orders, stops, display IDs, fare quote/snapshot, state machine, offers, concurrent accept, create-order idempotency.
- Payments, 85/15/50 freeze from Trip Fare, cash/online transactions, finance snapshots.
- Rider wallet and COD Due ledgers; ₹100 NUMERIC suspension; settle-first recharge.
- In-app notifications, delivery outbox, PostgreSQL worker, unconfigured push provider.
- Routing provider (`mock` \| `google`); quote uses stored stops; rider location memory seam.

### Phase 8

- Flutter shared `/v1` client for Customer and Rider. Admin was plan-only.

### Phase 9 (this phase)

- Admin Nest JWT login/session/refresh/logout + profile role mapping.
- Hydrate orders/riders/customers/payments from `/v1`. Assign / cancel / canonical status hops.
- Wallet, COD, frozen earnings, payment transactions, notification inbox from stored backend values.
- New minimum list APIs: `GET /v1/admin/riders`, `GET /v1/admin/customers`, `GET /v1/admin/payments`, `GET /v1/admin/earnings` (finance-gated where required).
- Admin JS does not split 85/15/operations/profit for API orders; frozen snapshots are displayed.
- Remaining mock: KYC, payouts, coupons, vehicles/zones CRUD, invoices, campaign composer, Admin create-order, Admin wallet mutations, refunds.
- PostgreSQL and migrations unchanged. Flutter unchanged. Master Architecture unchanged.

---

## Verification (Phase 9)

| Command | Result |
|---|---|
| Admin `npm test` | **2 suites / 7 tests passed** |
| Admin `npm run lint` | **exit 0** (warnings only) |
| Admin `npm run build` | **exit 0** |
| Backend `tsc --noEmit -p tsconfig.build.json` | **exit 0** |
| Backend `npm test` | **16 suites / 58 tests passed** |
| Backend `npm run test:e2e` | **15 suites / 98 tests passed** |

---

## Blocked

| Slice | Blocker |
|---|---|
| Live OTP on a phone without SMS | Capture provider is in-process only (not HTTP). |
| Create-order without catalog UUIDs | No `GET /v1/cities` / vehicle-category list for Flutter. |
| Admin create order | `POST /v1/orders` is CUSTOMER-only. |
| Admin wallet credit / payout / refund | No mutation APIs. |
| Production push | FCM (or equivalent) vendor + device tokens |
| Production ONLINE PAID | Provider vendor + webhook; authorize vs capture **NEEDS BUSINESS DECISION** |
| Auto finance freeze | Production capture moment **NEEDS BUSINESS DECISION** |
| Production Google routing | Valid `GOOGLE_MAPS_API_KEY` + travel-mode product choice |
| Hot GPS | Redis deploy (seam exists; not implemented) |
| Production dispatch | SEARCHING TTL / radius / retry / broadcast vs sequential **NEEDS BUSINESS DECISION** |
| Admin login without a DB admin | Needs an `admin_profiles` row in Postgres |

---

## Needs business decision

Unchanged from Phase 7, still including OTP length/SMS vendor, invoice legal fields, cash-vs-online launch, capture moment, customer wallet, GPS retention, dispatch TTL, payout/withdraw, production push, Google travel mode, Redis GPS TTL.

---

## Next phase

**Stop after Phase 9.** Do not automatically begin Phase 10.

Likely later slices (not started): FCM production push, Redis GPS, payment provider, Google Maps production configuration, production deployment, remaining mock Admin screens only after APIs exist.
