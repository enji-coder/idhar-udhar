# DATABASE IMPLEMENTATION REPORT

**Date:** 2026-08-24  
**Phase:** Local PostgreSQL implementation (V1 schema)  
**Authoritative rules:** `MASTER_SYSTEM_ARCHITECTURE.md` (highest), then Implementation Blueprint, Schema Specification, Schema Audit  

This report records what was created in the **local** Docker database. It does not change locked business rules.

---

## Connection

| Item | Value |
|---|---|
| PostgreSQL version | **17.11** (Debian 17.11-1.pgdg13+2) |
| Database name | `idhar_udhar` |
| User | `idhar_admin` |
| Host / port | localhost:5432 (Docker container `idhar_udhar_postgres`) |
| SSL | false (local) |
| Credentials | Read from `records_database/.env` only — not hardcoded in SQL |
| Connection verified | **YES** |
| Migration execution verified | **YES** (15/15 applied; second run skipped all) |

---

## Technical decisions applied

Documented in `records_database/TECHNICAL_DECISIONS.md`. Summary:

| Topic | Implementation |
|---|---|
| Money | `NUMERIC(12,2)` via domain `money_inr`. No FLOAT/DOUBLE. |
| Percents | `NUMERIC(5,2)` domain `percent_100` (0–100) |
| UUID | Type UUID; default `uuid_generate_v7()` using `pgcrypto` |
| Wallet ↔ COD twins | `DEFERRABLE INITIALLY DEFERRED` FKs, `ON DELETE RESTRICT` |
| GPS samples | **Not created** (Redis is hot GPS; no retain policy) |
| Customer wallet | Tables created, **isolated**, not wired to booking/payments |
| Case A versions | CHECK requires fare + payment-settings FKs for `resend_case = 'A'` |
| Max 3 drops | Deferred constraint trigger: 1 PICKUP + 1..3 DROP |
| Immutability | Triggers block UPDATE/DELETE on financial/history tables |
| Display IDs | Per-city atomic counter; format `IU-{CITY}-{10 digits}` |
| Extensions | `pgcrypto` only |

Locked 85/15, GST = 0, wallet ≠ COD, UUID + display_id, Case A/B formulas, cancellation default ₹0 were **not** changed.

---

## Migrations

| Item | Value |
|---|---|
| Directory | `records_database/migrations/` |
| Runner | `records_database/migrate.ps1` |
| History table | `schema_migrations` |
| Migration count | **15** |
| Transaction wrapping | Each file applied in a single `BEGIN`/`COMMIT` session |
| Idempotency | Re-run skips applied versions |

| Version | File |
|---|---|
| 0001 | `0001_extensions_helpers.sql` |
| 0002 | `0002_identity_geography_catalog.sql` |
| 0003 | `0003_profiles_auth.sql` |
| 0004 | `0004_files_vehicles_kyc.sql` |
| 0005 | `0005_configuration_versions.sql` |
| 0006 | `0006_rider_wallet_cod.sql` |
| 0007 | `0007_orders_stops_events_offers.sql` |
| 0008 | `0008_fare_quotes_snapshots.sql` |
| 0009 | `0009_payments.sql` |
| 0010 | `0010_finance_cancel_fail_resend.sql` |
| 0011 | `0011_invoices_ratings.sql` |
| 0012 | `0012_notifications_audit_idempotency.sql` |
| 0013 | `0013_architecture_ready_customer_wallet.sql` |
| 0014 | `0014_immutability_and_integrity_triggers.sql` |
| 0015 | `0015_fk_indexes.sql` |

The database can be recreated from an empty PostgreSQL 17 instance by creating the Docker volume/container (see `DEVELOPER_NOTE/database_note.txt`) and running `migrate.ps1`.

---

## Objects created

| Object | Count |
|---|---|
| Public tables (including `schema_migrations`) | **56** |
| Domain/application tables (excluding `schema_migrations`) | **55** |
| Locked production tables | **51** |
| Architecture-ready customer wallet tables | **2** |
| Notification worker-support tables (not in original 51) | **2** (`notification_preferences`, `notification_deliveries`) |
| GPS history table | **0** (intentionally omitted) |
| Primary keys | **56** |
| Foreign keys | **102** |
| UNIQUE constraints (`pg_constraint` type `u`) | **35** |
| Unique indexes (includes PKs and partial uniques) | **109** |
| CHECK constraints | **114** |
| Constraint triggers (deferred integrity) | **4** |
| User triggers | **49** |
| Indexes (`pg_indexes`, includes PK/unique) | **182** |
| Extensions besides plpgsql | **1** (`pgcrypto` 1.3) |
| FLOAT/DOUBLE columns | **0** |
| ON DELETE CASCADE foreign keys | **0** |
| ON DELETE SET NULL foreign keys | **1** (`vehicles.rider_profile_id`) |

### Locked production tables (51)

`identities`, `otp_challenges`, `sessions`, `customer_profiles`, `rider_profiles`, `admin_profiles`, `customer_saved_addresses`, `cities`, `zones`, `vehicle_categories`, `fare_config_versions`, `fare_config_version_rates`, `payment_settings_versions`, `payment_method_policy_versions`, `cancellation_config_versions`, `cancellation_config_version_rules`, `cod_policy_versions`, `extra_rate_versions`, `company_office_versions`, `order_display_counters`, `vehicles`, `rider_drivers`, `stored_files`, `rider_documents`, `vehicle_documents`, `rider_bank_accounts`, `rider_upis`, `rider_wallet_accounts`, `wallet_ledger_entries`, `rider_cod_accounts`, `cod_ledger_entries`, `orders`, `order_stops`, `order_status_events`, `order_offers`, `fare_quotes`, `order_fare_snapshots`, `order_payment_responsibilities`, `order_payment_plans`, `payment_transactions`, `order_finance_snapshots`, `order_cancellation_snapshots`, `failed_deliveries`, `order_adjustments`, `resend_snapshots`, `invoices`, `invoice_lines`, `order_ratings`, `notifications`, `audit_logs`, `idempotency_keys`

### Architecture-ready (isolated)

- `customer_wallet_accounts`
- `customer_wallet_ledger_entries`

No FK from `orders` or `payment_transactions` into customer wallet. V1 payment methods remain ONLINE/CASH. `payment_method_policy_versions.wallet_enabled` defaults FALSE.

### Notification schema (architecture + future worker)

- `notifications` — inbox, identity recipient, optional typed profile FKs, `read_at` unread state, optional `order_id`
- `notification_preferences` — `in_app_enabled` / `push_enabled` per identity
- `notification_deliveries` — IN_APP/PUSH channel, PENDING/SENT/FAILED/SKIPPED, attempt_count, last_error, provider_message_id

No push-provider integration. No chat table.

---

## Financial protection checks

| Check | Result |
|---|---|
| 85/15 stored against Trip Fare | `order_finance_snapshots.trip_fare` + copied percents/amounts. Payment settings default 85/15/50 with share CHECK = 100 |
| 85/15 not applied to invoice grand total | Invoice stores `trip_fare` and `billed_total` separately. No generated 85/15 from `billed_total` |
| GST = 0 | `order_fare_snapshots.tax = 0`, `fare_quotes.tax = 0`, `invoices.gst_on_fare = 0` |
| Operations from company share only | `operational_cost_percentage_of_commission` on settings + freeze rows |
| Snapshots immutable | UPDATE/DELETE triggers on fare, finance, cancel, failed delivery, adjustments, ledgers, audit, responsibility, plan |
| Payment txn | Amount/payer/method immutable; status PENDING→PAID/FAILED only; refund = new row |
| Invoice amounts | Immutable after insert; status ISSUED→CANCELLED allowed; no hard delete |
| Config published payload | ACTIVE/SUPERSEDED cannot change numbers; publish N+1 |
| No CASCADE on money FKs | **0** CASCADE FKs in public schema |
| Finance ORIGINAL uniqueness | Partial unique `(order_id) WHERE snapshot_kind = 'ORIGINAL'` — reversals allowed |

---

## Wallet / COD separation check

| Concept | Table | Separated? |
|---|---|---|
| Rider earning wallet | `rider_wallet_accounts` (`available_balance >= 0`) | YES |
| Rider wallet transactions | `wallet_ledger_entries` (append-only, amount > 0) | YES |
| Rider COD Due | `rider_cod_accounts` (`cod_due >= 0`) | YES |
| COD settlement events | `cod_ledger_entries` direction `DECREASE` | YES — **not** a third balance table |

Twin settlement FKs are DEFERRABLE. No merged wallet+COD table. Customer wallet is a different pair and is not V1 operational.

---

## Payment model check

| Capability | Supported |
|---|---|
| Customer pays | `who_pays` / `payer_type` CUSTOMER |
| Receiver pays | RECEIVER (no Receiver user table) |
| Split | CUSTOMER/RECEIVER/SPLIT; responsibility sum CHECK |
| Multiple transactions | `payment_transactions` 1:N |
| UNPAID / PARTIALLY_PAID / PAID | Derived aggregates — **not** a transaction status |
| Transaction PENDING / PAID / FAILED / REFUNDED | CHECK on `transaction_status` |
| COD (cash collection) | method CASH + COD ledger for company share |
| Online | method ONLINE; unique `provider_event_id` |
| Refund | New row `direction = REFUND` |
| Responsibility ≠ transaction | Separate tables |

---

## Order ID check

| Rule | Implementation |
|---|---|
| UUID PK | `orders.order_id UUID` default v7 |
| Unique display_id | UNIQUE + CHECK `^IU-[A-Z]{2,5}-[0-9]{10}$` |
| Sequence | `order_display_counters` + `allocate_order_display_id(city_id)` atomic per city |
| Invoice number | Separate UNIQUE `invoices.invoice_number` (not the PK, not display_id) |

---

## Snapshot immutability check

Append-only / no-delete (triggers): fare snapshot, finance snapshot, cancellation snapshot, failed deliveries, order adjustments, wallet ledger, COD ledger, customer wallet ledger, status events, audit logs, invoice lines, payment responsibility, payment plan, idempotency keys.

Guarded mutable: payment transaction status; resend `request_status`; invoice status/PDF/email; notification `read_at`.

---

## Notification schema check

Inbox, unread (`read_at`), Customer/Rider/Admin typed recipients, order link, preferences, delivery/retry rows: **present**. Push vendor: **not** integrated (by design).

---

## Audit & idempotency

- `audit_logs`: actor identity/profile/role, action, entity type/id, old/new JSONB, reason, request_id, ip, user_agent, category, timestamp. Append-only.
- `idempotency_keys`: unique `(scope, key)`, request_hash, result payload. **No TTL column.**

---

## Files / documents

`stored_files` holds metadata (`storage_key`, purpose KYC/POD/INVOICE_PDF). **No bytea.** Bank/UPI/licence use masked + encrypted/token columns.

---

## Future scaling considerations (not built now)

- UUID PKs and per-city display counters avoid a global integer hotspot.
- Append-only ledgers/events/audit are natural **time-partition candidates** later (`created_at` / month).
- Hot GPS remains Redis; Postgres was not used as a 1 Hz GPS sink.
- Connection pooling (PgBouncer) is compatible: no session-required features except deferred FKs **inside a transaction** (normal).
- Read replicas: reporting can move to a replica; accept/pay/wallet stay on primary.
- Do not split Order / Wallet / COD into separate databases.
- Object storage for files; signed URLs later.
- Notification deliveries table is a worker outbox-style queue, not an in-API send.

---

## Remaining NEEDS BUSINESS DECISION

These are **product/ops** items. Schema columns exist without inventing the policy.

1. OTP length, SMS provider, expiry minutes, max attempts, lockout  
2. Session TTL and JWT vs cookie  
3. Invoice legal series format; GSTIN / SAC / e-invoice (fare GST stays ₹0)  
4. First production cash-only vs online enabled  
5. Authorize-at-booking vs capture-at-delivery; payment vendor  
6. Case A/B **runtime** storage (child order vs related record) — both columns exist  
7. Close failed delivery without resend (no invented status/fee)  
8. Customer wallet auto-debit / min-max / KYC  
9. GPS breadcrumb retention (table omitted until decided)  
10. Rating rider→customer edit / public comments  
11. Admin manual second live trip for one rider  
12. Staff RBAC cells beyond Master §8.2 minimums  
13. SEARCHING TTL / dispatch algorithm / offer timeout  
14. Pickup/drop contacts required at booking?  
15. 85/15 paise rounding on non-even rupees (engine stores already-rounded freeze amounts)

No remaining **technical** blocker for this local schema.

---

## Final safety check

| Item | Status |
|---|---|
| No locked business rule changed | YES |
| No financial model changed | YES |
| No GST introduced | YES (`= 0` CHECKs) |
| 85/15 not moved to invoice total | YES |
| Wallet and COD remain separate | YES |
| Multiple payment transactions | YES |
| Customer / Receiver / Split | YES |
| Historical snapshots protected | YES |
| Order UUID / display_id preserved | YES |
| Resend Case A/B preserved | YES |
| Cancellation rules preserved | YES |
| Admin configuration versioning | YES |
| Notification architecture supported | YES |
| Application/UI/API code unmodified | YES |
| Local PostgreSQL healthy | YES |
| Recreatable from migrations | YES |
| Authoritative markdown files unmodified | YES |

**Migration success status: SUCCESS**
