# DATABASE SCHEMA AUDIT

**Type:** Audit only. No SQL. No migrations. No schema edits.  
**Date:** 2026-08-24  
**Audited file:** `records_database/DATABASE_SCHEMA_SPECIFICATION.md`  
**Authoritative sources (higher wins):**
1. `records_database/MASTER_SYSTEM_ARCHITECTURE.md` (highest)
2. `records_database/IMPLEMENTATION_BLUEPRINT.md`

**This audit does not modify** the Master Architecture, the Implementation Blueprint, or the Schema Specification.

**Legend:** Severity CRITICAL / HIGH / MEDIUM / LOW.  
**User decision required?** YES / NO.

---

## 1. Executive Summary

The Schema Specification is **aligned with the locked IDHAR UDHAR money model**. It does not revive stale `04`/`05` single-payment rows, COD-as-negative-wallet, unique-per-order finance snapshots that block reversals, invoice GST 5%, or a Receiver user table.

**What is correct (locked rules preserved):**

- 85/15 is stored against **Trip Fare** (`order_fare_snapshots.trip_fare` / `order_finance_snapshots.trip_fare`), not net payable, not invoice grand total, not GST, not payment amount.
- Operations cost is **50% of company commission**, not a rider deduction.
- GST on fare is locked with `CHECK (tax = 0)` / `CHECK (gst_on_fare = 0)`.
- Wallet and COD Due are **separate** accounts and **separate** ledgers. Wallet `available_balance >= 0`. COD `cod_due >= 0`.
- COD settlement is **not** a third balance table; it is a COD ledger `DECREASE` plus an optional wallet twin credit (Master §18.2–18.3; Blueprint B.28).
- Order PK is UUID; human id is unique `IU-{CITY}-{10 digits}`.
- Responsibility, plan, and transactions are three tables. Aggregate UNPAID / PARTIALLY_PAID / PAID is derived.
- Cancellation default fee ₹0; rider% + company% = 100; not auto 85/15.
- Resend Case A / Case B formulas are stated correctly; original fare snapshot is not overwritten.
- Append-only snapshots, ledgers, and audit. Default FK `ON DELETE RESTRICT` on money.

**What is not safe to convert to SQL yet:**

1. Master §43 money storage is still unpicked (`NUMERIC(12,2)` vs integer paise). The spec’s working type is not a silent lock.
2. Several tables are **abbreviated** in §7. SQL cannot be emitted from those sections without inventing columns.
3. Twin FKs between `wallet_ledger_entries` and `cod_ledger_entries` create a **circular dependency** with no DEFERRABLE / single-direction rule.
4. Case A version FKs are nullable without CHECKs that Case A must snapshot fare settings and 85/15 at resend time.
5. Inventory arithmetic is wrong: the spec claims **50 locked + 4 architecture-ready = 54**. The listed architecture-ready set is **3 tables**, which implies **51 locked**, not 50.

**SQL readiness:** **READY WITH DECISIONS**

Not **READY FOR SQL**: money type must be chosen uniformly first, and HIGH specification gaps must be closed in the spec (not invented in SQL).  
Not **NOT READY**: the entity model matches Master §12.5 / Blueprint §B, and no locked business rule was rewritten into a conflicting structure.

| Metric | Count |
|---|---|
| Issues logged below | **42** |
| CRITICAL | **0** |
| HIGH | **9** |
| MEDIUM | **18** |
| LOW | **15** |
| Spec NEEDS DECISION items classified A (must decide before SQL) | **2** (money type; ledger twin-FK mechanism — the second is a spec gap, not one of the original 22) |
| Original 22 items that remain A | **1** (`NUMERIC(12,2)` vs `BIGINT` paise) |
| Original 22 items that can be deferred after SQL | **14** |
| Original 22 already decided by Master / already chosen by the spec / not a decision | **7** |

---

## 2. Table Inventory Audit

### 2.1 Architecture entity → schema table

| Architecture Entity | Required? | Schema Table | Correct? | Notes |
|---|---|---|---|---|
| Identity | YES (Master §7, §12.5) | `identities` | YES | Unique phone; unique email when present |
| OTP challenge | YES (§7.5) | `otp_challenges` | YES | Hash only |
| Session | YES (§7.6; BP B.3) | `sessions` | YES | Three typed profile FKs instead of untyped `profile_id` — valid technical mapping |
| Customer profile | YES (§9) | `customer_profiles` | YES | Unique per identity |
| Rider profile | YES (§10) | `rider_profiles` | YES | COD operational status present |
| Admin profile | YES (§8, §11) | `admin_profiles` | YES | See password-location issue |
| Customer saved address | YES (§9.2; BP B.7) | `customer_saved_addresses` | YES | Copied onto stops |
| City | YES (§12.1, §I) | `cities` | YES | `city_code` unique |
| Zone | YES | `zones` | YES | |
| Vehicle category | YES (§26) | `vehicle_categories` | YES | Join by id |
| Fare config version | YES (§15, §24) | `fare_config_versions` | YES | |
| Fare rates inside version | YES (§15.2) | `fare_config_version_rates` | YES | Child rows = spec’s pick of a TECHNICAL DESIGN OPTION |
| Payment settings 85/15/50 | YES (§4, §22, §24) | `payment_settings_versions` | YES | Defaults 85 / 15 / 50; sum CHECK = 100 |
| Payment method policy | YES (§24) | `payment_method_policy_versions` | YES | Extra method flags beyond cash/online match Master “support all labels day one” |
| Cancellation config | YES (§20) | `cancellation_config_versions` + `cancellation_config_version_rules` | YES | Actor streams; fee default 0 |
| COD policy version | YES (§18.4, §24) | `cod_policy_versions` | YES | Default threshold 100 |
| Resend / office extra rates | YES (§21, §24) | `extra_rate_versions` | YES | One sheet = spec pick of TECHNICAL DESIGN OPTION |
| Company office version | YES (§25) | `company_office_versions` | YES | Copy onto failed delivery |
| Display-id sequence | YES as mechanism (§12.1) | `order_display_counters` | YES | Not a business entity; required for `IU-{CITY}-{10 digits}` |
| Vehicle instance | YES (§26.2) | `vehicles` | YES | |
| Optional driver | YES as placeholder (§10.1) | `rider_drivers` | YES | V1 UNIQUE per rider |
| Stored file metadata | YES (§27) | `stored_files` | YES | No bytea |
| Rider KYC document | YES (§27.1) | `rider_documents` | YES | |
| Vehicle document | YES (§26–27) | `vehicle_documents` | YES | |
| Rider bank | YES (§27.2) | `rider_bank_accounts` | YES | Masked + encrypted columns |
| Rider UPI | YES (§27.2) | `rider_upis` | YES | |
| Rider earning wallet | YES (§19) | `rider_wallet_accounts` | YES | 1:1; never COD |
| Wallet ledger / wallet transaction | YES (§19.1) | `wallet_ledger_entries` | YES | Append-only |
| Rider COD Due | YES (§18) | `rider_cod_accounts` | YES | Separate from wallet |
| COD ledger + settlement events | YES (§18.2–18.3) | `cod_ledger_entries` | YES | No third `cod_settlements` table — correct |
| Order / trip | YES (§12) | `orders` | YES | UUID PK; unique `display_id`; nullable rider; `parent_order_id` |
| Order stop | YES (§13) | `order_stops` | YES | 1 pickup + 1..3 drops |
| Order status event | YES (§14.2) | `order_status_events` | YES | Append-only |
| Order offer | YES (§O, §31.2) | `order_offers` | YES | One ACCEPTED |
| Fare quote | YES (§15) | `fare_quotes` | YES | |
| Fare snapshot | YES (§15.2) | `order_fare_snapshots` | YES | UNIQUE 1:1 billed order; tax = 0 |
| Payment responsibility | YES (§16.1) | `order_payment_responsibilities` | YES | Sum = bill; not 85/15 base |
| Payment plan | YES (§16.2) | `order_payment_plans` | YES | Intention only |
| Payment transaction | YES (§17) | `payment_transactions` | YES | 1:N; PENDING/PAID/FAILED/REFUNDED |
| Finance snapshot | YES (§22) | `order_finance_snapshots` | YES | `order_id` not unique; ORIGINAL partial unique |
| Cancellation snapshot | YES (§20.4) | `order_cancellation_snapshots` | YES | Write even if fee 0 |
| Failed delivery | YES (§21.1) | `failed_deliveries` | YES | Not a cancel |
| Order adjustment | YES (§21.1, §22) | `order_adjustments` | YES | Office ₹8/km |
| Resend snapshot | YES (§21.4) | `resend_snapshots` | YES | Case A/B; original fare untouched |
| Invoice | YES (§23) | `invoices` | PARTIAL | Entity exists; header columns abbreviated — Issue 14 |
| Invoice lines | OPTIONAL (BP B.44 either fields **or** children) | `invoice_lines` | YES as option | Spec also keeps header amounts — Issue 28 |
| Order rating | YES when product persists ratings (§40; BP B.45) | `order_ratings` | PARTIAL | Unique per direction; rater columns abbreviated — Issue 15 |
| Notification | YES (§28) | `notifications` | YES | |
| Audit log | YES (§29) | `audit_logs` | YES | One table with `category` |
| Idempotency record | YES (§30) | `idempotency_keys` | YES | No invented TTL |
| Customer wallet | ARCHITECTURE READY (§9.3, §19.3) | `customer_wallet_accounts` | YES as ready | Not required to book |
| Customer wallet ledger | ARCHITECTURE READY (§19.3; BP B.29) | `customer_wallet_ledger_entries` | YES as ready | |
| GPS / location samples | OPTIONAL / READY (Master: Redis hot GPS; BP B.49) | `rider_location_samples` | YES as optional | Not required by Master as a Postgres table |
| Receiver user | NO (§4.17) | — | YES omitted | `payer_type` only |
| Chat | NO | — | YES omitted | |
| Combined wallet+COD | FORBIDDEN | — | YES omitted | |
| Single `payments` row as the model | FORBIDDEN (§34.3) | — | YES omitted | |
| `cod_settlements` third balance | NO (settlement is a posting pair) | — | YES omitted | Correct |

**Issue 1 — MEDIUM**  
**Problem:** Inventory arithmetic is internally inconsistent. Spec §3 claims “50 required + 4 ARCHITECTURE READY = 54” and then lists only three architecture-ready names. Counting rows 1–54 minus the three ready tables yields **51** locked tables, not 50.  
**Source:** Spec §3 vs table list rows 1–54.  
**Affected:** Whole inventory.  
**Recommended resolution:** Recount. Treat locked production as **51** (including `order_display_counters` and `invoice_lines`) and architecture-ready as **3**, total **54**. Or reclassify `invoice_lines` / `order_display_counters` explicitly if the intended locked count is 50.  
**User decision required?** NO (counting). Optionally YES if the team wants `invoice_lines` folded into `invoices`.

### 2.2 Locked production vs architecture-ready vs should-not-exist

#### A. LOCKED PRODUCTION TABLES (required for the locked model)

All inventory rows **except** 32, 33, and 54:

`identities`, `otp_challenges`, `sessions`, `customer_profiles`, `rider_profiles`, `admin_profiles`, `customer_saved_addresses`, `cities`, `zones`, `vehicle_categories`, `fare_config_versions`, `fare_config_version_rates`, `payment_settings_versions`, `payment_method_policy_versions`, `cancellation_config_versions`, `cancellation_config_version_rules`, `cod_policy_versions`, `extra_rate_versions`, `company_office_versions`, `order_display_counters`, `vehicles`, `rider_drivers`, `stored_files`, `rider_documents`, `vehicle_documents`, `rider_bank_accounts`, `rider_upis`, `rider_wallet_accounts`, `wallet_ledger_entries`, `rider_cod_accounts`, `cod_ledger_entries`, `orders`, `order_stops`, `order_status_events`, `order_offers`, `fare_quotes`, `order_fare_snapshots`, `order_payment_responsibilities`, `order_payment_plans`, `payment_transactions`, `order_finance_snapshots`, `order_cancellation_snapshots`, `failed_deliveries`, `order_adjustments`, `resend_snapshots`, `invoices`, `invoice_lines`, `order_ratings`, `notifications`, `audit_logs`, `idempotency_keys`.

**Count: 51** (not 50).

`order_display_counters` is not named in Master §12.5 but **is required** to implement Master §12.1 (“database sequence for the 10-digit part”). Keep it.

`invoice_lines` is a TECHNICAL DESIGN OPTION (Blueprint B.44). Keep only if header amounts are not the sole display store — see Issue 28.

#### B. ARCHITECTURE-READY / FUTURE TABLES

See §3.

#### C. TABLES THAT SHOULD NOT EXIST

None of the 54 is a forbidden revival (no Receiver app users, no chat, no merged wallet+COD, no third COD balance, no single `payments` truth).

No table must be deleted as “should not exist.” Two architecture-ready tables must not be treated as V1 booking requirements.

---

## 3. Extra / Future Tables Audit

The previous specification reported **4** architecture-ready tables: “customer wallet ×2, customer wallet ledger, GPS samples.”

The actual specified ready tables are **three**:

| Table | Explicitly required by Master? | Required for current production / V1 booking? | Only future-ready? | Duplicate of another table? | Remain in final production schema? | Why |
|---|---|---|---|---|---|---|
| `customer_wallet_accounts` | **No as V1.** Master §9.3 / §19.3: **ARCHITECTURE READY** — “a customer wallet + ledger **can** exist.” Booking must **not** require wallet debit. | **No.** | **Yes.** | **No.** Separate from `rider_wallet_accounts`. | **Optional.** May be created so the model is not redesigned later. Must **not** be in the locked V1 booking set. Must **not** auto-debit. Dummy ₹420 / ₹50 / ₹200 / ₹150 must not become defaults (Master §V; spec already says this). | Ready, not live. |
| `customer_wallet_ledger_entries` | Same as above (the ledger half of §19.3). | **No.** | **Yes.** | **No.** Companion to customer wallet, not a second rider ledger. | **Optional, paired with the account.** If the account table is created, the ledger must exist too (Master: same ledger pattern). If neither is created in V1 SQL, that is also valid. | Ready, not live. |
| `rider_location_samples` | **No.** Master hot GPS is **Redis** (§5, §33.1, §39). Master never names a Postgres GPS history table. Blueprint A: do **not** write 1 Hz GPS to Postgres. B.49: optional sampled history; retain days open. | **No.** | **Yes**, and even then only if a retain policy is later decided. | **Does not duplicate a required Postgres table.** It **would** be wrong to use this as the hot last-point store (that is Redis). | **Do not treat as locked production.** Including it in V1 SQL without a retention policy stores location PII with no Master-defined retain rule. Prefer **omit from V1 SQL**; add later if product wants breadcrumbs. | Optional; Master does not require it. |

There is **no fourth** architecture-ready table.

**Issue 2 — HIGH**  
**Problem:** Spec §3 double-counts customer wallet (“×2” plus “customer wallet ledger”) to invent a fourth ready table. The locked-count “50” is then forced to make 50+4=54.  
**Source:** Spec §3 last paragraphs; Master §9.3, §19.3, §P/Redis GPS; Blueprint B.29, B.49.  
**Affected:** Inventory classification of tables 32, 33, 54.  
**Recommended resolution:** Publish 51 locked + 3 ready = 54, or 51 locked + 2 ready if GPS is dropped from the spec’s CREATE list. Do not invent a fourth ready table.  
**User decision required?** YES only for whether V1 SQL **creates** customer wallet tables and/or GPS samples. The architecture already answers “required for booking?” = **no**.

**Issue 3 — MEDIUM**  
**Problem:** Spec §3 says architecture-ready tables “may be created with the schema so it does not need redesign.” Master §9.3 / §44 allow the ledger to exist without limits, but GPS retain days are explicitly unnumbered. Creating `rider_location_samples` in V1 without retention is not required and is not equivalent to creating customer wallet.  
**Source:** Master §38 Redis/GPS rebuildable; Blueprint #25.  
**Affected:** `rider_location_samples`.  
**Recommended resolution:** Keep customer wallet as optional CREATE; keep GPS as optional CREATE **only after** retention is decided, or omit.  
**User decision required?** YES (create GPS table in V1 or not). Can be deferred if the table is simply omitted from the first SQL.

---

## 4. Column Audit

Method: every production table in spec §7 was checked against Master named facts and Blueprint §B field lists. **PASS** means required columns are present with compatible types and nullability. Abbreviated §7 sections that only say “same shape / columns per Blueprint” are **not** SQL-complete.

| Table | Required columns | Missing vs Master/Blueprint | Unnecessary | Type | NULL | Default | PK/FK/UNIQUE/CHECK | Mutability / audit | Result |
|---|---|---|---|---|---|---|---|---|---|
| `identities` | Match B.1 | None required | None | TEXT/UUID/timestamptz OK | email NULL OK | auth ACTIVE OK | Unique phone; unique email WHERE NOT NULL | Phone not casual edit | PASS |
| `otp_challenges` | Match B.2 | None | None | Hash TEXT OK | identity optional | attempt_count 0 | FK identity | No plaintext OTP | PASS |
| `sessions` | Match B.3 | Untyped `profile_id` replaced by 3 FKs | None | OK | refresh hash NULL | — | CHECK exactly one profile FK | Revoke mutable | PASS (better FK) |
| `customer_profiles` | Match B.4 | None | None | OK | email NULL | ACTIVE | Unique identity_id | Soft delete | PASS |
| `rider_profiles` | Match B.5 | No `deactivated_at` (customer has it). Vehicle is via `vehicles`, not a column — OK | None | OK | city/zone NULL | OFFLINE / CLEAR | Unique identity | KYC enum open | PASS with Issue 16 |
| `admin_profiles` | Match B.6 | Password on profile not identity — Issue 11 | None | modules JSONB OK | city_scope NULL | finance flags false | Unique identity | Audited role/flags | PASS with Issue 11 |
| `customer_saved_addresses` | Match B.7 | None | None | NUMERIC(9,6) invented precision | lat/lng NULL | — | FK customer | Soft delete | PASS |
| `cities` | Match B.8 | None | None | OK | — | active true | Unique city_code | Soft via active | PASS |
| `zones` | Match B.9 | No UNIQUE (city_id, name) | None | OK | — | active true | FK city | — | PASS with Issue 17 |
| `vehicle_categories` | Match B.10 | None | None | weight as TEXT OK | code NULL | active true | Optional unique code | Snapshot name on orders | PASS |
| `fare_config_versions` | Match B.11 header | None | None | OK | effective_until NULL | DRAFT | Unique version; one ACTIVE | Drafts only mutable | PASS |
| `fare_config_version_rates` | Match B.11 rates | None | None | NUMERIC(12,2) working type | — | — | UNIQUE (version, category) | Drafts only | PASS |
| `payment_settings_versions` | Match B.12 | None | None | percent NUMERIC(5,2) | — | 85/15/50 | Sum = 100; 0–100 | Versioned | PASS |
| `payment_method_policy_versions` | Match B.13 + Master method labels | None required | Extra booleans UPI/Card/NetBanking/Wallet — **justified** by Master §E | BOOLEAN | — | extra flags FALSE | — | PASS |
| `cancellation_config_*` | Match B.14 | None | None | fee default 0 | — | 0 | Shares = 100; unique stage | Not auto 85/15 | PASS |
| `cod_policy_versions` | Match B.15 | None | None | money | — | **100** | >= 0 | Versioned threshold | PASS |
| `extra_rate_versions` | Match B.16 | None | None | defaults 10/10/8/2/8 | — | locked defaults | No forever 10=8+2 CHECK — correct | PASS |
| `company_office_versions` | Match B.17 | None | None | lat/lng NOT NULL | — | — | One ACTIVE per city | Copied on fail | PASS |
| `order_display_counters` | Sequence | No CHECK last_seq ≤ 10 digits | None | BIGINT | — | — | PK city_id | Counter only | PASS with Issue 18 |
| `vehicles` | Match B.18 | No V1 unique one **active** vehicle per rider | None | subtype CHECK | rider NULL OK | active true | FK category | SET NULL on rider | PASS with Issue 19 |
| `rider_drivers` | Match B.19 | Licence not encrypted column — Issue 20 | None | DATE DOB | fields NULL | — | UNIQUE rider V1 | KYC-like | PASS with Issue 20 |
| `stored_files` | Match B.20 | None | None | no bytea | scan NULL | — | Unique storage_key | Virus scan READY | PASS |
| `rider_documents` / `vehicle_documents` | Match B.21–B.22 | `document_type` list open | None | TEXT | reviewer NULL | UPLOADED | FK file | Status mutable | PASS |
| `rider_bank_accounts` | Match B.23 | `is_current` default **FALSE** vs Blueprint default **true** | None | encrypted TEXT | verification NULL | FALSE vs true | Partial unique current | Supersede | Issue 21 |
| `rider_upis` | Match B.24 | Abbreviated §7.25 | None | same pattern | — | — | Partial unique current | — | PASS if literally same as bank |
| `rider_wallet_accounts` | Match B.25 | None | None | NUMERIC(12,2) | — | 0 | UNIQUE rider; **>= 0** | Only with ledger | PASS |
| `wallet_ledger_entries` | Match B.26 | Closed CHECK on example entry types may be tight | None | amount **> 0** | related_* NULL | — | Append-only | Twin COD FK — Issue 8 | PASS with Issues 8, 22 |
| `rider_cod_accounts` | Match B.27 | None | None | **>= 0** | — | 0 | UNIQUE rider | Only with ledger | PASS |
| `cod_ledger_entries` | Match B.28 | No actor columns (Blueprint also omits) | None | amount > 0 | source_txn NULL | — | Unique (account, source_txn) WHERE NOT NULL ≡ Master (rider, source_txn) | Twin wallet FK — Issue 8 | PASS with Issue 8 |
| `orders` | Match B.30 | Convenience trip_fare/payable **omitted on purpose** | No `payment_method` — correct | UUID + TEXT display_id | rider/vehicle/parent/scheduled NULL | CREATED | UNIQUE display_id; no unique-active-order | Status via events | PASS (Issue 23 format CHECK) |
| `order_stops` | Match B.31 | Structured address fields “as available” not listed; max-3-drops not a DB CHECK | None | lat/lng NOT NULL | contact NULL | — | UNIQUE (order_id, sequence); one PICKUP | Progress timestamps mutable | PASS with Issue 7, 24 |
| `order_status_events` | Match B.32 | None | None | TEXT+CHECK | from_status NULL first | — | UNIQUE (order_id, idempotency_key) | Append-only | PASS |
| `order_offers` | Match B.33 | No expires_at (timeout is NEEDS DECISION; B.33 has no column) | None | — | responded NULL | PENDING | Partial unique ACCEPTED; unique (order, rider) | — | PASS |
| `fare_quotes` | Match B.34 | Abbreviated but lists all money lines + tax=0 | None | stop_count 2–4; distance > 0 | — | tax 0 | FKs version/customer/category | Amounts immutable | PASS |
| `order_fare_snapshots` | Match B.15.2 / B.35 | `stop_count` CHECK not BETWEEN 2 AND 4 (quotes have it); `rounding` no sign CHECK | None | tax **= 0**; trip_fare is 85/15 base | quoted_at NULL | tax 0 | UNIQUE order_id | **Immutable** | PASS with Issue 25 |
| `order_payment_responsibilities` | Match B.36 | None | None | bill **not** 85/15 base | — | — | Sum CHECK; UNIQUE order | Immutable after confirm | PASS |
| `order_payment_plans` | Match B.37 | Cross-table sum-to-responsibility not a CHECK | None | >= 0 | — | 0 | UNIQUE order | Immutable after confirm | PASS (Issue 7) |
| `payment_transactions` | Match B.38 | `idempotency_key` uniqueness delegated — Issue 26 | No PAN/CVV — correct | amount > 0 | provider NULL | CHARGE / PENDING | UNIQUE provider_event_id WHERE NOT NULL; 1:N order | Status PENDING→PAID/FAILED only | PASS with Issue 26 |
| `order_finance_snapshots` | Match B.39 / §22.2 | No CHECK that amounts match copied percents × trip_fare (rounding) | None | percents 0–100; rider+company=100 | — | — | NOT unique order_id; partial UNIQUE ORIGINAL | Insert-only | PASS with Issue 27 |
| `order_cancellation_snapshots` | Match B.40 | UNIQUE order_id may block rejected-attempt rows | None | fee default 0; shares=100 | — | 0 | UNIQUE order_id (spec-added) | Immutable | Issue 12 |
| `failed_deliveries` | Match B.41 | UNIQUE order_id assumes one fail | None | reason default RECEIVER_UNAVAILABLE | — | — | UNIQUE order_id | Immutable; original fare not updated | PASS with Issue 29 |
| `order_adjustments` | Match B.42 by reference | Abbreviated | None | amount >= 0 | extra_rate NULL | — | Append-only | Office not 85/15 | PASS if B.42 is copied literally |
| `resend_snapshots` | Match B.43 | Case A `fare_config_version_id` and `payment_settings_version_id` nullable without Case A CHECK | None | Case A/B CHECKs on base_fare only | child NULL | — | FK original required | Money immutable; status mutable | **Issue 4 HIGH** |
| `invoices` | Match B.44 / Master §23 | Header list in §7.45 does **not** explicitly include trip_fare, discount, additional_locked_charges, rounding, payment_status_snapshot | Legal GSTIN omitted — correct | gst CHECK = 0 | issued_at NULL | gst 0 | UNIQUE invoice_number; UNIQUE order_id | Issued amounts immutable | **Issue 14 HIGH** |
| `invoice_lines` | Optional display | line_type/label not in Master (display only) | Duplicate of header if both used | amount NUMERIC | — | — | FK invoice | Immutable after issue | Issue 28 |
| `order_ratings` | Match B.45 | §7.46 does not list `from_profile_id`, `to_profile_id` | None | stars 1–5 | comment NULL | — | UNIQUE (order_id, direction) | Insert-once | **Issue 15 HIGH** |
| `notifications` | Match B.46 | `recipient_profile_id` untyped (no profile type / FK) | None | — | title NULL; at least one recipient | — | PK = dedupe id | read_at mutable | Issue 13 |
| `audit_logs` | Match B.47 / Master §29 | category NULL allowed | None | JSONB old/new | actor NULL = system | — | No FK on entity_id — correct | Append-only | PASS |
| `idempotency_keys` | Match B.48 / Master §30 | No TTL column — **correct** | None | JSONB result | actor NULL | — | UNIQUE (scope, key) | Never expire money keys | PASS |
| Customer wallet pair | Match B.29 | §7.30 omits `created_at` (and rider-like `updated_at`) | Dummy promo defaults correctly forbidden | >= 0 | — | 0 | UNIQUE customer | READY | Issue 30 |
| `rider_location_samples` | Match B.49 | Abbreviated PK | None | NUMERIC(9,6) | order NULL | — | Append-only | READY | PASS as optional |

### Column issues

**Issue 4 — HIGH**  
**Problem:** Case A must snapshot the rate sheet **and** 85/15 settings **at resend time** (Master §21.2, §21.4). Spec §7.44 allows `fare_config_version_id` and `payment_settings_version_id` NULL for all rows. CHECK only forces `case_a_base_fare` for Case A. A Case A row could be stored without the versions that make historical 85/15 reconstructible from config.  
**Source:** Master §21.2–21.4; Blueprint B.43.  
**Affected:** `resend_snapshots.fare_config_version_id`, `payment_settings_version_id`.  
**Recommended resolution:** CHECK: `resend_case = 'A'` ⇒ both version FKs NOT NULL; `resend_case = 'B'` ⇒ both NULL (Case B is not 85/15). Do not invent a new table.  
**User decision required?** NO.

**Issue 11 — MEDIUM**  
**Problem:** Master §36.1: “Identity is the only login entity. Profiles do not have independent passwords.” Spec puts `password_hash NOT NULL` on `admin_profiles`. Blueprint B.6 allows “Identity or here.” V1 staff-only login still works, but the password is on the profile, not the identity.  
**Source:** Master §7.5, §36.1; Blueprint B.6; Spec §7.6.  
**Affected:** `admin_profiles.password_hash`.  
**Recommended resolution:** Keep as documented technical pick **or** move to `identities.password_hash` NULL for OTP users. Either is implementable; document which Master 36.1 meaning is intended.  
**User decision required?** NO if the spec’s documented pick is accepted. YES only to move it to identity.

**Issue 12 — MEDIUM**  
**Problem:** Spec UNIQUE `order_id` on `order_cancellation_snapshots`. Master writes a snapshot on cancel, including fee ₹0. If `allowed = false` reject rows are also inserted, a later successful cancel cannot be stored. Blueprint B.40 does not require uniqueness.  
**Source:** Master §20.4; Spec §7.41.  
**Affected:** `order_cancellation_snapshots.order_id`.  
**Recommended resolution:** UNIQUE only where `allowed = TRUE`, or do not persist rejected attempts.  
**User decision required?** YES (store reject attempts or not). Default: do not persist rejects; then UNIQUE order_id is fine.

**Issue 13 — MEDIUM**  
**Problem:** `notifications.recipient_profile_id` is a UUID without profile type and without a FK. Customer, rider, and admin ids live in three tables. Blueprint §22 / Master §28 left identity vs profile as a TECHNICAL DESIGN OPTION; untyped profile id is not a safe FK.  
**Source:** Master §28; Blueprint B.46; Spec §7.47, §8.  
**Affected:** `notifications.recipient_profile_id`.  
**Recommended resolution:** Require `recipient_identity_id` (Master can scope inbox by identity) **or** add `recipient_profile_type` + three nullable typed FKs (same pattern as `sessions`).  
**User decision required?** YES (identity vs typed profile) — already Blueprint #22; spec’s “either column” is incomplete for a profile UUID.

**Issue 14 — HIGH**  
**Problem:** Blueprint B.44 requires invoice header fields: `trip_fare`, `discount`, `additional_locked_charges`, `rounding`, `billed_total`, `customer_paid`, `receiver_paid`, `gst_on_fare`, `payment_status_snapshot`. Spec §7.45 explicitly names only a subset and pushes display to `invoice_lines`. Master §23.1 requires the document to **show** Trip Fare, discount, extras, and full billed amount — not one payer’s share. SQL writers cannot tell which header columns exist.  
**Source:** Master §23; Blueprint B.44; Spec §7.45.  
**Affected:** `invoices` columns.  
**Recommended resolution:** Specify every B.44 header column in §7.45. Lines remain optional display copies. Do not invent GSTIN/SAC.  
**User decision required?** NO.

**Issue 15 — HIGH**  
**Problem:** Blueprint B.45 requires `from_profile_id` and `to_profile_id`. Spec §7.46 only mentions unique (order, direction), stars, comment.  
**Source:** Blueprint B.45; Master §X/§40.  
**Affected:** `order_ratings`.  
**Recommended resolution:** Add the two profile columns (typed FKs or type+id). Rider→customer remains optional/future.  
**User decision required?** NO for customer→rider columns. Rider→customer remains Blueprint #11.

**Issue 16 — LOW**  
**Problem:** Masters are soft-deleted (Master §34.2). Customer has `status` + `deactivated_at`. Rider has no deactivate timestamp; only approval/COD/online.  
**Source:** Master §34.2; Spec §7.4 vs §7.5.  
**Affected:** `rider_profiles`.  
**Recommended resolution:** Optional `deactivated_at` or document that `approval_status` covers offboarding.  
**User decision required?** NO.

**Issue 17 — LOW**  
**Problem:** Duplicate zone names in one city are allowed.  
**Source:** Blueprint B.9.  
**Affected:** `zones.name`.  
**Recommended resolution:** Optional UNIQUE (city_id, name). Not required by Master.  
**User decision required?** NO.

**Issue 18 — MEDIUM**  
**Problem:** `order_display_counters.last_seq` is BIGINT with CHECK >= 0 only. Master locks **10-digit** sequences. Nothing prevents 11-digit `display_id` suffixes.  
**Source:** Master §12.1; Spec §7.19.  
**Affected:** `order_display_counters.last_seq`, `orders.display_id`.  
**Recommended resolution:** CHECK `last_seq <= 9999999999` and/or CHECK `display_id` matches `IU-{city_code}-{10 digits}`.  
**User decision required?** NO.

**Issue 19 — LOW**  
**Problem:** V1 “one rider ≈ one vehicle” is not constrained (multiple active `vehicles` per rider allowed). Fleet is FUTURE.  
**Source:** Master §10.1; Spec §7.20.  
**Affected:** `vehicles.rider_profile_id`.  
**Recommended resolution:** Optional partial UNIQUE one active vehicle per rider for V1. Relax later for fleet.  
**User decision required?** NO for V1 SQL (application can enforce). YES to add a unique constraint.

**Issue 20 — HIGH**  
**Problem:** Master §32.3: encrypt/tokenize **bank and national IDs** at rest. `rider_drivers.licence_reference` is plaintext TEXT, marked sensitive but not encrypted/tokenized like bank/UPI.  
**Source:** Master §27.2, §32.3; Spec §7.21 vs §7.24.  
**Affected:** `rider_drivers.licence_reference`.  
**Recommended resolution:** Same pattern as bank: masked display + encrypted/token column, or store licence image via `stored_files` only.  
**User decision required?** NO (architecture already requires protection).

**Issue 21 — LOW**  
**Problem:** Blueprint `is_current` default **true**; spec default **FALSE**. FALSE is safer with “at most one current.”  
**Source:** Blueprint B.23; Spec §7.24.  
**Affected:** `rider_bank_accounts.is_current` (and UPI if same).  
**Recommended resolution:** Keep FALSE; note Blueprint default is not a business rule.  
**User decision required?** NO.

**Issue 22 — LOW**  
**Problem:** Wallet `entry_type` CHECK is a closed list of Master **examples**. Master §19.1: not a fee list. A later legitimate type (for example wallet refund credit) would need ALTER CHECK.  
**Source:** Master §19.1; Spec §6.2, §7.27.  
**Affected:** `wallet_ledger_entries.entry_type`.  
**Recommended resolution:** Keep the list for V1 **or** use TEXT without CHECK and constrain in the backend. Do not invent fee types.  
**User decision required?** NO.

**Issue 23 — LOW**  
**Problem:** `display_id` format is documented, not CHECKed.  
**Source:** Master §12.1; Spec §4, §7.31.  
**Affected:** `orders.display_id`.  
**Recommended resolution:** CHECK against city_code + 10 digits, or enforce in the allocator that writes `order_display_counters`.  
**User decision required?** NO.

**Issue 24 — LOW**  
**Problem:** Master §13 allows structured stop fields “as available.” Spec only `address_text` + lat/lng + zone. Enough for V1 if address_text is the full string.  
**Source:** Master §13; Spec §7.32.  
**Affected:** `order_stops`.  
**Recommended resolution:** No extra columns unless product later needs house number / pin separately. Do not store multi-city comma strings.  
**User decision required?** NO.

**Issue 25 — MEDIUM**  
**Problem:** `order_fare_snapshots.rounding` has no sign CHECK. Quotes use the same money type. Master formula is `round(trip_fare − discount)` with rounding stored as a fact. Negative rounding (paise down) may be valid; spec is silent. `stop_count` on snapshots lacks the 2–4 CHECK present on quotes.  
**Source:** Master §15; Spec §5, §7.35–7.36.  
**Affected:** `rounding`, `stop_count` on fare snapshot.  
**Recommended resolution:** Align stop_count CHECK with quotes. Mark rounding sign as NEEDS DECISION or allow any NUMERIC(12,2) with application rounding already applied.  
**User decision required?** YES for rounding sign only if the team wants a CHECK.

**Issue 26 — MEDIUM**  
**Problem:** `payment_transactions.idempotency_key` is NOT NULL but uniqueness is “via `idempotency_keys`.” Two columns can diverge. Blueprint has both stores.  
**Source:** Master §17.1, §30; Blueprint B.38, B.48; Spec §7.39.  
**Affected:** `payment_transactions.idempotency_key`.  
**Recommended resolution:** Unique (or unique per order) on the transaction key **or** drop the duplicate column and use only `idempotency_keys` (scope=payment).  
**User decision required?** NO (technical). Pick one uniqueness home.

**Issue 27 — MEDIUM**  
**Problem:** Finance snapshot does not CHECK `rider_amount + company_commission_amount` vs `trip_fare`, nor `operational_cost_amount + profit_amount` vs `company_commission_amount`. Rounding of 85/15 on non-even rupees is unspecified (Master only rounds `net_total`). Stored amounts could disagree with copied percents.  
**Source:** Master §15, §22.2, §43; Spec §7.40.  
**Affected:** `order_finance_snapshots` amount columns.  
**Recommended resolution:** Do **not** invent a second rounding mode in this audit. Application stores already-rounded freeze amounts. Optional CHECKs after a rounding rule is chosen.  
**User decision required?** YES for 85/15 paise rounding (can be deferred after SQL; not required to CREATE TABLE).

**Issue 28 — MEDIUM**  
**Problem:** Blueprint B.44: invoice lines **or** fields on invoice, not two independent truths. Spec has **both** header amounts and `invoice_lines`.  
**Source:** Blueprint B.44; Spec §7.45, §11.  
**Affected:** `invoices`, `invoice_lines`.  
**Recommended resolution:** Header is authority; lines are display-only copies (already stated). Keep both only with that rule. Or drop lines.  
**User decision required?** NO if header is authority.

**Issue 29 — LOW**  
**Problem:** UNIQUE `failed_deliveries.order_id` assumes one fail per order. Master does not say a second attempt cannot occur.  
**Source:** Master §21.1; Spec §7.42.  
**Affected:** `failed_deliveries`.  
**Recommended resolution:** Keep 1:1 for V1 unless product allows repeat fail events.  
**User decision required?** NO for V1.

**Issue 30 — MEDIUM**  
**Problem:** `customer_wallet_accounts` §7.30 omits Blueprint `created_at`. Ledger “same shape as rider” is not expanded.  
**Source:** Blueprint B.29; Spec §7.30.  
**Affected:** customer wallet tables.  
**Recommended resolution:** Expand full column lists before SQL, including created_at and ledger columns.  
**User decision required?** NO.

**Issue 31 — HIGH**  
**Problem:** Several §7 tables are abbreviated (`order_adjustments`, `rider_upis`, `failed_deliveries` id, `invoice` header, ratings, customer wallet, GPS). A later SQL phase cannot implement those tables without copying Blueprint §B or inventing columns. That is a specification completeness failure, not a business-rule failure.  
**Source:** Spec §7 vs Blueprint §B.  
**Affected:** Listed abbreviated tables.  
**Recommended resolution:** Expand every table to the same column-grid as `identities` before SQL. Do not invent extra fields while expanding.  
**User decision required?** NO.

---

## 5. Relationship Audit

Default `ON DELETE RESTRICT / ON UPDATE RESTRICT` matches Master §34.2 (no hard-delete of financial rows).

### 5.1 Required relationships

| Relationship | Parent exists | Child exists | FK column | Optional vs required | Verdict |
|---|---|---|---|---|---|
| Identity → profiles 1:0..1 each | YES | YES | `identity_id` UNIQUE | Required on profile | PASS |
| Customer → orders 1:N | YES | YES | `orders.customer_profile_id` NOT NULL | Required | PASS — not identity, not phone |
| Rider → orders 1:N | YES | YES | `orders.rider_profile_id` NULL | Optional until assign | PASS |
| Order self-FK parent | YES | YES | `parent_order_id` NULL | Optional Case A child | PASS |
| Order → stops 1:N | YES | YES | `order_id` NOT NULL | Required after confirm | PASS |
| Order → status events 1:N | YES | YES | `order_id` NOT NULL | Required | PASS |
| Order → offers 1:N | YES | YES | both NOT NULL | Required for dispatch | PASS |
| Order → fare snapshot 1:1 | YES | YES | UNIQUE `order_id` | After confirm | PASS |
| Order → responsibility 1:1 | YES | YES | UNIQUE `order_id` | After confirm | PASS |
| Order → plan 1:1 | YES | YES | UNIQUE `order_id` | After confirm | PASS |
| Order → payment_transactions 1:N | YES | YES | `order_id` NOT NULL | Many txns | PASS |
| Order → finance snapshots 1:N | YES | YES | `order_id` NOT NULL, **not unique** | Reversals allowed | PASS |
| Order → cancellation 1:0..1 | YES | YES | UNIQUE order_id | If cancelled | PASS with Issue 12 |
| Order → failed delivery 1:0..1 | YES | YES | UNIQUE order_id | If failed | PASS |
| Order → adjustments 1:N | YES | YES | `order_id` | Office / audit | PASS |
| Order → resend original 1:0..1 | YES | YES | `original_order_id` NOT NULL | | PASS |
| Order → resend child 1:0..1 | YES | YES | `child_order_id` NULL | Optional | PASS |
| Order → invoice 1:0..1 | YES | YES | UNIQUE order_id | | PASS with Issue 33 |
| Wallet 1:1 rider | YES | YES | UNIQUE rider | Required | PASS |
| COD account 1:1 rider | YES | YES | UNIQUE rider | Required | PASS |
| Wallet ledger N | YES | YES | `wallet_account_id` NOT NULL | | PASS |
| COD ledger N | YES | YES | `cod_account_id` NOT NULL | | PASS |
| Config versions → snapshots | YES | YES | version UUIDs | Required where used | PASS with Issue 4 |
| No customer–rider M:N junction | — | — | Order is the join | Correct | PASS |
| Audit/idempotency logical UUID | — | — | No FK | Correct | PASS |

There is **no missing required relationship** from Master §12 order map (stops, events, offers, fare snapshot, responsibility, plan, transactions, finance, invoice, cancel, fail, resend, adjustments, audit/idempotency).

### 5.2 Circular dependency

**Issue 8 — HIGH**  
**Problem:** `wallet_ledger_entries.related_cod_ledger_id` → `cod_ledger_entries` **and** `cod_ledger_entries.related_wallet_ledger_id` → `wallet_ledger_entries`. Inserting a settlement twin pair cannot satisfy both FKs in one statement unless constraints are `DEFERRABLE INITIALLY DEFERRED`, or only one direction is stored. Spec §8 does not mention DEFERRABLE. PostgreSQL CREATE TABLE / first settlement insert will fail or require a two-step update.  
**Source:** Blueprint B.26–B.28; Spec §7.27, §7.29, §8.  
**Affected:** `related_cod_ledger_id`, `related_wallet_ledger_id`.  
**Recommended resolution:** Pick one: (1) DEFERRABLE FKs inside one transaction, or (2) store the twin id on **one** table only. Do not CASCADE.  
**User decision required?** YES (technical). **Must decide before SQL.**

No other cycle is introduced. `orders.parent_order_id` is a standard self-FK (RESTRICT). `sessions` → profiles → identities plus `sessions` → identities is not a cycle.

### 5.3 Delete / update behaviour

See also §6 of this audit for financial protection.

| Child | Spec ON DELETE | Appropriate? |
|---|---|---|
| All money / snapshot / ledger / invoice / audit FKs | RESTRICT | YES |
| `vehicles.rider_profile_id` | SET NULL | YES — unassigned vehicle allowed |
| `otp_challenges.identity_id` | SET NULL **or** RESTRICT | NEEDS DECISION (spec #8). Identities are not hard-deleted; RESTRICT is safe |
| `invoice_lines` | RESTRICT (inventory text also says “with invoice retention”) | YES if invoices are never hard-deleted |
| `fare_quotes` | Unused expired may purge | YES — snapshot does not FK the quote |

**Issue 5 — MEDIUM**  
**Problem:** Inventory §3 `invoice_lines` Delete = “with invoice retention”; §8 ON DELETE = RESTRICT. Consistent only because invoices are never hard-deleted. If someone later CASCADEs invoice delete, lines vanish.  
**Source:** Spec §3 vs §8.  
**Affected:** `invoice_lines.invoice_id`.  
**Recommended resolution:** Keep RESTRICT. Never CASCADE invoices.  
**User decision required?** NO.

**Issue 6 — LOW (NEEDS DECISION already listed)**  
**Problem:** `otp_challenges.identity_id` ON DELETE not finalized.  
**Source:** Spec §8, NEEDS DECISION #8.  
**Affected:** `otp_challenges`.  
**Recommended resolution:** RESTRICT (identities are soft-deactivated).  
**User decision required?** YES but deferrable; RESTRICT is the safe default.

No CASCADE on snapshots, payments, wallet txns, COD ledger, invoices, audit, or status events. **Correct.**

Where architecture did not name ON DELETE, spec default RESTRICT is appropriate. Remaining explicit gap is OTP identity only.

---

## 6. Financial Integrity Audit

Locked picture (Master §4, §15, §22):

```text
Trip Fare ₹100     ← 85/15 BASE
Discount  ₹10
Bill      ₹90      ← responsibility sums here; NOT 85/15 base

Rider     ₹85      (85% of Trip Fare)
Company   ₹15      (15% of Trip Fare)
  Ops     ₹7.50    (50% of company share only)
  Profit  ₹7.50    (remainder of company share)
GST on fare = ₹0
```

| Check | Spec behaviour | Verdict |
|---|---|---|
| 85/15 applied to Trip Fare | `order_finance_snapshots.trip_fare`; `order_fare_snapshots.trip_fare` labeled 85/15 base | PASS |
| Not applied to invoice grand total | Invoice `billed_total` is the bill; gst CHECK 0; 85/15 not computed from billed_total | PASS (if header columns are completed — Issue 14) |
| Not applied to GST | GST stored as 0; not an 85/15 input | PASS |
| Not applied to unrelated charges | Office extra is `order_adjustments`, not 85/15; Case B is ₹10/₹8/₹2 on `resend_snapshots` | PASS |
| Not applied to payment amount | `payment_transactions.amount` is collection, not P&L base | PASS |
| GST locked 0 | Fare quote/snapshot `tax = 0`; invoice `gst_on_fare = 0` | PASS |
| Snapshot stores trip amount, percents, rider, company, ops, profit, settings version, timestamp | All present on `order_finance_snapshots` | PASS |
| Historical freeze not overwritten | Insert-only; ORIGINAL partial unique; reversal = new row | PASS |
| Settings version at **freeze**, not later publish | `payment_settings_version_id` + copied percents | PASS |
| Who pays does not change P&L | Responsibility separate from finance snapshot | PASS |
| Cancellation not auto 85/15 | Cancel snapshot has its own percents; CHECK sum 100 | PASS |
| Default 85/15/50 still Admin-versionable | Defaults on version table; not CHECK = 85 forever | PASS |

**Issue 9 — MEDIUM (documentation drift, not a second formula)**  
**Problem:** Spec §7.44 **describes** Case A rider/company as “85% / 15% of customer_amount.” Master: Case A uses **normal 85/15**, meaning the **payment-settings version in force at resend**, which **defaults** to 85/15 but is Admin-configurable for **future** versions. Hardcoding “85%” in the column description can cause an implementer to ignore `payment_settings_version_id`.  
**Source:** Master §21.2; Spec §7.44.  
**Affected:** `resend_snapshots` narrative; columns themselves can store any split.  
**Recommended resolution:** Wording: “Case A rider/company amounts from snapshotted payment-settings percents (default 85/15) applied to (resend-time base + ₹10/km).”  
**User decision required?** NO.

**Issue 10 — HIGH (Case B / extras vs payment aggregates)**  
**Problem:** Responsibility and plan are **immutable after confirm** (spec). Master §16.1 says extra charges belong on **this** order’s bill only if they are on this bill (not a child resend). Case B on the **same** order adds a customer charge that is **not** in original `applicable_bill_total`. Aggregate PAID is defined as sum(PAID txns) vs **responsibility**. Paying Case B on the same order would look like overpay vs original bill, or Case B would be uncollectable in the payment model. Master left Case A/B **storage** as a TECHNICAL DESIGN OPTION; it did **not** specify how same-order Case B is collected. Spec must not invent a second responsibility row.  
**Source:** Master §16.1, §16.3, §21.3; Spec §7.37, §13, §15.  
**Affected:** `order_payment_responsibilities`, `payment_transactions`, `resend_snapshots`.  
**Recommended resolution:** Do **not** invent a structure in this audit. Keep storage-shape NEEDS DECISION. If Case A is a **child order**, child has its own responsibility/plan/txns/finance — payment math is safe. If Case B stays on the original order, **how the extra is owed/collected is unspecified** — mark NEEDS DECISION (already #5). Invoice `additional_locked_charges` can **display** extras without fixing collection.  
**User decision required?** YES — same as Case A/B storage; **do not invent** a second responsibility table.

No CRITICAL formula error found. 85/15 is not wired to invoice total or GST.

---

## 7. Wallet & COD Audit

| Concept | Table | Separate? | Notes |
|---|---|---|---|
| A. Rider earning wallet | `rider_wallet_accounts` | YES | Materialized `available_balance`; ledger is truth |
| B. Rider wallet transactions | `wallet_ledger_entries` | YES | Append-only; CREDIT/DEBIT; amount > 0 |
| C. Rider COD Due | `rider_cod_accounts` + INCREASE rows | YES | Not stored on wallet |
| D. COD settlement events | `cod_ledger_entries` direction=DECREASE | YES as events, **not** a third balance | Twin optional wallet CREDIT of remainder |

| Rule | Representable? |
|---|---|
| Wallet never negative | YES — CHECK >= 0; spec forbids silent debit. Race prevention is rider finance **lock** (application/transaction), not a SQL type |
| COD Due not a wallet balance | YES — two accounts, two FKs |
| COD Due ≥ threshold suspends | YES — `cod_policy_versions.suspend_threshold` default **100**; `rider_profiles.cod_operational_status = SUSPENDED_FOR_COD`. Cross-table “due ≥ threshold ⇒ status” is application (same as Master) |
| Recharge/digital earning settles COD first | YES — DECREASE COD then CREDIT wallet remainder; sources RECHARGE_SETTLEMENT / DIGITAL_EARNING_SETTLEMENT / CANCELLATION_SHARE_SETTLEMENT |
| Cash-trip ₹85 must **not** settle that trip’s ₹15 | YES — cash company share is COD INCREASE; no wallet EARNING required on that trip. Spec §12 states this |
| History traceable | YES — append-only ledgers; `source_txn_id` unique per account |
| Physical cash in hand | Correctly **not** a ledger table (Master §10.2 operational note only) |

Concepts are **not** merged. No `wallet_and_cod` table.

Settlement as ledger rows rather than `cod_settlements` matches Master §18.2–18.3 and Blueprint B.28. **Do not add a third balance table.**

---

## 8. Payment Audit

| Capability | Supported? | How |
|---|---|---|
| Customer pays | YES | `who_pays` CUSTOMER; `payer_type` CUSTOMER |
| Receiver pays | YES | RECEIVER; **no** Receiver user table |
| Split payment (who owes) | YES | CUSTOMER/RECEIVER/SPLIT; customer + receiver = bill |
| Split methods per payer | YES | plan online+cash per payer |
| Multiple payment transactions | YES | `payment_transactions` 1:N |
| UNPAID / PARTIALLY_PAID / PAID | YES as **aggregates** | Derived from PAID charges minus refunds vs responsibility. **Not** on the transaction row |
| Transaction PENDING / PAID / FAILED / REFUNDED | YES | Closed list |
| COD (cash collection) | YES | method CASH PAID + COD ledger if company share held. Not `orders.payment_method` |
| Online | YES | method ONLINE; PAID only after provider confirm (application). `provider_event_id` unique |
| Refund records | YES | New row `direction=REFUND`; original unchanged |
| Responsibility ≠ transaction | YES | Separate tables |
| Overpay ≠ silent PAID | YES in rules | OVERPAY_CORRECTION adjustment or refund row (Blueprint B.42) |

**Missing capability (not invented here):**

- Same-order Case B extra collection vs frozen responsibility — Issue 10.
- Authorize-at-booking vs capture-at-delivery — Master FUTURE; columns already support PENDING then PAID.
- Launch cash-only vs online — policy, not a missing table.
- WALLET method on transactions — Master says V1 ONLINE/CASH; WALLET later without rewriting history. Spec correctly omits WALLET on txn method CHECK.

No missing **V1** payment table. Four-layer model is intact.

---

## 9. Order / Trip Audit

| Requirement | Spec | Verdict |
|---|---|---|
| UUID PK | `orders.order_id` UUID PK | PASS |
| Unique `display_id` | UNIQUE TEXT NOT NULL | PASS |
| `IU-{CITY}-{10-digit sequence}` | Documented; allocator uses `cities.city_code` + `order_display_counters` | PASS with Issues 18, 23 (no CHECK) |
| Canonical ID rules unchanged | PK is not display_id; invoice number separate | PASS |
| Multiple stops | `order_stops`; 1 PICKUP; 1–3 DROP | PASS; enforcement trigger vs app = NEEDS DECISION #7 |
| Status history | `order_status_events` append-only; current status on order | PASS |
| Rider offers | `order_offers`; one ACCEPTED | PASS |
| Fare snapshot | 1:1 immutable; tax 0 | PASS |
| Finance snapshot | N rows; ORIGINAL unique | PASS |
| Cancellation snapshot | Present; fee default 0 | PASS |
| Failed delivery | Separate table; not cancel | PASS |
| Resend | `resend_snapshots` + optional `parent_order_id` | PASS; shape open |
| Adjustments | `order_adjustments` | PASS |
| Invoice | `invoices` unique number ≠ display_id | PASS entity; Issue 14 columns |
| Many active customer orders | No unique-active-order constraint | PASS |
| Rider not auto second live trip | Not a DB unique; application + FUTURE manual assign | PASS (not silently forbidden/allowed in SQL) |
| `scheduled_at` nullable reserved | Present; not V1 product | PASS |
| No join by phone/name/“Bike” | FKs are profile and category ids; name snapshot | PASS |

Canonical ID rules were **not** changed.

---

## 10. Resend Audit

| Case | Formula | Original trip | Spec storage | Distinguishable? |
|---|---|---|---|---|
| **A** | Rate-sheet **base at resend** + ₹10/km; then **normal 85/15** on that combined amount | Original **ended** | `resend_case = 'A'`; `case_a_base_fare` required; optional `child_order_id` / `orders.parent_order_id`; fare + payment setting versions **should** be required (Issue 4) | YES if `resend_case` is set and versions filled |
| **B** | Customer ₹10/km; rider ₹8/km; company ₹2/km; **not** 85/15 | Original **not** ended | `resend_case = 'B'`; `case_a_base_fare` MUST be NULL (CHECK); payment/fare versions intended NULL | YES |

Office ₹8/km is **not** Case A/B; it is `order_adjustments` (PASS).

Master §21.2–21.3: child order vs related record is a **TECHNICAL DESIGN OPTION**. Spec supports **both** columns and correctly **does not pick one**.

**Issue 32 — HIGH (Case A storage still open; do not invent)**  
**Problem:** Case A **money** is defined. Case A **row shape** (mandatory child order vs related snapshot only) is **not**. Spec §15 lists this as NEEDS DECISION. That is correct. The audit must **not** invent a mandatory child-order rule.  
**Source:** Master §21.2; Blueprint #20; Spec §15, NEEDS DECISION #5.  
**Affected:** `orders.parent_order_id`, `resend_snapshots.child_order_id`.  
**Recommended resolution:** Keep both columns. Choose the operational shape in implementation. Child order is the **safer payment** isolation (Issue 10). Related-record Case A still must not write a second `order_fare_snapshots` row on the original (UNIQUE 1:1 forbids it — which is correct).  
**User decision required?** YES for **runtime** shape. **Not** required to CREATE the two columns. Marked **B** for SQL, **open** for go-live behaviour.

If Case A storage were **genuinely undefined** with **no** columns: that would be NEEDS DECISION and block a complete money model. Here columns exist for both shapes; only the **mandatory** shape is undefined. **Do not invent** a third structure.

---

## 11. Configuration Version Audit

| Config | Versioned table | Historical order reference | In-place edit of used version forbidden? |
|---|---|---|---|
| Fare / category rates | `fare_config_versions` + rates | `order_fare_snapshots.fare_config_version_id` + copied numbers | YES — drafts only; publish N+1 |
| 85/15/50 | `payment_settings_versions` | `order_finance_snapshots.payment_settings_version_id` + copied percents/amounts at **freeze** | YES |
| Cancellation | `cancellation_config_versions` + rules | `order_cancellation_snapshots.cancellation_config_version_id` + copied fee/shares | YES |
| COD threshold | `cod_policy_versions` | Accept uses **active** version; default ₹100 | YES versioned. Spec does **not** snapshot threshold onto the rider suspend event (Master: snapshot **if ever changed**). Accept-time check can use active version; historical “why suspended that day” is weaker |
| Office | `company_office_versions` | Copied onto `failed_deliveries` | YES |
| Extra ₹/km | `extra_rate_versions` | Resend + office adjustment version ids | YES |
| Payment methods | `payment_method_policy_versions` | Booking validated against then-current; not copied onto order | Acceptable; methods on **transactions** are the historical fact |

Header DRAFT → ACTIVE → SUPERSEDED; at most one ACTIVE per stream. Matches Master §24.

**Issue 34 — LOW**  
**Problem:** COD suspend threshold is versioned, but a suspend event does not store `cod_policy_version_id` on the rider or an audit-specific freeze. Master §18.4: version so a later change does not rewrite history. Operational status is a live flag. Audit log can capture the change.  
**Source:** Master §11.2, §18.4; Spec §10.  
**Affected:** `rider_profiles.cod_operational_status`.  
**Recommended resolution:** Rely on `audit_logs` + ledger timestamps, or later add a small suspend-event snapshot. Do not invent a new money table.  
**User decision required?** NO for SQL.

Old published versions cannot be silently changed **as a spec rule**. Physical UPDATE prevention (trigger / grants) is application/DBA — Issue 35.

**Issue 35 — MEDIUM**  
**Problem:** Immutability of snapshots/ledgers is specified as policy (“Never UPDATE”) without a named DB mechanism (REVOKE UPDATE, trigger, or table owner). Status transitions are also backend-enforced, so this is consistent with Master §14.3, but SQL implementers may leave UPDATE granted.  
**Source:** Master §22, §34.2; Spec §9.  
**Affected:** Snapshot and ledger tables.  
**Recommended resolution:** In the SQL phase, REVOKE UPDATE/DELETE on those tables from app roles, or add reject-update triggers. Not a product decision.  
**User decision required?** NO.

---

## 12. Status Audit

Closed lists use TEXT + CHECK (not PostgreSQL ENUM). Values were compared to Blueprint §D and Master §14. **No invented order status** (including no failed-closed).

| Field | Allowed values | Match Blueprint/Master? | Transitions in DB? | Who triggers | Representation |
|---|---|---|---|---|---|
| `orders.canonical_status` | CREATED … RESEND_COMPLETED (18 values) | YES Master §14.1 / BP D.1 | **No** — backend only | D.1 Who column | TEXT+CHECK |
| Offer | PENDING/REJECTED/EXPIRED/ACCEPTED | YES D.2 | App | System/rider | TEXT+CHECK |
| Payment txn | PENDING/PAID/FAILED/REFUNDED | YES D.3 | PENDING→PAID/FAILED; refund new row | Webhook/rider/admin | TEXT+CHECK |
| Aggregate UNPAID/PARTIAL/PAID | Derived | YES D.4 | N/A | N/A | **Not a column** |
| Invoice | DRAFT/ISSUED/CANCELLED | YES D.5 | App | Worker / finance | TEXT+CHECK |
| Rider online | OFFLINE/ONLINE | YES D.6 | Rider | Rider | TEXT+CHECK |
| Rider approval | PENDING/APPROVED/REJECTED/SUSPENDED | YES D.6 | Audited | Ops/Super Admin | TEXT+CHECK |
| COD operational | CLEAR/SUSPENDED_FOR_COD | YES | System at threshold | System | TEXT+CHECK |
| Customer | ACTIVE/DEACTIVATED | YES D.7 | Soft delete | Customer/admin | TEXT+CHECK |
| Config version | DRAFT/ACTIVE/SUPERSEDED | YES D.8 | Publish | Super Admin | TEXT+CHECK |
| Documents | UPLOADED/APPROVED/REJECTED | YES D.9 | Ops | Ops/Super Admin | TEXT+CHECK |
| Identity auth | ACTIVE/LOCKED/REVOKED | YES B.1 | Extra values open | System | TEXT+CHECK |

Master §14.1: OFFER_REJECTED is an **event then SEARCHING**, not an order status. Spec does **not** add it. Correct.

**Issue 36 — LOW**  
**Problem:** Spec §6.2 `onboarding_kyc_status` “minimum usable values: PENDING, SUBMITTED, APPROVED, REJECTED.” `SUBMITTED` is not named in Master. Document status is already UPLOADED/APPROVED/REJECTED.  
**Source:** Master §10.1; Spec §6.2; Blueprint #26.  
**Affected:** `rider_profiles.onboarding_kyc_status`.  
**Recommended resolution:** Keep as NEEDS DECISION labels; do not treat SUBMITTED as locked.  
**User decision required?** YES (enum labels) — deferrable; TEXT column can exist.

Transitions and “who” belong in the backend state machine (Blueprint D.1), not extra CHECK constraints. Spec is correct not to encode the full graph in SQL.

---

## 13. Audit & Idempotency Audit

### 13.1 `audit_logs`

Master §29 minimum fields vs spec §7.48:

| Master field | Spec column | Present? |
|---|---|---|
| Actor identity | `actor_identity_id` NULL = system | YES |
| Actor profile | `actor_profile_id` | YES |
| Actor role | `actor_role` | YES |
| Action | `action` | YES |
| Entity type + id | `entity_type`, `entity_id` (no FK) | YES |
| Old / new | `old_value` / `new_value` JSONB | YES |
| Reason | `reason` | YES |
| Request id | `request_id` | YES |
| Timestamp | `created_at` | YES |
| IP / UA | `ip`, `user_agent` | YES |
| Category one-or-two tables | `category` on one table | YES (TECHNICAL DESIGN OPTION picked) |

Must-audit list (fare publish, payment settings, cancellation, office, wallet/COD/order financial adjustment, permissions, rider approve/reject/suspend, refunds) is **stated**, not enforced by CHECK (cannot be). Append-only; never hard-delete financial audit. PASS.

### 13.2 `idempotency_keys`

| Master §30 | Spec | Present? |
|---|---|---|
| Key | `key` | YES |
| Actor | `actor_identity_id` | YES |
| Request hash | `request_hash` | YES |
| Result entity / payload | `result_entity_id`, `result_payload` | YES |
| created_at | YES | YES |
| Same key+hash → original; same key+different hash → reject | Stated | YES |
| Unique (scope, key) | YES | YES |
| Mandatory operations | scopes listed: create-order, accept-offer, payment, webhook, recharge, cod-settlement, cancel, resend, invoice, status | YES |
| COD (rider_id, source_txn_id) | Also UNIQUE on `cod_ledger_entries` | YES |
| Webhook provider event | UNIQUE `provider_event_id` | YES |
| Invoice retry same number | UNIQUE invoice_number + unique order_id | YES with Issue 33 |
| **TTL / expiration** | **Not defined; no TTL column** | CORRECT — do not invent |

**Issue 22 in spec (idempotency expiration)** is **not a decision**. See §17 item 22.

---

## 14. Index Audit

Compared to Master §35 and Blueprint entity indexes.

| Need | Spec index | Verdict |
|---|---|---|
| Customer order list | `(customer_profile_id, created_at DESC)` | PASS |
| Customer active | `(customer_profile_id, canonical_status)` — not partial “non-terminal” | CLOSE — Issue 37 |
| Rider active/history | `(rider_profile_id, canonical_status, created_at DESC)` | PASS |
| Dispatch offers | `(order_id)`; `(rider_profile_id, status)`; unique ACCEPTED | PASS |
| Admin city ops | `(city_id, canonical_status, created_at DESC)` | PASS |
| Display id | UNIQUE `display_id` | PASS |
| Webhook | UNIQUE `provider_event_id` WHERE NOT NULL | PASS |
| Payment by order | `(order_id, created_at)` | PASS |
| Wallet ledger | `(wallet_account_id, created_at)` | PASS |
| COD due / suspend | `(cod_due)` or filtered | PASS |
| Idempotency | UNIQUE `(scope, key)` | PASS |
| Audit by entity | `(entity_type, entity_id, created_at)` | PASS |
| Status timeline | `(order_id, created_at)` | PASS |
| Invoice number | UNIQUE | PASS |
| OTP phone+time | Spec “all FKs” + identities unique; Blueprint B.2 also wants phone+created_at | Issue 38 |
| Session identity | FK index | PASS if “all FKs” |
| Finance snapshot reporting by time | Relies on FK `order_id` only | Issue 39 |
| Cursor `(created_at, id)` | Stated as strategy, not a concrete extra index list on every table | LOW — OK as guidance |
| Partition readiness | Named, not day-1 extra indexes | PASS — not premature |

No duplicate unique indexes detected beyond overlapping UNIQUE + btree on the same FK (normal).

**Issue 37 — LOW**  
**Problem:** Master suggests a **partial** index on customer active (status not terminal). Spec indexes all statuses. Harmless extra index width, not wrong.  
**Source:** Master §35; Spec §18.  
**Affected:** `orders`.  
**Recommended resolution:** Optional partial index later. Do not add both.  
**User decision required?** NO.

**Issue 38 — LOW**  
**Problem:** Blueprint B.2 index `(phone_normalized, created_at)` on OTP not listed in Spec §18 (only “all FKs”). OTP `identity_id` is nullable so FK index does not cover phone lookup.  
**Source:** Blueprint B.2; Master §32.1 rate-limit phone+IP.  
**Affected:** `otp_challenges`.  
**Recommended resolution:** Add `(phone_normalized, created_at)` when writing SQL. Justified by login, not premature.  
**User decision required?** NO.

**Issue 39 — MEDIUM**  
**Problem:** Master §37.2 Phase 1 reports filter snapshots/ledgers **by date**. Spec does not list `(frozen_at)` / `(confirmed_at)` / `(issued_at)` indexes. FK `order_id` does not serve “P&L for day D.”  
**Source:** Master §35–§37; Spec §18.  
**Affected:** `order_finance_snapshots.frozen_at`, `order_fare_snapshots.confirmed_at`, `invoices.issued_at`, `payment_transactions.created_at` (order+time exists).  
**Recommended resolution:** Add time indexes on finance freeze and invoice issue in SQL if Admin day/week/month reports are in V1. Not a new business rule.  
**User decision required?** NO.

No incorrect unique index was found that would break reversals (finance ORIGINAL is **partial** unique — correct).

---

## 15. Security Audit

Database-level only, limited to what Master §32 / Blueprint §J support.

| Area | Spec | Issue? |
|---|---|---|
| Rider KYC | Metadata + `stored_files`; bytes in object storage; no bytea | PASS |
| Licence / national ID | Licence plaintext — **Issue 20 HIGH** | YES |
| Bank | `account_masked` + `account_encrypted_or_token`; never log full numbers (API) | PASS |
| UPI | masked + encrypted | PASS |
| Customer PII | phone on identity; stop contact_phone nullable sensitive | PASS |
| Payment | No PAN/CVV columns | PASS |
| OTP | `code_hash` only | PASS |
| Admin password | Hash column; never in React | PASS with Issue 11 location |
| Session refresh | Hash NULL optional | PASS |
| Secrets in DB | No provider private keys / keystores | PASS |
| RLS | Not required; API RBAC | PASS — do not invent RLS as product |
| GPS samples | Location PII if table created without retention | Issue 3 |
| Audit IP | Super Admin read | PASS |
| Counterpart phones | Masking is API, not a column | PASS |

No extra copy of card data or raw OTP. No duplicate full bank number column alongside encrypted (only masked + encrypted).

---

## 16. Normalization Audit

| Item | Duplicate source of truth? | Verdict |
|---|---|---|
| Fare snapshot copies live rates | **Required** historical snapshot | Do **not** flag |
| Finance snapshot copies percents and amounts | **Required** | Do **not** flag |
| Cancel/resend/office copies | **Required** | Do **not** flag |
| Invoice copies snapshot amounts | **Required** | Do **not** flag |
| `vehicle_category_name_snapshot` on order **and** fare snapshot | Required so history does not join by “Bike” | OK |
| Office address on `failed_deliveries` | Required (office may move) | OK |
| Convenience trip_fare on `orders` | **Omitted** to avoid second mutable truth | Correct |
| Aggregate payment status on `orders` | **Omitted** | Correct |
| Invoice header **and** `invoice_lines` | Display duplication | Issue 28 — allowed if header is authority |
| `payment_transactions.idempotency_key` **and** `idempotency_keys` | Two homes | Issue 26 |
| `orders.parent_order_id` **and** `resend_snapshots.child_order_id` | Redundant if both set | Acceptable until Case A shape is chosen; CHECK they agree if both non-null is missing — Issue 40 |
| Wallet balance + ledger | Materialized cache + truth | Required; reconcile rule stated |
| COD due + COD ledger | Same pattern | Required |

**Issue 40 — MEDIUM**  
**Problem:** If both `orders.parent_order_id` (on the child) and `resend_snapshots.child_order_id` are used, nothing CHECKs they point at the same pair.  
**Source:** Master §21.2 optionality; Spec §8, §15.  
**Affected:** `orders.parent_order_id`, `resend_snapshots.child_order_id`.  
**Recommended resolution:** If both columns are non-null, application (or later CHECK/trigger) must keep them consistent. Do not drop either column until Case A shape is chosen.  
**User decision required?** NO for SQL.

Missing normalized relationships: none required by Master. Receiver is correctly **not** normalized into a user table.

---

## 17. NEEDS DECISION Classification

Spec §23 lists **22** items. Each is classified against Master / Blueprint.

| Spec # | Item | Class | Why |
|---|---|---|---|
| 1 | `NUMERIC(12,2)` vs `BIGINT` paise for **all** money | **A. MUST DECIDE BEFORE SQL** | Master §43: pick **one** physical type and use it everywhere. Mixing is forbidden. CREATE TABLE cannot proceed without the type. Spec’s working NUMERIC is **not** a lock. |
| 2 | Who generates UUID v7 (app vs DB) | **B. CAN BE DEFERRED AFTER SQL** | Type is UUID either way (Master §12.1, §43). Tables can be created without a DEFAULT generator. |
| 3 | Fare/cancel rates child tables vs JSONB | **D. NOT ACTUALLY A DECISION — REMOVE** | Master: TECHNICAL DESIGN OPTION. Spec **already chose child rows**. SQL can follow the spec. Re-asking is noise. |
| 4 | Extra rates one table vs split | **D. NOT ACTUALLY A DECISION — REMOVE** | Spec **already chose one** `extra_rate_versions`. Numbers are locked either way. |
| 5 | Case A/B mandatory storage shape | **B. CAN BE DEFERRED AFTER SQL** | Master left it TECHNICAL DESIGN OPTION. Columns for both shapes exist. **Runtime** choice remains; do not invent a third shape. Payment isolation is safer with child orders (Issue 10, 32). |
| 6 | CHECK Case B 10=8+2 on future extra_rate versions | **D. NOT ACTUALLY A DECISION — REMOVE** | Master locks **today’s** numbers, not that future Admin versions must always sum. Spec correctly omitted the CHECK. |
| 7 | Plan-vs-responsibility and 1–3 drops: trigger vs application | **B. CAN BE DEFERRED AFTER SQL** | Rules are locked. Enforcement mechanism is not. Tables/CHECKs can be created; trigger can be added later. |
| 8 | OTP `identity_id` ON DELETE SET NULL vs RESTRICT | **B. CAN BE DEFERRED AFTER SQL** | Identities are not hard-deleted. RESTRICT is safe and can be the SQL default. |
| 9 | OTP expiry / max_attempts defaults | **B. CAN BE DEFERRED AFTER SQL** | Master §7.5 / §44: columns exist without policy numbers. `expires_at` NOT NULL is supplied per row. |
| 10 | Session TTL; refresh_token required | **B. CAN BE DEFERRED AFTER SQL** | Master §7.6 TECHNICAL DESIGN OPTION. Columns exist; transport is not a table type. |
| 11 | Invoice number format / series | **B. CAN BE DEFERRED AFTER SQL** | Uniqueness is locked (`invoice_number TEXT UNIQUE`). Statutory pattern is Master §44. Do not invent GSTIN. |
| 12 | One invoice per order vs re-issue after CANCELLED | **B. CAN BE DEFERRED AFTER SQL** | Retry **same** number is locked (Master §23, §30.1). Unique `order_id` is a valid V1 happy path. Re-issue is future. |
| 13 | Notification recipient identity vs profile vs either | **D. NOT ACTUALLY A DECISION — REMOVE** from “blocks SQL” | Spec **already chose** both columns + CHECK at least one. Remaining work is Issue 13 (typed FK), which is a **fix**, not a new product rule. Master did not pick identity vs profile; spec’s “either” is enough to CREATE if identity is preferred as the real FK. |
| 14 | Audit one table vs two | **D. NOT ACTUALLY A DECISION — REMOVE** | Master §29 TECHNICAL DESIGN OPTION. Spec **already chose one** table with `category`. |
| 15 | Postgres RLS vs API-only | **C. ALREADY DECIDED BY MASTER ARCHITECTURE** | Master §8, §32.2: API RBAC / object checks. Do not invent RLS as a required product rule. Optional later is not a schema blocker. |
| 16 | KYC / bank / UPI / document_type labels | **B. CAN BE DEFERRED AFTER SQL** | Concepts locked; exact labels not listed (Blueprint #26). TEXT columns can exist. |
| 17 | UNIQUE one driver vs fleet | **B. CAN BE DEFERRED AFTER SQL** | Fleet is FUTURE (Master §10.1). V1 UNIQUE is a spec pick; can CREATE. |
| 18 | GPS retention / create `rider_location_samples` in V1 | **B. CAN BE DEFERRED AFTER SQL** | Omit the table until retention exists (Issue 3). Not required for other CREATE TABLEs. |
| 19 | Create customer wallet tables in V1 | **B. CAN BE DEFERRED AFTER SQL** | ARCHITECTURE READY; booking does not require them (Master §9.3). |
| 20 | Launch `cash_enabled` / `online_enabled` values | **B. CAN BE DEFERRED AFTER SQL** | Model supports both (Master §E, §44). Seed/policy, not column types. |
| 21 | Quote TTL duration | **B. CAN BE DEFERRED AFTER SQL** | `expires_at` exists; minutes unnumbered (Master “short TTL”). |
| 22 | Idempotency key expiration | **D. NOT ACTUALLY A DECISION — REMOVE** | Master does **not** define TTL. Spec correctly forbids inventing one. Listing it as a decision invites a wrong TTL column. |

**Additional A item not in the original 22:**

| New | Item | Class | Why |
|---|---|---|---|
| A2 | Wallet ↔ COD ledger twin FK: DEFERRABLE vs single direction | **A. MUST DECIDE BEFORE SQL** | Issue 8. CREATE/INSERT of settlement twins is otherwise undefined. |

**Counts for the original 22:** A=1, B=14, C=1, D=6.

**Decisions required before SQL (honest set):** **2** — (1) money physical type; (2) ledger twin-FK mechanism.

HIGH spec **fixes** (Case A version CHECKs, expand abbreviated columns, licence encryption pattern, invoice header list, ratings rater columns) are **not** user product decisions. They must still be applied in the specification before SQL so implementers do not invent.

---

## 18. Business Rule Drift Check

Searched for accidental changes to locked rules.

| Locked rule | Drift in spec? | Evidence |
|---|---|---|
| 85% rider | **No** | Default 85; finance copies percent; not CHECK frozen at 85 forever (Admin versioning required) |
| 15% company | **No** | Default 15; sum with rider = 100 |
| 50% of company commission as ops | **No** | Default 50; ops from company share; not a rider deduction |
| GST = 0 | **No** | CHECK = 0 on fare tax and invoice gst |
| Trip Fare is 85/15 base | **No** | Explicit on fare + finance snapshots; bill is `net_payable` / responsibility |
| Wallet never negative | **No** | CHECK >= 0; COD not stored there |
| COD Due separate from wallet | **No** | Two accounts, two ledgers |
| COD Due threshold = ₹100 | **No** | Policy default 100; still versioned |
| Order UUID | **No** | UUID PK |
| `IU-{CITY}-{10 digit sequence}` | **No change to the rule**; weak CHECK | Documented; Issues 18, 23 |
| Multiple payment transactions | **No** | 1:N |
| Customer / Receiver / Split payer | **No** | `who_pays` + plan + txns |
| Resend Case A | **No formula drift**; version FKs too nullable; narrative says “85%” | Issues 4, 9, 32 |
| Resend Case B | **No** | ₹10/₹8/₹2; not 85/15; base_fare NULL |
| Cancellation default ₹0 | **No** | fee DEFAULT 0; snapshot even if 0 |
| Admin-configurable settings | **No** | Versioned surfaces including extra rates and COD threshold |
| Historical snapshots | **No** | Insert-only; copied numbers |
| Append-only financial history | **No** | Ledgers and snapshots |
| Maximum 3 drops | **No rule change**; DB CHECK deferred to trigger vs app | Issue 7 |

**Detected drift / mis-statement (not formula rewrites):**

1. Inventory 50+4 vs 51+3 (Issues 1–2) — classification drift.  
2. Case A description hardcodes 85% instead of “versioned percents defaulting to 85/15” (Issue 9).  
3. `admin_profiles.password_hash` vs Master “profiles do not have independent passwords” (Issue 11).  
4. Invoice uniqueness `order_id` only vs Master §30.1 `order_id + invoice type` (Issue 33).  
5. `SUBMITTED` KYC value not named in Master (Issue 36) — label invention, not a money rule.  
6. Bank `is_current` default inverted vs Blueprint (Issue 21) — not a locked money rule.

**Issue 33 — MEDIUM**  
**Problem:** Master §30.1 / §31.1: invoice generate uniqueness is `order_id + invoice type`. Spec UNIQUE `(order_id)` and no `invoice_type` column. Blueprint B.44 also omits `invoice_type`. Retry same number is still possible with unique order_id. A second **type** (if ever needed) cannot be stored.  
**Source:** Master §30.1; Spec §7.45, NEEDS DECISION #12.  
**Affected:** `invoices`.  
**Recommended resolution:** V1 unique order_id is compatible with “retry returns the same invoice.” Add `invoice_type` only if Master’s phrase is treated as a real discriminator. Do not invent types.  
**User decision required?** YES whether `invoice_type` exists. Can defer (B) if V1 has one document per order.

**No drift found** that applies 85/15 to invoice total, GST, or payment amount, or that merges COD into wallet, or that changes display-id format, or that sets GST to 5%.

---

## 19. SQL Readiness

### Score: **READY WITH DECISIONS**

**Why not READY FOR SQL**

- Master §43 money type is unpicked. Every money column’s PostgreSQL type depends on it.
- Twin ledger FKs need DEFERRABLE vs single-direction before CREATE/INSERT.
- HIGH specification gaps (abbreviated columns, Case A version CHECKs, invoice header list, ratings rater columns, licence encryption pattern) would force the SQL author to **invent** or to silently copy Blueprint text. This audit forbids inventing.

**Why not NOT READY**

- Entity coverage matches Master §12.5 and Blueprint §B.
- Locked 85/15/50, GST 0, UUID + display_id, wallet ≠ COD, four payment layers, cancellation ₹0, Case A/B formulas, append-only snapshots are structurally present.
- Forbidden models were not revived.
- Most of the 22 NEEDS DECISION rows are **not** schema-type blockers.

**What must happen before SQL (not done in this step)**

1. User/team picks **one** money type for all amount columns.  
2. Spec (later phase) expands abbreviated tables, adds Case A version CHECKs, and resolves twin FKs.  
3. Decide whether V1 SQL **creates** customer wallet tables and/or GPS samples (optional; default recommendation: wallet optional, GPS omit).

---

## 20. Final Recommendations

1. **Do not generate SQL from the specification as-is.** Close HIGH issues in a future spec revision, then pick the money type, then write migrations.  
2. **Keep** the 51 locked-production tables (including `order_display_counters`). **Do not** add `cod_settlements`, Receiver users, chat, or a single `payments` truth table.  
3. **Reclassify** architecture-ready as **3 tables**, not 4. Customer wallet pair: optional CREATE. GPS samples: omit from V1 unless retention is decided.  
4. **Fix Case A CHECKs** so resend-time fare + payment-settings versions are mandatory for `resend_case = 'A'`.  
5. **Resolve circular ledger FKs** with DEFERRABLE constraints or one-direction twin pointers. Never CASCADE money.  
6. **Expand §7** so every table has an explicit column grid (especially `invoices`, `order_ratings`, customer wallet, `order_adjustments`).  
7. **Treat** 85/15 as versioned defaults on Trip Fare freeze rows; do not hardcode 85 into Case A CHECK arithmetic.  
8. **Leave** Case A/B **operational** shape as a TECHNICAL DESIGN OPTION; do not invent a third storage model. Prefer child order if same-order Case B payment vs frozen responsibility is not designed.  
9. **Remove** from the decision list: JSONB vs child rates (already chosen), one vs two extra-rate tables (already chosen), Case B 10=8+2 forever CHECK (correctly omitted), audit one vs two (already chosen), RLS (Master = API RBAC), idempotency TTL (do not invent).  
10. **Protect** licence/national IDs the same way as bank/UPI.

---

## Appendix A — Issue register

| ID | Severity | Problem (short) | Source | Affected | Resolution | User decision? |
|---|---|---|---|---|---|---|
| 1 | MEDIUM | 50+4 inventory arithmetic wrong (51+3) | Spec §3 | Inventory | Recount | NO |
| 2 | HIGH | Fourth architecture-ready table does not exist | Spec §3; Master §9.3, Redis GPS | Tables 32, 33, 54 | 3 ready tables | YES only for V1 CREATE of optional tables |
| 3 | MEDIUM | GPS table in V1 without retention | Master Redis GPS; BP #25 | `rider_location_samples` | Omit from V1 SQL | YES |
| 4 | HIGH | Case A version FKs nullable | Master §21.2–21.4 | `resend_snapshots` version columns | CHECK NOT NULL when case=A | NO |
| 5 | MEDIUM | invoice_lines delete wording vs RESTRICT | Spec §3 vs §8 | `invoice_lines` | Keep RESTRICT | NO |
| 6 | LOW | OTP identity ON DELETE open | Spec #8 | `otp_challenges` | Prefer RESTRICT | YES (deferrable) |
| 7 | MEDIUM | 1–3 drops / plan sums not DB-enforced | Master §13, §16.2; Spec #7 | `order_stops`, plans | App or later trigger | YES (deferrable) |
| 8 | HIGH | Circular wallet↔COD ledger FKs | BP B.26–B.28; Spec §7.27–7.29 | Twin id columns | DEFERRABLE or one direction | YES — before SQL |
| 9 | MEDIUM | Case A text says “85%” not versioned percents | Master §21.2; Spec §7.44 | Narrative | Re-word | NO |
| 10 | HIGH | Same-order Case B extra vs frozen responsibility | Master §16.1, §21.3 | Responsibility, txns, resend | Do not invent; child order safer | YES (storage shape) |
| 11 | MEDIUM | Admin password on profile vs Master 36.1 | Master §36.1; Spec §7.6 | `password_hash` | Document pick or move | NO if pick accepted |
| 12 | MEDIUM | UNIQUE cancel snapshot vs reject rows | Spec §7.41 | `order_cancellation_snapshots` | Unique successful cancel only | YES |
| 13 | MEDIUM | Untyped notification profile id | Master §28; Spec §7.47 | `notifications` | Identity FK or typed FKs | YES |
| 14 | HIGH | Invoice header columns incomplete vs B.44 | Master §23; BP B.44; Spec §7.45 | `invoices` | Expand header list | NO |
| 15 | HIGH | Ratings missing from/to profile columns | BP B.45; Spec §7.46 | `order_ratings` | Add columns | NO |
| 16 | LOW | Rider has no deactivated_at | Master §34.2 | `rider_profiles` | Optional column | NO |
| 17 | LOW | Zone name not unique per city | BP B.9 | `zones` | Optional unique | NO |
| 18 | MEDIUM | Sequence can exceed 10 digits | Master §12.1 | `last_seq`, `display_id` | CHECK 10 digits | NO |
| 19 | LOW | V1 one active vehicle not unique | Master §10.1 | `vehicles` | Optional unique | NO |
| 20 | HIGH | Licence not encrypted/tokenized | Master §32.3 | `licence_reference` | Mask + encrypt | NO |
| 21 | LOW | `is_current` default FALSE vs BP true | BP B.23; Spec §7.24 | Bank/UPI | Keep FALSE | NO |
| 22 | LOW | Closed wallet entry_type CHECK | Master §19.1 | `entry_type` | V1 list or TEXT | NO |
| 23 | LOW | display_id format not CHECKed | Master §12.1 | `orders.display_id` | CHECK or allocator | NO |
| 24 | LOW | No structured stop fields | Master §13 | `order_stops` | address_text enough | NO |
| 25 | MEDIUM | rounding sign / snapshot stop_count CHECK | Master §15 | fare snapshot | Align CHECKs | YES for rounding sign |
| 26 | MEDIUM | Duplicate payment idempotency homes | Master §30; Spec §7.39 | txn key vs idempotency table | One unique home | NO |
| 27 | MEDIUM | No 85/15 amount arithmetic CHECK / rounding rule | Master §15, §22 | finance amounts | App rounding; optional later | YES (deferrable) |
| 28 | MEDIUM | Invoice header + lines both exist | BP B.44 | `invoices`, `invoice_lines` | Header authority | NO |
| 29 | LOW | One failed_delivery per order | Spec §7.42 | `failed_deliveries` | OK for V1 | NO |
| 30 | MEDIUM | Customer wallet columns abbreviated | BP B.29; Spec §7.30 | customer wallet | Expand | NO |
| 31 | HIGH | Multiple §7 tables not SQL-complete | Spec §7 vs BP §B | Several tables | Expand all grids | NO |
| 32 | HIGH | Case A mandatory shape undefined | Master §21.2 | parent/child columns | Do not invent; both columns OK | YES runtime; NO for CREATE columns |
| 33 | MEDIUM | Invoice unique order_id vs order+type | Master §30.1 | `invoices` | V1 unique order_id or add type | YES (deferrable) |
| 34 | LOW | COD threshold not snapshotted on suspend | Master §18.4 | rider COD status | Audit + versions | NO |
| 35 | MEDIUM | Immutability not a DB privilege/trigger | Master §22 | snapshot/ledger tables | REVOKE UPDATE in SQL phase | NO |
| 36 | LOW | SUBMITTED KYC label not in Master | Spec §6.2 | `onboarding_kyc_status` | Keep open | YES labels |
| 37 | LOW | Customer active index not partial | Master §35 | `orders` | Optional later | NO |
| 38 | LOW | OTP (phone, created_at) index omitted | BP B.2 | `otp_challenges` | Add in SQL | NO |
| 39 | MEDIUM | Missing time indexes for snapshot reports | Master §37 | finance/invoice times | Add in SQL | NO |
| 40 | MEDIUM | parent_order_id vs child_order_id can disagree | Spec §15 | order/resend FKs | Keep consistent if both set | NO |
| 41 | LOW | Finance ORIGINAL unique per order vs “per component” | Master §31.1 | `order_finance_snapshots` | OK if extras use ADJUSTMENT_FREEZE / child order | NO |
| 42 | LOW | `payment_method_policy` extra method flags | Master §E | policy booleans | Justified | NO |

**Issue 41 — LOW**  
**Problem:** Master §31.1: unique original finance kind **per component**. Spec partial UNIQUE ORIGINAL **per order**. Safe if Case A is a child order (own ORIGINAL) and office/Case B use `ADJUSTMENT_FREEZE`. Unsafe if related-record Case A tries a second ORIGINAL on the same order.  
**Source:** Master §31.1; Spec §7.40.  
**Affected:** `order_finance_snapshots`.  
**Recommended resolution:** Keep one ORIGINAL trip-fare freeze per order. Put resend P&L on the child or as ADJUSTMENT_FREEZE / resend snapshot copy — not a second ORIGINAL. Tied to Issue 32.  
**User decision required?** NO if child-or-adjustment rule is followed.

**Issue 42 — LOW**  
**Problem:** None — extra method flags are **not** drift. Listed so the register accounts for a possible “unnecessary column” question.  
**Source:** Master §E.  
**Affected:** `payment_method_policy_versions`.  
**Recommended resolution:** Keep.  
**User decision required?** NO.

---

**End of DATABASE SCHEMA AUDIT**

No SQL was written.  
`MASTER_SYSTEM_ARCHITECTURE.md`, `IMPLEMENTATION_BLUEPRINT.md`, and `DATABASE_SCHEMA_SPECIFICATION.md` were **not** modified.  
Only this file was created.
