# IDHAR UDHAR — PROJECT IMPLEMENTATION AUDIT

**Type:** Phase 0 repository audit (read-only inspection)  
**Date:** 2026-08-24  
**Scope:** Entire `CURSOR_PROJECT` repository as it exists today  
**Does not modify:** Application code, PostgreSQL schema, Master Architecture, locked business rules  

This report records **verified** current state. Nothing in this file is a new business rule.

**Authority order used:** `MASTER_SYSTEM_ARCHITECTURE.md` → finalized business decisions → `IMPLEMENTATION_BLUEPRINT.md` → schema specification / audit / implementation report → `TECHNICAL_DECISIONS.md` → existing application code.

---

## 1. Executive summary

IDHAR UDHAR is **not** a greenfield project. It is a **frontend + documentation + local PostgreSQL schema** repository.

| Layer | Verified state |
|---|---|
| Locked business rules | Present and encoded in docs + mock engines |
| Customer Flutter UI | Complete as a **local demo** |
| Rider Flutter UI | Complete as a **local demo** |
| Admin web UI | Complete as a **local demo** (Netlify-hosted) |
| PostgreSQL schema (local) | **Complete** — 15 migrations applied; 55 domain tables |
| Backend API (`/v1`) | **Does not exist** |
| App ↔ database wiring | **Does not exist** |
| Redis / workers / object storage | Documented only |
| Live payment provider | Not integrated |
| Push notifications (FCM) | Not integrated |
| Automated backend tests | None (Flutter has client-side rule tests) |

The next implementation work is **Phase 1 — backend foundation** (API + PostgreSQL connection). Do not rebuild UIs. Do not recreate the database. Do not change 85/15, GST = ₹0, wallet/COD separation, or resend formulas.

**No destructive database operation is required.**  
**No locked business rule conflicts with the schema.**  
**No production credential is required to start local API work.**

---

## 2. Audit method

Inspected (read-only):

- `records_database/` authoritative architecture, schema, migrations, `migrate.ps1`
- `idhar_udhar/` Flutter customer + rider apps, shared business engines, tests, env templates
- `IDHAR_UDHAR_ADMIN/` React admin, Netlify functions, mock stores
- `Project_Documentation/` (treated as **stale** where it conflicts with `records_database/`)
- Environment templates and gitignore (values of live `.env` files were not copied into this report)

Not assumed: a backend folder, Redis, payment SDK, Firebase, or API client. Each was searched and confirmed present or absent.

---

## 3. Repository layout

```text
CURSOR_PROJECT/
├── idhar_udhar/              Flutter monorepo (Customer + Rider Android flavors)
├── IDHAR_UDHAR_ADMIN/        React 19 + Vite 8 admin (mock + 4 Netlify functions)
├── records_database/         Architecture, SQL migrations, local DB ops
└── Project_Documentation/    Older product docs (superseded where they conflict)
```

There is **no** `backend/`, `api/`, `server/`, or equivalent application-server folder.

---

## 4. Existing architecture

### 4.1 Target (authoritative)

From `MASTER_SYSTEM_ARCHITECTURE.md` §5:

```text
Flutter Customer / Flutter Rider / Admin Web
        → HTTPS /v1 + future realtime
        → Modular monolith Backend API
              → PostgreSQL (source of truth)
              → Redis* (hot GPS, cache, rate limit)
              → Object storage* (KYC, POD, invoice PDF)
              → Workers* (notifications, PDF, webhooks, reports)
```

\* Redis, object storage, and workers are **ARCHITECTURE READY**. Master §5: Phase 1 may start with **API + PostgreSQL only**.

### 4.2 What is actually built

| Component | Status |
|---|---|
| Modular monolith API | Missing |
| PostgreSQL 17.11 local (`idhar_udhar`, container `idhar_udhar_postgres`) | Present, migrated |
| Redis | Missing |
| Object storage | Missing (`stored_files` metadata table exists) |
| Notification worker | Missing (tables exist) |
| Push provider abstraction | Missing |
| Payment provider adapter | Missing |
| Observability stack | Missing |
| Reporting warehouse / replicas | Missing (correct — not V1) |

### 4.3 Architecture docs vs operational fact

`MASTER_SYSTEM_ARCHITECTURE.md` and `IMPLEMENTATION_BLUEPRINT.md` still say PostgreSQL schema is “FUTURE / not implemented”. That is **stale**. `DATABASE_IMPLEMENTATION_REPORT.md` (2026-08-24) records successful local schema migration. This audit does **not** edit the Master file.

`records_database/README.md` still says “PostgreSQL is not implemented.” That is also stale.

`Project_Documentation/12_Firebase_Architecture.md` and `13_API_Strategy.md` describe Firestore + Cloud Functions. **Rejected** by ADR-001 / ADR-004. `records_database/` wins.

---

## 5. Existing applications

### 5.1 Flutter Customer + Rider (`idhar_udhar/`)

**Shape:** One Flutter package, **two Android product flavors** (not in-app role switching).

| App | Entry | Application ID |
|---|---|---|
| Customer | `lib/main.dart` → `lib/customer/customer_main.dart` | `com.idharudhar.idhar_udhar` |
| Rider | `lib/rider/rider_main.dart` | `com.idharudhar.rider` |

**Stack:** Flutter 3.x / Dart SDK `>=3.2.6`, Riverpod, GoRouter, Dio (almost unused).

**iOS:** No flavor/scheme split matching Android. Rider iOS packaging is incomplete.

**State:** Separate Riverpod trees. Customer: `sessionProvider`, `bookingDraftProvider`, `savedAddressesProvider`. Rider: dummy repository providers.

**Navigation:** Isolated GoRouters (`lib/customer/core/routing/`, `lib/rider/routing/`).

**Data:** Almost entirely mock.

- Customer: `lib/customer/core/data/mock/`
- Rider: `lib/rider/data/dummy/`
- Shared rules: `lib/shared/business/` (15 files)

**Only live HTTP call:**

`lib/shared/vehicle_category/vehicle_category_catalog.dart` →  
`https://idhar-udhar-admin.netlify.app/.netlify/functions/vehicle-categories`  
with a hardcoded fallback catalog (`VC-1001` Bike, etc.).

`AppConfig.apiBaseUrl` exists (`https://dev-api.idharudhar.local` / staging / production) and is **never used**.

**Tests (5 files):**

| File | What it covers |
|---|---|
| `test/business/scenario_a_to_h_test.dart` | Client fare / 85/15 / COD / resend / cancellation |
| `test/customer/booking_draft_test.dart` | Booking draft provider |
| `test/customer/drop_location_multi_test.dart` | Multi-drop |
| `test/customer/searching_rider_layout_test.dart` | UI layout |
| `test/widget_test.dart` | Minimal boot |

No API, auth, or rider integration tests. Financial tests run against **Dart `double`**, not `NUMERIC`.

**Declared but unused in `lib/`:** `hive`, `flutter_secure_storage`, `connectivity_plus`, `logger`, `get` (GetX), Freezed codegen (no generated files).

### 5.2 Admin web (`IDHAR_UDHAR_ADMIN/`)

**Stack:** React 19, Vite 8, Tailwind 3, React Router 7. No test suite.

**Pages (routed):** Login, Dashboard, Live Operations, Orders, Tracking, Riders, Customers, Verification (KYC), Payments, Earnings, Payouts, Coupons, Promotions, Notifications, Support, Reports, Settings, Profile, Vehicles, Vehicle Categories, Wallet, Zones, Invoices, Purchase Invoices, Announcements.

**Data:** `localStorage` entity stores (`src/services/entityStore.js`, `stores.js`) + seed mock files (`src/data/`). Fake loader delay `useMockLoader.js`.

**Auth:** See §9. Hybrid Netlify cookie (Super Admin) + client-only sub-admin.

**Deployment:** Netlify (`netlify.toml`) — SPA redirect `/*` → `index.html`. Functions in `netlify/functions/`.

**Invoice PDF:** Browser `html2canvas` (`invoiceService.js`). Not object storage. Not a worker.

---

## 6. Existing backend

**There is no modular backend.** Searched the repo for Express, Nest, FastAPI, Flask, Django, Spring, Prisma, Drizzle, Knex, SQLAlchemy, Redis clients, and `/v1` route handlers. None exist as runnable servers.

What exists instead:

| Location | Role |
|---|---|
| `IDHAR_UDHAR_ADMIN/netlify/functions/admin-login.js` | Super Admin login |
| `IDHAR_UDHAR_ADMIN/netlify/functions/admin-session.js` | Session check |
| `IDHAR_UDHAR_ADMIN/netlify/functions/admin-logout.js` | Logout |
| `IDHAR_UDHAR_ADMIN/netlify/functions/lib/session.js` | HMAC cookie `iu_admin` (8h) |
| `IDHAR_UDHAR_ADMIN/netlify/functions/vehicle-categories.js` | GET public / PUT cookie-gated catalog (Netlify Blobs) |
| `idhar_udhar/secrets/backend/.env.example` | Placeholder for a future backend — no code |

These four functions are **not** the production API. They must not become the financial write path.

---

## 7. Existing APIs

| Surface | Status |
|---|---|
| Planned contract `records_database/06_API_CONTRACT_BLUEPRINT.md` | Documentation only. Prefix **`/v1`** is **FINAL**. |
| `POST /v1/auth/otp/request` and remaining catalog | Not implemented |
| Netlify `/.netlify/functions/admin-*` | Live for Admin Super Admin login |
| Netlify `/.netlify/functions/vehicle-categories` | Live; consumed by Flutter |
| Flutter `Dio` API client / interceptors / auth headers | Missing |
| Admin REST client for orders/payments/wallet | Missing |

Error format in the blueprint (`{ "error": { "code", "message" } }`) is designed, not implemented.

---

## 8. Existing database integration

### 8.1 Local PostgreSQL (verified by `DATABASE_IMPLEMENTATION_REPORT.md`)

| Item | Value |
|---|---|
| Engine | PostgreSQL **17.11** |
| Database | `idhar_udhar` |
| Container | `idhar_udhar_postgres` |
| Port | 5432 |
| Volume | `idhar_udhar_postgres_data` (must not be deleted) |
| Runner | `records_database/migrate.ps1` |
| Migrations | **15/15** applied; re-run idempotent |
| Public tables | **56** (55 domain + `schema_migrations`) |
| Indexes | **182** |
| Foreign keys | **102** (0 CASCADE; 1 SET NULL on `vehicles.rider_profile_id`) |
| CHECK | **114** |
| UNIQUE | **35** |
| User triggers | **49** |
| Deferred constraint triggers | **4** |
| Extension | `pgcrypto` |

Credentials are read from `records_database/.env`. SQL does not hardcode passwords. **This audit did not recreate, drop, or migrate the database.**

### 8.2 Application integration

**None.** No `pg` pool, no ORM, no repository. Admin `.env` may contain `DATABASE_*` names; Admin JS does not use them.

Flutter never connects to PostgreSQL.

### 8.3 Schema coverage (locked domains)

Present: identities, OTP challenges, sessions, customer/rider/admin profiles, cities/zones, vehicle categories, versioned fare/payment/cancellation/COD/office/extra-rate configs, vehicles/KYC/files/bank/UPI, rider wallet + ledger, COD accounts + ledger, orders/stops/events/offers, fare quotes + snapshots, payment responsibility/plan/transactions, finance/cancel/fail/resend snapshots, invoices/lines, ratings, notifications + preferences + deliveries, audit logs, idempotency keys, isolated customer wallet tables.

Intentionally omitted: GPS breadcrumb history table (Redis is hot GPS; retain policy open).

---

## 9. Existing authentication

| Actor | Current implementation | Production target |
|---|---|---|
| Customer | Dummy OTP: **any 4 digits** accepted (`session_provider.dart`). Session JSON in SharedPreferences. | Server OTP + hashed challenge (`otp_challenges`) |
| Rider login | Phone-only dummy; skips OTP | Server OTP |
| Rider registration OTP | Hardcoded dummy code in `dummy_rider_data.dart` | Server OTP |
| Admin Super Admin | Netlify function + HMAC cookie; env `ADMIN_EMAIL` / `ADMIN_PASSWORD` | `admin_profiles.password_hash` + API sessions |
| Admin Sub Admin | Client-only check against committed password in `src/data/adminAccounts.js` | Server auth + RBAC |

Firebase Auth: **not present**. `firebase_placeholder.dart` only. No `google-services.json`, no `firebase_options.dart`, no FlutterFire deps.

`flutter_secure_storage` is declared and unused. Tokens are not issued.

**FINAL architecture decision:** custom server auth. Firebase is not the production database (ADR-001, Master §34.4). FCM may be used later for push only.

---

## 10. Existing notifications

| Capability | Status |
|---|---|
| In-app inbox UI | Placeholder empty states (“demo”) |
| `notifications` / `notification_preferences` / `notification_deliveries` tables | Present in PostgreSQL |
| Notification worker | Missing |
| Push provider (FCM or other) | Missing (`firebase_messaging` not in pubspec) |
| Unread/read persistence | Schema ready; apps do not use it |
| Preferences API | Missing |
| Admin campaign composer | Mock UI only (`pages/Notifications.jsx`) |

Do not treat Admin local notification campaigns as production delivery.

---

## 11. Existing payment, wallet, COD, invoice

### 11.1 Client mock engines (rules encoded, not authoritative)

Flutter `lib/shared/business/`:

| File | Encodes |
|---|---|
| `fare_engine.dart` / `fare_config.dart` | Server-intended fare quotes; **GST always 0** |
| `finance.dart` | 85/15 on Trip Fare; operations = 50% of company share |
| `payment.dart` | Customer / Receiver / Split; multiple UNPAID txn rows |
| `cod.dart` | COD Due separate; suspend at **₹100**; settle-first |
| `cancellation.dart` | Admin-configured; default ₹0 |
| `failed_delivery.dart` | Case A/B money formulas |
| `idempotency.dart` | Client helper only |

Admin JS mirrors: `fareEngine.js`, `commission.js`, `codWallet.js`, `cancellationRules.js`, `failedDelivery.js`, `invoiceService.js`, `paymentPlan.js`.

These engines are **discovery implementations**. Production must re-implement in the API using `NUMERIC`, transactions, and the existing snapshot tables. Do not keep Flutter as the financial authority.

### 11.2 Real payment

None. No Razorpay/Stripe/UPI SDK. Customer wallet screen states demo / no charge. Booking keeps online amounts **UNPAID** in the mock (correct posture). Rider wallet add/withdraw mutates local Riverpod state.

### 11.3 Invoice

Flutter: boolean `invoiceSent` flag. No PDF.  
Admin: client-generated PDF + placeholder GSTIN/CIN/PAN in `src/config/company.js`. Statutory identifiers are a **NEEDS BUSINESS DECISION** and must not be treated as locked production identity.

---

## 12. Existing deployment configuration

| Asset | Present? |
|---|---|
| Admin Netlify (`netlify.toml`) | Yes |
| Docker Compose / Dockerfiles in repo | No |
| GitHub Actions | No |
| `firebase.json` | No |
| Manual Postgres `docker run` notes | `records_database/DEVELOPER_NOTE/database_note.txt` |
| `migrate.ps1` | Yes |
| Flutter release signing | Release uses **debug** signing (`android/app/build.gradle`) |
| `records_database/.env.example` | **Missing** (live `.env` is local-only) |

Production posture in architecture: managed PostgreSQL, env-based connection, PITR, migrations-only schema change. **Not implemented.**

---

## 13. Completed components

- Locked V1 business rules (85/15, GST ₹0, payment split, COD, resend Case A/B formulas, display ID format, max 3 drops, cancellation default ₹0, versioned config)
- Customer, Rider, and Admin **UI shells** and navigation (themes/product identity — do not redesign)
- Shared mock rule engines + Flutter scenario tests
- Local PostgreSQL schema, constraints, immutability triggers, display-id allocator
- Migration runner with checksum history
- Admin vehicle-category Netlify function (temporary catalog bridge)
- Architecture documentation under `records_database/`

---

## 14. Partial components

| Component | What exists | What is missing |
|---|---|---|
| Authentication | Dummy OTP + Admin cookie login + DB tables | Server OTP, hashing, rate limit, sessions API |
| Orders | Full mock lifecycle in three apps + DB tables | Canonical server state machine |
| Fare | Client engines + versioned fare tables | Server fare engine writing quotes/snapshots |
| Payments | Model in schema + mock UNPAID rows | Transactional API, webhooks, provider |
| Wallet / COD | Client engines + ledgers in DB | Server ledger posts, suspend enforcement |
| Invoices | Admin HTML/PDF demo + invoice tables | Worker, object storage, immutable issue API |
| Notifications | UI placeholders + three tables | Worker, provider, inbox API |
| KYC | Rider screens + Admin queue + `stored_files` | Upload, review API, signed URLs |
| Vehicle categories | Netlify Blobs + Flutter fetch + DB table | API as single writer; stop dual sources |
| Admin RBAC | Client `permissions.js` | Server enforcement mapped to `admin_profiles` |
| Config versions | Admin localStorage sliders + DB version tables | Publish API that never mutates used versions |
| Tests | Flutter rule tests | Server financial/concurrency/idempotency tests |

---

## 15. Missing components

Backend foundation: process, config, logging, error standard, health checks, `/v1` router, connection pool.

Domain APIs: auth, identity, profiles, KYC, vehicles, orders, stops, fare, dispatch/offers, payments, wallet, COD, cancel, failed delivery, resend, invoices, ratings, notifications, admin config, audit reads.

Infrastructure: Redis, object storage, background workers, push provider adapter, payment provider adapter, PgBouncer, observability (structured logs, metrics, request IDs), backups/PITR runbooks, CI.

Flutter/Admin: API clients, token storage, replacement of mock stores **without UI redesign**.

---

## 16. Conflicting components

Do **not** silently merge these. Higher authority wins.

| Topic | Conflict | Resolution |
|---|---|---|
| Schema status | Master/Blueprint/README: not implemented vs `DATABASE_IMPLEMENTATION_REPORT.md`: migrated | Operational fact: schema **exists locally**. Do not recreate. |
| Firebase | `Project_Documentation/12` Firestore vs ADR-001 reject | Custom API + PostgreSQL |
| API style | `13_API_Strategy.md` Cloud Functions vs `06_API_CONTRACT_BLUEPRINT.md` `/v1` | `/v1` REST |
| Invoice tax | Historical `08_PAYMENT_FINANCIAL_ARCHITECTURE.md` 5% vs locked GST ₹0 | GST = ₹0 |
| Online “finalized” | `18` footer V1 online+cash vs `18` §E cash-first launch still open | **Model** supports both; **day-one enablement** is open |
| Resend split leftover | Leftover `18` §M “requires decision” vs V1 rules ₹10/₹8/₹2 | Trust V1 rules / Master §4 |
| Display ID | ADR-015 “IU vs IU-AMD open” vs implemented `IU-{CITY}-{10 digits}` | Schema + locked rule: `IU-AMD-0000000001` form |
| Vehicle catalog | Netlify Blobs vs `vehicle_categories` table | PostgreSQL must become source of truth |
| Statutory letterhead | Admin `company.js` GSTIN/CIN/PAN vs “do not invent GSTIN” | Mock UI only; not a business lock |
| Money type in clients | Dart/JS `double` vs DB `NUMERIC(12,2)` | Server uses decimal; clients display only |
| Phase numbering | This prompt’s Phases 0–10 vs Blueprint L Phases 0–6 | See §21 mapping. Schema Blueprint Phase 0 is **done**. |

Leftover `18` sections C / D / L / M and `04`/`05` single-payment models remain **rejected** (Master §3).

---

## 17. Dangerous components

These are demo/local risks. Do not ship them. Do not copy secrets into new docs.

1. **Client-side financial authority** — 85/15, COD, cancellation, resend computed in Flutter/Admin JS with no server enforcement.
2. **Customer accepts any 4-digit OTP.**
3. **Rider registration OTP hardcoded** in dummy data.
4. **Committed Sub Admin password** in `IDHAR_UDHAR_ADMIN/src/data/adminAccounts.js`.
5. **Admin session HMAC key = `ADMIN_PASSWORD`** (`netlify/functions/lib/session.js`).
6. **Sub-admin auth never hits a server** (`sessionStorage`).
7. **Vehicle-categories GET is public** with `Access-Control-Allow-Origin: *`.
8. **Synthetic KYC fields** when missing (`profileEnrichment.js`) — misleading if mistaken for real KYC.
9. **Placeholder GSTIN/CIN/PAN/bank account** in `IDHAR_UDHAR_ADMIN/src/config/company.js` — must not become production statutory identity without a business decision.
10. **Local DB credentials** documented in `DEVELOPER_NOTE/database_note.txt`. Treat as local-only; do not publish.
11. **Flutter release builds signed with debug keys.**
12. **No parameterized API yet** — future SQL must stay parameterized (schema is ready; API is not).

No production Firebase keys or payment secrets were found in tracked application source. `.env` files are gitignored except `.env.example`.

---

## 18. Duplicate implementations

| Concern | Copies |
|---|---|
| Financial rules | Dart `lib/shared/business/` + Admin JS services + PostgreSQL CHECKs/triggers |
| Vehicle categories | Flutter fallback list + Netlify Blobs + `vehicle_categories` table |
| Auth/session | Customer SharedPreferences, Rider prefs, Admin sessionStorage, Netlify cookie, unused `sessions` table |
| OTP UI | Customer and Rider separate screens/widgets |
| Order models | `MockOrder`, `rider_order.dart`, Admin mock orders — incompatible enums (ADR-008) |
| Wallet | Customer dummy balance, Rider dummy finance, Admin `riderWallet.js` / `codWallet.js`, DB ledgers |
| Glass/theme widgets | Customer `core/` vs `shared/` facades |

**Intentional (keep):** separate Customer and Rider apps/themes; shared `lib/shared/business/` as a **reference** until the server engine exists.

Production rule: **one server implementation**. Clients display server results. Mock engines remain until each screen is wired; they must not stay authoritative.

---

## 19. Environment configuration

| File | Role |
|---|---|
| `records_database/.env` | Local Postgres (gitignored). Used by `migrate.ps1` |
| `IDHAR_UDHAR_ADMIN/.env` | `ADMIN_EMAIL`, `ADMIN_PASSWORD`; unused `DATABASE_*` may be present locally |
| `IDHAR_UDHAR_ADMIN/.env.example` | Admin email/password names only |
| `idhar_udhar/.env.example` | `APP_ENV`, `API_BASE_URL`, `API_KEY`, `SECRET_KEY` — not loaded at runtime |
| `idhar_udhar/secrets/{customer,rider,backend,firebase}/.env.example` | Templates |

**Gap:** no `records_database/.env.example`. Should be added in Phase 1 (variable **names** only).

Flutter does not load dotenv. Environment is hardcoded `development` in `customer_main.dart`.

---

## 20. Business decision register

Search covered Master, Blueprint, `18_FINAL_BUSINESS_DECISIONS.md`, `OPEN_QUESTIONS.md`, `TECHNICAL_DECISIONS.md`, `DATABASE_IMPLEMENTATION_REPORT.md`, `RULES_BOOK.md`, ADRs.

### 20.1 FINAL (do not reopen)

| Item | Decision |
|---|---|
| Financial model | Trip Fare base; Rider 85%; Company 15%; Operations 50% of company share; remainder profit |
| GST | ₹0 on fare. Do not calculate 85/15 from invoice grand total |
| Historical snapshots | Immutable; reversals are new rows |
| Payment model | WHO PAYS ≠ HOW THEY PAY; Customer / Receiver / Split; multiple transactions; UNPAID / PARTIALLY_PAID / PAID aggregates; txn lifecycle separate; refund = new row |
| Wallet vs COD | Separate ledgers; wallet ≥ 0; COD Due ≥ ₹100 suspends new accepts; settle-first |
| Order IDs | UUID PK; unique `IU-{CITY}-{10 digits}` |
| Max drops | 1 pickup + 1..3 drops |
| Resend Case A | Original ended: current base fare + ₹10/km; normal 85/15 |
| Resend Case B | Original not ended: customer ₹10/km, rider ₹8/km, company ₹2/km; not 85/15 |
| Cancellation | Default ₹0 until Admin configures; not auto 85/15 |
| Config | Versioned; published payload must not mutate historical orders |
| API version | `/v1` |
| Auth shape | Custom server OTP (customer/rider); Admin password hash; Firebase not production DB |
| Backend shape | Modular monolith; apps are clients |
| Database | PostgreSQL system of record; money `NUMERIC(12,2)` already chosen |
| Receiver app | Not required |
| Auto second live trip | Forbidden |
| Customer wallet auto-debit | **Not required for V1 booking** (tables isolated; `wallet_enabled` default false) |
| Offer accept | One winner; `SELECT FOR UPDATE` / unique accept |
| Notification schema | Inbox + preferences + deliveries; no V1 chat |
| Hot GPS | Redis last point, not 1 Hz Postgres |

### 20.2 NEEDS BUSINESS DECISION (do not invent)

Continue unrelated work. Use safest neutral structure noted.

| Item | Why it affects implementation | Neutral structure until decided |
|---|---|---|
| OTP length (4 vs 6), SMS vendor, expiry minutes, max attempts, lockout | Auth UX + challenge columns | Configurable policy; hash only; 30s resend cooldown is already locked |
| Invoice legal series, GSTIN, SAC, CIN, e-invoice IRN | Statutory PDF/letterhead | Store nullable metadata; fare GST stays 0; do not copy mock `company.js` into production invoices |
| Cash-only first launch vs online enabled | Which payment methods Admin publishes | Schema supports both; default published policy can keep online off until confirmed |
| Authorize-at-booking vs capture-at-delivery | Payment adapter | Online stays UNPAID until verified provider callback; no fake PAID |
| Close failed delivery **without** resend | Terminal status / fee | Do not invent status or fee; keep failed-delivery + optional resend path |
| GPS breadcrumb retention days | Whether to add a history table | Table omitted; Redis hot point later |
| Rating: rider→customer in V1, edit, public comments | Ratings API | Persist customer→rider; extra directions/edits gated |
| Admin **manual** second live trip | Assign API | Reject automatic; manual assign flag off until decided |
| Staff RBAC cells beyond Master §8.2 | Admin authorization matrix | Enforce §8.2 minimums; extra modules remain configurable flags |
| SEARCHING TTL / dispatch retries / offer timeout | Dispatch worker | Keep searching until cancel or Admin assign; 3s/27s UI timers are demo |
| Pickup/drop contact required? | Booking validation | Keep nullable; do not block booking |
| 85/15 paise on non-even rupees | Exact freeze amounts | Engine stores already-rounded `NUMERIC(12,2)`; document when product picks a tie-break |
| Payment vendor | Webhook adapter | Adapter interface; no vendor lock-in in Phase 1 |
| Fare quote TTL minutes | Quote expiry | Short TTL column exists; minutes configurable |
| RPO/RTO minutes | Ops backup policy | PITR required; minutes later |

### 20.3 TECHNICAL DESIGN OPTIONS (engineering may pick)

These are **not** business rules. Phase 1 will lock the ones required to start the API.

| Item | Master status | Audit recommendation (Phase 1) |
|---|---|---|
| Backend language | “Node or similar” (ADR-004) | **TypeScript + NestJS** modular monolith; `pg` against existing SQL migrations (do not replace migrations with an ORM schema owner) |
| Session transport + TTL | JWT vs cookie | Customer/Rider: Bearer **access JWT** + **rotating refresh** hashed in `sessions`. Admin API: same Bearer model (cookie wrapper can be added later for the SPA). Exact minute values stay configurable. |
| Case A/B runtime row shape | Child order vs related record | Keep both columns; implement Case A as child order with `parent_order_id` when that phase starts (conceptual preference; not a fee change) |
| Notification scope | Identity vs profile | Inbox keyed by `identity_id` as schema already allows; optional profile FKs |
| Worker/queue product | Redis streams vs SQS | Defer to Redis/worker phase; Phase 1 has no workers |
| Object storage vendor | S3-compatible | Defer until files/KYC/invoice PDF phase |

OTP **policy numbers** remain business-owned; the API will expose them as configuration, not hardcoded product law.

---

## 21. Phase mapping

Two phase lists exist. This project will execute the **granular** order from the master implementation prompt, with Blueprint L as the architecture grouping.

| Granular phase (this program) | Blueprint L | Current status |
|---|---|---|
| 0 Repository audit / decision discovery | (implied) | **This document** |
| — Physical schema | Phase 0 | **COMPLETE** (local) |
| 1 Backend foundation (config, DB pool, logging, errors, authz skeleton) | Start of Phase 1 | **NEXT** |
| 2 Identity, profiles, KYC, vehicles | Phase 1 | Not started |
| 3 Orders, stops, fare, dispatch, offers, state machine | Phase 1 | Not started |
| 4 Payments, wallet, COD, snapshots, idempotency | Phase 1 | Not started |
| 5 Cancel, failed delivery, resend, invoice, ratings | Phase 2 | Not started |
| 6 Notifications + worker + push abstraction | Phase 3 | Not started |
| 7 Admin config, reporting, audit tools | Phase 3 | Not started |
| 8 Redis, realtime, background jobs, scheduling | Phase 4 | Not started |
| 9 Testing, security, performance, concurrency | Cross-cutting; intensify here | Flutter rule tests only |
| 10 Deployment, backups, monitoring, scale path | Phases 5–6 + ops | Netlify Admin only |

Blueprint Phase 1 “modular core” is **too large for one uncontrolled coding pass**. It will be delivered as granular phases 1–4 without splitting microservices.

---

## 22. Recommended implementation order (immediate)

1. **Do not** touch PostgreSQL schema, Docker volume, Flutter themes, or Admin visual identity.
2. **Do not** implement orders/payments until the API process, config, and auth foundation exist.
3. Create a backend package (recommended path `backend/` at repo root) as a NestJS modular monolith.
4. Connect **read-only health** to existing `idhar_udhar` using `records_database/.env` variable names — no new migration unless a genuine gap appears.
5. Implement `/v1` error standard, request IDs, structured logs, `/health`.
6. Then authentication foundation (OTP challenge hash + Admin password verify against `admin_profiles` once seed/admin bootstrap exists).
7. Only after that: identity APIs, then orders, then money.

SMS provider, payment vendor, and Redis are **not** blockers for Phase 1 local foundation. Use a pluggable OTP sender (log/dev sink first). Never store raw OTP. Never fake online PAID.

---

## 23. Technical blockers

| Blocker | Severity | Notes |
|---|---|---|
| No backend process | **Hard** — next work | Phase 1 |
| Apps do not speak PostgreSQL | **Hard** | Solved by API, not by opening DB to Flutter |
| Dual vehicle catalog | Medium | Replace Netlify Blobs after catalog API exists |
| OTP SMS vendor unknown | Low for local | Dev sender; production vendor is a business/ops pick |
| Payment vendor unknown | Blocks **live ONLINE PAID** only | Cash + UNPAID online can proceed |
| Unresolved product items in §20.2 | Do not block Phase 1 | Neutral structures listed |

**Not blockers:** locked money rules, schema completeness, UI completeness.

---

## 24. Exact next implementation phase

**Phase 1 — Backend foundation**

Inspected and required:

- NestJS + TypeScript modular layout (controllers, services, repositories, validation, errors)
- Env-based PostgreSQL pool to the **existing** database
- `/v1` prefix, health, structured logging, request ID, safe error JSON
- AuthN/AuthZ skeleton (guards, roles CUSTOMER / RIDER / ADMIN) without rewriting UIs
- `.env.example` files for backend and `records_database` (names only)
- `BACKEND_ARCHITECTURE.md` + update `IMPLEMENTATION_STATUS.md`

Out of scope for Phase 1: order booking, fare engine port, wallet posts, Redis, Flutter rewiring, new SQL migrations unless a connection/bootstrap table is truly required (it is not expected).

---

## 25. Files this audit created

| File | Action |
|---|---|
| `records_database/PROJECT_IMPLEMENTATION_AUDIT.md` | Created (this file) |
| `records_database/IMPLEMENTATION_STATUS.md` | Created |

No application, migration, or Master Architecture files were modified.

---

**End of PROJECT IMPLEMENTATION AUDIT**
