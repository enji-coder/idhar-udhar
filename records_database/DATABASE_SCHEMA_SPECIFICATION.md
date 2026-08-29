# IDHAR UDHAR — DATABASE SCHEMA SPECIFICATION

**Type:** PostgreSQL design specification only  
**Date:** 2026-08-24  
**Status:** SPECIFICATION — not implemented. No SQL, no migrations, no physical tables.  
**Sources (authoritative):**
1. `records_database/MASTER_SYSTEM_ARCHITECTURE.md` (priority on conflict)
2. `records_database/IMPLEMENTATION_BLUEPRINT.md`

This file defines the exact PostgreSQL structure that a later approved phase will convert into SQL migrations.

It does **not** modify the Master Architecture, the Implementation Blueprint, application code, UI, APIs, or a live database.

```text
MASTER_SYSTEM_ARCHITECTURE.md
        ↓
IMPLEMENTATION_BLUEPRINT.md
        ↓
DATABASE_SCHEMA_SPECIFICATION.md   ← this file
        ↓
SQL migrations                     ← not this phase
```

---

# 1. SOURCE VERIFICATION

## 1.1 Cross-check result

The Implementation Blueprint §B entity list matches Master §12.5 and §34. No locked money rule in the Blueprint contradicts the Master.

| Topic | Master | Blueprint | Spec action |
|---|---|---|---|
| Identity + profiles | §7 | B.1–B.6 | Same |
| Order UUID + display_id | §12.1 | B.30 | Same |
| Stops as rows, max 3 drops | §13 | B.31 | Same |
| One canonical status + events | §14 | B.32, D.1 | Same |
| Fare snapshot ≠ live rates | §15 | B.35 | Same |
| 85/15 on Trip Fare, ops from company share | §4, §22 | C.2 | Same |
| GST on fare = 0 | §4.5 | C.1, B.35 tax=0 | Same |
| Responsibility ≠ plan ≠ transaction | §16–17 | B.36–B.38 | Same |
| Wallet ≠ COD | §18–19 | B.25–B.28 | Same. **No merged table.** |
| Finance snapshot not unique-per-order | §22, §42 | B.39 | Same. Reversals allowed |
| Cancel default ₹0, shares=100, not auto 85/15 | §20 | B.14, B.40 | Same |
| Resend Case A / B | §21 | B.43 | Same. Storage shape open |
| COD settlement as third balance table | Settlement is a ledger posting pair (§18.3, Blueprint B.28) | Not a third account | **No `cod_settlements` table.** Settlement rows live on `cod_ledger_entries` (+ twin wallet row) |
| Money physical type | Integer paise **or** `NUMERIC(12,2)` §43 | NEEDS DECISION | See §8. Not silently mixed |
| Case A child order vs related record | TECHNICAL DESIGN OPTION §21.2 | NEEDS DECISION #20 | Schema supports **both** via `orders.parent_order_id` and `resend_snapshots.child_order_id` |
| Fare rates JSONB vs child rows | TECHNICAL DESIGN OPTION | B.11 | This spec uses **child rows** so CHECKs and category FKs are enforceable. Alternative remains listed under NEEDS DECISION |
| Extra rates one sheet vs two | TECHNICAL DESIGN OPTION | B.16 | This spec uses **one** `extra_rate_versions` table. Numbers are locked |
| Audit one log vs two | TECHNICAL DESIGN OPTION §29 | NEEDS DECISION #23 | This spec uses **one** `audit_logs` table with `category` |
| Notification identity vs profile | TECHNICAL DESIGN OPTION §28 | NEEDS DECISION #22 | Both recipient columns exist; CHECK that at least one is set |
| Customer wallet | ARCHITECTURE READY §9.3 | B.29 | Tables specified; **not required for V1 booking** |
| GPS samples | Redis hot; Postgres optional §P | B.49 | Optional table; retention NEEDS DECISION |
| Receiver application / user table | Not required §4.17 | Explicitly omitted | **No table** |
| Chat | Not V1 | Omitted | **No table** |
| Stale `04`/`05` single payment | Forbidden §34.3 | Forbidden | **No single `payments` row as the whole model** |

**No locked business rule was changed to make this specification fit.**

---

# 2. CONVENTIONS USED IN THIS SPECIFICATION

These are physical mappings of architecture types, not new product rules.

| Architecture | This specification |
|---|---|
| Time-sortable UUID PK (e.g. UUID v7) | PostgreSQL `UUID`. Generation of v7 is application-side unless a later migration uses a v7 function. **Who generates UUID v7 (app vs database) is NEEDS DECISION.** Type is UUID. |
| Conceptual `money` | See **§8**. Columns are written as `NUMERIC(12,2)` as the **working type for this document**. Integer paise remains the Master-allowed alternative and must be chosen uniformly before SQL. |
| Conceptual `percent` | `NUMERIC(5,2)` — values 0–100 inclusive |
| `timestamptz` | `TIMESTAMP WITH TIME ZONE` |
| Closed status lists | `TEXT` + `CHECK` (not PostgreSQL `ENUM`). Adding a locked status later does not require `ALTER TYPE`. Values must still match the Blueprint; do not invent statuses |
| Structured audit/idempotency payloads | `JSONB` |
| Admin `modules[]` | `JSONB` (array of text) |
| Soft delete | `deactivated_at TIMESTAMP WITH TIME ZONE NULL` and/or status flags. **No hard delete of financial rows** |

**Never use `FLOAT`, `REAL`, or `DOUBLE PRECISION` for money.**

**Currency:** INR. No currency column on amounts (single-currency system in the architecture). Do not invent multi-currency.

**Naming:** snake_case tables (plural) and columns. Architecture entity names are mapped in the inventory.

---

# 3. COMPLETE TABLE INVENTORY

Legend — **Class:** master / reference / transactional / configuration / snapshot / ledger / audit / security.

**Delete:** Never = no hard delete. Soft = deactivate. Purge allowed = architecture allows removing unused/expired non-financial rows.

**Retention:** If the architecture did not define days, the cell says “not numbered” (PITR still required for money — Master §38).

| # | Table | Purpose | Source | Class | Append-only | Update | Delete | Retention |
|---|---|---|---|---|---|---|---|---|
| 1 | `identities` | One physical person / login | Master §7; BP B.1 | master | no | limited | soft (auth_status) | not numbered |
| 2 | `otp_challenges` | Hashed OTP | Master §7.5; BP B.2 | security | no | attempts | purge expired allowed | OTP lifetime NEEDS DECISION |
| 3 | `sessions` | Logged-in profile session | Master §7.6; BP B.3 | security | no | revoke | purge expired allowed | session TTL NEEDS DECISION |
| 4 | `customer_profiles` | Customer role | Master §9; BP B.4 | master | no | yes (non-money) | soft | keep if orders exist |
| 5 | `rider_profiles` | Rider role | Master §10; BP B.5 | master | no | yes (non-money) | soft | keep if orders exist |
| 6 | `admin_profiles` | Staff role | Master §8, §11; BP B.6 | master | no | yes (audited) | soft | keep |
| 7 | `customer_saved_addresses` | Reusable addresses | Master §9.2; BP B.7 | master | no | yes | soft | stops do not depend on this row |
| 8 | `cities` | City + display-id code | Master §I; BP B.8 | reference | no | limited | soft | keep |
| 9 | `zones` | Service area | Master §I; BP B.9 | reference | no | yes | soft | keep |
| 10 | `vehicle_categories` | Sellable type | Master §26; BP B.10 | reference | no | yes | soft | never if orders reference |
| 11 | `fare_config_versions` | Published rate-sheet header | Master §15, §24; BP B.11 | configuration | new version | drafts only | never if used | keep published |
| 12 | `fare_config_version_rates` | Per-category rates in a version | Master §15.2; BP B.11 | configuration | with parent | drafts only | with unused draft only | keep published |
| 13 | `payment_settings_versions` | 85/15/50 | Master §4, §22, §24; BP B.12 | configuration | new version | drafts only | never if used | keep |
| 14 | `payment_method_policy_versions` | Methods on/off | Master §24, §E; BP B.13 | configuration | new version | drafts only | never if used | keep |
| 15 | `cancellation_config_versions` | Cancel table header per actor | Master §20; BP B.14 | configuration | new version | drafts only | never if used | keep |
| 16 | `cancellation_config_version_rules` | Per-stage fee/shares | Master §20.2; BP B.14 | configuration | with parent | drafts only | unused draft only | keep published |
| 17 | `cod_policy_versions` | COD suspend threshold | Master §18.4, §24; BP B.15 | configuration | new version | drafts only | never if used | keep |
| 18 | `extra_rate_versions` | Resend ₹10/₹8/₹2 + office ₹8/km | Master §21, §24; BP B.16 | configuration | new version | drafts only | never if used | keep |
| 19 | `company_office_versions` | Office location | Master §25; BP B.17 | configuration | new version | drafts only | never if used | keep |
| 20 | `order_display_counters` | Per-city 10-digit sequence | Master §12.1 | reference | counter | last_seq only | never | keep |
| 21 | `vehicles` | Vehicle instance | Master §26.2; BP B.18 | master | no | yes | soft | keep |
| 22 | `rider_drivers` | Licence-holder placeholder | Master §10.1; BP B.19 | master | no | yes | soft if unused | keep if used |
| 23 | `stored_files` | Object-storage metadata | Master §27; BP B.20 | reference | no | scan status | never for invoice PDF | KYC/invoice keep |
| 24 | `rider_documents` | KYC metadata | Master §27.1; BP B.21 | master | no | status | no erase of approved without policy | keep |
| 25 | `vehicle_documents` | Vehicle paper metadata | Master §26–27; BP B.22 | master | no | status | same as KYC | keep |
| 26 | `rider_bank_accounts` | Payout destination | Master §27.2; BP B.23 | master | supersede | current flag | never if used for payout | keep |
| 27 | `rider_upis` | UPI destination | Master §27.2; BP B.24 | master | supersede | current flag | never if used | keep |
| 28 | `rider_wallet_accounts` | Available balance (materialized) | Master §19; BP B.25 | transactional | no | balance via ledger only | **never** | financial PITR |
| 29 | `wallet_ledger_entries` | Wallet source of truth | Master §19; BP B.26 | ledger | **yes** | **no** | **never** | financial PITR |
| 30 | `rider_cod_accounts` | COD Due (materialized) | Master §18; BP B.27 | transactional | no | due via ledger only | **never** | financial PITR |
| 31 | `cod_ledger_entries` | COD increases + settlements | Master §18; BP B.28 | ledger | **yes** | **no** | **never** | financial PITR |
| 32 | `customer_wallet_accounts` | Optional prepaid | Master §9.3; BP B.29 | transactional | no | via ledger | never if used | ARCHITECTURE READY |
| 33 | `customer_wallet_ledger_entries` | Customer wallet history | Master §W; BP B.29 | ledger | **yes** | **no** | **never** | ARCHITECTURE READY |
| 34 | `orders` | Canonical trip | Master §12; BP B.30 | transactional | no | status/rider/vehicle | **never hard-delete** | financial PITR |
| 35 | `order_stops` | Pickup/drops | Master §13; BP B.31 | transactional | no | arrival/POD | never after confirm | with order |
| 36 | `order_status_events` | Status history | Master §14.2; BP B.32 | snapshot/history | **yes** | **no** | **never** | with order |
| 37 | `order_offers` | Dispatch offers | Master §O; BP B.33 | transactional | no | pending → terminal | **never** | with order |
| 38 | `fare_quotes` | Pre-confirm quote | Master §15; BP B.34 | transactional | no | unused expire | unused expired may purge | TTL NEEDS DECISION |
| 39 | `order_fare_snapshots` | Locked Trip Fare | Master §15.2; BP B.35 | snapshot | **yes** | **no** | **never** | financial PITR |
| 40 | `order_payment_responsibilities` | Who owes | Master §16.1; BP B.36 | snapshot | insert at confirm | **no** after confirm | **never** | financial PITR |
| 41 | `order_payment_plans` | How they intend | Master §16.2; BP B.37 | snapshot | insert at confirm | **no** after confirm | **never** | financial PITR |
| 42 | `payment_transactions` | Actual money movement | Master §17; BP B.38 | transactional | new row for refund | status PENDING→PAID/FAILED only | **never** | financial PITR |
| 43 | `order_finance_snapshots` | Frozen 85/15/50 | Master §22; BP B.39 | snapshot | **yes** (incl. reversal) | **no** | **never** | financial PITR |
| 44 | `order_cancellation_snapshots` | Fee/shares used | Master §20.4; BP B.40 | snapshot | **yes** | **no** | **never** | financial PITR |
| 45 | `failed_deliveries` | Receiver unavailable | Master §21.1; BP B.41 | snapshot | **yes** | **no** | **never** | financial PITR |
| 46 | `order_adjustments` | Office extra / audited fix | Master §21.1, §22; BP B.42 | snapshot | **yes** | **no** | **never** | financial PITR |
| 47 | `resend_snapshots` | Case A/B money | Master §21; BP B.43 | snapshot | **yes** | progress only via order status | **never** money fields | financial PITR |
| 48 | `invoices` | Financial document | Master §23; BP B.44 | snapshot/document | no | status/PDF/email | **never hard-delete issued** | financial PITR |
| 49 | `invoice_lines` | Copied display lines | Master §23; BP B.44 | snapshot | **yes** after issue | **no** | with invoice retention | financial PITR |
| 50 | `order_ratings` | Stars after delivery | Master §X; BP B.45 | transactional | insert-once until decided | edit NEEDS DECISION | no public erase without policy | not numbered |
| 51 | `notifications` | Inbox | Master §28; BP B.46 | transactional | no | read_at | hide; not money erase | not numbered |
| 52 | `audit_logs` | Who/what/old/new | Master §29; BP B.47 | audit | **yes** | **no** | **never** (financial) | financial PITR |
| 53 | `idempotency_keys` | Retry safety | Master §30; BP B.48 | security | insert | **no** | never for money keys; expiry **not defined** | do not invent TTL |
| 54 | `rider_location_samples` | Optional GPS history | Master §P; BP B.49 | transactional | **yes** | **no** | retain policy NEEDS DECISION | ARCHITECTURE READY |

**Tables deliberately not created**

| Name someone might add | Why not |
|---|---|
| `receivers` / receiver app users | Receiver is `payer_type` on the trip |
| `customer_logins` + `rider_logins` | One `identities` row |
| `cod_settlements` as a third balance | Settlement = `cod_ledger_entries` DECREASE (+ wallet twin) |
| Combined `wallet_and_cod` | Forbidden |
| `chat_messages` | Not V1 |
| `referrals` with dummy ₹200/₹50/₹150 | Not one program |
| `purchase_invoices` inside 85/15 | Separate AP if ever built; not trip P&L |
| Per-app order status tables | One canonical status |

**Total tables specified: 54**  
(50 required for the locked production model + 4 ARCHITECTURE READY: customer wallet ×2, location samples, and customer wallet ledger counted in the 54.)

ARCHITECTURE READY (may be created with the schema so it does not need redesign, but not required for V1 booking): `customer_wallet_accounts`, `customer_wallet_ledger_entries`, `rider_location_samples`.

---

# 4. PRIMARY KEY STRATEGY

| Rule | Specification |
|---|---|
| All entity PKs | `UUID` PRIMARY KEY, time-sortable (architecture example: UUID v7) |
| Generation | Application or database v7 function. **NEEDS DECISION** which process generates them. Type is still UUID |
| Do not use | Phone, name, vehicle name, display_id, or invoice_number as PRIMARY KEY |
| Order internal ID | `orders.order_id UUID PK` — all FKs to a trip use this |
| Order human ID | `orders.display_id TEXT UNIQUE NOT NULL` — format `IU-{CITY_CODE}-{10-digit sequence}` e.g. `IU-AMD-0000010421`. **Not** the PK |
| Display sequence | `order_display_counters.city_id` + `last_seq BIGINT`. Next display id = city_code + zero-padded 10 digits. Unique globally on the **string**, so two cities may both use sequence 1 (`IU-AMD-…0001` vs `IU-SRT-…0001`) |
| Invoice number | `invoices.invoice_number TEXT UNIQUE` — **separate series** from display_id. Format of the series is **NEEDS DECISION** (statutory). Uniqueness is locked |
| Config versions | UUID PK + integer `version` unique per stream (see each table) |

---

# 5. MONEY / DECIMAL DESIGN

Master §43: pick **one** of integer minor units **or** `NUMERIC(12,2)` and use it everywhere.

**This specification writes every money column as `NUMERIC(12,2)`.**

| Rule | Value |
|---|---|
| PostgreSQL type | `NUMERIC(12,2)` |
| Precision / scale | 12, 2 (rupees, paise as decimals) |
| Currency | INR implied |
| FLOAT/DOUBLE | **Forbidden** |
| Alternative | `BIGINT` paise (₹1.00 = 100). If chosen, **every** money column in this file becomes `BIGINT` with scale 0. Mixing is forbidden |
| Confirmation before SQL | **NEEDS DECISION** (Master allowed both; this spec’s working type is NUMERIC(12,2)) |

**Rounding:** Fare engine `net_total = round(trip_fare − discount)` (Master §15). Database stores the **already rounded** snapshot amounts. Do not invent a second rounding mode.

**Negative values**

| Column class | Negative allowed |
|---|---|
| Wallet `available_balance` | **No** (`>= 0`) |
| COD `cod_due` | **No** (`>= 0`) |
| Ledger `amount` | **No** (`> 0`); direction carries sign |
| Fare / finance / responsibility amounts | **No** (`>= 0`) unless a reversal finance row uses positive amounts with `snapshot_kind = REVERSAL` (amounts stay non-negative; kind indicates reversal) |
| Adjustment `amount` | `>= 0` (type/beneficiary say who it is for). Do not use negative wallet to express COD |

Percent columns: `NUMERIC(5,2)`, `>= 0`, `<= 100`.

Distance: `NUMERIC(10,3)` km (not money). Architecture did not name precision; this is a schema-time technical mapping.

Coordinates: `NUMERIC(9,6)`.

---

# 6. STATUS / ENUM DESIGN

Mechanism for all status fields: **`TEXT NOT NULL` + `CHECK (column IN (...))`**.  
Do not invent values. Transitions are enforced by the backend (Master §14.3), not by inventing extra statuses.

### 6.1 `orders.canonical_status`

| Value | Meaning |
|---|---|
| CREATED | Order recorded |
| SEARCHING | Looking for rider |
| OFFERED | Offer(s) out |
| ASSIGNED | Accepted |
| EN_ROUTE_PICKUP | Going to pickup |
| ARRIVED_PICKUP | At pickup |
| PICKED_UP | Parcel picked |
| IN_TRANSIT | To drop |
| NEAR_DROP | Near drop |
| DELIVERY_ATTEMPT | Attempt |
| DELIVERED | Done |
| CANCELLED | Cancelled |
| RECEIVER_UNAVAILABLE | Receiver not available |
| FAILED_DELIVERY | Failed delivery recorded |
| PARCEL_AT_COMPANY_OFFICE | At company office |
| RESEND_REQUESTED | Resend requested |
| RESEND_IN_PROGRESS | Resend moving |
| RESEND_COMPLETED | Resend done |

Valid transitions: Implementation Blueprint §D.1 (and Master §14). Terminal: DELIVERED, CANCELLED, RESEND_COMPLETED.  
Do **not** add a failed-closed status (Master §14.3).

### 6.2 Other closed lists

| Field | Values | Transitions |
|---|---|---|
| `identities.auth_status` | ACTIVE, LOCKED, REVOKED | Extra values NEEDS DECISION |
| `customer_profiles.status` | ACTIVE, DEACTIVATED | Soft delete |
| `rider_profiles.online_status` | ONLINE, OFFLINE | Rider |
| `rider_profiles.approval_status` | PENDING, APPROVED, REJECTED, SUSPENDED | Operations/Super Admin. Master says approve/reject/suspend; PENDING is the pre-review state required to store the row |
| `rider_profiles.cod_operational_status` | CLEAR, SUSPENDED_FOR_COD | System when due ≥ threshold |
| `admin_profiles.role` | SUPER_ADMIN, SUB_ADMIN, OPERATIONS, FINANCE, SUPPORT, MANAGER | Audited |
| `sessions.active_profile_type` | CUSTOMER, RIDER, ADMIN | Set at login |
| Version `status` | DRAFT, ACTIVE, SUPERSEDED | Publish = new version; do not edit ACTIVE used by orders |
| `order_offers.status` | PENDING, REJECTED, EXPIRED, ACCEPTED | One ACCEPTED per order |
| `order_stops.stop_type` | PICKUP, DROP | Immutable after confirm |
| `payment_transactions.payer_type` | CUSTOMER, RECEIVER | Immutable |
| `payment_transactions.method` | ONLINE, CASH | V1. WALLET later without rewriting history |
| `payment_transactions.direction` | CHARGE, REFUND | Refund = new row |
| `payment_transactions.transaction_status` | PENDING, PAID, FAILED, REFUNDED | PENDING→PAID/FAILED; refund is new row. **Not** UNPAID/PARTIALLY_PAID/PAID |
| Aggregate payment (derived, **not a table column as truth**) | UNPAID, PARTIALLY_PAID, PAID | From sum of PAID transactions vs responsibility |
| `order_payment_responsibilities.who_pays` | CUSTOMER, RECEIVER, SPLIT | At confirm |
| `order_finance_snapshots.snapshot_kind` | ORIGINAL, REVERSAL, ADJUSTMENT_FREEZE | Insert-only |
| `cancellation_config_versions.actor` | CUSTOMER, RIDER | Separate streams |
| Cancellation `stage` | BEFORE_ACCEPT, AFTER_ACCEPT, AFTER_ARRIVE_PICKUP, AFTER_PICKUP, IN_TRANSIT | Master §20.2 stages; codes are schema labels for those five locked stages |
| Cancel snapshot `actor_type` | CUSTOMER, RIDER, ADMIN | |
| `failed_deliveries.reason` | RECEIVER_UNAVAILABLE | V1 only |
| `order_adjustments.adjustment_type` | OFFICE_COMPENSATION, ADMIN_ADJUSTMENT, OVERPAY_CORRECTION | Do not invent fees |
| `order_adjustments.beneficiary` | RIDER, COMPANY, CUSTOMER | |
| `resend_snapshots.resend_case` | A, B | Locked formulas |
| `resend_snapshots.request_status` | NOT_DECIDED, REQUESTED, IN_PROGRESS, COMPLETED | Progress; money immutable |
| `invoices.status` | DRAFT, ISSUED, CANCELLED | |
| Document `status` | UPLOADED, APPROVED, REJECTED | |
| `stored_files.purpose` | KYC, POD, INVOICE_PDF, OTHER | |
| `wallet_ledger_entries.direction` | CREDIT, DEBIT | |
| `wallet_ledger_entries.entry_type` | EARNING, COD_SETTLEMENT, RECHARGE, PAYOUT, ADJUSTMENT, CANCELLATION_SHARE, RESEND_EARNING | Master examples, not a fee list |
| `cod_ledger_entries.direction` | INCREASE, DECREASE | |
| `cod_ledger_entries.source` | CASH_COMPANY_SHARE, RECHARGE_SETTLEMENT, DIGITAL_EARNING_SETTLEMENT, CANCELLATION_SHARE_SETTLEMENT, ADMIN_ADJUSTMENT | |
| `order_ratings.direction` | CUSTOMER_TO_RIDER, RIDER_TO_CUSTOMER | Opposite direction optional/future |
| `vehicles.two_wheeler_subtype` | BIKE, SCOOTER | Nullable |
| Actor type (events/ledger) | CUSTOMER, RIDER, ADMIN, WEBHOOK, SYSTEM | |

`rider_profiles.onboarding_kyc_status` exact extra steps: **NEEDS DECISION**. Minimum usable values: PENDING, SUBMITTED, APPROVED, REJECTED (document-level status is separate).

Bank/UPI verification enum: **NEEDS DECISION**. Column `TEXT NULL` until locked; do not invent PAID-like values.

---

# 7. TABLE-BY-TABLE COLUMN SPECIFICATION

Column flags: **PK** primary key · **FK** foreign key · **U** unique · **S** sensitive · **M** mutable after insert · **A** include in audit when changed.

FK delete/update behaviour is summarized in §9. Default: **ON DELETE RESTRICT / ON UPDATE RESTRICT**.

---

## 7.1 `identities`

**Purpose:** One person, one login. Phone is not an order FK.

| Column | Type | Null | Default | Keys | Mutable | Sensitive | Audit | Description |
|---|---|---|---|---|---|---|---|---|
| identity_id | UUID | NOT NULL | generated | PK | no | no | yes | |
| phone_normalized | TEXT | NOT NULL | — | U | no (not casual edit) | yes | yes | Unique 10-digit / E.164 |
| email | TEXT | NULL | NULL | U WHERE NOT NULL | yes | yes | yes | Unique when present |
| auth_status | TEXT | NOT NULL | `'ACTIVE'` | CHECK | yes | no | yes | ACTIVE/LOCKED/REVOKED |
| created_at | TIMESTAMPTZ | NOT NULL | now() | | no | no | no | |
| updated_at | TIMESTAMPTZ | NOT NULL | now() | | yes | no | no | |

CHECK: `auth_status IN ('ACTIVE','LOCKED','REVOKED')`.

---

## 7.2 `otp_challenges`

| Column | Type | Null | Default | Keys | Mutable | Sensitive | Audit | Description |
|---|---|---|---|---|---|---|---|---|
| otp_challenge_id | UUID | NOT NULL | generated | PK | no | no | no | |
| phone_normalized | TEXT | NOT NULL | — | | no | yes | no | |
| identity_id | UUID | NULL | NULL | FK identities | no | no | no | Optional if identity not yet created |
| code_hash | TEXT | NOT NULL | — | | no | **yes** | no | Never plaintext OTP |
| expires_at | TIMESTAMPTZ | NOT NULL | — | | no | no | no | Lifetime **NEEDS DECISION** |
| attempt_count | INTEGER | NOT NULL | 0 | CHECK >=0 | yes | no | no | |
| max_attempts | INTEGER | NULL | NULL | | no | no | no | Policy **NEEDS DECISION** |
| cooldown_until | TIMESTAMPTZ | NULL | NULL | | yes | no | no | Store cooldown (30s in current apps) |
| ip | TEXT | NULL | NULL | | no | yes | no | Rate-limit |
| consumed_at | TIMESTAMPTZ | NULL | NULL | | yes | no | no | |
| created_at | TIMESTAMPTZ | NOT NULL | now() | | no | no | no | |

---

## 7.3 `sessions`

| Column | Type | Null | Default | Keys | Mutable | Sensitive | Audit | Description |
|---|---|---|---|---|---|---|---|---|
| session_id | UUID | NOT NULL | generated | PK | no | no | no | |
| identity_id | UUID | NOT NULL | — | FK identities | no | no | no | |
| active_profile_type | TEXT | NOT NULL | — | CHECK | no | no | no | CUSTOMER/RIDER/ADMIN |
| customer_profile_id | UUID | NULL | NULL | FK customer_profiles | no | no | no | Exactly one profile FK matches type |
| rider_profile_id | UUID | NULL | NULL | FK rider_profiles | no | no | no | |
| admin_profile_id | UUID | NULL | NULL | FK admin_profiles | no | no | no | |
| refresh_token_hash | TEXT | NULL | NULL | | yes | **yes** | no | Optional (session transport NEEDS DECISION) |
| expires_at | TIMESTAMPTZ | NOT NULL | — | | no | no | no | TTL NEEDS DECISION |
| revoked_at | TIMESTAMPTZ | NULL | NULL | | yes | no | no | |
| created_at | TIMESTAMPTZ | NOT NULL | now() | | no | no | no | |

CHECK: exactly one of the three profile FKs is non-null and matches `active_profile_type`.

---

## 7.4 `customer_profiles`

| Column | Type | Null | Default | Keys | Mutable | Sensitive | Audit | Description |
|---|---|---|---|---|---|---|---|---|
| customer_profile_id | UUID | NOT NULL | generated | PK | no | no | no | Orders use this id |
| identity_id | UUID | NOT NULL | — | FK, U | no | no | no | At most one customer profile |
| display_name | TEXT | NOT NULL | — | | yes | no | yes | Required |
| email | TEXT | NULL | NULL | | yes | yes | yes | Optional until track/invoice |
| invoice_email | TEXT | NULL | NULL | | yes | yes | yes | Captured when required |
| status | TEXT | NOT NULL | `'ACTIVE'` | CHECK | yes | no | yes | ACTIVE/DEACTIVATED |
| default_city_id | UUID | NULL | NULL | FK cities | yes | no | no | |
| deactivated_at | TIMESTAMPTZ | NULL | NULL | | yes | no | yes | Soft delete |
| created_at | TIMESTAMPTZ | NOT NULL | now() | | no | no | no | |
| updated_at | TIMESTAMPTZ | NOT NULL | now() | | yes | no | no | |

---

## 7.5 `rider_profiles`

| Column | Type | Null | Default | Keys | Mutable | Sensitive | Audit | Description |
|---|---|---|---|---|---|---|---|---|
| rider_profile_id | UUID | NOT NULL | generated | PK | no | no | no | Assigned orders use this id |
| identity_id | UUID | NOT NULL | — | FK, U | no | no | no | |
| onboarding_kyc_status | TEXT | NOT NULL | `'PENDING'` | CHECK | yes | no | yes | Extra steps NEEDS DECISION |
| approval_status | TEXT | NOT NULL | `'PENDING'` | CHECK | yes | no | **yes** | APPROVED/REJECTED/SUSPENDED |
| online_status | TEXT | NOT NULL | `'OFFLINE'` | CHECK | yes | no | no | |
| home_city_id | UUID | NULL | NULL | FK cities | yes | no | no | |
| home_zone_id | UUID | NULL | NULL | FK zones | yes | no | no | |
| cod_operational_status | TEXT | NOT NULL | `'CLEAR'` | CHECK | yes (system) | no | yes | SUSPENDED_FOR_COD when due ≥ threshold |
| created_at | TIMESTAMPTZ | NOT NULL | now() | | no | no | no | |
| updated_at | TIMESTAMPTZ | NOT NULL | now() | | yes | no | no | |

---

## 7.6 `admin_profiles`

| Column | Type | Null | Default | Keys | Mutable | Sensitive | Audit | Description |
|---|---|---|---|---|---|---|---|---|
| admin_profile_id | UUID | NOT NULL | generated | PK | no | no | no | |
| identity_id | UUID | NOT NULL | — | FK, U | no | no | no | Staff identity (email+password typical) |
| role | TEXT | NOT NULL | — | CHECK | yes | no | **yes** | Master §8.1 roles |
| modules | JSONB | NOT NULL | `'[]'` | | yes | no | **yes** | Catalog NEEDS DECISION |
| finance_access | BOOLEAN | NOT NULL | FALSE | | yes | no | **yes** | |
| payout_approve | BOOLEAN | NOT NULL | FALSE | | yes | no | **yes** | |
| city_scope_id | UUID | NULL | NULL | FK cities | yes | no | yes | Optional later |
| password_hash | TEXT | NOT NULL | — | | yes | **yes** | no | Argon2id or equivalent. Never in React |
| active | BOOLEAN | NOT NULL | TRUE | | yes | no | yes | |
| created_at | TIMESTAMPTZ | NOT NULL | now() | | no | no | no | |
| updated_at | TIMESTAMPTZ | NOT NULL | now() | | yes | no | no | |

Marketplace identities do **not** store a password here. Password lives on the Admin profile (Blueprint: Identity or Admin Profile — this spec places it on Admin Profile so OTP users have no password column).

---

## 7.7 `customer_saved_addresses`

| Column | Type | Null | Default | Keys | Mutable | Sensitive | Audit | Description |
|---|---|---|---|---|---|---|---|---|
| saved_address_id | UUID | NOT NULL | generated | PK | no | no | no | |
| customer_profile_id | UUID | NOT NULL | — | FK | no | no | no | |
| label | TEXT | NULL | NULL | | yes | no | no | Not locked |
| address_text | TEXT | NOT NULL | — | | yes | yes | no | |
| latitude | NUMERIC(9,6) | NULL | NULL | | yes | no | no | |
| longitude | NUMERIC(9,6) | NULL | NULL | | yes | no | no | |
| zone_id | UUID | NULL | NULL | FK zones | yes | no | no | |
| deactivated_at | TIMESTAMPTZ | NULL | NULL | | yes | no | no | Soft delete |
| created_at | TIMESTAMPTZ | NOT NULL | now() | | no | no | no | |

Booked location is copied onto `order_stops`.

---

## 7.8 `cities`

| Column | Type | Null | Default | Keys | Mutable | Sensitive | Audit | Description |
|---|---|---|---|---|---|---|---|---|
| city_id | UUID | NOT NULL | generated | PK | no | no | no | |
| name | TEXT | NOT NULL | — | | yes | no | yes | |
| city_code | TEXT | NOT NULL | — | U | no (do not recycle) | no | yes | `AMD` = Ahmedabad |
| active | BOOLEAN | NOT NULL | TRUE | | yes | no | yes | Soft delete |
| created_at | TIMESTAMPTZ | NOT NULL | now() | | no | no | no | |

---

## 7.9 `zones`

| Column | Type | Null | Default | Keys | Mutable | Sensitive | Audit | Description |
|---|---|---|---|---|---|---|---|---|
| zone_id | UUID | NOT NULL | generated | PK | no | no | no | |
| city_id | UUID | NOT NULL | — | FK cities | no | no | no | |
| name | TEXT | NOT NULL | — | | yes | no | no | |
| active | BOOLEAN | NOT NULL | TRUE | | yes | no | no | |
| created_at | TIMESTAMPTZ | NOT NULL | now() | | no | no | no | |

---

## 7.10 `vehicle_categories`

| Column | Type | Null | Default | Keys | Mutable | Sensitive | Audit | Description |
|---|---|---|---|---|---|---|---|---|
| vehicle_category_id | UUID | NOT NULL | generated | PK | no | no | no | Never join by name |
| code | TEXT | NULL | NULL | U WHERE NOT NULL | no | no | no | Optional mock-id migration |
| name | TEXT | NOT NULL | — | | yes | no | yes | Orders snapshot name |
| active | BOOLEAN | NOT NULL | TRUE | | yes | no | yes | Soft delete |
| weight_capacity | TEXT | NULL | NULL | | yes | no | no | Catalog copy |
| size | TEXT | NULL | NULL | | yes | no | no | Catalog copy |
| created_at | TIMESTAMPTZ | NOT NULL | now() | | no | no | no | |
| updated_at | TIMESTAMPTZ | NOT NULL | now() | | yes | no | no | |

---

## 7.11 Shared versioned-config header columns

Used by fare, payment settings, method policy, cancellation, COD policy, extra rates, office.

| Column | Type | Null | Default | Notes |
|---|---|---|---|---|
| *_version_id | UUID PK | NOT NULL | generated | |
| version | INTEGER | NOT NULL | — | Unique per stream; CHECK > 0 |
| status | TEXT | NOT NULL | `'DRAFT'` | DRAFT/ACTIVE/SUPERSEDED |
| effective_from | TIMESTAMPTZ | NOT NULL | — | |
| effective_until | TIMESTAMPTZ | NULL | NULL | Optional |
| created_by_admin_profile_id | UUID | NOT NULL | — | FK admin_profiles |
| created_at | TIMESTAMPTZ | NOT NULL | now() | Immutable |

**Rule:** never UPDATE a row with `status IN ('ACTIVE','SUPERSEDED')` that orders already reference. Publish = INSERT version N+1; set previous ACTIVE → SUPERSEDED.

Partial UNIQUE: at most one `status = 'ACTIVE'` per stream (cancellation stream = actor; office stream = city_id; others = global).

---

## 7.12 `fare_config_versions` + `fare_config_version_rates`

Header as §7.11. Unique `(version)`.

**Rates child** (schema-time choice vs JSONB payload — NEEDS DECISION to switch to JSONB):

| Column | Type | Null | Default | Keys | Mutable | Description |
|---|---|---|---|---|---|---|
| fare_config_version_rate_id | UUID | NOT NULL | generated | PK | no | |
| fare_config_version_id | UUID | NOT NULL | — | FK | no | |
| vehicle_category_id | UUID | NOT NULL | — | FK | no | |
| base_fare | NUMERIC(12,2) | NOT NULL | — | CHECK >=0 | draft only | |
| per_km | NUMERIC(12,2) | NOT NULL | — | CHECK >=0 | draft only | |
| initial_minimum | NUMERIC(12,2) | NOT NULL | — | CHECK >=0 | draft only | |
| waiting | NUMERIC(12,2) | NOT NULL | — | CHECK >=0 | draft only | |
| surge | NUMERIC(12,2) | NOT NULL | — | CHECK >=0 | draft only | |
| toll | NUMERIC(12,2) | NOT NULL | — | CHECK >=0 | draft only | |
| parking | NUMERIC(12,2) | NOT NULL | — | CHECK >=0 | draft only | |

UNIQUE `(fare_config_version_id, vehicle_category_id)`.

---

## 7.13 `payment_settings_versions`

Header + money percents:

| Column | Type | Null | Default | CHECK |
|---|---|---|---|---|
| rider_percentage | NUMERIC(5,2) | NOT NULL | 85 | 0–100 |
| company_commission_percentage | NUMERIC(5,2) | NOT NULL | 15 | 0–100 |
| operational_cost_percentage_of_commission | NUMERIC(5,2) | NOT NULL | 50 | 0–100 |

CHECK: `rider_percentage + company_commission_percentage = 100`.  
85/15 applies to **Trip Fare**, not these columns being “of payable”.

---

## 7.14 `payment_method_policy_versions`

| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| cash_enabled | BOOLEAN | NOT NULL | — | Launch default NEEDS DECISION |
| online_enabled | BOOLEAN | NOT NULL | — | Launch default NEEDS DECISION |
| upi_enabled | BOOLEAN | NOT NULL | FALSE | Admin method labels; schema supports day one |
| card_enabled | BOOLEAN | NOT NULL | FALSE | Never store PAN/CVV |
| net_banking_enabled | BOOLEAN | NOT NULL | FALSE | |
| wallet_enabled | BOOLEAN | NOT NULL | FALSE | Customer wallet auto-debit still NEEDS DECISION |

Transaction rows still use method ONLINE/CASH in V1.

---

## 7.15 `cancellation_config_versions` + `cancellation_config_version_rules`

Header plus `actor TEXT NOT NULL` CHECK CUSTOMER/RIDER. UNIQUE `(actor, version)`. At most one ACTIVE per actor.

| Column | Type | Null | Default | CHECK |
|---|---|---|---|---|
| cancellation_config_version_rule_id | UUID PK | NOT NULL | generated | |
| cancellation_config_version_id | UUID FK | NOT NULL | — | |
| stage | TEXT | NOT NULL | — | five locked stages |
| enabled | BOOLEAN | NOT NULL | — | |
| fee | NUMERIC(12,2) | NOT NULL | 0 | >= 0. Default ₹0 |
| rider_share_percent | NUMERIC(5,2) | NOT NULL | — | 0–100 |
| company_share_percent | NUMERIC(5,2) | NOT NULL | — | 0–100 |

CHECK: `rider_share_percent + company_share_percent = 100`.  
UNIQUE `(cancellation_config_version_id, stage)`.  
Not auto 85/15.

---

## 7.16 `cod_policy_versions`

| Column | Type | Null | Default | CHECK |
|---|---|---|---|---|
| suspend_threshold | NUMERIC(12,2) | NOT NULL | 100 | >= 0. FINAL default ₹100; still versioned |

---

## 7.17 `extra_rate_versions`

| Column | Type | Null | Default | CHECK |
|---|---|---|---|---|
| resend_case_a_per_km | NUMERIC(12,2) | NOT NULL | 10 | >= 0 |
| resend_case_b_customer_per_km | NUMERIC(12,2) | NOT NULL | 10 | >= 0 |
| resend_case_b_rider_per_km | NUMERIC(12,2) | NOT NULL | 8 | >= 0 |
| resend_case_b_company_per_km | NUMERIC(12,2) | NOT NULL | 2 | >= 0 |
| office_handover_per_km | NUMERIC(12,2) | NOT NULL | 8 | >= 0 |

Case B: customer 10 = rider 8 + company 2 at default. Do **not** add a DB CHECK that 10=8+2 forever — Admin may version rates; snapshot copies the numbers used. (If a CHECK is desired that B parts sum to customer per-km, that is **NEEDS DECISION** — Master locks today’s numbers, not that they must always sum.)

---

## 7.18 `company_office_versions`

Header plus:

| Column | Type | Null | Keys |
|---|---|---|---|
| city_id | UUID | NOT NULL | FK cities. At most one ACTIVE per city |
| address | TEXT | NOT NULL | |
| latitude | NUMERIC(9,6) | NOT NULL | |
| longitude | NUMERIC(9,6) | NOT NULL | |

Failed delivery **copies** address/lat/lng onto `failed_deliveries`.

---

## 7.19 `order_display_counters`

Implements Master §12.1 sequence. Not a business entity; required for unique display ids.

| Column | Type | Null | Keys | Mutable |
|---|---|---|---|---|
| city_id | UUID | NOT NULL | PK, FK cities | no |
| last_seq | BIGINT | NOT NULL | CHECK >= 0 | yes (counter only) |

---

## 7.20 `vehicles`

| Column | Type | Null | Default | Keys | Mutable | Description |
|---|---|---|---|---|---|---|
| vehicle_id | UUID | NOT NULL | generated | PK | no | |
| vehicle_category_id | UUID | NOT NULL | — | FK | yes | |
| rider_profile_id | UUID | NULL | NULL | FK rider_profiles | yes | Unassigned allowed |
| registration | TEXT | NULL | NULL | | yes | Sensitive-ish; mask in lists |
| two_wheeler_subtype | TEXT | NULL | NULL | CHECK | yes | BIKE/SCOOTER |
| active | BOOLEAN | NOT NULL | TRUE | | yes | Soft delete |
| created_at | TIMESTAMPTZ | NOT NULL | now() | | no | |
| updated_at | TIMESTAMPTZ | NOT NULL | now() | | yes | |

---

## 7.21 `rider_drivers`

| Column | Type | Null | Keys | Sensitive | Description |
|---|---|---|---|---|---|
| rider_driver_id | UUID PK | NOT NULL | | no | Placeholder, not a fleet product |
| rider_profile_id | UUID | NOT NULL | FK | no | V1 typically 1:1 |
| name | TEXT | NULL | | no | |
| mobile | TEXT | NULL | | yes | Not an Identity login |
| date_of_birth | DATE | NULL | | yes | |
| licence_reference | TEXT | NULL | | **yes** | Protect like KYC |
| created_at | TIMESTAMPTZ | NOT NULL | | no | |

UNIQUE `rider_profile_id` for V1 (one driver record per rider). Relaxing this is the fleet NEEDS DECISION.

---

## 7.22 `stored_files`

| Column | Type | Null | Keys | Sensitive | Mutable |
|---|---|---|---|---|---|
| file_id | UUID PK | NOT NULL | | no | no |
| storage_key | TEXT NOT NULL | | U | no | no (invoice PDF frozen) |
| content_type | TEXT | NULL | | no | no |
| size_bytes | INTEGER | NULL | CHECK >=0 | no | no |
| checksum | TEXT | NULL | | no | no |
| purpose | TEXT NOT NULL | | CHECK | no | no |
| virus_scan_status | TEXT | NULL | | no | yes (ARCHITECTURE READY) |
| created_by_identity_id | UUID | NULL | FK identities | no | no |
| created_at | TIMESTAMPTZ NOT NULL | | | no | no |

No bytea file payload.

---

## 7.23 `rider_documents` / `vehicle_documents`

Same shape: id, owner FK (`rider_profile_id` / `vehicle_id`), `document_type TEXT NOT NULL` (list NEEDS DECISION), `file_id` FK, `status` UPLOADED/APPROVED/REJECTED, `reviewer_admin_profile_id` NULL FK, `reviewed_at` NULL, `created_at`. Status mutable; file replacement = new row.

---

## 7.24 `rider_bank_accounts`

| Column | Type | Null | Sensitive | Mutable |
|---|---|---|---|---|
| bank_account_id | UUID PK | NOT NULL | no | no |
| rider_profile_id | UUID FK | NOT NULL | no | no |
| holder_name | TEXT | NOT NULL | yes | no (supersede) |
| account_masked | TEXT | NOT NULL | no | no |
| account_encrypted_or_token | TEXT | NOT NULL | **yes** | no |
| ifsc_or_bank | TEXT | NULL | yes | no |
| is_current | BOOLEAN | NOT NULL DEFAULT FALSE | no | yes |
| verification_status | TEXT | NULL | no | yes | Enum NEEDS DECISION |
| created_at | TIMESTAMPTZ | NOT NULL | no | no |

At most one `is_current = TRUE` per rider (partial unique).

---

## 7.25 `rider_upis`

Same pattern: `vpa_masked`, `vpa_encrypted_or_token` (**sensitive**), `is_current`, verification_status NEEDS DECISION.

---

## 7.26 `rider_wallet_accounts`

| Column | Type | Null | Default | CHECK | Mutable | Description |
|---|---|---|---|---|---|---|
| wallet_account_id | UUID PK | NOT NULL | generated | | no | |
| rider_profile_id | UUID | NOT NULL | — | UNIQUE 1:1 | no | |
| available_balance | NUMERIC(12,2) | NOT NULL | 0 | **>= 0** | **only with ledger insert** | Materialized; ledger is truth |
| created_at | TIMESTAMPTZ | NOT NULL | now() | | no | |
| updated_at | TIMESTAMPTZ | NOT NULL | now() | | yes | |

**Never delete. Never store COD Due here.**

---

## 7.27 `wallet_ledger_entries` (architecture name: wallet transaction)

**Append-only. No UPDATE. No DELETE.**

| Column | Type | Null | Keys | Mutable | Description |
|---|---|---|---|---|---|
| wallet_ledger_id | UUID PK | NOT NULL | | no | |
| wallet_account_id | UUID | NOT NULL | FK | no | |
| direction | TEXT | NOT NULL | CHECK CREDIT/DEBIT | no | |
| amount | NUMERIC(12,2) | NOT NULL | CHECK > 0 | no | |
| entry_type | TEXT | NOT NULL | CHECK listed types | no | |
| related_order_id | UUID | NULL | FK orders | no | |
| related_payment_transaction_id | UUID | NULL | FK payment_transactions | no | |
| related_cod_ledger_id | UUID | NULL | FK cod_ledger_entries | no | Settlement twin |
| actor_type | TEXT | NOT NULL | CHECK | no | |
| actor_profile_id | UUID | NULL | | no | |
| created_at | TIMESTAMPTZ | NOT NULL | now() | no | |

---

## 7.28 `rider_cod_accounts` (architecture: rider COD Due)

| Column | Type | Null | Default | CHECK | Mutable |
|---|---|---|---|---|---|
| cod_account_id | UUID PK | NOT NULL | generated | | no |
| rider_profile_id | UUID UNIQUE | NOT NULL | — | 1:1 | no |
| cod_due | NUMERIC(12,2) | NOT NULL | 0 | **>= 0** | only with COD ledger insert |
| created_at / updated_at | TIMESTAMPTZ | NOT NULL | now() | | updated_at yes |

Separate from wallet. When `cod_due >=` active `cod_policy_versions.suspend_threshold`, rider `cod_operational_status = SUSPENDED_FOR_COD`.

---

## 7.29 `cod_ledger_entries` (includes settlement events)

**Append-only. No UPDATE. No DELETE.**  
There is **no** separate `cod_settlements` table. A settlement is `direction = DECREASE` with source RECHARGE_SETTLEMENT / DIGITAL_EARNING_SETTLEMENT / CANCELLATION_SHARE_SETTLEMENT, optionally twinned to a wallet CREDIT of the remainder.

| Column | Type | Null | Keys | Mutable |
|---|---|---|---|---|
| cod_ledger_id | UUID PK | NOT NULL | | no |
| cod_account_id | UUID FK | NOT NULL | | no |
| direction | TEXT | NOT NULL | INCREASE/DECREASE | no |
| amount | NUMERIC(12,2) | NOT NULL | CHECK > 0 | no |
| source | TEXT | NOT NULL | CHECK listed sources | no |
| related_order_id | UUID | NULL | FK orders | no |
| related_wallet_ledger_id | UUID | NULL | FK wallet_ledger_entries | no |
| source_txn_id | TEXT | NULL | UNIQUE with rider via (cod_account_id, source_txn_id) WHERE NOT NULL | no |
| created_at | TIMESTAMPTZ | NOT NULL | | no |

UNIQUE `(cod_account_id, source_txn_id)` WHERE `source_txn_id IS NOT NULL` — Master §30.1 COD settlement idempotency `(rider_id, source_txn_id)`.

---

## 7.30 Customer wallet (ARCHITECTURE READY)

`customer_wallet_accounts`: `customer_wallet_id` PK, `customer_profile_id` UNIQUE, `available_balance NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK >= 0`.

`customer_wallet_ledger_entries`: same shape as rider wallet ledger. Dummy promo amounts are **not** defaults.

Not required for V1 booking. No auto-debit until decided.

---

## 7.31 `orders`

| Column | Type | Null | Default | Keys | Mutable | Description |
|---|---|---|---|---|---|---|
| order_id | UUID | NOT NULL | generated | PK | no | Internal canonical id |
| display_id | TEXT | NOT NULL | generated | **UNIQUE** | **no** | `IU-{CODE}-{10 digits}` |
| customer_profile_id | UUID | NOT NULL | — | FK customer_profiles | **no** | Not identity, not phone |
| rider_profile_id | UUID | NULL | NULL | FK rider_profiles | yes (assign) | Null until assigned |
| city_id | UUID | NOT NULL | — | FK cities | no | |
| vehicle_category_id | UUID | NOT NULL | — | FK vehicle_categories | no | |
| vehicle_category_name_snapshot | TEXT | NOT NULL | — | | **no** | History |
| vehicle_id | UUID | NULL | NULL | FK vehicles | yes on assign | |
| canonical_status | TEXT | NOT NULL | `'CREATED'` | CHECK locked set | yes via events | One machine |
| parent_order_id | UUID | NULL | NULL | FK orders | **no** | Case A child option |
| scheduled_at | TIMESTAMPTZ | NULL | NULL | | no V1 product | Reserved |
| created_at | TIMESTAMPTZ | NOT NULL | now() | | no | |
| updated_at | TIMESTAMPTZ | NOT NULL | now() | | yes | |

Do **not** add `payment_method` as the payment model.  
Do **not** copy live Admin rates onto this row as authority — `order_fare_snapshots` is authority. Convenience copies of trip_fare/net_payable are **optional denormalization**; if present they must match the snapshot and are not independently editable. This spec **omits** convenience money columns to avoid a second truth (Blueprint: snapshot is authority).

CHECK `canonical_status` ∈ locked list.  
No unique-active-order constraint (customer may have many actives).

---

## 7.32 `order_stops`

| Column | Type | Null | Keys | Mutable | Description |
|---|---|---|---|---|---|
| order_stop_id | UUID PK | NOT NULL | | no | Stable id |
| order_id | UUID FK | NOT NULL | | no | |
| sequence | INTEGER | NOT NULL | UNIQUE (order_id, sequence); CHECK >= 0 | **no** after confirm | |
| stop_type | TEXT | NOT NULL | PICKUP/DROP | **no** after confirm | |
| address_text | TEXT | NOT NULL | | **no** after confirm | Never comma-separated multi-city string as the only stop |
| latitude | NUMERIC(9,6) | NOT NULL | | **no** after confirm | |
| longitude | NUMERIC(9,6) | NOT NULL | | **no** after confirm | |
| zone_id | UUID | NULL | FK zones | no after confirm | |
| contact_name | TEXT | NULL | | yes if later collected | Required? NEEDS DECISION |
| contact_phone | TEXT | NULL | | yes | Sensitive |
| arrived_at | TIMESTAMPTZ | NULL | | yes | Progress |
| completed_at | TIMESTAMPTZ | NULL | | yes | Progress |
| proof_file_id | UUID | NULL | FK stored_files | yes | POD |

Partial UNIQUE: at most one PICKUP per order.  
1–3 DROPs: enforce with constraint trigger or application. **Exact trigger vs application enforcement is NEEDS DECISION**; the rule is locked.

---

## 7.33 `order_status_events`

Append-only.

| Column | Type | Null | Keys | Mutable |
|---|---|---|---|---|
| order_status_event_id | UUID PK | NOT NULL | | no |
| order_id | UUID FK | NOT NULL | | no |
| from_status | TEXT | NULL | | no |
| to_status | TEXT | NOT NULL | CHECK | no |
| actor_type | TEXT | NOT NULL | CHECK | no |
| actor_profile_id | UUID | NULL | | no |
| reason | TEXT | NULL | | no |
| idempotency_key | TEXT | NOT NULL | UNIQUE (order_id, idempotency_key) | no |
| created_at | TIMESTAMPTZ | NOT NULL | | no |

---

## 7.34 `order_offers`

| Column | Type | Null | Keys | Mutable |
|---|---|---|---|---|
| order_offer_id | UUID PK | NOT NULL | | no |
| order_id | UUID FK | NOT NULL | | no |
| rider_profile_id | UUID FK | NOT NULL | | no |
| status | TEXT | NOT NULL DEFAULT 'PENDING' | CHECK | pending→terminal |
| created_at | TIMESTAMPTZ | NOT NULL | | no |
| responded_at | TIMESTAMPTZ | NULL | | yes |

Partial UNIQUE `(order_id)` WHERE `status = 'ACCEPTED'` — one winner.  
UNIQUE `(order_id, rider_profile_id)` — one offer row per rider per order (retry accept is idempotent on that row).

---

## 7.35 `fare_quotes`

All rate/amount columns `NUMERIC(12,2) NOT NULL`, `tax NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (tax = 0)`, `discount`/`rounding` default 0, `distance_km NUMERIC(10,3) NOT NULL CHECK > 0`, `stop_count INTEGER NOT NULL CHECK BETWEEN 2 AND 4` (1 pickup + 1..3 drops). `expires_at TIMESTAMPTZ NOT NULL` (TTL minutes NEEDS DECISION). `fare_config_version_id` FK, `customer_profile_id` FK, `vehicle_category_id` FK.

Mutable: none of the amounts. Unused expired rows may be purged.

---

## 7.36 `order_fare_snapshots`

**Immutable. Never UPDATE money. Never DELETE.**

| Column | Type | Null | CHECK | Description |
|---|---|---|---|---|
| fare_snapshot_id | UUID PK | NOT NULL | | |
| order_id | UUID | NOT NULL | **UNIQUE 1:1** | One snapshot per billed order |
| fare_config_version_id | UUID FK | NOT NULL | | Version used at quote/confirm |
| vehicle_category_id | UUID FK | NOT NULL | | |
| vehicle_category_name | TEXT | NOT NULL | | Snapshot |
| distance_km | NUMERIC(10,3) | NOT NULL | > 0 | |
| stop_count | INTEGER | NOT NULL | | |
| base_fare, per_km, distance_charge, initial_minimum, waiting, surge, toll, parking | NUMERIC(12,2) | NOT NULL | >= 0 | Copied rates |
| trip_fare | NUMERIC(12,2) | NOT NULL | >= 0 | **85/15 base** |
| discount | NUMERIC(12,2) | NOT NULL DEFAULT 0 | >= 0 | |
| rounding | NUMERIC(12,2) | NOT NULL DEFAULT 0 | | |
| net_payable | NUMERIC(12,2) | NOT NULL | >= 0 | Bill (usually) |
| tax | NUMERIC(12,2) | NOT NULL DEFAULT 0 | **= 0** | GST on fare locked 0 |
| quoted_at | TIMESTAMPTZ | NULL | | |
| confirmed_at | TIMESTAMPTZ | NOT NULL | | |

`trip_fare` is **not** `net_payable`. Child Case A orders get their **own** row.

---

## 7.37 `order_payment_responsibilities`

**Immutable after confirm.** UNIQUE `order_id`.

| Column | Type | Null | CHECK |
|---|---|---|---|
| payment_responsibility_id | UUID PK | NOT NULL | |
| order_id | UUID UNIQUE FK | NOT NULL | |
| applicable_bill_total | NUMERIC(12,2) | NOT NULL | >= 0. **Not** the 85/15 base |
| customer_responsibility | NUMERIC(12,2) | NOT NULL | >= 0 |
| receiver_responsibility | NUMERIC(12,2) | NOT NULL | >= 0 |
| who_pays | TEXT | NOT NULL | CUSTOMER/RECEIVER/SPLIT |

CHECK: `customer_responsibility + receiver_responsibility = applicable_bill_total`.

No Receiver user table.

---

## 7.38 `order_payment_plans`

**Immutable after confirm.** UNIQUE `order_id`. Intention only — not PAID.

| Column | Type | Null | Default | CHECK |
|---|---|---|---|---|
| payment_plan_id | UUID PK | NOT NULL | | |
| order_id | UUID UNIQUE FK | NOT NULL | | |
| customer_planned_online | NUMERIC(12,2) | NOT NULL | 0 | >= 0 |
| customer_planned_cash | NUMERIC(12,2) | NOT NULL | 0 | >= 0 |
| receiver_planned_online | NUMERIC(12,2) | NOT NULL | 0 | >= 0 |
| receiver_planned_cash | NUMERIC(12,2) | NOT NULL | 0 | >= 0 |

Per-payer sum-to-responsibility is a **cross-table** rule (plan vs responsibility). Prefer application/transaction validation; a DB CHECK cannot see the other table without a trigger. **Trigger vs application: NEEDS DECISION.** The rule is locked.

---

## 7.39 `payment_transactions`

| Column | Type | Null | Default | Keys | Mutable | Description |
|---|---|---|---|---|---|---|
| payment_transaction_id | UUID PK | NOT NULL | generated | | no | |
| order_id | UUID FK | NOT NULL | | | no | Many per order |
| payer_type | TEXT | NOT NULL | | CHECK | **no** | CUSTOMER/RECEIVER |
| method | TEXT | NOT NULL | | CHECK ONLINE/CASH | **no** | V1 |
| amount | NUMERIC(12,2) | NOT NULL | | CHECK > 0 | **no** | |
| direction | TEXT | NOT NULL | `'CHARGE'` | CHECK | **no** | REFUND = new row |
| transaction_status | TEXT | NOT NULL | `'PENDING'` | CHECK | PENDING→PAID/FAILED only | Not aggregate status |
| provider_txn_id | TEXT | NULL | | | no | |
| provider_event_id | TEXT | NULL | | **UNIQUE WHERE NOT NULL** | no | Webhook idempotency |
| idempotency_key | TEXT | NOT NULL | | UNIQUE with scope via idempotency_keys | no | |
| created_by_type | TEXT | NOT NULL | | CHECK | no | |
| created_by_profile_id | UUID | NULL | | | no | |
| created_at | TIMESTAMPTZ | NOT NULL | now() | | no | |
| updated_at | TIMESTAMPTZ | NOT NULL | now() | | status only | |

**Never** UNPAID/PARTIALLY_PAID/PAID on this row as trip status.  
Card PAN/CVV: **no columns**.

---

## 7.40 `order_finance_snapshots`

**Insert-only. `order_id` is NOT unique.**

| Column | Type | Null | Description |
|---|---|---|---|
| finance_snapshot_id | UUID PK | NOT NULL | |
| order_id | UUID FK | NOT NULL | Many rows |
| snapshot_kind | TEXT | NOT NULL | ORIGINAL / REVERSAL / ADJUSTMENT_FREEZE |
| trip_fare | NUMERIC(12,2) | NOT NULL | Confirmed Trip Fare (**85/15 base**) |
| rider_percentage | NUMERIC(5,2) | NOT NULL | Copied at freeze |
| company_commission_percentage | NUMERIC(5,2) | NOT NULL | |
| operational_cost_percentage_of_commission | NUMERIC(5,2) | NOT NULL | Of company share only |
| rider_amount | NUMERIC(12,2) | NOT NULL | |
| company_commission_amount | NUMERIC(12,2) | NOT NULL | |
| operational_cost_amount | NUMERIC(12,2) | NOT NULL | Not a rider deduction |
| profit_amount | NUMERIC(12,2) | NOT NULL | company − operational |
| payment_settings_version_id | UUID FK | NOT NULL | Version **in force at freeze** |
| frozen_at | TIMESTAMPTZ | NOT NULL | |

Partial UNIQUE `(order_id)` WHERE `snapshot_kind = 'ORIGINAL'` — one original trip-fare freeze; reversals are extra rows.  
CHECK percents 0–100; `rider_percentage + company_commission_percentage = 100`.  
Never UPDATE.

---

## 7.41 `order_cancellation_snapshots`

Immutable. Write even if fee = 0. UNIQUE `order_id` (one cancel event).

Columns: stage, actor_type (CUSTOMER/RIDER/ADMIN), allowed BOOLEAN, fee NUMERIC(12,2) DEFAULT 0, rider_share_percent, company_share_percent, rider_amount, company_amount, `cancellation_config_version_id` FK, created_at.

CHECK: `rider_share_percent + company_share_percent = 100`.

---

## 7.42 `failed_deliveries`

Immutable. UNIQUE `order_id` for V1 single event.

`reason TEXT NOT NULL DEFAULT 'RECEIVER_UNAVAILABLE'`, office_version_id FK, office_address_snapshot TEXT, office_latitude/longitude NUMERIC(9,6), office_distance_km NUMERIC(10,3) NOT NULL CHECK >= 0, created_at.

Original fare/finance **not** updated.

---

## 7.43 `order_adjustments`

Append-only. Office compensation = distance × snapshotted ₹8, beneficiary RIDER, not 85/15.

Columns per Blueprint B.42. `reason TEXT NOT NULL`. `amount NUMERIC(12,2) NOT NULL CHECK >= 0`.

---

## 7.44 `resend_snapshots`

Money columns immutable. `child_order_id` NULL until Case A storage is decided; column exists so either shape works.

| Column | Type | Null | Description |
|---|---|---|---|
| resend_snapshot_id | UUID PK | NOT NULL | |
| original_order_id | UUID FK | NOT NULL | Never overwrite original fare |
| child_order_id | UUID FK orders | NULL | Case A child **NEEDS DECISION** whether required |
| resend_case | TEXT | NOT NULL | A or B |
| distance_km | NUMERIC(10,3) | NOT NULL | |
| case_a_base_fare | NUMERIC(12,2) | NULL | Required when case = A |
| customer_amount | NUMERIC(12,2) | NOT NULL | Case A: base + ₹10×km; Case B: ₹10×km |
| rider_amount | NUMERIC(12,2) | NOT NULL | Case A: 85% of customer_amount; Case B: ₹8×km |
| company_amount | NUMERIC(12,2) | NOT NULL | Case A: 15%; Case B: ₹2×km |
| fare_config_version_id | UUID | NULL | Case A rate sheet **at resend time** |
| extra_rate_version_id | UUID FK | NOT NULL | |
| payment_settings_version_id | UUID | NULL | Case A 85/15 |
| request_status | TEXT | NOT NULL | NOT_DECIDED…COMPLETED |
| created_at | TIMESTAMPTZ | NOT NULL | |

CHECK: if `resend_case = 'A'` then `case_a_base_fare IS NOT NULL`.  
CHECK: if `resend_case = 'B'` then `case_a_base_fare IS NULL`.  
Do not change Case A/B formulas.

---

## 7.45 `invoices` + `invoice_lines`

`invoice_number TEXT UNIQUE NOT NULL` ≠ `orders.display_id`.  
`gst_on_fare NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK = 0`.  
`billed_total` = full bill, not one payer’s share.  
`customer_paid` / `receiver_paid` separate.  
status DRAFT/ISSUED/CANCELLED. issued_at after delivered + P&L freeze. pdf_file_id FK. emailed_to.  
UNIQUE `(order_id)` for issued retry identity — **one invoice per order type**; retry returns same row (Master §23). If cancelled re-issue is ever needed, that is **NEEDS DECISION**; this spec uses unique order_id for the happy path.

`invoice_lines`: invoice_id FK, line_type TEXT, label TEXT, amount NUMERIC(12,2). Immutable after issue. Not a second money authority; copied display.

Legal GSTIN/SAC columns: **omitted** (NEEDS DECISION). Do not invent.

---

## 7.46 `order_ratings`

UNIQUE `(order_id, direction)`. `stars INTEGER CHECK BETWEEN 1 AND 5`. `comment TEXT NULL`. Insert-once until edit is decided.

---

## 7.47 `notifications`

`notification_id UUID PK` (also dedupe id). `recipient_identity_id` and/or `recipient_profile_id` (at least one NOT NULL). `type TEXT`, `title TEXT NULL`, `body TEXT NOT NULL`, `order_id UUID NULL FK`, `read_at TIMESTAMPTZ NULL` (mutable), `created_at`.

---

## 7.48 `audit_logs`

**Append-only. Never UPDATE. Never hard-delete financial audit.**

| Column | Type | Null | Description |
|---|---|---|---|
| audit_log_id | UUID PK | NOT NULL | |
| actor_identity_id | UUID | NULL | System if null |
| actor_profile_id | UUID | NULL | |
| actor_role | TEXT | NULL | |
| action | TEXT | NOT NULL | |
| entity_type | TEXT | NOT NULL | |
| entity_id | UUID | NOT NULL | Logical pointer; not a FK that blocks |
| old_value | JSONB | NULL | Previous |
| new_value | JSONB | NULL | New |
| reason | TEXT | NULL | Where Admin is asked |
| request_id | TEXT | NULL | |
| ip | TEXT | NULL | Sensitive-ish |
| user_agent | TEXT | NULL | |
| category | TEXT | NULL | ADMIN / FINANCIAL (one table) |
| created_at | TIMESTAMPTZ | NOT NULL | |

Must cover: fare publish, payment settings, cancellation, office, wallet/COD/order financial adjustment, permissions, rider approve/reject/suspend, refunds.

---

## 7.49 `idempotency_keys`

| Column | Type | Null | Description |
|---|---|---|---|
| idempotency_id | UUID PK | NOT NULL | |
| scope | TEXT | NOT NULL | create-order, accept-offer, payment, webhook, recharge, cod-settlement, cancel, resend, invoice, status |
| key | TEXT | NOT NULL | Client or provider event id |
| actor_identity_id | UUID | NULL | Request identity |
| request_hash | TEXT | NOT NULL | Same key + different hash → reject |
| result_entity_id | UUID | NULL | First result |
| result_payload | JSONB | NULL | Stored original result |
| created_at | TIMESTAMPTZ | NOT NULL | |

UNIQUE `(scope, key)`.  
**Expiration: not defined. Do not invent a TTL column.** Money keys follow financial retention (never delete).

---

## 7.50 `rider_location_samples` (ARCHITECTURE READY)

rider_profile_id FK, order_id NULL FK, latitude/longitude NUMERIC(9,6), recorded_at. Append-only. Hot last point is Redis, not this table. Retention days NEEDS DECISION.

---

# 8. FOREIGN KEYS AND RELATIONSHIPS

Default: **ON DELETE RESTRICT, ON UPDATE RESTRICT**.  
Financial / snapshot / ledger / audit parents must not disappear. Master forbids hard-delete of financial rows, so CASCADE would only hide a mistake. **Do not CASCADE money.**

| Parent | Child | FK column | Card. | Required | ON DELETE |
|---|---|---|---|---|---|
| identities | customer_profiles | identity_id | 1:0..1 | yes | RESTRICT |
| identities | rider_profiles | identity_id | 1:0..1 | yes | RESTRICT |
| identities | admin_profiles | identity_id | 1:0..1 | yes | RESTRICT |
| identities | otp_challenges | identity_id | 1:N | no | SET NULL or RESTRICT. **NEEDS DECISION** if identity never deleted; RESTRICT is safe |
| identities | sessions | identity_id | 1:N | yes | RESTRICT |
| customer_profiles | customer_saved_addresses | customer_profile_id | 1:N | yes | RESTRICT |
| customer_profiles | orders | customer_profile_id | 1:N | yes | RESTRICT |
| customer_profiles | customer_wallet_accounts | customer_profile_id | 1:0..1 | yes if row exists | RESTRICT |
| rider_profiles | rider_drivers | rider_profile_id | 1:0..1 | yes | RESTRICT |
| rider_profiles | vehicles | rider_profile_id | 1:N | no | SET NULL (unassigned vehicle). Architecture allows nullable assignment |
| rider_profiles | rider_documents | rider_profile_id | 1:N | yes | RESTRICT |
| rider_profiles | rider_bank_accounts | rider_profile_id | 1:N | yes | RESTRICT |
| rider_profiles | rider_upis | rider_profile_id | 1:N | yes | RESTRICT |
| rider_profiles | rider_wallet_accounts | rider_profile_id | 1:1 | yes | RESTRICT |
| rider_profiles | rider_cod_accounts | rider_profile_id | 1:1 | yes | RESTRICT |
| rider_profiles | order_offers | rider_profile_id | 1:N | yes | RESTRICT |
| rider_profiles | orders | rider_profile_id | 1:N | no | RESTRICT (once set; column nullable) |
| cities | zones | city_id | 1:N | yes | RESTRICT |
| cities | orders | city_id | 1:N | yes | RESTRICT |
| cities | company_office_versions | city_id | 1:N | yes | RESTRICT |
| cities | order_display_counters | city_id | 1:1 | yes | RESTRICT |
| zones | rider_profiles | home_zone_id | 1:N | no | RESTRICT |
| zones | order_stops | zone_id | 1:N | no | RESTRICT |
| vehicle_categories | vehicles | vehicle_category_id | 1:N | yes | RESTRICT |
| vehicle_categories | orders | vehicle_category_id | 1:N | yes | RESTRICT |
| vehicle_categories | fare_config_version_rates | vehicle_category_id | 1:N | yes | RESTRICT |
| fare_config_versions | fare_config_version_rates | fare_config_version_id | 1:N | yes | RESTRICT |
| fare_config_versions | fare_quotes / order_fare_snapshots | fare_config_version_id | 1:N | yes | RESTRICT |
| payment_settings_versions | order_finance_snapshots | payment_settings_version_id | 1:N | yes | RESTRICT |
| cancellation_config_versions | cancellation_config_version_rules | cancellation_config_version_id | 1:N | yes | RESTRICT |
| cancellation_config_versions | order_cancellation_snapshots | cancellation_config_version_id | 1:N | yes | RESTRICT |
| extra_rate_versions | resend_snapshots / order_adjustments | extra_rate_version_id | 1:N | yes/no | RESTRICT |
| company_office_versions | failed_deliveries | office_version_id | 1:N | yes | RESTRICT |
| vehicles | vehicle_documents | vehicle_id | 1:N | yes | RESTRICT |
| vehicles | orders | vehicle_id | 1:N | no | RESTRICT |
| stored_files | rider_documents, vehicle_documents, invoices, order_stops | file_id | 1:N | yes/no | RESTRICT |
| rider_wallet_accounts | wallet_ledger_entries | wallet_account_id | 1:N | yes | RESTRICT |
| rider_cod_accounts | cod_ledger_entries | cod_account_id | 1:N | yes | RESTRICT |
| orders | order_stops | order_id | 1:N | yes | RESTRICT |
| orders | order_status_events | order_id | 1:N | yes | RESTRICT |
| orders | order_offers | order_id | 1:N | yes | RESTRICT |
| orders | order_fare_snapshots | order_id | 1:1 | yes after confirm | RESTRICT |
| orders | order_payment_responsibilities | order_id | 1:1 | yes after confirm | RESTRICT |
| orders | order_payment_plans | order_id | 1:1 | yes after confirm | RESTRICT |
| orders | payment_transactions | order_id | 1:N | yes | RESTRICT |
| orders | order_finance_snapshots | order_id | 1:N | yes | RESTRICT |
| orders | order_cancellation_snapshots | order_id | 1:0..1 | if cancelled | RESTRICT |
| orders | failed_deliveries | order_id | 1:0..1 | if failed | RESTRICT |
| orders | order_adjustments | order_id | 1:N | | RESTRICT |
| orders | resend_snapshots | original_order_id | 1:0..1 | | RESTRICT |
| orders | resend_snapshots | child_order_id | 1:0..1 | optional | RESTRICT |
| orders | orders | parent_order_id | 1:0..N | optional | RESTRICT |
| orders | invoices | order_id | 1:0..1 | | RESTRICT |
| invoices | invoice_lines | invoice_id | 1:N | | RESTRICT |
| orders | order_ratings | order_id | 1:0..2 | per direction | RESTRICT |
| admin_profiles | all *_versions.created_by | created_by_admin_profile_id | 1:N | yes | RESTRICT |

**No many-to-many junction** between customer and rider. The order is the join.

**Polymorphic:** `audit_logs.entity_id` and `idempotency_keys.result_entity_id` are UUIDs **without** FK (Master: logical pointer). `sessions` uses three nullable typed FKs instead of an untyped profile_id.

ON DELETE SET NULL is used only where the architecture already allows the child to exist without that parent: `vehicles.rider_profile_id`, `otp_challenges.identity_id` (if chosen). All money FKs: **RESTRICT**.

---

# 9. FINANCIAL DATA PROTECTION

| Architecture name | Table | Immutable | Append-only | Mutable | Versioned | Historical |
|---|---|---|---|---|---|---|
| Fare snapshot | `order_fare_snapshots` | **yes** | insert | **no** | refs fare_config_version | **yes** |
| Finance snapshot | `order_finance_snapshots` | original **yes**; reversal = **new row** | insert | **no** | refs payment_settings_version | **yes** |
| Payment settings | `payment_settings_versions` | published **yes** | new versions | drafts only | **yes** | **yes** |
| Payment transaction | `payment_transactions` | amount/payer **yes** | refund = new row | status of attempt only | no | **yes** |
| Payment responsibility | `order_payment_responsibilities` | after confirm **yes** | insert | **no** | no | **yes** |
| Payment plan | `order_payment_plans` | after confirm **yes** | insert | **no** | no | **yes** |
| Wallet account | `rider_wallet_accounts` | — | — | balance **only with ledger** | no | balance is cache |
| Wallet transaction | `wallet_ledger_entries` | **yes** | **yes** | **no** | no | **yes** |
| Rider COD Due | `rider_cod_accounts` | — | — | due **only with ledger** | threshold versioned separately | cache |
| COD settlement | rows on `cod_ledger_entries` | **yes** | **yes** | **no** | no | **yes** |
| Invoice | `invoices` | issued amounts **yes** | — | status/PDF/email | no | **yes** |
| Order adjustment | `order_adjustments` | **yes** | **yes** | **no** | extra_rate_version | **yes** |
| Cancellation snapshot | `order_cancellation_snapshots` | **yes** | insert | **no** | refs cancel version | **yes** |
| Resend snapshot | `resend_snapshots` | money **yes** | insert | request_status only | extra_rate + optional fare/payment versions | **yes** |

**Never silently overwrite financial history.** Admin publishes version N+1. Reports sum snapshots, never live sliders.

---

# 10. CONFIGURATION VERSIONING

```text
DRAFT  →  ACTIVE  →  SUPERSEDED
              │
              └── orders/quotes/snapshots store the version UUID
```

| Config | Current | Historical | How an old order stays correct |
|---|---|---|---|
| Fare | ACTIVE `fare_config_versions` | SUPERSEDED + child rates | `order_fare_snapshots` copies numbers **and** `fare_config_version_id` |
| 85/15/50 | ACTIVE `payment_settings_versions` | SUPERSEDED | `order_finance_snapshots` copies percents/amounts **and** version id at **freeze** |
| Cancellation | ACTIVE per actor | SUPERSEDED | `order_cancellation_snapshots` copies fee/shares + version id |
| COD threshold | ACTIVE `cod_policy_versions` | SUPERSEDED | Accept uses active; suspend audit can store version; threshold default ₹100 |
| Office | ACTIVE per city | SUPERSEDED | `failed_deliveries` copies lat/lng/address + office_version_id |
| Extra ₹/km | ACTIVE `extra_rate_versions` | SUPERSEDED | Resend/adjustment snapshots copy amounts + extra_rate_version_id |
| Methods | ACTIVE policy | SUPERSEDED | Booking validated against version then in force |

Published rows used by orders are **never edited in place**.

---

# 11. SNAPSHOT DESIGN

| Snapshot table | Captures | When | Why | Source version | Update | Delete |
|---|---|---|---|---|---|---|
| `order_fare_snapshots` | Trip Fare, lines, GST 0, distance | Confirm | Old trips must not move when Admin changes rates | fare_config_version | **no** | **no** |
| `order_payment_responsibilities` | Who owes the bill | Confirm | WHO PAYS ≠ collections | — | **no** | **no** |
| `order_payment_plans` | Intended methods | Confirm | Intention ≠ PAID | — | **no** | **no** |
| `order_finance_snapshots` | 85/15/50 amounts | Delivered / terminal cancel-fail; reversals later | P&L freeze; reports | payment_settings_version at freeze | **no** | **no** |
| `order_cancellation_snapshots` | Fee and shares | Cancel | Not auto 85/15; even ₹0 | cancellation_config_version | **no** | **no** |
| `failed_deliveries` | Reason, office copy, km | Receiver unavailable | Not a cancel; km survives office move | company_office_version | **no** | **no** |
| `order_adjustments` | Extra money fact | Office extra / audited fix | Trip Fare must not jump in place | extra_rate_version if office | **no** | **no** |
| `resend_snapshots` | Case A/B amounts | Resend | Original fare untouched | extra_rate + fare/payment for Case A at **resend time** | money no | **no** |
| `invoices` / lines | Document amounts | After freeze | Invoice ≠ display_id; GST 0 | copied from snapshots | amounts no | no hard-delete issued |
| `order_status_events` | from/to/actor | Every transition | One machine history | — | **no** | **no** |

Snapshots **intentionally duplicate** live config numbers. That is required, not a normalization defect.

---

# 12. WALLET AND LEDGER DESIGN

## A. Rider earning wallet — `rider_wallet_accounts`

Materialized `available_balance >= 0`. **Not** COD Due. Cash-trip rider share is **physical** and is **not** posted here.

## B. Wallet transactions — `wallet_ledger_entries`

Source of truth. Append-only. Balance changes only in the same database transaction as the insert.

## C. Rider COD Due — `rider_cod_accounts` + `cod_ledger_entries`

`cod_due >= 0`. Increase on cash company share. Example: Trip Fare ₹100, cash ₹100 → wallet unchanged, COD Due +₹15.

## D. COD settlement events

**Not a third table.** Settlement = COD ledger DECREASE + optional wallet CREDIT of remainder, under one rider-finance lock.

Order: eligible **digital** inflows settle COD first (recharge, later online earning, cancellation rider share). Cash-trip ₹85 must **not** settle that trip’s own ₹15.

Suspend: `cod_due >=` active policy threshold (default ₹100) → `SUSPENDED_FOR_COD` → cannot accept **new** offers.

---

# 13. PAYMENT DESIGN

| Concept | Table | Role |
|---|---|---|
| Responsibility | `order_payment_responsibilities` | Customer and/or Receiver owe the **bill** (usually net payable). Sum = bill. Not 85/15 base |
| Plan | `order_payment_plans` | Intended ONLINE/CASH split per payer |
| Transactions | `payment_transactions` | Many rows. Payer CUSTOMER/RECEIVER. Method ONLINE/CASH. Status PENDING/PAID/FAILED/REFUNDED |
| Split | Same tables | Customer ₹50 + Receiver ₹50; or one payer Online+Cash |
| Aggregate UNPAID / PARTIALLY_PAID / PAID | **Derived** | Sum(PAID charges − refunds) vs responsibility. PAID only when **equals** owed |
| COD | Cash transaction PAID + COD ledger if company share held | Not a payment_method on the order |
| Online | method ONLINE, PAID only after provider confirm | Do not fake |
| Refund | New row `direction=REFUND` | Original unchanged |

No Receiver table. No single `orders.payment_method` as truth.

---

# 14. ORDER / TRIP STRUCTURE

```text
orders
  ├── order_stops                 (1 pickup + 1..3 drops)
  ├── order_status_events
  ├── order_offers                (≤1 ACCEPTED)
  ├── order_fare_snapshots        (1)
  ├── order_payment_responsibilities (1)
  ├── order_payment_plans         (1)
  ├── payment_transactions        (N)
  ├── order_finance_snapshots     (N)
  ├── order_cancellation_snapshots (0..1)
  ├── failed_deliveries           (0..1)
  ├── order_adjustments           (N)
  ├── resend_snapshots            (0..1)
  ├── parent_order_id / child     (Case A option)
  ├── invoices                    (0..1)
  └── order_ratings
```

Multi-stop: unique sequence; fare distance = sum of legs stored on fare snapshot. No extra-stop fee column.

---

# 15. RESEND DESIGN

**Case A** (original ended): customer = rate-sheet **base at resend time** + ₹10/km; then **normal 85/15** on that combined amount. Original fare snapshot **untouched**.

**Case B** (original not ended): customer ₹10/km, rider ₹8/km, company ₹2/km. **Not** 85/15. Original fare **untouched**.

**Physical storage (Master TECHNICAL DESIGN OPTION):**

| Mechanism | Column | Status |
|---|---|---|
| Child order | `orders.parent_order_id` | Supported |
| Related record | `resend_snapshots` + optional `child_order_id` | Supported |
| Which Case A/B shape is mandatory | — | **NEEDS DECISION** |

Schema must not overwrite `order_fare_snapshots` of the original. Office ₹8/km is `order_adjustments`, not a rewrite of Trip Fare.

Close-without-resend status/fee: **NEEDS DECISION**. No extra status value in this spec.

---

# 16. AUDIT LOG

See `audit_logs` §7.48. Required fields match Master §29: who (identity, profile, role), what (action), which entity (type + id), old value, new value, timestamp, reason, request/reference, IP/UA where useful.

One table with `category` (this spec). Two tables remains an allowed technical alternative (**NEEDS DECISION**).

---

# 17. IDEMPOTENCY

Table `idempotency_keys`: unique `(scope, key)`, `request_hash`, `actor_identity_id`, `result_entity_id`, `result_payload`, `created_at`.

Same key + same hash → original result. Same key + different hash → reject.

**Expiration: not defined. Do not invent.**

Scopes: create-order, accept-offer, payment, webhook (`provider_event_id` also unique on `payment_transactions`), recharge, COD settlement `(cod_account_id, source_txn_id)`, cancel, resend, invoice, status.

---

# 18. INDEX STRATEGY

Only indexes justified by Master §35 and Blueprint lookup patterns.

| Table | Index | Why |
|---|---|---|
| All | PRIMARY KEY UUID | Identity |
| identities | UNIQUE phone_normalized | Login |
| identities | UNIQUE email WHERE email IS NOT NULL | Optional email |
| orders | UNIQUE display_id | Support lookup |
| orders | (customer_profile_id, created_at DESC) | Customer history |
| orders | (customer_profile_id, canonical_status) | Active trips (many allowed) |
| orders | (rider_profile_id, canonical_status, created_at DESC) | Rider active/history |
| orders | (city_id, canonical_status, created_at DESC) | Admin city ops |
| order_offers | (order_id) | Dispatch |
| order_offers | (rider_profile_id, status) | Incoming offers |
| order_offers | UNIQUE (order_id) WHERE status='ACCEPTED' | One winner |
| payment_transactions | (order_id, created_at) | Reconcile paid vs owed |
| payment_transactions | UNIQUE provider_event_id WHERE NOT NULL | Webhook retry |
| wallet_ledger_entries | (wallet_account_id, created_at) | Statement / reconcile |
| rider_cod_accounts | (cod_due) or (cod_due) WHERE due >= threshold | Suspend list (Master §35) |
| cod_ledger_entries | (cod_account_id, created_at) | COD statement |
| invoices | UNIQUE invoice_number | Download |
| invoices | (order_id) | Idempotent generate |
| audit_logs | (entity_type, entity_id, created_at) | Who changed this |
| idempotency_keys | UNIQUE (scope, key) | Retry |
| order_status_events | (order_id, created_at) | Timeline |
| fare_quotes | (customer_profile_id, created_at) | Latest quote |
| notifications | (recipient_identity_id, created_at) / profile | Inbox |
| All FKs | btree on FK columns | Join / restrict |

Cursor pagination uses `(created_at, id)`, not deep OFFSET (Master §35).

Do not index every TEXT column. Partition **readiness** later for orders, status events, payment_transactions, wallet_ledger_entries, audit_logs — not day-1 extra indexes.

---

# 19. CONSTRAINT STRATEGY

| Constraint | Level | Why |
|---|---|---|
| UUID PKs | PK | Canonical ids |
| display_id unique | UNIQUE | One human trip id |
| invoice_number unique | UNIQUE | Documents |
| phone unique | UNIQUE | One identity |
| email unique where present | UNIQUE partial | |
| One profile per identity per role | UNIQUE identity_id on each profile | |
| customer + receiver = bill | CHECK on responsibility | Locked |
| rider% + company% = 100 | CHECK on payment settings and cancel rules/snapshots | Locked |
| percents 0–100 | CHECK | Locked |
| wallet >= 0, COD due >= 0 | CHECK | Locked |
| ledger amount > 0 | CHECK | Direction carries sign |
| fare/invoice tax = 0 | CHECK | GST locked 0 |
| one ACCEPTED offer | UNIQUE partial | Accept race |
| one ORIGINAL finance snapshot per order | UNIQUE partial | Reversals still allowed |
| unique stop sequence | UNIQUE (order_id, sequence) | Route |
| unique (scope, key) idempotency | UNIQUE | Retries |
| unique provider_event_id | UNIQUE partial | Double webhook |
| unique (cod_account_id, source_txn_id) | UNIQUE partial | Settlement once |
| unique (order_id, direction) ratings | UNIQUE | One per direction |
| version unique per stream | UNIQUE | Config |
| one ACTIVE fare/payment/cod/extra/method | UNIQUE partial | Current version |
| one ACTIVE cancel per actor | UNIQUE partial | |
| one ACTIVE office per city | UNIQUE partial | |
| FK RESTRICT on money | FK | No orphan snapshots |

**Do not** implement 85/15 arithmetic as a generated column from live settings. Store freeze amounts.  
**Do not** put dispatch algorithm or OTP length into CHECK constraints.

Cross-table: plan vs responsibility; paid vs owed aggregates — application or triggers (**NEEDS DECISION** for trigger). Architecture requires the rules either way.

---

# 20. SECURITY / DATA ACCESS

Database-level notes only (Master §32). Not a complete IAM framework.

| Table / column | Sensitivity | DB consideration |
|---|---|---|
| identities.phone_normalized, email | PII | Unique; mask in counterpart UIs at API |
| otp_challenges.code_hash | Secret | Hash only; no plaintext column |
| sessions.refresh_token_hash | Secret | Hash |
| admin_profiles.password_hash | Secret | Argon2id; never in app repos |
| rider_bank_accounts.account_encrypted_or_token | Financial | Encrypt/tokenize at rest; masked display column |
| rider_upis.vpa_encrypted_or_token | Financial | Same |
| rider_drivers.licence_reference, DOB | KYC | Protect |
| rider_documents / stored_files | KYC | Metadata only; bytes in object storage; signed URLs |
| payment_transactions | Financial | No PAN/CVV columns |
| wallet / COD / snapshots / invoices | Financial | RESTRICT delete; RBAC at API |
| audit_logs.ip | PII-ish | Super Admin read |
| order_stops.contact_phone | PII | Nullable |

Row-level security policies: **not defined** in the architecture. Enforcement is API RBAC (Master §8, §32.2). Do not invent Postgres RLS as a required product rule. Optional later = **NEEDS DECISION**.

---

# 21. NORMALIZATION CHECK

| Item | Verdict |
|---|---|
| Duplicate live fare on snapshot | **Required.** Historical truth |
| vehicle_category_name_snapshot on orders/fare snapshot | **Required.** Do not join by “Bike” |
| Office address copied onto failed_delivery | **Required.** Office may move |
| Invoice copies snapshot amounts | **Required.** Do not rebuild from live Admin |
| Convenience trip_fare on `orders` | **Omitted** to avoid a second mutable truth |
| Receiver as user table | **Omitted.** Payer type only |
| JSONB vs child fare rates | Child rows specified; JSONB alternative listed |
| Wallet balance + ledger | Materialized cache + append-only truth. Reconcile: balance = sum(credits)−sum(debits) |
| Aggregate payment status on orders | **Omitted as source of truth.** Derive from transactions |

Missing relationships: none required by Master. No N:N customer–rider table.

---

# 22. TRACEABILITY MATRIX

| Master requirement | Blueprint | Table(s) | Important constraints |
|---|---|---|---|
| One identity, many profiles | B.1–B.6 | identities, *_profiles | unique phone; unique identity_id per profile |
| Same phone Customer+Rider | §7 | identities + two profiles | not two logins |
| UUID + display_id | B.30 | orders, order_display_counters | unique display_id; PK UUID |
| Stops 1 pickup + ≤3 drops | B.31 | order_stops | unique sequence; type CHECK |
| One status + history | D.1, B.32 | orders.canonical_status, order_status_events | locked status list; append-only events |
| Offer lock / one winner | B.33 | order_offers | unique ACCEPTED per order |
| Fare version ≠ snapshot | B.11, B.35 | fare_config_*, order_fare_snapshots | snapshot UNIQUE order_id; tax=0 |
| 85/15 on Trip Fare; ops from company | C.2, B.12, B.39 | payment_settings_versions, order_finance_snapshots | % sum 100; many finance rows; trip_fare base |
| GST = 0 | C.1 | fare snapshot tax, invoices.gst_on_fare | CHECK = 0 |
| WHO PAYS / HOW / actuals | B.36–B.38 | responsibility, plan, payment_transactions | responsibility sum; many txns |
| UNPAID/PARTIAL/PAID | C.3 | derived from PAID txns | not txn status |
| Wallet ≠ COD; never negative | B.25–B.28 | rider_wallet_accounts, wallet_ledger_entries, rider_cod_accounts, cod_ledger_entries | balances >= 0; separate FKs |
| Settle COD first; suspend ≥ threshold | C.4–C.5 | COD ledger DECREASE; rider_profiles.cod_operational_status; cod_policy_versions | threshold default 100 |
| Cancel versioned, ₹0 default, shares 100 | B.14, B.40 | cancellation_config_*, order_cancellation_snapshots | % = 100; fee default 0 |
| Failed delivery ≠ cancel | B.41–B.42 | failed_deliveries, order_adjustments | reason RECEIVER_UNAVAILABLE; ₹8/km adjustment |
| Resend A/B | B.43 | resend_snapshots, optional parent_order_id | case CHECK; original fare untouched |
| Invoice ≠ trip id; full bill | B.44 | invoices | unique invoice_number; gst 0 |
| Audit who/old/new | B.47 | audit_logs | append-only |
| Idempotency | B.48 | idempotency_keys | unique (scope, key) |
| Admin config versioning | E, B.11–B.17 | *_versions | no in-place edit of used versions |
| KYC files in object storage | B.20–B.22 | stored_files, *_documents | no bytea |
| Bank/UPI masked | B.23–B.24 | rider_bank_accounts, rider_upis | encrypted + masked columns |
| No Receiver app | §4.17 | — | payer_type only |
| Reports from snapshots | §37 | finance/fare/ledgers | no live recalc |

---

# 23. NEEDS DECISION

Only items still undefined for **physical schema / SQL**. Do not re-ask locked money rules.

| # | Decision | Why it is still open |
|---|---|---|
| 1 | Confirm `NUMERIC(12,2)` vs `BIGINT` paise for **all** money columns | Master §43; this spec’s working type is NUMERIC(12,2) |
| 2 | Who generates UUID v7 (application vs database function) | Type is UUID either way |
| 3 | Fare/cancel rates as child tables (this spec) vs JSONB payload | Master technical option |
| 4 | Extra rates one table (this spec) vs split resend vs office tables | Numbers locked either way |
| 5 | Case A/B storage: require child order, related snapshot only, or both | Columns exist for both |
| 6 | CHECK that Case B 10=8+2 on future extra_rate versions | Today’s numbers locked; future edits not constrained by Master |
| 7 | Plan-vs-responsibility and 1–3 drop counts: constraint trigger vs application only | Rules locked; enforcement mechanism not |
| 8 | `otp_challenges.identity_id` ON DELETE SET NULL vs RESTRICT | Identities are not hard-deleted anyway |
| 9 | OTP expiry, max_attempts defaults | Policy not locked; columns exist |
| 10 | Session TTL; refresh_token_hash required or not | Transport NEEDS DECISION |
| 11 | Invoice number format / series | Uniqueness locked; statutory format open |
| 12 | Unique one invoice per order forever vs allow re-issue after CANCELLED | Retry same number locked for generate |
| 13 | Notification recipient: require identity, profile, or either | Both columns specified |
| 14 | Audit one table (this spec) vs two | Same columns |
| 15 | Postgres RLS vs API-only access control | Architecture: API RBAC |
| 16 | `onboarding_kyc_status`, bank/UPI verification, document_type lists | Concepts locked; labels not fully listed |
| 17 | Rider UNIQUE one driver row (this spec) vs multiple when fleet decided | Fleet is future |
| 18 | GPS sample retention / whether to create `rider_location_samples` in V1 schema | ARCHITECTURE READY |
| 19 | Whether to physically create customer wallet tables in V1 schema | ARCHITECTURE READY; not required to book |
| 20 | Launch values of cash_enabled / online_enabled | Model supports both |
| 21 | Quote TTL duration to store in `expires_at` | Short TTL locked; minutes not numbered |
| 22 | Idempotency key expiration | **Not defined — do not invent a TTL** |

Items 8–29 in the Implementation Blueprint that are product/ops (dispatch algorithm, OTP length digits, capture moment, SAC/GSTIN, etc.) remain open for **product**, not additional tables. Columns already exist without those policy numbers.

---

# 24. FINAL VALIDATION

| Check | Result |
|---|---|
| 1. Compared to Master Architecture | Yes. Master wins on conflict |
| 2. Compared to Implementation Blueprint | Yes. Entity list aligned |
| 3. Every Master-required entity covered | Yes. Settlement is ledger rows, not a third table |
| 4. Relationships covered | Yes. No invented N:N |
| 5. Financial snapshots protected | Yes. Insert-only; RESTRICT delete |
| 6. Wallet and COD Due separate | Yes. Two accounts, two ledgers |
| 7. 85/15/50 preserved | Yes. On finance snapshot from Trip Fare; ops from company share |
| 8. Trip Fare is 85/15 base, not invoice grand total / net payable | Yes. `order_fare_snapshots.trip_fare`; bill is `net_payable` / responsibility total |
| 9. GST = 0 | Yes. CHECK on fare snapshot and invoice |
| 10. Order UUID + display_id | Yes. PK UUID; unique `IU-{CITY}-{10 digits}` |
| 11. Multi-payment | Yes. `payment_transactions` 1:N |
| 12. Customer/Receiver/Split responsibility | Yes. Separate from plan and transactions |
| 13. Resend Case A and Case B | Yes. Formulas unchanged; storage shape NEEDS DECISION |
| 14. Cancellation configuration/versioning | Yes. Actor streams + snapshot |
| 15. Audit and idempotency | Yes. No invented idempotency TTL |
| 16. No new business decisions | Yes. Technical mappings listed; product opens remain NEEDS DECISION |

**No SQL was written. No source architecture file was modified. No application, UI, API, or database was modified.**

---

**End of DATABASE SCHEMA SPECIFICATION**
