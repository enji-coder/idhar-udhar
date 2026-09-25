# IDHAR UDHAR — Admin Panel Integration & Functional Audit Report

Date: 2026-08-27
Branch: `main` (HEAD `7da305b`)
Scope: Admin Panel ↔ API ↔ PostgreSQL integration, Vehicle Category defects.

---

## 1. Architecture Verified

The architecture was traced from source and confirmed against the running
system. It was **not** changed.

```
IDHAR_UDHAR_ADMIN  (React 19 + Vite, dev server :5173)
        |
        |  fetch() with Bearer access token
        |  src/api/client.js -> VITE_API_BASE_URL = http://localhost:3000
        v
NestJS modular monolith  (backend/, global prefix /v1, port 3000)
        |
        |  pg Pool (backend/src/database/postgres.service.ts)
        v
PostgreSQL 17.11  (localhost:5432, database "idhar_udhar", user "idhar_admin")
```

Evidence:

- `GET http://localhost:3000/health` returned
  `{"status":"ok","checks":{"process":"ok","database":"ok"},"database":{"name":"idhar_udhar","version":"17.11 (Debian ...)"}}`.
- `GET /v1/admin/vehicle-categories` without a token returned `401`.
- Connection settings come from `backend/.env`, with `records_database/.env` as
  fallback (`backend/src/config/configuration.ts`, first-wins order).

**There is no Next.js API layer.** The Admin Panel is a Vite SPA and calls
NestJS directly.

### Netlify functions are NOT in the live path

`IDHAR_UDHAR_ADMIN/netlify/functions/vehicle-categories.js` serves a hardcoded
six-category seed over GET/PUT. Nothing references it: the frontend calls
`/v1/admin/vehicle-categories` via `src/api/adminApi.js`, and the response shape
differs (`{success, categories}` vs `{vehicle_categories}`). It is dead code
from the pre-backend phase. **Left untouched** (deleting it is out of scope).

---

## 2. Database State and Dummy Data

The database was inspected before any change. **It was already clean** — the
dummy-data purge was done by earlier work in this repo
(`records_database/cleanup_dummy_business_data.sql`, plus a pre-integration
backup at `records_database/backups/idhar_udhar_pre_admin_integration_20260827.dump`).

Row counts across all 56 tables at audit time — every business table is empty:

| Table | Rows | Assessment |
| --- | --- | --- |
| `orders`, `customer_profiles`, `rider_profiles`, `vehicles`, `zones`, `payment_transactions`, `invoices`, `notifications`, `audit_logs`, and all other business tables | 0 | Clean — no dummy business records |
| `vehicle_categories` | 1 | `Truck`, `active=false` — leftover from the failed-delete session (see §5) |
| `fare_config_versions` / `fare_config_version_rates` | 1 / 1 | Version 1 ACTIVE, holding `Truck`'s published rates |
| `cities` | 1 | Reference data — required, retained |
| `identities` / `admin_profiles` | 2 / 2 | Admin login accounts — required, retained |
| `sessions` | 3 | Live admin sessions — retained |
| `order_display_counters`, `payment_settings_versions` | 1 / 1 | Configuration — required, retained |
| `schema_migrations` | 15 | Migration ledger — retained |

**Records removed by me: none.** No deletion was necessary. Removal of the
leftover `Truck` category was subsequently requested and **attempted**, but the
database itself refused it — see §10.

No table was dropped, truncated, or altered. No constraint, index, foreign key,
trigger, or migration was modified.

---

## 3. Vehicle Category — End-to-End Verification

Verified against a build of the fixed code running on port 3001 (a temporary
second instance, so your server on port 3000 was never interrupted), talking to
the **same** `idhar_udhar` database.

| Step | Result | Evidence |
| --- | --- | --- |
| READ | PASS | `GET /v1/admin/vehicle-categories` → 200; API returned 1 category; `SELECT count(*)` → 1. API and PostgreSQL agree. |
| EMPTY STATE | PASS | Stores seed `[]` with `persist:false`; page renders `EmptyState` "No vehicle categories found". No demo rows. |
| CREATE | PASS | `POST` → 201; row present in PostgreSQL by direct `SELECT`. |
| READ back | PASS | New row returned by a fresh `GET`. |
| UPDATE | PASS | `PATCH` name + `weight_capacity` → 200; PostgreSQL shows `..._RENAMED` / `750`. |
| DEACTIVATE | PASS | `PATCH {active:false}` → 200; PostgreSQL `active=false`. |
| DELETE (unused) | PASS | `DELETE` → 200; row count in PostgreSQL → 0. |
| DELETE (in use) | PASS | `DELETE` on `Truck` → 409 `VEHICLE_CATEGORY_IN_USE`; row preserved. Correct per design. |
| AUTH | PASS | No token → 401. Non-admin role token → 401. |
| Backend restart | PASS | Data read back from PostgreSQL by a freshly started process; nothing held in memory. |
| Existing e2e suite | PASS | `admin-vehicle-categories.e2e-spec.ts` CRUD test passes against the real database. |

The temporary test record was created, updated, deactivated, deleted, and its
removal confirmed. **The database was returned to exactly its prior state**
(one `Truck` category, fare version 1 ACTIVE).

### pgAdmin verification

I do not have pgAdmin access, so "pgAdmin shows the same record" was verified
equivalently by querying `idhar_udhar` directly with the `pg` client using the
same credentials pgAdmin uses. Any query you run in pgAdmin against
`idhar_udhar` will return the same rows. This is called out rather than claimed
as a pgAdmin check.

---

## 4. Delete Bug — Root Cause and Fix

### Reported symptom

Admin Panel → Vehicle Categories → Delete → error appears → record is not deleted.

### Root cause

Two separate things combined. The backend was behaving **correctly**; the Admin
Panel could not see why.

1. `VehicleCategoriesService.remove()` blocks deletion when a category is in
   use, counting `vehicles + orders + fare_quotes + fare_snapshots + fare_rates`.
   `fare_rates` counts rows in `fare_config_version_rates`. Because
   `create()` publishes a fare version whenever the Add form contains any
   amount, **a category created with fare values immediately has
   `fare_rates = 1` and can never be hard-deleted.** This is intentional and
   locked: `fare_config_versions` is immutable published pricing history, the
   FK is `ON DELETE RESTRICT`, and `admin-vehicle-categories.e2e-spec.ts`
   explicitly asserts a 409 plus "deactivate instead".

   Confirmed in your data — `Truck` has `vehicles=0, orders=0, fare_quotes=0,
   fare_snapshots=0, **fare_rates=1**`.

2. `VehicleCategoriesService.list()` called `serialize(row)` **without** usage,
   so every row in the list response carried `usage: null`. The Admin Panel's
   `mapVehicleCategory` then computed `usage.total = 0` for every category.
   The confirm dialog in `VehicleCategories.jsx` shows "Cannot delete… Deactivate
   instead" only when `confirmUsage.total > 0` — which was never true. So the
   user was always offered a plain **Delete**, the API answered 409, and the
   page showed an error toast and closed the dialog. Dead end.

### Fix applied (minimal, additive)

- `backend/src/catalog/vehicle-categories.repository.ts` — added
  `usageByCategory()`: one query returning usage counts for all categories.
- `backend/src/catalog/vehicle-categories.service.ts` — `list()` now passes each
  row's usage into the existing `serialize()`.

Nothing else changed. The delete rule, the 409, the foreign keys, and the fare
versioning are all untouched.

This was the intended contract all along: `src/api/mappers.js` already reads
`row.usage`, and `src/api/mappers.spec.js` already asserts a `usage` object on a
list row. The backend simply was not sending it.

### Behaviour after the fix

- Category **not** in use → confirm dialog offers **Delete** → row deleted from
  PostgreSQL. (Verified: 200, row count 0.)
- Category **in** use → dialog now reads "Cannot delete this vehicle category
  because it is currently being used. Please deactivate it instead." with a
  **Deactivate instead** button. No error toast, no dead end.
- If usage changes between page load and the click, the API still returns 409
  and the page surfaces the real message. The error is never suppressed and
  success is never faked.

### What was deliberately NOT done

- Foreign keys were not removed, and `ON DELETE CASCADE` was not introduced.
- `fare_config_version_rates` rows are not silently deleted to force a hard delete.
- The delete button was not removed and the error was not swallowed.
- The database schema was not modified.

---

## 5. Double Plus Icon — Cause and Fix

**Cause.** `components/common/Button.jsx` renders its `icon` prop as a leading
element. `pages/VehicleCategories.jsx` line 164 passed **both** `icon={Plus}`
**and** a literal `"+ "` in the button text, producing `＋ + Add Vehicle Category`.

**Fix.** Removed the literal `"+ "` from the label, leaving the lucide `Plus`
icon. This matches the convention used elsewhere in the panel (for example
`Riders.jsx`: `<Button icon={Plus}>Add Rider</Button>`).

```diff
- <Button icon={Plus} onClick={panel.openCreate}>+ Add Vehicle Category</Button>
+ <Button icon={Plus} onClick={panel.openCreate}>Add Vehicle Category</Button>
```

**Scope.** This was the only occurrence in the Admin Panel. The `EmptyState`
button on line 167 also reads `"+ Add Vehicle Category"` but passes **no** `icon`
prop, so it renders a single plus and is correct — it was left alone. No
styling, layout, or button design was changed.

---

## 6. All Admin Features

See `ADMIN_FEATURE_FUNCTIONAL_AUDIT.md` for the full matrix. Summary:

- **PASS (verified):** Vehicle Categories, Admin Login.
- **PARTIAL:** Orders, Riders, Customers, Payments, Earnings, Wallet/COD,
  Notifications, Reports — real endpoints exist and are wired, but they are
  read-mostly and could not be exercised because the database holds no business
  records.
- **NOT VERIFIED:** Zones, Vehicles, Dashboard, Settings/Profile — full CRUD
  endpoints exist and are wired; not exercised for the same reason.
- **NOT IMPLEMENTED (no endpoint):** Verification/KYC, Coupons, Promotions,
  Invoices, Purchase Invoices, Payouts, Announcements, Support.
- **FAIL / PARTIAL:** Tracking and Live Operations still render hardcoded map
  pins from `data/mockData.js`.

No feature is marked PASS without direct evidence.

---

## 7. Mock Map Pins Removed

`data/mockData.js` exported `trackingPins` (5 fabricated riders with names,
IDs and map coordinates) and `mapStops` (fabricated pickup/drop points). These
were rendered as if they were live operations data.

| File | Change |
| --- | --- |
| `pages/Tracking.jsx` | Removed both mock imports. Stats (`Active Riders`, `In Transit`, `Average ETA`) are now derived from the real `riderStore` / `orderStore`; `Average ETA` shows `—` when there is nothing in transit. The "Active riders" list now renders real riders, with an `EmptyState` when none are online. Caption changed from "Ahmedabad mock map / Architected for live GPS later" to "Live GPS overlay not connected yet". |
| `pages/LiveOperations.jsx` | Removed the mock pin/stop overlay from the SVG. Caption changed from "dummy GPS overlay" to "live GPS overlay not connected yet". Its order table and KPI cards were already real and were left untouched. |

The decorative background paths were kept — they are styling, not business data.
Layout, spacing, card structure, and the design system are unchanged.

`data/mockData.js` and `data/logisticsSeed.js` are now referenced by nothing and
are dead code. They were **not deleted** — they are untracked in git, so deletion
would be unrecoverable, and removing them is not required for correctness (the
bundler drops them). Deleting them is a safe follow-up if you want.

**There is no remaining hardcoded business data in the Admin Panel.**

---

## 8. Files Changed

Five files were modified:

| File | Change |
| --- | --- |
| `backend/src/catalog/vehicle-categories.repository.ts` | Added `usageByCategory()` (new method, single query) |
| `backend/src/catalog/vehicle-categories.service.ts` | `list()` passes usage into `serialize()` |
| `IDHAR_UDHAR_ADMIN/src/pages/VehicleCategories.jsx` | Removed the duplicate literal `"+ "` from one button label |
| `IDHAR_UDHAR_ADMIN/src/pages/Tracking.jsx` | Replaced mock pins/stats with real store data + empty state |
| `IDHAR_UDHAR_ADMIN/src/pages/LiveOperations.jsx` | Removed mock map overlay |

Two documents were added: this report and `ADMIN_FEATURE_FUNCTIONAL_AUDIT.md`.
Temporary verification scripts were created under `backend/` and deleted
afterwards; no stray files remain.

Verification performed:

- `tsc --noEmit` clean; `nest build` clean.
- `admin-vehicle-categories.e2e-spec.ts` CRUD test passing against real PostgreSQL.
- Admin `vite build` succeeds (1922 modules).
- Admin `npm test` — 11/11 passing.
- `oxlint` — 0 errors (5 pre-existing warnings in `Dashboard.jsx`,
  `AuthContext.jsx`, `Reports.jsx`, none in files I touched).

---

## 9. Files Protected

```
Customer Flutter UI: NOT MODIFIED
Rider Flutter UI:    NOT MODIFIED
```

Verified by modification timestamp: my three edits carry an 11:02 timestamp, and
no file under `idhar_udhar/` has a modification time within this session. The
uncommitted changes visible under `idhar_udhar/` in `git status` are **your
pre-existing work** (timestamps 09:44–10:51 and earlier) and were left exactly
as they were.

Also untouched: the database schema, all migrations, all business rules (fare,
commission, wallet, COD, cancellation, order status), authentication and
authorization, the design system, and every other Admin page.

---

## 10. Leftover `Truck` Category — Removal Attempted and Refused by the Database

Removal of `Truck` plus fare config version 1 was requested and attempted. The
attempt ran inside a single guarded transaction that first verified all
dependent business tables were empty (`vehicles`, `orders`, `fare_quotes`,
`order_fare_snapshots`, `resend_snapshots` — all 0) and deleted rows in strict
foreign-key order, with no CASCADE and no constraint changes.

**PostgreSQL rejected it:**

```
cannot delete rates of a published fare version   (ERRCODE restrict_violation)
```

The transaction rolled back in full. The database is byte-for-byte unchanged
(verified afterwards: 1 category, 1 fare version, 1 rate row).

### Why it is blocked

`records_database/migrations/0014_immutability_and_integrity_triggers.sql`
installs two deliberate guards:

- `protect_published_fare_rates` (trigger `fare_rates_protect_published`) —
  refuses INSERT, UPDATE **and DELETE** on `fare_config_version_rates` whenever
  the parent version's status is `ACTIVE` or `SUPERSEDED`.
- `protect_published_config` (trigger `fare_config_protect_published`) — closes
  the obvious workaround: `published config cannot return to DRAFT`.

Fare config version 1 is `ACTIVE`, so its rate row cannot be deleted, and the
version cannot be demoted to `DRAFT` to make it deletable. Because the FK
`fare_rates_category_fk` is `ON DELETE RESTRICT`, the category cannot be deleted
while that rate row exists.

**This is not a bug — it is the published-pricing-immutability rule working as
designed.** The only ways through it are to drop or disable
`fare_rates_protect_published`, or to `ALTER TABLE ... DISABLE TRIGGER`. Both
are explicitly forbidden by the task ("DO NOT remove constraints", "Do not
change database integrity merely to make the button work"), so **the operation
was stopped rather than forced.**

### DECISION TAKEN: leave `Truck` deactivated

The record stays in place with `active = false`. Because it is inactive it is
excluded from customer- and rider-facing category lists, and the Admin Panel
shows it as a single `Inactive` row. **No trigger was dropped or disabled, and
no integrity guard was weakened.**

Options that were considered and not taken:

1. **Repurpose it** — rename `Truck` to a category you actually want and
   activate it via the normal Admin Panel edit form. Fully supported by the API
   and violates nothing. Still available at any time.
2. **Restore from the pre-integration dump**
   (`records_database/backups/idhar_udhar_pre_admin_integration_20260827.dump`),
   which predates the `Truck` record — but it also rolls back everything else
   since that point.
3. **Drop the immutability trigger** — rejected. It would remove a deliberate
   financial-integrity guard to satisfy a cosmetic cleanup.

### If you ever want a genuinely empty catalog

Hard-deleting a category is only possible **before** any fare rates are
published against it. In the Add Vehicle Category form, leaving every fare field
blank creates the category with no `fare_config_version_rates` row, and it stays
fully deletable. Once you save fare amounts, the category becomes
deactivate-only — by design.

---

## 11. Remaining Issues

1. **`Truck` category retained, deactivated** — decided, see §10. Not an open
   issue; recorded so it is not mistaken for a defect later.

2. **Test admin account retained (as instructed).**
   `phase3-catalog-owner@example.test` in `admin_profiles` was created by the
   e2e helpers. Its `password_hash` is the literal string
   `phase3-catalog-not-a-login-hash`, so it cannot log in. Your real admin is
   `swiftsendinnovation@gmail.com`.

3. **Your running API needs a restart.** The backend on port 3000 (PID 1876) was
   started with `nest start` (no watch) before this fix. `dist/` has been
   rebuilt, but that process is still serving the old code. Restart it to pick
   up the delete-bug fix. The Vite dev server picks up the frontend fixes
   automatically.

4. **Features without endpoints.** Eight Admin pages have no backend. They
   correctly show empty states rather than dummy data, but they are not
   database-backed and cannot become so without new API work.

5. **Dead Netlify function.** `netlify/functions/vehicle-categories.js` contains
   a hardcoded six-category seed. It is unreachable from the current frontend
   but would serve stale fake data if anything ever called it.

6. **Orphaned mock files.** `data/mockData.js` and `data/logisticsSeed.js` are
   no longer imported anywhere. Safe to delete whenever you want.
