# ADMIN FINAL DATABASE AND FUNCTIONAL AUDIT

Date: 2026-08-27  
Scope: Admin Panel + NestJS + local PostgreSQL cleanup and verification  
Not in scope: Customer Flutter UI, Rider Flutter UI, schema redesign, business-rule changes

---

## Architecture Found

```text
IDHAR_UDHAR_ADMIN  (React 19 + Vite)
        │  fetch + Bearer JWT
        │  VITE_API_BASE_URL = http://localhost:3000
        ▼
NestJS modular monolith  (backend/, prefix /v1, port 3000)
        │  pg Pool (PostgresService)
        ▼
PostgreSQL 17.11  database idhar_udhar
        host localhost:5432  user idhar_admin
        Docker container idhar_udhar_postgres

pgAdmin 4  (idhar_udhar_pgadmin, http://localhost:5050)
        inspect-only — same PostgreSQL instance
```

- Admin login: `POST /v1/admin/auth/login` → `admin_profiles` / `sessions`.
- Directory hydrate: orders, riders, customers, payments, vehicle categories, vehicles, zones from NestJS. Failure replaces stores with `[]` and shows `ErrorState`. No dummy fallback.
- Vehicle categories: `GET/POST/PATCH/DELETE /v1/admin/vehicle-categories` → table `vehicle_categories`. Fare amounts are published as version N+1 into `fare_config_versions` / `fare_config_version_rates` (never UPDATE of ACTIVE rate payloads).
- Customers: `GET /v1/admin/customers` and `GET /v1/admin/customers/:id` → `customer_profiles` joined to `identities`. No Admin POST.
- Customer app registration: phone OTP (`OtpService` → `IdentityRepository.ensureCustomerProfile`). Table is `customer_profiles`, not a separate admin customer table.
- Migration `0014_immutability_and_integrity_triggers.sql` installs `protect_published_fare_rates` / `fare_rates_protect_published` (row DELETE of ACTIVE/SUPERSEDED rates is refused) and `protect_published_config` (published payloads cannot return to DRAFT).

No schema, migration, FK, index, or trigger was dropped, disabled, or rewritten.

---

## Database Cleanup

### Before this session

Live catalog contained only e2e leftovers:

| Object | Rows | Classification |
| --- | ---: | --- |
| `vehicle_categories` | 2 | `E2E Fare 1787811261617`, `E2E Fare 1787811267557`, both `active=false` |
| `fare_config_versions` | 2 | version 1 SUPERSEDED, version 2 ACTIVE |
| `fare_config_version_rates` | 3 | published ₹79 test rates copied across versions |
| `identities` / `admin_profiles` | 4 / 4 | 2 real keepers + 2 `p2-admin-…@example.test` e2e owners |
| `orders`, `vehicles`, `fare_quotes`, `order_fare_snapshots`, `resend_snapshots` | 0 | no historical business dependents |
| `customer_profiles`, `rider_profiles`, `zones` | 0 | already empty |

### Dependency chain

```text
E2E Vehicle Category
        ↓  fare_rates_category_fk  ON DELETE RESTRICT
Published Fare Configuration (ACTIVE / SUPERSEDED)
        ↓  fare_rates_version_fk  ON DELETE RESTRICT
Published Fare Rate
        ↓  (no incoming FKs)
```

Row `DELETE` on those rates is correctly blocked by `fare_rates_protect_published` while the parent version is ACTIVE or SUPERSEDED. Demoting ACTIVE → DRAFT is blocked by `protect_published_config`. That is the 0014 architecture working as designed — not a defect.

### Safe development cleanup (triggers left enabled)

Strategy used, after proving zero historical dependents and that remaining category names were only `E2E Fare %` / `E2E Bike %`:

1. Backup: `records_database/backups/idhar_udhar_pre_e2e_fare_cleanup_20260827.dump`
2. `TRUNCATE fare_config_version_rates`  
   TRUNCATE does not fire FOR EACH ROW DELETE triggers and does **not** disable or drop `fare_rates_protect_published`.
3. `DELETE FROM fare_config_versions` (no DELETE trigger on that table)
4. `DELETE FROM vehicle_categories` for the E2E names
5. Delete leftover `p2-admin-…@example.test` sessions / admin_profiles / identities

Script: `records_database/cleanup_e2e_published_test_fares.sql`

Not used: `DISABLE TRIGGER`, `DROP TRIGGER`, FK drops, `ON DELETE CASCADE`, or any edit to migration 0014.

### Dummy records removed

| Record | Action |
| --- | --- |
| 2 × E2E Fare vehicle categories | deleted |
| 2 × fare_config_versions (test) | deleted |
| 3 × fare_config_version_rates (test) | truncated |
| 2 × p2-admin e2e identities / admin_profiles | deleted |

### Kept (required)

| Object | After |
| --- | --- |
| `schema_migrations` | 15 files, all present |
| `cities` | 1 (`AMD` / Ahmedabad) |
| `payment_settings_versions` | 1 ACTIVE **85/15** |
| `identities` / `admin_profiles` | `swiftsendinnovation@gmail.com`, `phase3-catalog-owner@example.test` (FK owner of published 85/15; cannot be deleted without changing published payment settings) |
| `order_display_counters` | AMD, `last_seq = 0` |

### Verification result

| Check | Result |
| --- | --- |
| `vehicle_categories` | 0 |
| `fare_config_versions` / `_rates` | 0 / 0 |
| `orders`, `customers`, `riders`, `zones`, `vehicles` | 0 |
| `fare_rates_protect_published` / `fare_config_protect_published` | enabled (`tgenabled = O`) |
| `protect_published_fare_rates` function md5 | unchanged `32da4ea9a38b6094627e402347b5ce10` |
| User triggers | 49 |
| Foreign keys | 102 |
| Indexes | 182 |
| Public tables | 56 |
| Migrations | 15 |
| Orphan E2E categories | none |

Admin Panel and PostgreSQL now agree on an empty catalog: **No records found**.

---

## Vehicle Category

### Fresh category deletion

```text
POST category with no fare amounts
  → INSERT vehicle_categories only
  → DELETE → 200
  → row removed from PostgreSQL
```

Verified in e2e this session (DELETE 200, subsequent SELECT empty).

### Protected category behavior

```text
POST category with rates
  → publish ACTIVE fare_config_versions + fare_config_version_rates
  → DELETE → 409 VEHICLE_CATEGORY_IN_USE
  → PATCH active=false (deactivate) → 200
```

Application `usage.fare_rates` is included in `inUse()`. That is correct: published rates **are** a protected dependency under 0014. The service was not weakened.

### Migration 0014 status

Intact. Triggers enabled. Function bodies unchanged. No ALTER of the migration file.

### Double-plus icon fix

Cause: `Button` already renders the `icon` prop. The empty-state action still used a literal `"+ "` in the label (`+ Add Vehicle Category`), which reads as a second plus next to the header button’s lucide `Plus`.

Fix in `VehicleCategories.jsx` only: empty-state action is now `<Button icon={Plus} …>Add Vehicle Category</Button>`, matching the header. No redesign.

---

## Customer

### Decision

**Admin customer creation is NOT supported** by the existing product/architecture.

### Reasoning

1. Customer identity is phone + OTP. `OtpService.verify` → `insertPhoneIdentity` → `ensureCustomerProfile` writes `customer_profiles`.
2. Nest Admin APIs are GET list/detail only (`AdminDirectoryController`). There is no `POST /v1/admin/customers`.
3. Admin permission model has `customers.view / edit / activate / deactivate` — no `create` action, and edit/deactivate have no backend implementation.
4. Product docs (`real_service.txt`) define Customer registration as Flutter → NestJS → MSG91 OTP.
5. Inventing Admin create would skip OTP verification and duplicate the identity model. That is a new architecture, which this task forbids.

### Implementation/removal

- Removed **Add Customer** button, modal, and Dashboard quick action.
- Removed Edit / Delete / Deactivate actions that only toasted “not available on the server yet”.
- Preserved list, search, KPIs, View, View Orders, and Customer Detail (read-only).
- Empty copy: customers appear after they register with OTP on the Customer app.

### Actual database table

`customer_profiles` (FK to `identities`). No `admin_customer` / `admin_customers` table was created.

### API behavior

`GET /v1/admin/customers` → `{ customers: [] }` when the table is empty. Unauthenticated → 401.

---

## Admin Feature Audit

See `ADMIN_FEATURE_FUNCTIONAL_AUDIT.md`.

PASS this session: Vehicle Categories (full CRUD + protected delete), Zones (create/list/delete), Admin login (e2e), Customers/Riders/Payments/Earnings list reads (e2e).

---

## Database Verification

| Operation | Result |
| --- | --- |
| CREATE | Vehicle category POST 201 → INSERT confirmed; zone POST 201 → INSERT confirmed |
| READ | GET lists match PostgreSQL (empty after cleanup; created rows during e2e) |
| UPDATE | Vehicle category PATCH 200 |
| DELETE / DEACTIVATE | Unused DELETE 200; published-fare DELETE 409 then PATCH deactivate 200 |
| REFRESH / restart | Data lives in PostgreSQL, not process memory |
| pgAdmin | Same Docker database `idhar_udhar`. Direct `psql` with the same credentials pgAdmin uses returned the counts above. Browser login to pgAdmin UI was not available in this session |

Empty tables render empty Admin lists. Dummy E2E categories are gone.

---

## Files Changed

This session only:

| File | Change |
| --- | --- |
| `records_database/cleanup_e2e_published_test_fares.sql` | Dependency-aware E2E fare cleanup (no trigger disable) |
| `records_database/backups/idhar_udhar_pre_e2e_fare_cleanup_20260827.dump` | Pre-cleanup backup |
| `backend/test/helpers.ts` | `purgeIsolatedTestVehicleCatalog()` so e2e does not re-leave published test fares |
| `backend/test/admin-vehicle-categories.e2e-spec.ts` | Call purge in `afterAll` |
| `IDHAR_UDHAR_ADMIN/src/pages/VehicleCategories.jsx` | Empty-state single Plus icon |
| `IDHAR_UDHAR_ADMIN/src/pages/Customers.jsx` | Hide unsupported Add/Edit/Delete/Deactivate |
| `IDHAR_UDHAR_ADMIN/src/pages/CustomerDetail.jsx` | Remove unsupported Edit |
| `IDHAR_UDHAR_ADMIN/src/pages/Dashboard.jsx` | Remove Add Customer quick action |
| `IDHAR_UDHAR_ADMIN/src/data/vehicles.js` | Remove unused dummy fleet array (`[]`) |
| `IDHAR_UDHAR_ADMIN/src/data/zones.js` | Remove unused dummy zone array (`[]`) |
| `ADMIN_FEATURE_FUNCTIONAL_AUDIT.md` | This session’s matrix |
| `ADMIN_FINAL_DATABASE_AND_FUNCTIONAL_AUDIT.md` | This report |

Pre-existing uncommitted Admin/backend work from earlier sessions was left as-is.

---

## Protected Apps

```text
Customer Flutter UI: NOT MODIFIED

Rider Flutter UI: NOT MODIFIED
```

No Write/StrReplace path under `idhar_udhar/` was used. Uncommitted Flutter files visible in `git status` are pre-existing user work and were not touched.

---

## Remaining Issues

1. **Browser click-through of the Admin SPA** was not available (no browser automation in this session). Empty states, plus-icon, and customer-button removal were verified in source; CRUD was verified through Nest e2e against the same PostgreSQL instance.
2. **pgAdmin GUI** was not opened. Equivalence is the shared `idhar_udhar` database.
3. **`phase3-catalog-owner@example.test`** remains because ACTIVE `payment_settings_versions` `created_by` cannot be rewritten (0014 published-config immutability). It cannot log in (`password_hash` is not a real hash).
4. **Features without endpoints** (KYC, coupons, promotions, invoices, payouts, announcements, support) still show empty UI. They are not dummy records.
5. **Dashboard still offers Add Rider / Create Order / etc.** Those operations remain toast-gated where the server has no Admin API. Only the Customer create path was removed, as analyzed.
6. Dead files `src/data/mockData.js` and `src/data/logisticsSeed.js` are still unimported. They are not rendered.
7. Netlify `netlify/functions/vehicle-categories.js` is still dead code with a dummy seed. The live Admin path does not call it.
