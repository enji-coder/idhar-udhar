# IDHAR UDHAR — Admin Feature Functional Audit

Date: 2026-08-27
Database: `idhar_udhar` @ localhost:5432 (PostgreSQL 17.11)
API: NestJS on `http://localhost:3000`, global prefix `/v1`
Admin Panel: React 19 + Vite (`IDHAR_UDHAR_ADMIN`)

## Legend

| Mark | Meaning |
| --- | --- |
| PASS | Exercised in this session and confirmed against PostgreSQL |
| FAIL | Exercised and did not behave correctly |
| PARTIAL | Works, but with a documented limitation |
| NOT VERIFIED | Endpoint/UI exists and was code-traced, but not functionally exercised |
| N/A | Operation does not exist in this build |

**Empty development database:** after cleanup, business tables have zero rows. Create/update/delete on features that need real customers, riders, or orders was not fabricated. Those rows stay NOT VERIFIED rather than PASS.

## Matrix

| Feature | Read | Create | Update | Delete/Deactivate | PostgreSQL Sync | Result |
| --- | --- | --- | --- | --- | --- | --- |
| **Vehicle Categories** | PASS | PASS | PASS | PASS | `vehicle_categories` + optional `fare_config_versions` / `fare_config_version_rates` | **PASS** |
| Zones | PASS | PASS | N/A (not exercised) | PASS | `zones` | **PASS** (create/list/delete against AMD) |
| Vehicles | NOT VERIFIED | NOT VERIFIED | NOT VERIFIED | NOT VERIFIED | `vehicles` | Present; empty table; API exists |
| Orders | NOT VERIFIED | N/A | NOT VERIFIED | N/A | `orders` | PARTIAL — Admin create/delete not supported |
| Riders | PASS (list/get in e2e) | N/A | N/A | N/A | `rider_profiles` | PARTIAL (read-only) |
| Customers | PASS (list/get in e2e) | N/A | N/A | N/A | `customer_profiles` | PARTIAL (read-only by design) |
| Payments | PASS (empty list in e2e) | N/A | N/A | N/A | `payment_transactions` | PARTIAL (read-only) |
| Earnings | PASS (empty list in e2e) | N/A | N/A | N/A | `order_finance_snapshots` | PARTIAL (read-only) |
| Wallet / COD | NOT VERIFIED | N/A | N/A | N/A | `rider_wallet_accounts`, `cod_ledger_entries` | PARTIAL (read-only APIs exist) |
| Notifications | NOT VERIFIED | N/A | NOT VERIFIED | N/A | `notifications` | PARTIAL |
| Dashboard | NOT VERIFIED | N/A | N/A | N/A | derived from directory hydrate | NOT VERIFIED in browser |
| Live Operations | NOT VERIFIED | N/A | NOT VERIFIED | N/A | `orders` | PARTIAL |
| Tracking | NOT VERIFIED | N/A | N/A | N/A | `rider_profiles`, `orders` | NOT VERIFIED |
| Verification (KYC) | N/A | N/A | N/A | N/A | `rider_documents` | NOT IMPLEMENTED |
| Coupons | N/A | N/A | N/A | N/A | none | NOT IMPLEMENTED |
| Promotions | N/A | N/A | N/A | N/A | none | NOT IMPLEMENTED |
| Invoices | N/A | N/A | N/A | N/A | `invoices` | NOT IMPLEMENTED |
| Purchase Invoices | N/A | N/A | N/A | N/A | none | NOT IMPLEMENTED |
| Payouts | N/A | N/A | N/A | N/A | none | NOT IMPLEMENTED |
| Announcements | N/A | N/A | N/A | N/A | none | NOT IMPLEMENTED |
| Support | N/A | N/A | N/A | N/A | none | NOT IMPLEMENTED |
| Reports | N/A | N/A | N/A | N/A | client join over hydrated stores | PARTIAL |
| Settings / Profile | NOT VERIFIED | N/A | N/A | N/A | `admin_profiles` | NOT VERIFIED |
| Admin Login | PASS | N/A | N/A | N/A | `admin_profiles`, `sessions` | **PASS** (e2e fixture login) |

### Vehicle Categories — evidence (this session)

Against live PostgreSQL via Nest e2e (`admin-vehicle-categories.e2e-spec.ts`):

| Call | HTTP | PostgreSQL |
| --- | --- | --- |
| GET `/v1/admin/vehicle-categories` | 200 | empty / listed created row |
| POST category without fare amounts | 201 | INSERT `vehicle_categories` |
| PATCH name / weight | 200 | UPDATE confirmed |
| DELETE unused category | 200 | row gone |
| POST category with published rates | 201 | INSERT category + ACTIVE `fare_config_version_rates` |
| DELETE while published rates exist | 409 `VEHICLE_CATEGORY_IN_USE` | row preserved |
| PATCH `{ active: false }` | 200 | deactivate instead of hard delete |
| GET without token | 401 | n/a |

After e2e `afterAll` purge, `vehicle_categories`, `fare_config_versions`, and `fare_config_version_rates` are **0**.

### Customers — architecture decision

Admin customer **create / edit / delete / deactivate** are **N/A**. Customers are created by Customer-app OTP (`POST /v1/auth/otp/request` + `verify` → `identities` + `customer_profiles`). Admin APIs are GET list/detail only. The misleading Add/Edit/Delete/Deactivate controls were removed from the Admin UI.

### Empty-state behaviour

List stores seed `[]` with `persist: false`. Empty PostgreSQL renders **No records found** / **No customers found** rather than demo rows. API failure uses `ErrorState`; dummy records are not substituted.

### Not-implemented features

Pages without Nest endpoints still render empty states from in-memory `[]` stores. They are not showing dummy business data.
