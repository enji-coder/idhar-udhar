# ADMIN DATABASE INTEGRATION AUDIT

**Type:** Read-only pre-implementation audit  
**Date:** 2026-08-27  
**Scope:** Admin Panel + Admin NestJS APIs + local PostgreSQL  
**Not in scope:** Customer Flutter UI, Rider Flutter UI, schema redesign, business-rule changes  

Implementation after this audit is documented in `ADMIN_DATABASE_INTEGRATION_FINAL_REPORT.md`.

No application code was modified while producing this file.

---

## A. Current Architecture

```text
React Admin (IDHAR_UDHAR_ADMIN, Vite :5173)
        │  fetch + Bearer JWT
        │  VITE_API_BASE_URL = http://localhost:3000
        ▼
NestJS API (backend/, prefix /v1, PORT 3000)
        │  pg Pool (PostgresService)
        ▼
PostgreSQL 17  database `idhar_udhar`
        host localhost:5432
        user idhar_admin
        Docker container `idhar_udhar_postgres`

pgAdmin 4 (container `idhar_udhar_pgadmin`, http://localhost:5050)
        │  inspect only — not an application backend
        ▼
same PostgreSQL instance / same database `idhar_udhar`
```

### Admin Panel

- Path: `IDHAR_UDHAR_ADMIN/`
- React 19 + Vite 8 + React Router
- Login already calls `POST /v1/admin/auth/login`
- After login, `AdminLayout` hydrates orders / riders / customers / payments from NestJS
- Directory hydrate **does not** fall back to dummy rows on API failure (`hydrate.js` replaces stores with `[]` and `ErrorState` is shown)
- Several screens still read **localStorage entity stores** seeded from `src/data/*`

### Backend

- Path: `backend/`
- NestJS 11 modular monolith, global prefix `/v1`
- Database access is raw parameterized SQL via `pg` (`backend/src/database/postgres.service.ts`)
- Not TypeORM, not Prisma, not SQLite, not Firebase
- JWT access + hashed refresh in `sessions`
- `@Roles('ADMIN')` + `JwtAuthGuard` globally
- CORS: `CORS_ORIGIN` plus loopback origins in non-production (`backend/src/app.setup.ts`)

### PostgreSQL

| Item | Verified value |
|---|---|
| Container | `idhar_udhar_postgres` (Up) |
| Database | `idhar_udhar` |
| User | `idhar_admin` |
| Host / port | `localhost:5432` |
| SSL | false (local) |
| Migrations | 15 files in `records_database/migrations/`, 15 rows in `schema_migrations` |
| Canonical catalog table | `vehicle_categories` (plural). There is **no** table named `vehicle_category`. |

### pgAdmin

| Item | Value |
|---|---|
| Container | `idhar_udhar_pgadmin` (Up) |
| URL | http://localhost:5050 |
| Role | Database inspection only |

pgAdmin and NestJS both target the same local Docker Postgres. A row inserted by NestJS is the same row visible in pgAdmin.

### Environment

| File | Role |
|---|---|
| `backend/.env` / `records_database/.env` | `DATABASE_*`, JWT, OTP, CORS. Backend loads both (backend first). |
| `IDHAR_UDHAR_ADMIN/.env` | `VITE_API_BASE_URL=http://localhost:3000` |
| `IDHAR_UDHAR_ADMIN/.env.example` | Same variable name only |
| `backend/.env.example` | Documents `DATABASE_NAME=idhar_udhar`, CORS including Admin origins |

---

## B. Dummy Data Locations

### B1. Admin frontend — actual business-data mocks

| Path | What it seeds | Used as live business data? |
|---|---|---|
| `IDHAR_UDHAR_ADMIN/src/data/vehicleCategories.js` | 6 fake categories (Bike, Auto, Mini Truck, Tempo, Large Tempo, Truck) with `VC-1001`… IDs | **YES** — `vehicleCategoryStore` default + localStorage `iu_admin_vehicle_categories_v1` |
| `IDHAR_UDHAR_ADMIN/src/services/vehicleCategories.js` | localStorage CRUD; `syncVehicleCategories()` is a no-op `Promise.resolve()` | **YES** — Vehicle Categories screen never calls NestJS |
| `IDHAR_UDHAR_ADMIN/src/data/vehicles.js` | 9 fake fleet vehicles / RC numbers / rider names | **YES** — `vehicleStore` |
| `IDHAR_UDHAR_ADMIN/src/data/zones.js` | 7 fake Ahmedabad zones with invented rider/order counts | **YES** — `zoneStore` |
| `IDHAR_UDHAR_ADMIN/src/data/mockData.js` | Fake KPIs, orders, riders, customers, tickets, payouts, coupons, promotions, map pins, verification queue | Mixed: orders/riders/customers/payments stores are API-backed and **not** seeded; tickets/coupons/promotions/payouts/verification still are |
| `IDHAR_UDHAR_ADMIN/src/data/logisticsSeed.js` | Extra fake customers/riders/orders | Imported by `mockData.js` |
| `IDHAR_UDHAR_ADMIN/src/data/invoices.js` | Fake customer + purchase invoices | **YES** — invoice stores |
| `IDHAR_UDHAR_ADMIN/src/data/announcements.js` | Fake announcements | **YES** |
| `IDHAR_UDHAR_ADMIN/src/data/notifications.js` | Fake notification campaigns | Campaign composer only (inbox is API) |
| `IDHAR_UDHAR_ADMIN/src/data/earnings.js` | Fake earnings rows | Earnings page now prefers API; file still present |
| `IDHAR_UDHAR_ADMIN/src/data/wallet.js` | Fake wallet ledger | Wallet page prefers API; file still present |
| `IDHAR_UDHAR_ADMIN/src/data/adminAccounts.js` | Hardcoded admin emails/passwords | Settings “Admins & Access” local store; login is NestJS |
| `IDHAR_UDHAR_ADMIN/src/data/companyOffice.js` | Local office copy | Settings office tab (localStorage) |
| `IDHAR_UDHAR_ADMIN/src/services/stores.js` | Wires the seeds above into `createEntityStore` | Vehicles/zones/coupons/etc. persist to localStorage |
| `IDHAR_UDHAR_ADMIN/src/services/entityStore.js` | localStorage persist helper | If key exists, seed is skipped (stale dummy can linger) |
| `IDHAR_UDHAR_ADMIN/src/services/fareEngine.js` | `DEFAULT_FARE_BY_CATEGORY` + in-memory `publishFareVersion` | Fare numbers on category save never reach Postgres |
| `IDHAR_UDHAR_ADMIN/src/hooks/useMockLoader.js` | Fake 320ms loading delay | Vehicle Categories, Vehicles, Zones, and several mock pages |
| `IDHAR_UDHAR_ADMIN/src/services/vehicleCategories.js` `defaultVehicleCategoryName()` | Returns `'Bike'` when the list is empty | Dummy name fallback |

### B2. Netlify dummy catalog (not NestJS, not PostgreSQL)

| Path | Behavior |
|---|---|
| `IDHAR_UDHAR_ADMIN/netlify/functions/vehicle-categories.js` | In-memory / Netlify Blobs catalog. GET is public (`Access-Control-Allow-Origin: *`). PUT requires Netlify session cookie. Seeds the same 6 dummy categories. **Falls back to dummy if blob empty.** Admin `syncVehicleCategories()` does **not** currently call this function. |

### B3. Backend — not dummy business lists, but test leftovers in the live DB

There is **no** backend mock repository that returns fake vehicle categories to Admin. `CatalogRepository.findActiveVehicleCategory` reads `vehicle_categories` in PostgreSQL.

E2E helpers **insert** catalog rows into the **same** local database:

| Path | Effect |
|---|---|
| `backend/test/helpers.ts` `ensureOrderCatalog` / `upsertVehicleCategory` | Inserts `cities` AMD + TST, zones named `Phase 3 …`, `vehicle_categories` code `BIKE`, ACTIVE fare version (₹100 / ₹10/km) |

Those rows are still present (see §C / §D).

### B4. Legitimate non-business placeholders (do not treat as dummy records)

| Path | Why it stays |
|---|---|
| `src/data/navigation.js` | Sidebar labels |
| `src/config/theme.js`, `company.js` | Visual / letterhead copy |
| `src/components/orders/MockRouteMap.jsx`, Tracking map pins | Decorative map artwork, not a fleet table |
| `useMockLoader` on remaining no-table screens | Visual loading only |
| `admin-auth.service.ts` dummy argon2 hash | Timing-safe login when email is unknown — not a fake user |

### B5. Flutter (out of scope — recorded only)

Customer/Rider still have local catalogs (`idhar_udhar/lib/shared/vehicle_category/`). Booking uses `--dart-define=IU_VEHICLE_CATEGORY_ID`. **No Flutter files will be changed.**

---

## C. Existing Real APIs

Table names are taken from `records_database/migrations/` and live `\dt` on `idhar_udhar`.

| Feature | UI | Nest API | DB table(s) | Current Admin data source | Status |
|---|---|---|---|---|---|
| Login / session / profile | Yes | Yes `POST /v1/admin/auth/login`, `GET /v1/auth/session`, `GET /v1/admin/profile`, refresh, logout | `identities`, `admin_profiles`, `sessions` | NestJS JWT | Connected |
| Dashboard | Yes | Indirect via directory hydrate | `orders`, `rider_profiles`, `customer_profiles` | API stores | Connected (KPIs from live lists) |
| Live Operations | Yes | `GET /v1/admin/orders` | `orders` | API `orderStore` | Connected |
| Orders list / assign / cancel / status | Yes | Yes admin order GET + POST assign/cancel/status/offers | `orders`, `order_stops`, `order_status_events`, `order_offers` | API | Connected |
| Admin create-order modal | Yes | `POST /v1/orders` is **CUSTOMER-only** | `orders` | Local overlay | **No Admin create-order API** — do not invent a second create path |
| Riders directory | Yes | Yes `GET /v1/admin/riders`, `GET /v1/admin/riders/:id` | `rider_profiles`, `identities` | API | Read connected. Create/edit/delete still toast “not on server” (Riders page) |
| Customers directory | Yes | Yes `GET /v1/admin/customers`, `GET /v1/admin/customers/:id` | `customer_profiles`, `identities` | API | Read connected. Mutations toast “not on server yet” |
| Payments | Yes | Yes `GET /v1/admin/payments` | `payment_transactions` | API | Read connected. Refund has no API |
| Earnings | Yes | Yes `GET /v1/admin/earnings` | `order_finance_snapshots` | API | Read connected |
| Rider wallet / COD | Yes | Yes `GET /v1/admin/riders/:id/wallet|cod|ledger|earnings` | `rider_wallet_accounts`, `wallet_ledger_entries`, `rider_cod_accounts`, `cod_ledger_entries` | API | Read connected. Recharge/payout POST does not exist |
| Notifications inbox | Yes | Yes `GET /v1/notifications*` | `notifications` | API | Inbox connected. Campaign composer still mock |
| **Vehicle Categories** | **Yes** | **No Admin CRUD** | **`vehicle_categories`** + fare in **`fare_config_versions` / `fare_config_version_rates`** | **Frontend dummy + localStorage** | **Broken vertical slice — primary gap** |
| Vehicles | Yes | No | `vehicles` | Dummy `vehicles.js` | Table exists; UI fields (brand/model/insurance) are **not** in schema |
| Zones | Yes | No | `zones` (requires `cities.city_id`) | Dummy `zones.js` | Table exists; UI `area` / counts are **not** in schema |
| Fare config | Embedded on category form | No Admin publish API | `fare_config_versions`, `fare_config_version_rates` | `fareEngine.js` in-memory | Must publish version N+1; never UPDATE ACTIVE rates |
| Payment settings 85/15 | Settings tab | No Admin publish API | `payment_settings_versions` | localStorage + `commission.js` | Live DB already has ACTIVE 85/15 from e2e helper. **Do not change the 85/15 rule.** |
| Cancellation rules | Settings tab | No | `cancellation_config_versions`, `cancellation_config_version_rules` | localStorage | No Admin API |
| Company office | Settings tab | No | `company_office_versions` | localStorage | No Admin API |
| Invoices | Yes | No | `invoices`, `invoice_lines` | Dummy | Table exists; no Admin invoice API (legal/invoice product still pending) |
| Coupons / promotions | Yes | No | **No tables** | Dummy | Cannot invent tables |
| Support tickets | Yes | No | **No table** | Dummy | Cannot invent tables |
| Payouts batches | Yes | No | **No payout-batch table** | Dummy | Cannot invent tables |
| Announcements composer | Yes | No | **No campaign table** | Dummy | Cannot invent tables |
| Verification / KYC | Yes | No | `rider_documents`, `stored_files` | Dummy | Review API not built; do not invent |
| Tracking map tiles | Yes | Route GET exists | — | Decorative SVG pins | Keep artwork; not a data table |

### Vehicle category schema (authoritative)

From `records_database/migrations/0002_identity_geography_catalog.sql`:

`vehicle_categories (vehicle_category_id UUID PK, code TEXT NULL, name TEXT NOT NULL, active BOOLEAN, weight_capacity TEXT, size TEXT, created_at, updated_at)`

Fare amounts are **not** columns on that table. They live on `fare_config_version_rates` and are quoted from the single ACTIVE `fare_config_versions` row (`backend/src/fare/fare.repository.ts`).

Soft-delete is `active = false`. Hard delete is `ON DELETE RESTRICT` from `vehicles`, `orders`, `fare_config_version_rates`, `fare_quotes`, `order_fare_snapshots`.

---

## D. Problems Found

### D1. Vehicle Categories are not database-backed

1. Admin UI reads/writes `localStorage` (`vehicle_categories_v1`) seeded with 6 dummy rows.
2. `syncVehicleCategories()` does nothing.
3. NestJS has **no** `GET/POST/PATCH/DELETE /v1/admin/vehicle-categories`.
4. Creating “Bike” in Admin does **not** `INSERT` into PostgreSQL.
5. Refreshing the browser keeps the localStorage row even if Postgres is empty (or vice versa).
6. Netlify Blobs function is a **second fake catalog** and is not PostgreSQL.

### D2. Dummy name fallback

`defaultVehicleCategoryName()` returns `'Bike'` when zero categories exist. That violates “empty database must show no records / must not invent Bike”.

### D3. Local PostgreSQL is full of e2e leftovers

Verified 2026-08-27 against `idhar_udhar` (exact `count(*)`):

| Table | Rows | Classification |
|---|---:|---|
| `schema_migrations` | 15 | **KEEP** (structure) |
| `cities` | 2 | KEEP Ahmedabad/`AMD`. DELETE `Phase 3 Sequence City` / `TST` (e2e) |
| `zones` | 2 | Both named `Phase 3 … Zone` — dummy. DELETE |
| `vehicle_categories` | 1 | `BIKE` / Bike inserted by `upsertVehicleCategory` — dummy catalog. DELETE after dependents |
| `vehicles` | 0 | Already empty |
| `identities` | 1033 | Almost all e2e phones. KEEP only real Admin + fare-config FK owner |
| `admin_profiles` | 118 | KEEP `swiftsendinnovation@gmail.com`. KEEP `phase3-catalog-owner@example.test` only if `payment_settings_versions.created_by` still points at it (ACTIVE payload cannot change `created_by`) |
| `customer_profiles` | 296 | 294 named `Phase 1 Test Customer` — dummy. DELETE with orders |
| `rider_profiles` | 619 | e2e fixtures. DELETE with orders/wallets |
| `orders` | 860 | e2e orders (`IU-AMD-…` counter at 839, `IU-TST-…` at 21). Dummy. |
| `fare_config_versions` / `_rates` | 1 / 1 | e2e Bike rates ₹100 / ₹10. Dummy catalog fare. DELETE with category |
| `payment_settings_versions` | 1 | ACTIVE 85/15 — **KEEP** (locked financial configuration; no Admin publish API yet) |
| `sessions` | 1049 | e2e sessions. DELETE |
| `notifications` + deliveries | 2422 / 4844 | e2e. DELETE |
| `idempotency_keys` | 1472 | e2e. DELETE |

Real operator Admin (must survive cleanup): `swiftsendinnovation@gmail.com` / role `SUPER_ADMIN`.

### D4. Immutability blocks naive DELETE

`0014_immutability_and_integrity_triggers.sql` forbids DELETE on:

- `orders`
- `order_status_events`
- `order_fare_snapshots`
- `order_finance_snapshots`
- `payment_transactions`
- `order_payment_responsibilities` / `order_payment_plans`
- wallet/COD ledgers and wallet **accounts**
- `idempotency_keys`
- published fare **rates** (`cannot delete rates of a published fare version`)

Therefore emptying `vehicle_categories` **cannot** be a simple `DELETE FROM vehicle_categories` while 860 orders still reference it.

**Cleanup strategy (local-dev only):**

1. `pg_dump` backup of `idhar_udhar`.
2. In a single transaction, `ALTER TABLE … DISABLE TRIGGER USER` on the immutability triggers (FK system triggers stay).
3. Delete dependents in FK order, then dummy catalog/geo/identity rows.
4. `ENABLE TRIGGER USER`.
5. Verify tables, PKs, FKs, indexes, `schema_migrations` still exist.
6. Do **not** `TRUNCATE` the whole schema. Do **not** drop objects.

This is data cleanup of e2e leftovers, not schema destruction.

### D5. Frontend issues on already-connected screens

- Customers/Riders mutation buttons already refuse to persist locally (toast). Good.
- `AdminLayout` shows `ErrorState` on directory failure — does not inject dummy orders. Good.
- Vehicle Categories / Vehicles / Zones still use `useMockLoader` instead of a real request.
- Fake coupons/vehicles/zones/invoices still render as if they were production records.

### D6. Auth / CORS / env

- Admin JWT login is real. No CORS defect found for `http://localhost:5173`.
- `VITE_API_BASE_URL` is set. Production build throws if missing (`src/api/config.js`).
- Backend `PostgresService` uses `DATABASE_HOST/PORT/NAME/USER` from env — confirmed `current_database() = idhar_udhar`.

### D7. Validation / DTO

- Nest `ValidationPipe` is whitelist + forbidNonWhitelisted.
- Vehicle category write DTOs **do not exist yet**.

### D8. Schema change assessment

**No schema change is required** for Vehicle Categories.

Vehicles UI and Zones UI contain columns that do not exist in Postgres (`brand`, `insurance`, zone `area`, invented counts). Per Phase 18 this audit **stops** inventing those columns. Zones/vehicles APIs will persist only existing columns.

### D9. Business rules (locked — will not be changed)

- 85/15 on confirmed Trip Fare
- Fare quote formula already in `FareRepository` (GREATEST initial_minimum, GST 0)
- Publish fare = INSERT version N+1; never UPDATE ACTIVE/SUPERSEDED rate payloads
- UUID PK; display ids `IU-{CITY}-{10 digits}`
- Soft-delete vehicle categories via `active`

---

## Planned implementation (after this audit)

1. Backup + dependency-safe cleanup of dummy/e2e **business** rows. Preserve schema, migrations, Ahmedabad/`AMD`, real Admin login, ACTIVE 85/15 payment settings.
2. Add Admin vehicle-category CRUD on NestJS → `vehicle_categories`, publishing fare rates through `fare_config_versions`.
3. Wire Vehicle Categories screen to those APIs. Empty seed. No dummy fallback. Real loading/error/empty states.
4. Same pattern for Zones and Vehicles using **existing** columns only.
5. Stop seeding dummy coupons/invoices/tickets/etc. as if they were database records. Do not invent missing tables.
6. Do not modify any Flutter UI file.

---

## Verification targets for Vehicle Categories

| Test | Expected |
|---|---|
| Empty `vehicle_categories` | Admin table empty state (existing EmptyState copy) |
| Add Bike | `POST /v1/admin/vehicle-categories` → INSERT → row in UI and pgAdmin |
| Browser refresh | Bike remains |
| NestJS restart | Bike remains |
| Edit | PATCH + fare publish N+1 if rates change |
| Delete unused / deactivate if referenced | Matches schema RESTRICT + `active` |
| API down | ErrorState, **not** dummy Bike/Auto/… |
