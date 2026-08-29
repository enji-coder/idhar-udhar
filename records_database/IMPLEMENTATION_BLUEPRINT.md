# IDHAR UDHAR — IMPLEMENTATION BLUEPRINT

**Type:** Implementation blueprint (documentation only)  
**Date:** 2026-08-22  
**Status:** BLUEPRINT — not implemented  
**Source of truth:** `records_database/MASTER_SYSTEM_ARCHITECTURE.md` (Sections 1–46, including the audit trail)

This file translates the locked Master System Architecture into a practical implementation plan.

It does **not** replace the Master Architecture.  
It does **not** change a locked business rule.  
It does **not** create PostgreSQL, APIs, or application code.

```text
MASTER_SYSTEM_ARCHITECTURE.md     (locked design)
        ↓
IMPLEMENTATION_BLUEPRINT.md       (this file)
        ↓
Physical PostgreSQL schema        (later approved phase)
        ↓
API / backend                     (later approved phase)
        ↓
Customer / Rider / Admin integration
```

**If this file and the Master Architecture ever disagree, the Master Architecture wins.**

---

## How this file uses the Master Architecture

| Master label | How this blueprint treats it |
|---|---|
| FINAL BUSINESS RULE | Implement exactly |
| ARCHITECTURE READY | Design and store for it; do not treat as live today |
| IMPLEMENTATION PENDING BACKEND | This is the work this blueprint sequences |
| FUTURE IMPLEMENTATION | Later phase; do not build as V1 product |
| TECHNICAL DESIGN OPTION | Engineering choice. Listed under **NEEDS DECISION** if Master did not pick one |
| FUTURE BUSINESS DECISION | Listed under **NEEDS DECISION**. Do not invent |

Master §3 also points at `RULES_BOOK.md` and confirmed sections of `18_FINAL_BUSINESS_DECISIONS.md` when documents disagree. This blueprint does **not** revive leftover `18` C / D / L / M, `04` / `05` single-payment models, or `08` invoice tax 5%.

---

## Conventions used in this blueprint

These are **not** new business rules. They only make the blueprint readable.

| Convention | Meaning | Source |
|---|---|---|
| `uuid` | Time-sortable UUID primary key (Master example: UUID v7) | Master §12.1, §34.2, §43 |
| `money` | A single rupee amount type used everywhere | Master §43: integer minor units **or** `numeric(12,2)`. **NEEDS DECISION** which one. Pick one at schema time and use it for every amount |
| `percent` | Numeric 0–100 | Master payment settings and cancellation shares |
| `timestamptz` | Timestamp with timezone | Master requires timestamps on facts |
| `text` | Human string | — |
| `enum` | Closed list named in Master | Do not add extra values unless Master allows |
| Required | Must exist for that row to be valid | — |
| Optional | Master allows null / later fill | — |

**Do not store:** card PAN / CVV, raw OTP, payment provider private keys, signing keystores in the database (Master §32.5).

**Firebase is not the production database** (Master §34.4).

---

# A. SYSTEM MODULES

One modular backend (Master §6.2 — TECHNICAL DESIGN OPTION: modular monolith, not microservices). Clients send commands. Backend applies rules. PostgreSQL stores facts (Master §6.3).

| Module | Master home | Responsibility | Must not do |
|---|---|---|---|
| **Authentication / Identity** | §7 | One Identity per person; OTP or Admin password; session claims `identity_id` + `active_profile_type` + `profile_id` | Two logins for one phone; phone as FK; Admin token on Customer/Rider APIs |
| **Customer** | §9 | Profile, addresses, book, track, cancel if allowed, request resend, own invoices | Own 85/15; see other customers’ orders; change Admin config |
| **Rider** | §10 | Profile, online/offline, accept/reject, trip progress, cash collect, wallet + COD Due | Decide accept winner locally; accept while COD-suspended; book as rider |
| **Admin / RBAC** | §8, §11 | Configure, assign, cancel, approve riders, finance views, reports | Recalculate old trips from live settings; store secrets in the browser |
| **Catalog** | §9, §26, §I | Cities, zones, vehicle categories | Join by the word “Bike” |
| **Vehicle management** | §26 | Vehicle instance, subtype, documents, optional driver | Invent a fleet-owner product |
| **Orders / Trips / Dispatch** | §12–14, §O | Canonical order, stops, offers, status machine | Client-side status as truth; two accepted riders |
| **Fare calculation** | §15 | Server quote + immutable fare snapshot | Client as fare authority; silent Trip Fare edits |
| **Payments** | §16–17 | Responsibility, plan, transactions, aggregates | One `payment_method` as the whole model; fake online PAID |
| **Wallet** | §19 | Rider available money + append-only ledger | Negative balance; store COD Due as −wallet |
| **COD** | §18 | Company cash held by rider + ledger + settle-first | Mix with wallet; settle a cash trip against itself |
| **Rider earnings** | §10.2, §18–19, §22 | Digital earnings after COD settlement; cash earning stays physical | Post cash-trip ₹85 into wallet |
| **Company revenue** | §4, §22 | 15% of confirmed Trip Fare (configurable version) | Take it from discounted payable |
| **Company operations cost** | §4, §22 | 50% of **company share only** (configurable). Internal P&L allocation | Deduct from rider; treat as vendor bill |
| **Company net profit** | §4, §22 | Company share − operations allocation | Recalculate from today’s sliders |
| **Finance snapshot** | §22 | Freeze P&L; reversals are new rows | Update original snapshot |
| **Invoices** | §23 | Document ≠ trip ID; full bill; GST ₹0 | Rebuild from live Admin rates; show one payer’s share as total |
| **Notifications** | §28 | Persisted inbox + dedupe; push ARCHITECTURE READY | V1 chat (not V1) |
| **Documents / Files** | §27 | KYC/POD/invoice metadata in Postgres; bytes in object storage | Store PAN; store file bytes in money tables |
| **Bank / UPI** | §27.2 | Payout destinations, masked | Log full account numbers |
| **Configuration / settings** | §24 | Versioned fare, 85/15/50, cancel, office, COD threshold, extra rates, methods | Edit a published version already used by an order |
| **Audit / history** | §29 | Append-only who/what/when/old/new/why | Hard-delete financial audit |
| **Idempotency** | §30 | Same retry = one money/status effect | Trust client retries without a key |
| **Reporting** | §37 | Sum snapshots and ledgers | Browser-scan all orders; live settings on old rows |
| **Realtime / GPS** | §P, §33.1 | WS/push ARCHITECTURE READY; Redis last GPS | 1 Hz write of all riders to Postgres |
| **Workers** | §5, §39 | SMS, invoice PDF, webhooks, daily stats — ARCHITECTURE READY | Required on day-one schema (Phase 1 can be API + Postgres only) |

**Not a module:** Receiver application (Master §4.17). Receiver is a **payer type** on the trip.

---

# B. DATABASE BLUEPRINT

PostgreSQL is the system of record (Master §34). This section is **not DDL**. It lists every entity the Master Architecture requires, with the fields Master named plus identifiers/timestamps the architecture already requires.

**Money columns:** type `money` until the physical type is chosen (**NEEDS DECISION**, Master §43).

**Delete policy (Master §34.2, §36.17):** soft-delete masters; **never hard-delete** financial rows, snapshots, ledgers, or financial audit.

---

## B.1 Identity

**Purpose:** One physical person, one login.

| Field | Type | Required | Default | Notes |
|---|---|---|---|---|
| identity_id | uuid | yes | generated | Primary identifier |
| phone_normalized | text | yes | — | Unique. 10-digit / E.164 |
| email | text | no | null | Unique when present. Typical for Admin |
| auth_status | enum | yes | ACTIVE | ACTIVE / LOCKED / REVOKED — exact extra values **NEEDS DECISION** if more are needed |
| created_at | timestamptz | yes | now | |
| updated_at | timestamptz | yes | now | |

**Primary identifier:** `identity_id`  
**Foreign keys:** none  
**Relationships:** 0..1 Customer Profile; 0..1 Rider Profile; 0..1 Admin Profile; N OTP; N Session  
**Constraints:** unique phone; unique email when present  
**Indexes:** unique phone; unique email  
**Audit:** phone/email/status changes  
**Soft delete:** deactivate via status; do not erase if orders exist  

Phone is **not** a foreign key on orders (Master §7.7, §36.2).

---

## B.2 OTP Challenge

**Purpose:** Hashed server OTP. Never plaintext (Master §7.5).

| Field | Type | Required | Default | Notes |
|---|---|---|---|---|
| otp_challenge_id | uuid | yes | generated | PK |
| phone_normalized | text | yes | — | Target phone |
| identity_id | uuid | no | null | Set if identity already exists |
| code_hash | text | yes | — | Never plaintext |
| expires_at | timestamptz | yes | **NEEDS DECISION** (OTP lifetime not locked) | |
| attempt_count | integer | yes | 0 | |
| max_attempts | integer | no | **NEEDS DECISION** | |
| cooldown_until | timestamptz | no | null | Resend cooldown 30s exists in current apps; production lifetime/lockout **NEEDS DECISION**. Master locks: store cooldown |
| ip | text | no | null | Rate-limit by phone + IP |
| consumed_at | timestamptz | no | null | |
| created_at | timestamptz | yes | now | |

**Relationships:** Identity optional  
**Indexes:** phone + created_at; identity_id  
**Never store raw OTP.**

---

## B.3 Session

**Purpose:** Logged-in period bound to one identity and one active profile (Master §7.6).

| Field | Type | Required | Default | Notes |
|---|---|---|---|---|
| session_id | uuid | yes | generated | PK |
| identity_id | uuid | yes | — | FK Identity |
| active_profile_type | enum | yes | — | CUSTOMER / RIDER / ADMIN |
| profile_id | uuid | yes | — | The profile used for this session |
| refresh_token_hash | text | no | null | If refresh tokens are used (TECHNICAL DESIGN OPTION) |
| expires_at | timestamptz | yes | — | Exact TTL **NEEDS DECISION** |
| revoked_at | timestamptz | no | null | |
| created_at | timestamptz | yes | now | |

**Constraints:** Admin session must never authorize Customer/Rider APIs and vice versa  
**Indexes:** identity_id; token lookup hash  

Session transport (JWT vs cookie) is a **TECHNICAL DESIGN OPTION** (Master §7.6) → **NEEDS DECISION**.

---

## B.4 Customer Profile

**Purpose:** Marketplace-customer role. Not login secrets (Master §9.1).

| Field | Type | Required | Default | Notes |
|---|---|---|---|---|
| customer_profile_id | uuid | yes | generated | PK |
| identity_id | uuid | yes | — | FK Identity, unique |
| display_name | text | yes | — | Required |
| email | text | no | null | Optional until tracking/invoice continue |
| invoice_email | text | no | null | Captured when required |
| status | enum | yes | ACTIVE | ACTIVE / DEACTIVATED |
| default_city_id | uuid | no | null | FK City |
| deactivated_at | timestamptz | no | null | Soft delete |
| created_at | timestamptz | yes | now | |
| updated_at | timestamptz | yes | now | |

**Relationships:** Identity 1:1; N Orders; N Saved Addresses; 0..1 Customer Wallet (ARCHITECTURE READY)  
**Orders use `customer_profile_id`, never identity_id or phone.**

---

## B.5 Rider Profile

**Purpose:** Delivery-worker role (Master §10.1).

| Field | Type | Required | Default | Notes |
|---|---|---|---|---|
| rider_profile_id | uuid | yes | generated | PK |
| identity_id | uuid | yes | — | FK Identity, unique |
| onboarding_kyc_status | enum | yes | — | Exact enum list beyond uploaded/approved/rejected **NEEDS DECISION** if more steps exist. Master: onboarding / KYC status |
| approval_status | enum | yes | — | approve / reject / suspend (Master §10.1) |
| online_status | enum | yes | OFFLINE | ONLINE / OFFLINE |
| home_city_id | uuid | no | null | FK City |
| home_zone_id | uuid | no | null | FK Zone |
| cod_operational_status | enum | yes | CLEAR | CLEAR / SUSPENDED_FOR_COD (Master §8.3) |
| created_at | timestamptz | yes | now | |
| updated_at | timestamptz | yes | now | |

**Relationships:** Identity; optional Driver; optional Vehicle; 1 Wallet Account; 1 COD Account; N Offers; N assigned Orders; Documents; Bank; UPI  

**SUSPENDED_FOR_COD** when COD Due ≥ active threshold (default ₹100). Cannot accept new offers. Can still see assigned trip and wallet. Admin can see the reason.

---

## B.6 Admin Profile

**Purpose:** Staff control plane (Master §11.1).

| Field | Type | Required | Default | Notes |
|---|---|---|---|---|
| admin_profile_id | uuid | yes | generated | PK |
| identity_id | uuid | yes | — | FK Identity, unique |
| role | enum | yes | — | SUPER_ADMIN / SUB_ADMIN / OPERATIONS / FINANCE / SUPPORT / MANAGER (Master §8.1) |
| modules | list/text | no | empty | Mock already has `modules[]`. Exact module catalog **NEEDS DECISION** beyond Master’s write surfaces |
| finance_access | boolean | yes | false | Master §8.1 / §11.1 |
| payout_approve | boolean | yes | false | Master §8.1 / §11.1 |
| city_scope_id | uuid | no | null | “if later needed” (Master §11.1) |
| password_hash | text | yes | — | On Identity or here. Server-side Argon2id or equivalent. Never in React |
| active | boolean | yes | true | |
| created_at | timestamptz | yes | now | |
| updated_at | timestamptz | yes | now | |

V1 Admin login is normally a **staff identity** (email + password). One human being all three roles is **not** a required product path (Master §7.3).

---

## B.7 Customer Saved Address

**Purpose:** Reusable addresses (Master §9.2).

| Field | Type | Required | Default | Notes |
|---|---|---|---|---|
| saved_address_id | uuid | yes | generated | PK |
| customer_profile_id | uuid | yes | — | FK |
| label | text | no | null | Master does not lock label values |
| address_text | text | yes | — | |
| latitude | number | no | null | |
| longitude | number | no | null | |
| zone_id | uuid | no | null | FK Zone |
| deactivated_at | timestamptz | no | null | Soft delete |
| created_at | timestamptz | yes | now | |

Booked trips **copy** location onto Order Stop. They do not depend on this row remaining forever.

---

## B.8 City

**Purpose:** Geography + display-ID city code (Master §I, §12.1).

| Field | Type | Required | Default | Notes |
|---|---|---|---|---|
| city_id | uuid | yes | generated | PK |
| name | text | yes | — | |
| city_code | text | yes | — | `AMD` = Ahmedabad. Unique |
| active | boolean | yes | true | |
| created_at | timestamptz | yes | now | |

**FINAL:** first launch city Ahmedabad / `AMD`. Multi-city schema from day one. Surat dummy is not a second launch city unless later confirmed.

Display ID sequence is conceptually scoped by city (Master §12.1). Exact sequence object is a schema-time detail, not a new business rule.

---

## B.9 Zone

**Purpose:** Service area under a city (Master §I).

| Field | Type | Required | Default | Notes |
|---|---|---|---|---|
| zone_id | uuid | yes | generated | PK |
| city_id | uuid | yes | — | FK City |
| name | text | yes | — | Navrangpura, Satellite, Maninagar, Bopal, Naroda, Gota, SG Highway already modelled |
| active | boolean | yes | true | |
| created_at | timestamptz | yes | now | |

Vehicle availability is per category **and** filterable by city/zone.

---

## B.10 Vehicle Category

**Purpose:** Sellable type. Join by id, never by name (Master §26, §T).

| Field | Type | Required | Default | Notes |
|---|---|---|---|---|
| vehicle_category_id | uuid | yes | generated | PK |
| code | text | no | null | Optional unique code if migrating mock IDs `VC-1001`… |
| name | text | yes | — | Bike, Auto, Mini Truck, Tempo, Large Tempo, Truck |
| active | boolean | yes | true | Soft delete = deactivate |
| weight_capacity | text/number | no | null | Catalog copy (Master fare fields) |
| size | text | no | null | Catalog copy |
| created_at | timestamptz | yes | now | |
| updated_at | timestamptz | yes | now | |

Scooty/scooter is a **vehicle subtype** under Bike, not a V1 category unless Admin later creates one.

---

## B.11 Fare Configuration Version

**Purpose:** Published rate sheet for **future** quotes (Master §15, §24).

| Field | Type | Required | Default | Notes |
|---|---|---|---|---|
| fare_config_version_id | uuid | yes | generated | PK |
| version | integer | yes | — | Monotonic |
| status | enum | yes | DRAFT | DRAFT / ACTIVE / SUPERSEDED |
| effective_from | timestamptz | yes | — | |
| effective_until | timestamptz | no | null | |
| created_by_admin_profile_id | uuid | yes | — | FK Admin Profile |
| created_at | timestamptz | yes | now | |
| payload / per-category rates | structured | yes | — | See items below |

**Per-category rate facts inside the version** (Master §S / §15.2):

| Field | Type | Required | Default |
|---|---|---|---|
| vehicle_category_id | uuid | yes | — |
| base_fare | money | yes | Admin-set (demo seeds are not a commercial lock) |
| per_km | money | yes | Admin-set |
| initial_minimum | money | yes | Admin-set |
| waiting | money | yes | Admin-set |
| surge | money | yes | Admin-set |
| toll | money | yes | Admin-set |
| parking | money | yes | Admin-set |

Whether rates are a JSON payload or child rows is a **TECHNICAL DESIGN OPTION** (not a business rule). Published versions used by orders are **never edited in place**.

---

## B.12 Payment Settings Version

**Purpose:** Versioned 85 / 15 / 50 (Master §4, §22, §24).

| Field | Type | Required | Default | Notes |
|---|---|---|---|---|
| payment_settings_version_id | uuid | yes | generated | PK |
| version | integer | yes | — | |
| status | enum | yes | DRAFT | DRAFT / ACTIVE / SUPERSEDED |
| rider_percentage | percent | yes | 85 | Of **Trip Fare** |
| company_commission_percentage | percent | yes | 15 | Of **Trip Fare** |
| operational_cost_percentage_of_commission | percent | yes | 50 | Of **company share only** |
| effective_from | timestamptz | yes | — | |
| effective_until | timestamptz | no | null | |
| created_by_admin_profile_id | uuid | yes | — | |
| created_at | timestamptz | yes | now | |

**Constraints:** `rider_percentage + company_commission_percentage = 100`; all three ≥ 0 and ≤ 100. Reject publish if invalid.

---

## B.13 Payment Method Policy Version

**Purpose:** Which methods Admin enabled (Master §24, §E).

| Field | Type | Required | Default | Notes |
|---|---|---|---|---|
| payment_method_policy_version_id | uuid | yes | generated | PK |
| version | integer | yes | — | |
| status | enum | yes | DRAFT | DRAFT / ACTIVE / SUPERSEDED |
| cash_enabled | boolean | yes | **NEEDS DECISION** whether first production is cash-only | Methods Admin already has: UPI, Card, Net Banking, Wallet, Cash |
| online_enabled | boolean | yes | **NEEDS DECISION** (online in first launch vs cash-first) | |
| effective_from | timestamptz | yes | — | |
| created_by_admin_profile_id | uuid | yes | — | |
| created_at | timestamptz | yes | now | |

Schema must support all method labels on day one (Master §E). Which are **on** at launch is a future decision.

---

## B.14 Cancellation Configuration Version

**Purpose:** Published cancel table for one actor (Master §20).

| Field | Type | Required | Default | Notes |
|---|---|---|---|---|
| cancellation_config_version_id | uuid | yes | generated | PK |
| actor | enum | yes | — | CUSTOMER / RIDER (separate streams) |
| version | integer | yes | — | |
| status | enum | yes | DRAFT | DRAFT / ACTIVE / SUPERSEDED |
| effective_from | timestamptz | yes | — | |
| created_by_admin_profile_id | uuid | yes | — | |
| created_at | timestamptz | yes | now | |

**Per-stage rows in the version:**

| Field | Type | Required | Default | Notes |
|---|---|---|---|---|
| stage | enum | yes | — | Before accept; after accept; after reach pickup; after pickup; during delivery / in transit |
| enabled | boolean | yes | — | If not enabled, that actor cannot cancel at that stage |
| fee | money | yes | 0 | Default fee ₹0 |
| rider_share_percent | percent | yes | — | Must sum to 100 with company |
| company_share_percent | percent | yes | — | |

**Constraint:** rider % + company % = 100. Not automatically 85/15.  
Admin may cancel until terminal as an **operational** power. A **fee** comes only from a snapshotted versioned rule. Do not invent a separate Admin fee schedule (Master §20.4, audit correction 18).

---

## B.15 COD Policy Version

**Purpose:** Version the suspend threshold (Master §18.4, §24). FINAL default today ₹100.

| Field | Type | Required | Default | Notes |
|---|---|---|---|---|
| cod_policy_version_id | uuid | yes | generated | PK |
| version | integer | yes | — | |
| status | enum | yes | DRAFT | DRAFT / ACTIVE / SUPERSEDED |
| suspend_threshold | money | yes | 100 | ₹100 FINAL today; still version |
| effective_from | timestamptz | yes | — | |
| created_by_admin_profile_id | uuid | yes | — | |
| created_at | timestamptz | yes | now | |

---

## B.16 Resend And Office Rate Version

**Purpose:** Version FINAL extra per-km rates so a later edit cannot rewrite old trips (Master §21, §24, audit #13).

| Field | Type | Required | Default | Notes |
|---|---|---|---|---|
| extra_rate_version_id | uuid | yes | generated | PK |
| version | integer | yes | — | |
| status | enum | yes | DRAFT | DRAFT / ACTIVE / SUPERSEDED |
| resend_case_a_per_km | money | yes | 10 | Plus rate-sheet base; 85/15 on combined customer amount |
| resend_case_b_customer_per_km | money | yes | 10 | |
| resend_case_b_rider_per_km | money | yes | 8 | |
| resend_case_b_company_per_km | money | yes | 2 | |
| office_handover_per_km | money | yes | 8 | Rider; not 85/15 |
| effective_from | timestamptz | yes | — | |
| created_by_admin_profile_id | uuid | yes | — | |
| created_at | timestamptz | yes | now | |

Whether this is one versioned sheet or separate resend vs office version entities is a **TECHNICAL DESIGN OPTION**. The **numbers and versioning requirement** are locked.

---

## B.17 Company Office Version

**Purpose:** Admin-configured failed-delivery destination (Master §25).

| Field | Type | Required | Default | Notes |
|---|---|---|---|---|
| company_office_version_id | uuid | yes | generated | PK |
| version | integer | yes | — | |
| status | enum | yes | DRAFT | DRAFT / ACTIVE / SUPERSEDED |
| city_id | uuid | yes | — | FK City. V1: one active office per launch city |
| address | text | yes | — | |
| latitude | number | yes | — | |
| longitude | number | yes | — | |
| effective_from | timestamptz | yes | — | |
| effective_until | timestamptz | no | null | |
| created_by_admin_profile_id | uuid | yes | — | |
| created_at | timestamptz | yes | now | |

Apps must not keep a hardcoded main office as authority. Failed delivery **copies** this snapshot onto the event.

---

## B.18 Vehicle

**Purpose:** Real vehicle instance (Master §26.2).

| Field | Type | Required | Default | Notes |
|---|---|---|---|---|
| vehicle_id | uuid | yes | generated | PK |
| vehicle_category_id | uuid | yes | — | FK |
| rider_profile_id | uuid | no | null | Nullable if unassigned |
| registration | text | no | null | RC fields |
| two_wheeler_subtype | enum | no | null | `bike` / `scooter` when category is Bike |
| active | boolean | yes | true | |
| created_at | timestamptz | yes | now | |
| updated_at | timestamptz | yes | now | |

V1 behaviour: one rider ≈ one driver ≈ one vehicle.

---

## B.19 Rider Driver

**Purpose:** Licence holder so owner ≠ driver can be stored later (Master §10.1, §H). Not a fleet product.

| Field | Type | Required | Default | Notes |
|---|---|---|---|---|
| rider_driver_id | uuid | yes | generated | PK |
| rider_profile_id | uuid | yes | — | FK |
| name | text | no | null | |
| mobile | text | no | null | Not an Identity login |
| date_of_birth | date | no | null | |
| licence_reference | text | no | null | Mask/protect like KYC |
| created_at | timestamptz | yes | now | |

**FUTURE BUSINESS DECISION:** hired driver / multi-vehicle fleet.

---

## B.20 Stored File

**Purpose:** Metadata only. Bytes in object storage (Master §27, §23).

| Field | Type | Required | Default | Notes |
|---|---|---|---|---|
| file_id | uuid | yes | generated | PK |
| storage_key | text | yes | — | Object storage key |
| content_type | text | no | null | |
| size_bytes | integer | no | null | |
| checksum | text | no | null | |
| purpose | enum | yes | — | KYC / POD / INVOICE_PDF / other |
| virus_scan_status | enum | no | PENDING | ARCHITECTURE READY |
| created_by_identity_id | uuid | no | null | |
| created_at | timestamptz | yes | now | |

Do not store file binary in PostgreSQL unless a later legal hold requires it. Master does not require that.

---

## B.21 Rider Document

**Purpose:** KYC metadata and review (Master §27.1).

| Field | Type | Required | Default | Notes |
|---|---|---|---|---|
| rider_document_id | uuid | yes | generated | PK |
| rider_profile_id | uuid | yes | — | FK |
| document_type | text | yes | — | Exact required document list **NEEDS DECISION** if not taken from current registration screens as discovery only |
| file_id | uuid | yes | — | FK Stored File |
| status | enum | yes | UPLOADED | UPLOADED / APPROVED / REJECTED |
| reviewer_admin_profile_id | uuid | no | null | |
| reviewed_at | timestamptz | no | null | |
| created_at | timestamptz | yes | now | |

Customer documents are **not** required for V1 booking (Master §27.3).

---

## B.22 Vehicle Document

**Purpose:** Vehicle paper metadata (Master §26.2, §27).

| Field | Type | Required | Default | Notes |
|---|---|---|---|---|
| vehicle_document_id | uuid | yes | generated | PK |
| vehicle_id | uuid | yes | — | FK |
| document_type | text | yes | — | |
| file_id | uuid | yes | — | FK |
| status | enum | yes | UPLOADED | UPLOADED / APPROVED / REJECTED |
| reviewer_admin_profile_id | uuid | no | null | |
| reviewed_at | timestamptz | no | null | |
| created_at | timestamptz | yes | now | |

---

## B.23 Rider Bank Account

**Purpose:** Payout destination (Master §27.2).

| Field | Type | Required | Default | Notes |
|---|---|---|---|---|
| bank_account_id | uuid | yes | generated | PK |
| rider_profile_id | uuid | yes | — | FK |
| holder_name | text | yes | — | |
| account_masked | text | yes | — | Display |
| account_encrypted_or_token | text | yes | — | At rest protected |
| ifsc_or_bank | text | no | null | |
| is_current | boolean | yes | true | Supersede, do not edit a paid-out row |
| status | enum | no | — | Verification status — exact values **NEEDS DECISION** |
| created_at | timestamptz | yes | now | |

Never log full account numbers. Finance-only full reveal with audit.

---

## B.24 Rider UPI

**Purpose:** UPI destination (Master §27.2).

| Field | Type | Required | Default | Notes |
|---|---|---|---|---|
| rider_upi_id | uuid | yes | generated | PK |
| rider_profile_id | uuid | yes | — | FK |
| vpa_masked | text | yes | — | |
| vpa_encrypted_or_token | text | yes | — | |
| is_current | boolean | yes | true | |
| status | enum | no | — | **NEEDS DECISION** exact verification states |
| created_at | timestamptz | yes | now | |

---

## B.25 Rider Wallet Account

**Purpose:** Available earning money. Never COD Due (Master §19.1).

| Field | Type | Required | Default | Notes |
|---|---|---|---|---|
| wallet_account_id | uuid | yes | generated | PK |
| rider_profile_id | uuid | yes | — | FK, unique 1:1 |
| available_balance | money | yes | 0 | ≥ 0. Materialized. Source of truth = ledger |
| created_at | timestamptz | yes | now | |
| updated_at | timestamptz | yes | now | |

**Never delete.** Balance changes only in the same DB transaction as a Wallet Ledger insert.

---

## B.26 Wallet Ledger

**Purpose:** Append-only source of truth for wallet (Master §19.1).

| Field | Type | Required | Default | Notes |
|---|---|---|---|---|
| wallet_ledger_id | uuid | yes | generated | PK |
| wallet_account_id | uuid | yes | — | FK |
| direction | enum | yes | — | CREDIT / DEBIT |
| amount | money | yes | — | > 0 |
| entry_type | enum | yes | — | Examples Master lists: EARNING, COD_SETTLEMENT, RECHARGE, PAYOUT, ADJUSTMENT, CANCELLATION_SHARE, RESEND_EARNING |
| related_order_id | uuid | no | null | FK Order |
| related_payment_transaction_id | uuid | no | null | |
| related_cod_ledger_id | uuid | no | null | Settlement twin |
| actor_type | enum | yes | — | customer / rider / admin / webhook / system |
| actor_profile_id | uuid | no | null | |
| created_at | timestamptz | yes | now | |

**Immutable.** Never update. Never hard-delete.  
**Index:** (wallet_account_id, created_at)

Master example types are **not a business fee list**. Do not invent extra fee types.

---

## B.27 Rider COD Account

**Purpose:** Money the rider owes the company from cash collections (Master §18).

| Field | Type | Required | Default | Notes |
|---|---|---|---|---|
| cod_account_id | uuid | yes | generated | PK |
| rider_profile_id | uuid | yes | — | FK, unique 1:1 |
| cod_due | money | yes | 0 | ≥ 0. Materialized. Truth = COD Ledger |
| created_at | timestamptz | yes | now | |
| updated_at | timestamptz | yes | now | |

If `cod_due` ≥ active COD Policy threshold → `Rider Profile.cod_operational_status = SUSPENDED_FOR_COD`.

---

## B.28 COD Ledger

**Purpose:** Append-only COD increases and settlements (Master §18.2–18.3).

| Field | Type | Required | Default | Notes |
|---|---|---|---|---|
| cod_ledger_id | uuid | yes | generated | PK |
| cod_account_id | uuid | yes | — | FK |
| direction | enum | yes | — | INCREASE / DECREASE |
| amount | money | yes | — | > 0 |
| source | enum | yes | — | CASH_COMPANY_SHARE / RECHARGE_SETTLEMENT / DIGITAL_EARNING_SETTLEMENT / CANCELLATION_SHARE_SETTLEMENT / ADMIN_ADJUSTMENT |
| related_order_id | uuid | no | null | |
| related_wallet_ledger_id | uuid | no | null | Twin posting |
| source_txn_id | text/uuid | no | null | Unique with rider for settlement idempotency (Master §30.1) |
| created_at | timestamptz | yes | now | |

**Settlement is not a third balance entity.** It is a COD Ledger decrease plus, if remainder exists, a Wallet Ledger credit. One rider-finance lock.

---

## B.29 Customer Wallet Account (ARCHITECTURE READY)

**Purpose:** Optional prepaid/promo. **Not required for V1 booking.** Booking does **not** auto-debit until a future decision (Master §9.3, §W).

| Field | Type | Required | Default | Notes |
|---|---|---|---|---|
| customer_wallet_id | uuid | yes | generated | PK |
| customer_profile_id | uuid | yes | — | Unique 1:1 if created |
| available_balance | money | yes | 0 | ≥ 0 unless a future credit product is explicitly decided |
| created_at | timestamptz | yes | now | |

Companion append-only **Customer Wallet Ledger** if enabled. Dummy ₹420 / ₹50 / ₹200 / ₹150 are **not** official program amounts (Master §V).

---

## B.30 Order

**Purpose:** Canonical trip. Central business entity (Master §12).

| Field | Type | Required | Default | Notes |
|---|---|---|---|---|
| order_id | uuid | yes | generated | PK. Time-sortable UUID |
| display_id | text | yes | generated | Unique. `IU-{CITY_CODE}-{10-digit sequence}` e.g. `IU-AMD-0000010421` |
| customer_profile_id | uuid | yes | — | FK Customer Profile. **Not** identity_id. **Not** phone |
| rider_profile_id | uuid | no | null | FK Rider Profile. Null until assigned |
| city_id | uuid | yes | — | FK City |
| vehicle_category_id | uuid | yes | — | FK |
| vehicle_category_name_snapshot | text | yes | — | History |
| vehicle_id | uuid | no | null | Assigned rider vehicle |
| canonical_status | enum | yes | CREATED | See §D |
| parent_order_id | uuid | no | null | Resend child only |
| scheduled_at | timestamptz | no | null | Not V1. Do not build a scheduler |
| created_at | timestamptz | yes | now | |
| updated_at | timestamptz | yes | now | |

Convenience copies of trip fare / payable may exist on the order row; **Fare Snapshot is the authority** (Master §12.2).

**Never join on** customer name, phone, “Bike”, or display id as the only key.

**Indexes:** unique display_id; (customer_profile_id, created_at desc); (customer_profile_id, canonical_status); (rider_profile_id, canonical_status, created_at desc); (city_id, canonical_status, created_at desc)

One customer may have many running trips. One rider does **not automatically** take a second live trip. Manual Admin second assign is **NEEDS DECISION**.

---

## B.31 Order Stop

**Purpose:** Ordered pickup/drops. Never a comma-separated string (Master §13).

| Field | Type | Required | Default | Notes |
|---|---|---|---|---|
| order_stop_id | uuid | yes | generated | PK. Stable ID |
| order_id | uuid | yes | — | FK |
| sequence | integer | yes | — | Unique per order |
| stop_type | enum | yes | — | PICKUP / DROP |
| address_text | text | yes | — | Plus structured fields as available |
| latitude | number | yes | — | |
| longitude | number | yes | — | |
| zone_id | uuid | no | null | If known |
| contact_name | text | no | null | Required-at-booking **NEEDS DECISION** |
| contact_phone | text | no | null | Required-at-booking **NEEDS DECISION** |
| arrived_at | timestamptz | no | null | |
| completed_at | timestamptz | no | null | |
| proof_file_id | uuid | no | null | POD — object storage. Master mentions POD files |

**Constraints:** exactly 1 PICKUP; 1..3 DROP; unique sequence per order.  
**FINAL today:** fare uses total route distance. Do **not** invent a multi-stop extra fee.

---

## B.32 Order Status Event

**Purpose:** Append-only history (Master §14.2).

| Field | Type | Required | Default | Notes |
|---|---|---|---|---|
| order_status_event_id | uuid | yes | generated | PK |
| order_id | uuid | yes | — | FK |
| from_status | enum | no | null | Null on first create |
| to_status | enum | yes | — | Canonical status |
| actor_type | enum | yes | — | customer / rider / admin / system |
| actor_profile_id | uuid | no | null | |
| reason | text | no | null | |
| idempotency_key | text | yes | — | Duplicate ignored |
| created_at | timestamptz | yes | now | |

**Immutable.** Order row holds **current** status for queries.  
**Index:** (order_id, created_at)

---

## B.33 Order Offer

**Purpose:** Accept lock (Master §O, §31.2).

| Field | Type | Required | Default | Notes |
|---|---|---|---|---|
| order_offer_id | uuid | yes | generated | PK |
| order_id | uuid | yes | — | FK |
| rider_profile_id | uuid | yes | — | FK |
| status | enum | yes | PENDING | PENDING / REJECTED / EXPIRED / ACCEPTED |
| created_at | timestamptz | yes | now | |
| responded_at | timestamptz | no | null | |

**Constraints:** at most one ACCEPTED offer per order.  
**Indexes:** (order_id); (rider_profile_id, status)  
Dummy 27s timer is **not** production policy. Production timeout **NEEDS DECISION**.

---

## B.34 Fare Quote

**Purpose:** Server-calculated price before confirm; TTL (Master §15, §B).

| Field | Type | Required | Default | Notes |
|---|---|---|---|---|
| fare_quote_id | uuid | yes | generated | PK |
| customer_profile_id | uuid | yes | — | FK |
| fare_config_version_id | uuid | yes | — | FK |
| vehicle_category_id | uuid | yes | — | |
| distance_km | number | yes | — | Sum of ordered legs |
| stop_count | integer | yes | — | |
| base / per_km / distance_charge / minimum / waiting / surge / toll / parking | money | yes | — | Copied from version |
| trip_fare | money | yes | — | |
| discount | money | yes | 0 | |
| rounding | money | yes | 0 | |
| net_payable | money | yes | — | |
| tax | money | yes | 0 | GST = 0 |
| expires_at | timestamptz | yes | — | TTL value **NEEDS DECISION** (Master says short TTL, not a number) |
| created_at | timestamptz | yes | now | |

---

## B.35 Fare Snapshot

**Purpose:** Immutable confirmed fare (Master §15.2).

| Field | Type | Required | Default | Notes |
|---|---|---|---|---|
| fare_snapshot_id | uuid | yes | generated | PK |
| order_id | uuid | yes | — | FK. One per billed order |
| fare_config_version_id | uuid | yes | — | |
| vehicle_category_id | uuid | yes | — | |
| vehicle_category_name | text | yes | — | |
| distance_km | number | yes | — | |
| stop_count | integer | yes | — | |
| base_fare | money | yes | — | |
| per_km | money | yes | — | |
| distance_charge | money | yes | — | |
| initial_minimum | money | yes | — | |
| waiting | money | yes | — | |
| surge | money | yes | — | |
| toll | money | yes | — | |
| parking | money | yes | — | |
| trip_fare | money | yes | — | 85/15 base |
| discount | money | yes | 0 | |
| rounding | money | yes | 0 | |
| net_payable | money | yes | — | Bill (usually) |
| tax | money | yes | 0 | Always 0 on fare |
| quoted_at | timestamptz | no | null | |
| confirmed_at | timestamptz | yes | now | |

**Immutable.** Never delete. Never silently change Trip Fare.

---

## B.36 Payment Responsibility

**Purpose:** Who owes how much of **this bill** (Master §16.1).

| Field | Type | Required | Default | Notes |
|---|---|---|---|---|
| payment_responsibility_id | uuid | yes | generated | PK |
| order_id | uuid | yes | — | Unique 1:1 |
| applicable_bill_total | money | yes | — | Usually net payable. Not the 85/15 base |
| customer_responsibility | money | yes | — | |
| receiver_responsibility | money | yes | — | |
| who_pays | enum | yes | — | CUSTOMER / RECEIVER / SPLIT |

**Constraint:** customer + receiver = applicable bill total.  
Receiver is a payer type, **not** a user table.

---

## B.37 Payment Plan

**Purpose:** How they **intend** to pay (Master §16.2). Not PAID.

| Field | Type | Required | Default | Notes |
|---|---|---|---|---|
| payment_plan_id | uuid | yes | generated | PK |
| order_id | uuid | yes | — | Unique 1:1 |
| customer_planned_online | money | yes | 0 | |
| customer_planned_cash | money | yes | 0 | |
| receiver_planned_online | money | yes | 0 | |
| receiver_planned_cash | money | yes | 0 | |

**Constraint:** per payer, planned online + planned cash = that payer’s responsibility.  
V1 methods: ONLINE | CASH. WALLET can be added later without rewriting history.

---

## B.38 Payment Transaction

**Purpose:** One actual attempt or cash collection (Master §17).

| Field | Type | Required | Default | Notes |
|---|---|---|---|---|
| payment_transaction_id | uuid | yes | generated | PK |
| order_id | uuid | yes | — | FK |
| payer_type | enum | yes | — | CUSTOMER / RECEIVER |
| method | enum | yes | — | ONLINE / CASH (V1) |
| amount | money | yes | — | |
| direction | enum | yes | CHARGE | CHARGE / REFUND (refund = new row) |
| transaction_status | enum | yes | PENDING | PENDING / PAID / FAILED / REFUNDED |
| provider_txn_id | text | no | null | |
| provider_event_id | text | no | null | Unique when present (webhook) |
| idempotency_key | text | yes | — | |
| created_by_type | enum | yes | — | customer / rider / admin / webhook / system |
| created_by_profile_id | uuid | no | null | |
| created_at | timestamptz | yes | now | |
| updated_at | timestamptz | yes | now | |

**Do not** store UNPAID / PARTIALLY_PAID / PAID on this row as the trip status. Those are **aggregates**.  
**Indexes:** (order_id, created_at); unique provider_event_id; unique idempotency per payment-create scope  
Online PAID only after verified provider confirmation. Do not fake success.

---

## B.39 Finance Snapshot

**Purpose:** Frozen P&L. Insert-only. Many rows per order allowed (Master §22).

| Field | Type | Required | Default | Notes |
|---|---|---|---|---|
| finance_snapshot_id | uuid | yes | generated | PK |
| order_id | uuid | yes | — | FK. **Not unique** — reversals need another row |
| snapshot_kind | enum | yes | ORIGINAL | ORIGINAL / REVERSAL / ADJUSTMENT_FREEZE |
| trip_fare / ride_amount | money | yes | — | Confirmed Trip Fare |
| rider_percentage | percent | yes | — | Copied |
| company_commission_percentage | percent | yes | — | Copied |
| operational_cost_percentage_of_commission | percent | yes | — | Copied |
| rider_amount | money | yes | — | |
| company_commission_amount | money | yes | — | |
| operational_cost_amount | money | yes | — | From company share only |
| profit_amount | money | yes | — | company − operational |
| payment_settings_version_id | uuid | yes | — | FK |
| frozen_at | timestamptz | yes | now | |

**Timing (Master §B / §22):** Fare locked at confirm. P&L freeze uses payment-settings version **in force at freeze time** (normally DELIVERED). Does not re-quote. Does not use settings published **after** freeze.

One rupee of extra money has **one** business fact (cancel / resend / office). A freeze row may **copy** it for reports. Do not store the same rupee three independent times.

---

## B.40 Cancellation Snapshot

**Purpose:** Exact rule used on that cancel (Master §20.4). Write even if fee is ₹0.

| Field | Type | Required | Default | Notes |
|---|---|---|---|---|
| cancellation_snapshot_id | uuid | yes | generated | PK |
| order_id | uuid | yes | — | FK |
| stage | enum | yes | — | |
| actor_type | enum | yes | — | customer / rider / admin |
| allowed | boolean | yes | — | If false, reject; no cancel |
| fee | money | yes | 0 | |
| rider_share_percent | percent | yes | — | |
| company_share_percent | percent | yes | — | |
| rider_amount | money | yes | — | |
| company_amount | money | yes | — | |
| cancellation_config_version_id | uuid | yes | — | FK |
| created_at | timestamptz | yes | now | |

---

## B.41 Failed Delivery

**Purpose:** Receiver unavailable; parcel to office. **Not** cancellation (Master §21.1).

| Field | Type | Required | Default | Notes |
|---|---|---|---|---|
| failed_delivery_id | uuid | yes | generated | PK |
| order_id | uuid | yes | — | FK |
| reason | enum | yes | receiver_unavailable | V1 reason locked |
| office_version_id | uuid | yes | — | FK Company Office Version |
| office_address_snapshot | text | yes | — | Copy |
| office_latitude | number | yes | — | Copy |
| office_longitude | number | yes | — | Copy |
| office_distance_km | number | yes | — | Used for ₹8 compensation |
| created_at | timestamptz | yes | now | |

Original 85/15 stays. Office compensation is an **Order Adjustment**, not a rewrite of Trip Fare.

---

## B.42 Order Adjustment

**Purpose:** One extra money fact (Master §12, §21.1, §22.2).

| Field | Type | Required | Default | Notes |
|---|---|---|---|---|
| order_adjustment_id | uuid | yes | generated | PK |
| order_id | uuid | yes | — | FK |
| adjustment_type | enum | yes | — | OFFICE_COMPENSATION / ADMIN_ADJUSTMENT / OVERPAY_CORRECTION (overpay handling required by Master §16.3). Do not invent fee types |
| amount | money | yes | — | |
| beneficiary | enum | yes | — | RIDER / COMPANY / CUSTOMER as applicable |
| extra_rate_version_id | uuid | no | null | For office ₹8/km |
| distance_km | number | no | null | |
| reason | text | yes | — | Required for Admin adjustments |
| actor_type | enum | yes | — | |
| actor_profile_id | uuid | no | null | |
| created_at | timestamptz | yes | now | |

Office compensation = `office_distance_km × snapshotted ₹8`. Not 85/15.

---

## B.43 Resend Snapshot

**Purpose:** Case A or Case B money. Never overwrite original fare (Master §21).

| Field | Type | Required | Default | Notes |
|---|---|---|---|---|
| resend_snapshot_id | uuid | yes | generated | PK |
| original_order_id | uuid | yes | — | FK |
| child_order_id | uuid | no | null | If Case A stored as child order |
| resend_case | enum | yes | — | A / B |
| distance_km | number | yes | — | |
| case_a_base_fare | money | no | null | Required for Case A |
| customer_amount | money | yes | — | |
| rider_amount | money | yes | — | |
| company_amount | money | yes | — | |
| fare_config_version_id | uuid | no | null | Case A rate sheet **at resend time** |
| extra_rate_version_id | uuid | yes | — | |
| payment_settings_version_id | uuid | no | null | Case A 85/15 |
| request_status | enum | yes | — | not_decided / requested / in_progress / completed (Master / `19`) |
| created_at | timestamptz | yes | now | |

**TECHNICAL DESIGN OPTION (Master §21.2–21.3):** Case A as child order vs related record; Case B on same order vs related record. Money rules stay the same. Storage shape → **NEEDS DECISION**.

Closing failed delivery **without** resend is **NEEDS DECISION**. Do not invent a status or fee.

---

## B.44 Invoice

**Purpose:** Financial document ≠ trip ID (Master §23).

| Field | Type | Required | Default | Notes |
|---|---|---|---|---|
| invoice_id | uuid | yes | generated | PK |
| invoice_number | text | yes | generated | Unique series. Never equal to display_id |
| order_id | uuid | yes | — | FK |
| status | enum | yes | DRAFT | DRAFT / ISSUED / CANCELLED |
| issued_at | timestamptz | no | null | After delivered + P&L freeze for completed trip |
| trip_fare | money | yes | — | Copied |
| discount | money | yes | 0 | Copied |
| additional_locked_charges | money | yes | 0 | Copied extras on **this** bill |
| rounding | money | yes | 0 | |
| billed_total | money | yes | — | Full bill, not one payer’s share |
| customer_paid | money | yes | 0 | |
| receiver_paid | money | yes | 0 | |
| gst_on_fare | money | yes | 0 | Always 0 |
| payment_status_snapshot | enum | no | — | UNPAID / PARTIALLY_PAID / PAID at issue |
| pdf_file_id | uuid | no | null | FK Stored File |
| emailed_to | text | no | null | |
| created_at | timestamptz | yes | now | |

Legal letterhead GSTIN / SAC / e-invoice: **NEEDS DECISION**. Do not invent. Do not require for fare correctness.

Invoice lines (copied fare/discount/extras) may be fields on Invoice or child rows. Same amounts. Not a second money truth.

Retry generate: **same invoice number, same snapshot amounts** (idempotent).

---

## B.45 Order Rating

**Purpose:** Customer rates rider after delivery (Master §X).

| Field | Type | Required | Default | Notes |
|---|---|---|---|---|
| order_rating_id | uuid | yes | generated | PK |
| order_id | uuid | yes | — | |
| direction | enum | yes | CUSTOMER_TO_RIDER | Rider→customer nullable/future |
| from_profile_id | uuid | yes | — | |
| to_profile_id | uuid | yes | — | |
| stars | integer | yes | — | 1–5 |
| comment | text | no | null | |
| created_at | timestamptz | yes | now | |

**Constraint:** one rating per order per direction.  
Rider→customer, edit, public comments → **NEEDS DECISION**.

---

## B.46 Notification

**Purpose:** Persisted inbox + dedupe (Master §28).

| Field | Type | Required | Default | Notes |
|---|---|---|---|---|
| notification_id | uuid | yes | generated | PK and dedupe id |
| recipient_identity_id | uuid | no | null | Scope by identity **or** profile — TECHNICAL DESIGN OPTION |
| recipient_profile_id | uuid | no | null | |
| type | text | yes | — | |
| title | text | no | null | |
| body | text | yes | — | |
| order_id | uuid | no | null | |
| read_at | timestamptz | no | null | |
| created_at | timestamptz | yes | now | |

No V1 chat entity. Calls must **mask** counterpart numbers.

---

## B.47 Audit Log

**Purpose:** Append-only who/what/when/old/new/why (Master §29).

| Field | Type | Required | Default | Notes |
|---|---|---|---|---|
| audit_log_id | uuid | yes | generated | PK |
| actor_identity_id | uuid | no | null | System if null |
| actor_profile_id | uuid | no | null | |
| actor_role | text | no | null | |
| action | text | yes | — | |
| entity_type | text | yes | — | |
| entity_id | uuid | yes | — | |
| old_value | structured | no | null | |
| new_value | structured | no | null | |
| reason | text | no | null | Where Admin is asked |
| request_id | text | no | null | |
| ip | text | no | null | |
| user_agent | text | no | null | |
| category | text | no | null | Admin vs financial — TECHNICAL DESIGN OPTION one log or two |
| created_at | timestamptz | yes | now | |

**Immutable.** Never hard-delete financial audit.  
**Index:** (entity_type, entity_id, created_at)

Must audit: fare publish, payment settings publish, cancellation publish, office change, wallet adjustment, COD adjustment, order financial adjustment, permission change, rider approve/reject/suspend, refunds.

---

## B.48 Idempotency Record

**Purpose:** Same request twice → money/status once (Master §30).

| Field | Type | Required | Default | Notes |
|---|---|---|---|---|
| idempotency_id | uuid | yes | generated | PK |
| scope | text | yes | — | create-order, accept-offer, payment, webhook, recharge, cod-settlement, cancel, resend, invoice, status |
| key | text | yes | — | |
| actor_identity_id | uuid | no | null | |
| request_hash | text | yes | — | |
| result_entity_id | uuid | no | null | |
| result_payload | structured | no | null | |
| created_at | timestamptz | yes | now | |

**Constraint:** unique (scope, key)  
Same key + same hash → original result. Same key + different hash → reject.  
**Index:** unique (scope, key)

---

## B.49 Rider Location Sample (ARCHITECTURE READY)

**Purpose:** Optional sampled history. Hot last point = Redis TTL ~30s (Master §P). Not a money entity.

| Field | Type | Required | Default | Notes |
|---|---|---|---|---|
| location_sample_id | uuid | yes | generated | PK |
| rider_profile_id | uuid | yes | — | |
| order_id | uuid | no | null | |
| latitude | number | yes | — | |
| longitude | number | yes | — | |
| recorded_at | timestamptz | yes | now | |

Do not write every ping forever. Retention legal policy is not blocking schema (Master §P). Exact retain days **NEEDS DECISION** if samples are stored.

---

# C. BUSINESS LOGIC

Use locked formulas exactly. Do not invent fees.

---

## C.1 Fare calculation (Master §15)

Server-calculated. Client quote is advisory.

```text
distance_km       = sum of ordered stop legs
distance_charge   = per_km × distance_km
trip_fare         = max(initial_minimum, base + distance_charge + waiting + surge + toll + parking)
net_total         = round(trip_fare − discount)
tax               = 0
```

No invented multi-stop extra fee.

**Quote → confirm:** persist quote; on confirm copy onto Fare Snapshot. Later Admin version N+1 does not touch this snapshot.

**Trip Fare ≠ Net Payable.**

```text
Trip Fare ₹100, Discount ₹10, Net Payable ₹90
85/15 uses ₹100, not ₹90
```

---

## C.2 IDHAR UDHAR distribution / rider / company / operations / profit (Master §4, §22)

Applies to **confirmed Trip Fare**. Who pays and how they pay **do not change** this.

```text
rider_amount           = trip_fare × rider_percentage / 100
company_commission     = trip_fare × company_commission_percentage / 100
operational_allocation = company_commission × operational_cost_percentage_of_commission / 100
actual_profit          = company_commission − operational_allocation
```

Defaults: 85 / 15 / 50.

Locked example:

```text
Trip Fare ₹100
Rider ₹85
Company ₹15
  Operations ₹7.50
  Net Profit ₹7.50
```

Operations is **not** a rider deduction and **not** a vendor bill. Purchase invoices (if any later) stay separate. Do not double-count.

P&L freeze: normally at DELIVERED; also terminal cancel/fail as needed. Settings version = version **in force at freeze**. Insert-only. Reversal = new row.

---

## C.3 Payment (Master §16–17)

Four facts:

1. **Responsibility** — who owes the **bill** (usually net payable).
2. **Plan** — intended ONLINE/CASH amounts.
3. **Transactions** — PENDING / PAID / FAILED / REFUNDED.
4. **Aggregate** — UNPAID / PARTIALLY_PAID / PAID from **PAID** transactions only.

Validations:

- customer_responsibility + receiver_responsibility = bill
- per payer, planned methods = that payer’s responsibility
- PAID aggregate only when paid **equals** owed after rounding
- Overpay → adjustment or refund row, not silent PAID
- ONLINE → PAID only after verified webhook/provider confirm
- Do not dispatch as paid while online is still pending (Master §12.3)
- Refund = new transaction direction=refund; original row stays

If online is later enabled, order does not enter searching as paid until cash selection or authorized/successful online (Master §E). Capture moment (authorize at booking vs capture at delivery) → **NEEDS DECISION**.

---

## C.4 COD (Master §18)

```text
Trip Fare ₹100 → Rider ₹85, Company ₹15
Customer gives ₹100 cash

Physical cash = ₹100
Rider earning = ₹85   (physical; NOT a wallet credit)
COD Due      += ₹15
Wallet        = unchanged
```

If cash collected ≤ rider earning: COD Due += ₹0. Platform may still owe the rider a digital remainder later.

Do not invent a COD surcharge.

**Eligible digital inflows settle COD first:** later online earning, cancellation rider share, wallet recharge, other digital earnings marked as settling COD.

**This cash trip’s rider share must not settle this trip’s own COD Due.**

Suspend: COD Due ≥ threshold (default ₹100) → cannot accept **new** rides; existing assigned trip can finish.

---

## C.5 Wallet (Master §19)

- Materialized balance ≥ 0
- Every change = ledger insert in the same transaction
- Lock rider finance (wallet + COD) for earning freeze, COD create, recharge, payout, Admin adjustment
- Recharge: settle COD first, remainder to wallet  
  Example: Due ₹60, recharge ₹100 → settle ₹60, wallet +₹40
- Later online ₹85 with Due ₹15 → settle ₹15, wallet +₹70
- Payout debits wallet only, after freeze, for online/digital available balance (Master §B payout timing)
- Customer wallet: ARCHITECTURE READY; no auto-debit until decided

---

## C.6 Cancellation (Master §20)

1. Load **active** cancellation version for that actor (CUSTOMER or RIDER).
2. Map current canonical status to a locked stage (do not invent extra stages).
3. If stage not enabled → reject.
4. Snapshot fee and shares (even if fee ₹0).
5. Fee uses **cancellation shares**, not 85/15.
6. If fee > 0: credit rider share immediately, then COD settlement if digital.
7. If cancelled before trip-fare P&L freeze: do not invent 85/15 earnings.
8. If a freeze already exists and must be undone: insert REVERSAL finance snapshot. Do not edit the original.
9. Admin may cancel until terminal; fee still comes only from a versioned snapshotted rule.

---

## C.7 Refund (Master §17.2, §C)

- New Payment Transaction, direction REFUND
- Original row not overwritten
- Refund to wallet only if original payment was wallet (Master §W) — Customer wallet auto-debit itself is not a V1 booking rule
- Do not invent a cancellation-refund amount beyond the snapshotted fee / paid transactions
- Audit the refund

Online provider refunds follow webhook + idempotency. Provider vendor **NEEDS DECISION**.

---

## C.8 Trip lifecycle (Master §14)

Backend is the only legal transitioner. Invalid transition rejected. Duplicate idempotency key ignored.

Happy path:

```text
CREATED → SEARCHING → OFFERED → ASSIGNED
→ EN_ROUTE_PICKUP → ARRIVED_PICKUP → PICKED_UP
→ IN_TRANSIT → NEAR_DROP → DELIVERY_ATTEMPT → DELIVERED
```

Failed delivery:

```text
DELIVERY_ATTEMPT → RECEIVER_UNAVAILABLE → FAILED_DELIVERY
→ PARCEL_AT_COMPANY_OFFICE → RESEND_REQUESTED
→ RESEND_IN_PROGRESS → RESEND_COMPLETED
```

Offer reject / timeout: event, then status SEARCHING.

After confirm: create order + fare snapshot + responsibility + plan; then SEARCHING / dispatch.

If Case A is a child order: original keeps ended status; child has its own status. Do not hide the first trip.

SEARCHING auto-cancel TTL / radius / retry count → **NEEDS DECISION**. Until then: keep searching until customer/admin cancel or admin assigns (Master §N).

---

## C.9 Rider lifecycle (Master §10, §8.3)

```text
Register + documents + vehicle + bank/UPI
  → KYC uploaded
  → Operations/Super Admin approve or reject
  → Go online (if approved and not COD-suspended)
  → Receive offers
  → Accept (server lock) or reject
  → Progress assigned trip
  → COD Due may suspend new accepts
```

Must be online and not COD-suspended to accept.  
One rider does not automatically take a second live trip.

---

## C.10 Customer lifecycle (Master §9)

```text
OTP login → Identity
  → Customer Profile (name required; email optional)
  → Saved addresses
  → Book (pickup + 1..3 drops, vehicle, parcel, who-pays, how-they-pay)
  → Confirm (locks fare)
  → Track (email required to continue if still empty)
  → Cancel if rule enabled
  → Resend after failed delivery
  → Invoice after delivered + freeze
```

Many orders, including many active. Phone not editable in Edit Profile (OTP-verified).

---

## C.11 Invoice lifecycle (Master §23)

```text
DRAFT (worker may prepare)
  → ISSUED after delivered + P&L freeze
  → CANCELLED if the document must be voided
```

PDF by worker, private storage, signed download. Email failure does not un-pay. Retry returns same number and amounts. Customer invoice is not forced to show 85/15 unless product later asks (Master §23.2).

---

## C.12 Failed delivery and resend (Master §21)

Failed delivery ≠ cancel. V1 reason: `receiver_unavailable`.

**Office extra:** `km × ₹8` to rider. Not 85/15. Adjustment + office snapshot.

**Case A** (original trip ended):

```text
customer_pays = (rate-sheet base at resend time) + (₹10 × km)
Then normal 85/15 on that combined amount
Example: base ₹100 + 5 km → ₹150; rider ₹127.50; company ₹22.50
         operations/profit from that ₹22.50 using snapshotted 50% rule
```

**Case B** (original trip not ended):

```text
customer = ₹10 × km
rider    = ₹8 × km
company  = ₹2 × km
Not 85/15
Example: 5 km → ₹50 / ₹40 / ₹10
```

Never overwrite original Fare Snapshot or original 85/15.

---

## C.13 Accept race (Master §31.2)

```text
BEGIN
  lock order
  if status not OFFERED/SEARCHING (as allowed) → reject
  if another accepted offer exists → reject
  if rider COD Due ≥ threshold → reject
  if rider offline or not approved → reject
  if automatic second live trip → reject
  accept offer
  set rider_id, status ASSIGNED
  write status event
COMMIT
```

Second rider: already accepted. Same rider retry: idempotent.  
Cancel vs accept: lock order; first commit wins.

---

# D. STATE MACHINES

## D.1 Order canonical status (Master §14)

| Status | Typical meaning |
|---|---|
| CREATED | Order recorded |
| SEARCHING | Looking for a rider |
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
| PARCEL_AT_COMPANY_OFFICE | At Admin office |
| RESEND_REQUESTED | Customer requested resend |
| RESEND_IN_PROGRESS | Resend moving |
| RESEND_COMPLETED | Resend done |

**Do not create** Customer Status / Rider Status / Admin Status as separate truths. UI labels may differ (Master table §14.1).

### Valid transitions (locked happy + failed paths)

| From | To | Who | Conditions |
|---|---|---|---|
| (none) | CREATED | System at confirm | Fare snapshot + responsibility + plan written |
| CREATED | SEARCHING | System | Not treated as paid if online still pending |
| SEARCHING | OFFERED | System / dispatch | Offer rows created. Algorithm **NEEDS DECISION** |
| SEARCHING | ASSIGNED | Admin assign | Admin may assign while searching |
| SEARCHING | CANCELLED | Customer or Admin | Customer cancel only if rule for that stage enabled |
| OFFERED | ASSIGNED | Rider accept (winner) | Order lock + unique accepted offer + COD check |
| OFFERED | SEARCHING | Rider reject / offer timeout | Event then SEARCHING |
| OFFERED | CANCELLED | Customer or Admin | Stage rule; lock vs accept |
| ASSIGNED | EN_ROUTE_PICKUP | Assigned rider | |
| EN_ROUTE_PICKUP | ARRIVED_PICKUP | Assigned rider | |
| ARRIVED_PICKUP | PICKED_UP | Assigned rider | |
| PICKED_UP | IN_TRANSIT | Assigned rider | |
| IN_TRANSIT | NEAR_DROP | Assigned rider | |
| NEAR_DROP | DELIVERY_ATTEMPT | Assigned rider | |
| DELIVERY_ATTEMPT | DELIVERED | Assigned rider | Then cash confirm as applicable; P&L freeze |
| DELIVERY_ATTEMPT | RECEIVER_UNAVAILABLE | Assigned rider | Not a cancel |
| RECEIVER_UNAVAILABLE | FAILED_DELIVERY | System / rider | |
| FAILED_DELIVERY | PARCEL_AT_COMPANY_OFFICE | Assigned rider | Office snapshot + ₹8/km adjustment |
| PARCEL_AT_COMPANY_OFFICE | RESEND_REQUESTED | Customer | |
| RESEND_REQUESTED | RESEND_IN_PROGRESS | System / rider | Case A/B snapshot |
| RESEND_IN_PROGRESS | RESEND_COMPLETED | System / rider | |
| Any non-terminal | CANCELLED | Admin | Until delivered/cancelled/failed-terminal; fee from versioned rule only |
| ASSIGNED and later | CANCELLED | Rider | Only if rider rule enabled at that stage (Master: current app has limited rider cancel; production follows Admin enable) |

**Terminal in current machine:** DELIVERED, CANCELLED, RESEND_COMPLETED.

After each transition: write Status Event; update current status with compare-and-set (only if `from_status` still matches).

Customer cancel after `en_route_pickup` is **not** in the current app; production must not invent a fee for a forbidden cancel.

---

## D.2 Order Offer

| Status | Who | Next |
|---|---|---|
| PENDING | System creates | ACCEPTED / REJECTED / EXPIRED |
| ACCEPTED | Winning rider | Terminal for this offer; order ASSIGNED |
| REJECTED | That rider | Order may return SEARCHING |
| EXPIRED | System | Order may return SEARCHING |

Only one ACCEPTED per order.

---

## D.3 Payment transaction

| From | To | Who | Restriction |
|---|---|---|---|
| PENDING | PAID | Webhook (online) or rider/admin (cash) | Online requires signature-verified provider confirm |
| PENDING | FAILED | Provider / timeout | Do not fake |
| PAID | (no overwrite) | — | Refund = **new** row REFUNDED / direction refund |

---

## D.4 Aggregate payment status (derived)

| Status | Rule |
|---|---|
| UNPAID | paid = 0 |
| PARTIALLY_PAID | 0 < paid < owed |
| PAID | paid = owed after rounding |

Computed for Customer, Receiver, and Overall. Not stored as the only payment truth.

---

## D.5 Invoice

| From | To | Who | After |
|---|---|---|---|
| DRAFT | ISSUED | Worker after delivered + freeze | PDF + optional email |
| ISSUED | CANCELLED | Finance/Super Admin | Document void; money rows stay |
| any | retry | Worker | Same number, same amounts |

---

## D.6 Rider operational / KYC

| Machine | States | Who | Restriction |
|---|---|---|---|
| Online | OFFLINE ↔ ONLINE | Rider | Approve required; COD suspend does not forbid viewing assigned trip |
| Approval | pending → APPROVED / REJECTED / SUSPENDED | Operations / Super Admin | Audited |
| KYC document | UPLOADED → APPROVED / REJECTED | Operations / Super Admin | |
| COD | CLEAR ↔ SUSPENDED_FOR_COD | System when due crosses threshold | Accept blocked when suspended |

---

## D.7 Customer profile

ACTIVE ↔ DEACTIVATED (customer or Admin support process). Soft delete only. Orders remain.

---

## D.8 Configuration versions

DRAFT → ACTIVE → SUPERSEDED.  
Publish = new version. Never edit ACTIVE/SUPERSEDED in place if orders point at it. Super Admin write for fare, payments, cancellation, office (Master §8.2). Extra-rate and COD threshold follow the same versioning rule (Master §24).

---

## D.9 Document / file

UPLOADED → APPROVED / REJECTED. Virus scan ARCHITECTURE READY.

---

# E. ADMIN CONFIGURATION

Every value that can change **future** money or historical operational calculations must be versioned (Master §24).

| Value / rule | Configurable from Admin? | Hardcoded? | Default | Who writes |
|---|---|---|---|---|
| Vehicle category catalog | YES | NO | Locked master names; IDs not names | Super Admin create |
| Fare: base, per km, minimum, waiting, surge, toll, parking | YES | NO | Admin-set. Demo seeds are **not** a commercial lock | Super Admin publish new version |
| rider_percentage | YES | NO | 85 | Super Admin |
| company_commission_percentage | YES | NO | 15 | Super Admin |
| operational_cost_percentage_of_commission | YES | NO | 50 | Super Admin |
| Enabled payment methods | YES | NO | Cash is MVP in product notes; online on/off **NEEDS DECISION** | Super Admin |
| Cancellation enabled / fee / shares per actor per stage | YES | NO | Fee ₹0; customer table ≠ rider table | Super Admin |
| Company office address / lat / lng | YES | NO | Must not use a permanent hardcoded office as authority | Super Admin |
| COD suspend threshold | YES (versioned) | Default number is FINAL today | ₹100 | Super Admin |
| Resend Case A extra ₹10/km | YES (versioned) | Default FINAL today | ₹10/km | Super Admin |
| Resend Case B ₹10 / ₹8 / ₹2 | YES (versioned) | Default FINAL today | 10 / 8 / 2 | Super Admin |
| Office handover ₹8/km | YES (versioned) | Default FINAL today | ₹8/km | Super Admin |
| GST on fare | NO as a live tax | Locked ₹0 | 0 | Not an Admin tax slider |
| 85/15 base (Trip Fare vs payable) | NO | Locked: Trip Fare | — | Not configurable away |
| Display ID format | NO | Locked `IU-{CITY}-{10 digits}` | — | |
| Max drops | NO | Locked 3 | — | Do not invent extra-stop fee |
| Identity model | NO | Locked | — | |
| COD as negative wallet | NO | Forbidden | — | |

Admin **creates a new version**. Admin does **not** edit yesterday’s version in place.  
Admin money fixes go through **audited adjustment commands**, never by editing a snapshot (Master §11.3).

---

# F. API BLUEPRINT

No API code. One versioned HTTPS API, e.g. `/v1` (Master §33).  
Style is a **TECHNICAL DESIGN OPTION** (resource-oriented JSON).  
Cursor pagination on lists. Every money POST requires an idempotency key.  
Backend validates fare and transitions status.

Exact path catalog is a later API contract phase (Master §33.2). Below are the **required modules and operations** Master already named.

Authz: session decides identity + profile. Then object checks. Never trust client-sent “I am finance” or a client-chosen profile id (Master §32.2).

---

## F.1 `/auth` — OTP, session, logout

| Item | Content |
|---|---|
| Purpose | Authenticate Identity; open a profile session |
| Request | Phone + OTP (Customer/Rider); email + password (Admin); logout |
| Response | Session / tokens with `identity_id`, `active_profile_type`, `profile_id` |
| Auth | Public for start; session for logout |
| Role | Customer/Rider phone OTP; Admin password |
| Validation | Rate-limit phone + IP; hashed OTP; hashed Admin password |
| Logic | One phone → one Identity; attach/create profile for that app only |
| Entities | Identity, OTP Challenge, Session, Profiles |

---

## F.2 `/me` — identity + profiles

| Item | Content |
|---|---|
| Purpose | Read own identity and profiles; update allowed profile fields |
| Request | Name, email (Customer); online flag (Rider) |
| Response | Identity (masked phone), profile(s) |
| Auth | Session |
| Role | Matching profile |
| Validation | Customer email optional until track/invoice; phone not casually edited |
| Entities | Identity, Customer/Rider/Admin Profile |

---

## F.3 `/customer/addresses`

| Item | Content |
|---|---|
| Purpose | Saved addresses |
| Request | Address, lat/lng, zone |
| Response | Address list |
| Auth | Customer profile |
| Entities | Customer Saved Address |

---

## F.4 `/customer/orders` — create, read, cancel, resend

| Item | Content |
|---|---|
| Purpose | Book and manage own trips |
| Create request | Idempotency key; quote id; stops (1 pickup + 1..3 drops); vehicle_category_id; responsibility; plan; discount if a locked rule supplies one |
| Create response | order_id, display_id, fare snapshot, responsibility, plan, status SEARCHING (or waiting payment if online pending) |
| Read | Own orders, cursor page; active filter |
| Cancel request | Idempotency key; reason |
| Resend request | Idempotency key; case determined by whether original trip ended |
| Auth | Customer; own orders only |
| Validation | Backend recomputes fare; responsibility sums; plan sums; max 3 drops |
| Logic | Fare snapshot at confirm; no client 85/15 authority |
| Entities | Order, Stop, Fare Quote/Snapshot, Responsibility, Plan, Status Event, Cancellation/Resend snapshots |

---

## F.5 `/rider/offers` — incoming, accept, reject

| Item | Content |
|---|---|
| Purpose | Show offers; accept/reject |
| Accept request | offer_id; idempotency |
| Accept response | Assigned order or “already accepted” |
| Auth | Rider profile; offered rider only |
| Validation | Online; not COD-suspended; accept lock (Master §31.2) |
| Entities | Order Offer, Order, Status Event, Rider COD Account |

---

## F.6 `/rider/orders/{id}` — status commands

| Item | Content |
|---|---|
| Purpose | Progress trip; cash confirm; receiver unavailable; office drop |
| Request | Command + idempotency + expected from_status |
| Response | New status + events |
| Auth | Assigned rider (or offered for reject) |
| Logic | Compare-and-set status; failed delivery ≠ cancel |
| Entities | Order, Status Event, Failed Delivery, Adjustment, Payment Transaction (cash) |

---

## F.7 `/rider/wallet` — balance, ledger, recharge

| Item | Content |
|---|---|
| Purpose | Available balance, ledger, recharge |
| Recharge request | Amount; idempotency; provider refs when live |
| Response | COD Due after settlement; wallet remainder |
| Auth | Owner; Finance/Super Admin may read |
| Logic | Settle COD first; never negative; cash-trip earning not posted here |
| Entities | Wallet Account/Ledger, COD Account/Ledger, Idempotency |

---

## F.8 `/admin/orders` — search, assign, cancel

| Item | Content |
|---|---|
| Purpose | City ops on the **same** canonical order |
| Request | Filters city/status/time; assign rider_id; cancel reason |
| Response | Same UUID, display id, fare, payers, payments, rider/company, COD, cancel, resend |
| Auth | Admin RBAC |
| Logic | Assign while searching; cancel until terminal; never recompute old money from live settings |
| Entities | Order, Offer, Status Event, Cancellation Snapshot |

---

## F.9 `/admin/settings/fare|payments|cancellation|office`

Also required by Master §24 even if not all listed as URL tokens: COD threshold, extra rates, payment methods.

| Item | Content |
|---|---|
| Purpose | Publish **new** versions |
| Request | Payload + confirm publish |
| Response | New version id; previous ACTIVE → SUPERSEDED |
| Auth | Super Admin write (Master §8.2) |
| Validation | 85+15=100; cancel shares=100; no in-place edit of used versions |
| Entities | All configuration version entities; Audit Log |

---

## F.10 `/admin/riders` — approve, suspend

| Item | Content |
|---|---|
| Purpose | KYC approve/reject; operational suspend; see COD reason |
| Auth | Operations / Super Admin for KYC; Admin RBAC for suspend |
| Entities | Rider Profile, Documents, Audit |

---

## F.11 `/webhooks/payments`

| Item | Content |
|---|---|
| Purpose | Provider updates transaction |
| Request | Signed payload; provider event id |
| Response | 200 idempotent |
| Auth | Provider signature only — not user JWT |
| Logic | Unique event id; PENDING → PAID/FAILED; retry worker if order update fails |
| Entities | Payment Transaction, Idempotency, aggregates |

---

## F.12 `/invoices/{id}`

| Item | Content |
|---|---|
| Purpose | Authorized signed download |
| Auth | Customer (own) or Admin RBAC |
| Logic | Built from snapshots; GST 0; full billed total |
| Entities | Invoice, Stored File, Fare Snapshot, Payment facts |

Generate/retry is idempotent: same order + invoice type → same invoice number and amounts. PDF/email failure does not un-pay.

---

## F.13 Realtime (ARCHITECTURE READY — Master §33.1)

| Channel | Purpose | Auth |
|---|---|---|
| WebSocket or equivalent | Offer + live order + last GPS | Rider publishes while online and on an active trip (or Admin tracking that rider). Customer sees assigned rider on that live order only |
| Push (FCM or equivalent) | Background notifications | Dedupe by notification id |
| Admin dashboard | Short-interval **aggregate** poll | Not “download all orders every second” |

GPS interval 3–8 seconds, throttled. Idle/offline: no high-frequency GPS write. Hot store: Redis last point, TTL ~30s.

---

## F.14 Reporting read APIs (Master §6.2, §37)

| Item | Content |
|---|---|
| Purpose | Totals that Master §37.1 requires |
| Auth | Admin RBAC; finance pages finance-gated |
| Logic | Sum snapshots and ledgers. Never `calculateDistribution(old_order.trip_fare, todays_admin_settings)` |
| Phase 1 | SQL over snapshots + ledgers with date filters |
| Phase 2 | Worker daily counters |
| Phase 3 | Replica / warehouse if analytics hurts bookings |

Must be able to answer: trip counts by status; Trip Fare / discounts / extras; rider earnings; company commission / operations / profit; COD outstanding and settlements; wallet movements; cash vs online collections; Customer vs Receiver paid; resend Case A vs B volume; cancellation fees collected.

---

# G. ROLE & PERMISSION MATRIX

Enforced **on the API**, not only by hiding UI (Master §8).

Marketplace roles are Customer and Rider.  
Staff roles: Super Admin, Sub Admin, Operations, Finance, Support, Manager.  
Mock flags that production must honor: `modules[]`, `financeAccess`, `payoutApprove`.

**Exact capability of Sub Admin vs Support vs Manager beyond the minimum object rules is not fully specified in the Master Architecture.** Those cells are **NEEDS DECISION**. The matrix below uses only locked minimums. Where Master is silent, the cell says **NEEDS DECISION**.

---

## G.1 Marketplace

| Object / action | Customer | Rider |
|---|---|---|
| View own profile | YES | YES |
| Update own name / email / addresses | YES (phone not casual edit) | YES (online, uploads) |
| View other customers’ orders | NO | NO (unless offered or assigned) |
| Create order | YES (own) | NO |
| View order | Own only | Offered or assigned only |
| Update order status | NO (commands only where cancel/resend allowed) | Assigned trip progress + cash confirm + failed delivery |
| Accept / reject offer | NO | YES if online, approved, not COD-suspended |
| Decide accept winner locally | NO | NO |
| Cancel | Only if customer rule enabled at that stage | Only if rider rule enabled at that stage |
| Request resend | YES after failed delivery | NO |
| View 85/15 as authority | NO | May see rider/company lines; cannot change settings |
| View / change Admin configuration | NO | NO |
| View own wallet | Customer wallet ARCHITECTURE READY; not required to book | YES (available + ledger) |
| View own COD Due | NO | YES |
| Recharge rider wallet | NO | YES |
| View own invoices | YES | NO (not required) |
| Rate rider after delivery | YES (1–5 + optional comment) | Rider→customer **NEEDS DECISION** |
| Approve / reject KYC | NO | NO |
| Financial adjustments | NO | NO |
| Delete financial rows | NO | NO |

COD suspend: rider **cannot accept new offers**; can still view assigned trip and wallet. Admin can see the reason (Master §8.3).

A person with both profiles: Customer App acts only as customer; Rider App acts only as rider (Master §7.4).

---

## G.2 Admin — locked minimums (Master §8.2, §11)

| Object / action | Super Admin | Finance | Operations | Other staff (Sub Admin / Support / Manager) |
|---|---|---|---|---|
| View order (RBAC city/ops) | YES | YES if `financeAccess` / module allows | YES if module allows | **NEEDS DECISION** per `modules[]` |
| Assign rider while searching | YES | **NEEDS DECISION** | **NEEDS DECISION** | **NEEDS DECISION** |
| Cancel until terminal | YES | **NEEDS DECISION** | **NEEDS DECISION** | **NEEDS DECISION** |
| Publish fare / payment settings / cancellation / office | YES write | NO (unless Super Admin) | NO | NO |
| Publish COD threshold / extra rates / methods | Implied Super Admin write (same versioning family, Master §24) | NO | NO | NO |
| View wallet | YES | YES | NO unless module | **NEEDS DECISION** |
| Wallet / COD / order financial adjustment | YES via audited command | YES if finance + audit | NO | NO |
| `payoutApprove` | YES | Only if flag true | NO | NO |
| Bank / UPI full reveal | YES | YES + audit | NO (masked) | NO |
| KYC approve / reject | YES | NO | YES | NO |
| Rider approve / reject / suspend | YES | NO | YES (approve) | Suspend **NEEDS DECISION** |
| Audit log read | YES | NO unless Super Admin | NO | NO |
| Audit log write | System only | System only | System only | System only |
| Recalculate old trips from live settings | NO | NO | NO | NO |
| Store secrets in browser | NO | NO | NO | NO |
| Invoice download | YES | YES if finance | **NEEDS DECISION** | **NEEDS DECISION** |
| Reports (snapshot sums) | YES | YES if finance | Ops counts **NEEDS DECISION** | **NEEDS DECISION** |

Admin tokens never grant Customer/Rider APIs and vice versa.

---

# H. FINANCIAL LEDGER / MONEY FLOW

Do not assume accounting entries the Master Architecture did not define (no double-entry chart of accounts, no GST output tax, no invented cash-handling fee).

---

## H.1 Confirmed trip (locked picture)

```text
Customer / Receiver pay the BILL (usually Net Payable)
                │
                ▼
        Fare Snapshot
        Trip Fare = ₹100          ← 85/15 BASE
        Discount  = ₹10
        Bill      = ₹90           ← responsibility sums here
                │
                ▼
        Finance Snapshot (at freeze)
        Rider earning     ₹85     (85% of Trip Fare)
        Company share     ₹15     (15% of Trip Fare)
           ├── Operations ₹7.50   (50% of ₹15)  INTERNAL P&L ONLY
           └── Net profit ₹7.50   (the other 50% of ₹15)
```

Who pays and how they pay **do not change** the ₹85 / ₹15 / ₹7.50 / ₹7.50 split.

Operations is **not** taken from the rider and is **not** a vendor bill.

---

## H.2 Customer / Receiver payment movement

```text
Responsibility (owed)
    → Payment Plan (intention only; not money)
    → Payment Transaction(s)
         ONLINE: PENDING → PAID after provider confirm
         CASH:   PAID when rider/admin confirms collection at delivery
    → Aggregate UNPAID / PARTIALLY_PAID / PAID
    → Invoice shows full bill + Customer Paid + Receiver Paid
```

Online money never becomes PAID in the apps without a provider.  
Receiver online is ARCHITECTURE READY / PAYMENT PROVIDER INTEGRATION PENDING.

---

## H.3 Cash / COD movement (separate from wallet)

```text
Trip Fare ₹100, rider ₹85, company ₹15
Customer pays ₹100 CASH to rider

Physical cash in hand     = ₹100     (operational note; not ledger truth)
Rider cash earning        = ₹85      (physical; NOT wallet credit)
COD Ledger INCREASE       = ₹15      (company share held as cash)
Wallet Ledger             = no row
Wallet balance            = unchanged
```

If cash collected ≤ rider earning: no COD increase. Company may still owe the rider a later digital remainder.

**Do not** run this trip’s ₹85 through the wallet. That would falsely settle this trip’s ₹15 COD Due and invent a digital credit the rider does not have.

---

## H.4 Wallet settlement (digital only)

```text
Eligible DIGITAL inflow (later online earning, cancel-fee rider share, recharge)
    → lock rider finance
    → if COD Due > 0:
         COD Ledger DECREASE (settlement)
         remainder (if any) → Wallet Ledger CREDIT
    → else:
         full amount → Wallet Ledger CREDIT
```

Examples locked in Master:

```text
COD Due ₹60 + recharge ₹100 → COD −₹60, Wallet +₹40
COD Due ₹15 + later online ₹85 → COD −₹15, Wallet +₹70
```

Payout: Wallet Ledger DEBIT after freeze, from available digital balance. Payout does **not** reduce COD Due.

---

## H.5 Cancellation money

```text
Cancellation Snapshot (fee, rider%, company% — not auto 85/15)
    → if fee ₹0: snapshot still written; no 85/15 invented
    → if fee > 0:
         rider share credited immediately (digital)
         then COD settlement if Due > 0
         company share is company money (Master does not define a separate company cash ledger beyond COD/finance snapshots)
```

Do not invent a company bank posting beyond finance snapshot / fee amounts Master named.

---

## H.6 Failed delivery / resend money

```text
Original Finance Snapshot  — UNCHANGED

Office Adjustment          — rider ₹8 × km (not 85/15)

Resend Case A              — new bill: base(at resend) + ₹10/km; then 85/15 on that amount
Resend Case B              — customer ₹10/km; rider ₹8/km; company ₹2/km; not 85/15
```

If Case A is a child order, that child has its own fare / responsibility / finance snapshots. Original rows stay.

---

## H.7 Refund

```text
Original Payment Transaction  — stays
New Payment Transaction       — direction REFUND
Audit Log                     — required
```

Refund-to-wallet only if original method was wallet (Master §W). Customer booking does not auto-debit wallet until decided.

---

## H.8 What is not a money flow in this architecture

- GST on fare (always ₹0)
- Extra multi-stop fee (not invented)
- COD surcharge (not invented)
- Referral ₹200 / ₹50 / ₹150 (dummy; not one program)
- Purchase invoices mixed into the 50% operations allocation
- Negative wallet because of COD

---

# I. AUDIT & HISTORY

## I.1 What must be recorded (Master §29)

| Event | Record |
|---|---|
| Fare version publish | Old active version → new version payload |
| Payment settings publish | Old percents → new percents |
| Cancellation rule publish | Old table → new table |
| Office change | Old address/lat/lng → new |
| COD threshold / extra rates / methods publish | Old → new |
| Wallet Admin adjustment | Old balance / ledger ref → new |
| COD Admin adjustment | Old due → new |
| Order financial adjustment | Reason + amounts |
| Admin permission / role / flags change | Old → new |
| Rider approve / reject / suspend | Old status → new + reason |
| Refund | Original txn + new refund txn |
| Status change | Also Order Status Event (from/to/actor/reason/time) |

## I.2 Required fields on Audit Log

- Who: actor identity + profile + role
- What: action
- Which entity: type + id
- Previous value
- New value
- Timestamp
- Reason / request id where Admin is asked
- IP / user agent where useful

## I.3 History that is not the Audit Log (but is still immutable)

| Store | What it proves |
|---|---|
| Order Status Event | Lifecycle |
| Fare / Finance / Cancel / Resend snapshots | Money used that day |
| Wallet Ledger / COD Ledger | Every rupee of available vs due |
| Payment Transaction | Actual collections and refunds |
| Idempotency Record | First successful side effect |

Never hard-delete financial audit or these history stores.

---

# J. SECURITY

From Master §7, §8, §32, §AA.

## J.1 Authentication

- Customer / Rider: server OTP, `code_hash` only, SMS from server, 30s resend cooldown already in apps
- OTP length, provider, expiry, max attempts, lockout → **NEEDS DECISION**
- Admin: Argon2id (or equivalent) server-side only
- Rate-limit OTP and login by phone + IP
- Session revocation
- Separate tokens per app profile
- Claims: `identity_id` + `active_profile_type` + `profile_id`

## J.2 Authorization

- RBAC for Admin; object checks for orders, wallets, files
- Session loads identity/profile; then check this order / wallet / file
- Never trust client role claims
- Customer cannot do rider work in the Customer app
- Rider cannot do admin work
- Admin tokens never open Customer/Rider APIs

## J.3 Role separation

See §G. One Identity; profiles are authorization, not a second phone.

## J.4 Financial data protection

- TLS in transit
- Wallet / COD / snapshots / payments only via backend transactions
- Idempotency on every money POST
- Webhook signature verification
- Unique provider event id
- Reports from snapshots, not live sliders

## J.5 Sensitive rider / customer information

- Encrypt or tokenize bank and national IDs at rest
- Mask phones in counterpart UIs (Rider already masks customer; Customer must not show raw rider phone in production)
- Raw phone reveal: Admin / RBAC only
- Bank / UPI: owner sees masked; Finance full reveal + audit
- KYC: owner + Operations / Super Admin
- Signed short-lived URLs for invoices and KYC
- Never store card PAN / CVV
- Never store raw OTP
- Never put secrets in git, app binaries, Admin JS, or `000_info.txt`

## J.6 Admin-only operations

- Publish configuration versions
- Assign rider
- Cancel until terminal
- Approve / reject / suspend riders
- Financial adjustments
- Read audit log (Super Admin)
- Payout approve (`payoutApprove`)

## J.7 Audit requirements

See §I. Financial and Admin writes are append-only.

## J.8 Application safety (Master §32.4)

- Parameterized SQL only
- Input validation at API edge
- Fraud watches: many failed OTPs, many unpaid online intents, unusual COD spikes

2FA is optional later (dummy toggle exists). Not required to create schema (Master §AA).

---

# K. IMPLEMENTATION DEPENDENCIES

Derived from Master §5, §6, §34, §39, §45 — not an invented stack.

```text
PostgreSQL foundation
  (Identity, City/Zone, Vehicle Category, constraints, pools)
        ↓
Authentication
  (OTP Challenge, Session, Admin password hash)
        ↓
Profiles + Catalog
  (Customer, Rider, Admin, Saved Address, Vehicle, Driver placeholder)
        ↓
Versioned configuration
  (Fare, Payment settings, Cancellation, Office, COD threshold,
   Extra rates, Payment methods)
        ↓
Order + Stops + Status Events + Idempotency
        ↓
Fare engine (Quote + Fare Snapshot)
        ↓
Payment Responsibility + Plan + Transactions
        ↓
Dispatch / Offers (lock + one winner; algorithm later)
        ↓
Wallet Account + Wallet Ledger
        ↓
COD Account + COD Ledger + settle-first + suspend
        ↓
Finance Snapshot (85/15/50 freeze + reversals)
        ↓
Cancellation Snapshot + Failed Delivery + Office Adjustment + Resend
        ↓
Invoice (after freeze)
        ↓
Documents / object storage (KYC, POD, invoice PDF)
        ↓
Notifications (persist + dedupe)
        ↓
Admin ops APIs + RBAC + Audit
        ↓
Reporting reads (snapshot sums)
        ↓
Workers / Redis / realtime     (ARCHITECTURE READY; not required to start schema)
        ↓
Payment provider adapter       (ARCHITECTURE READY / INTEGRATION PENDING)
```

**Hard dependency rule (Master §6.2, §39):** do not split Order, Wallet, and COD into separate services. They must share transactions.

**Phase 1 can start with API + PostgreSQL only** (Master §5). Redis, object storage, and workers are ARCHITECTURE READY.

---

# L. IMPLEMENTATION PHASES

Aligned with Master §39 and §45. UI in these phases means **wire existing apps to the backend**, not a theme redesign (Master §1, §17 frozen UI).

---

## Phase 0 — Physical schema (next dedicated phase after this blueprint)

| | |
|---|---|
| **Objective** | Create PostgreSQL from Master + this blueprint. No app rewrite required to finish this phase |
| **Modules** | All entities in §B |
| **Database** | Tables, FKs, checks, unique display_id, append-only snapshots/ledgers |
| **API** | None yet |
| **UI** | None |
| **Completion** | Schema review: no single payment row; no COD-as-negative-wallet; finance snapshot not unique-per-order; identity ≠ two phones; GST 0 |

---

## Phase 1 — Modular core (Master §39 Phase 1)

| | |
|---|---|
| **Objective** | One API. Postgres is the writer. Correct money. |
| **Modules** | Auth, Customer, Rider, Admin RBAC, Catalog, Order/status, Fare, Payment (cash + UNPAID online), Wallet, COD, Finance snapshot, Audit, Idempotency |
| **Database** | Phase 0 + connection pool (PgBouncer or equivalent). Workers use a separate pool when added |
| **API** | `/auth`, `/me`, `/customer/*`, `/rider/*`, `/admin/orders`, `/admin/settings/*`, `/admin/riders` |
| **UI** | Replace mock stores incrementally; existing UI/theme stays |
| **Completion** | Customer booking appears as the same order for Rider and Admin. Accept race has one winner. Fare snapshot immutable. Wallet ≥ 0. COD separate. 85/15 on Trip Fare. No faked online PAID |

---

## Phase 2 — Failed delivery, resend, invoices, files

| | |
|---|---|
| **Objective** | Complete locked operational money after the happy path |
| **Modules** | Failed delivery, office, adjustments, resend Case A/B, invoice worker, object storage |
| **Database** | Failed Delivery, Office Version, Adjustment, Resend Snapshot, Invoice, Stored File |
| **API** | Resend, office-drop, `/invoices/{id}`, file signed URLs |
| **UI** | Existing resend / invoice surfaces; PDF is server/worker truth |
| **Completion** | Original fare never overwritten. Case A 85/15; Case B ₹10/₹8/₹2. Invoice number ≠ display id. Retry idempotent |

---

## Phase 3 — Notifications, KYC review, Admin reports

| | |
|---|---|
| **Objective** | Persist inbox; Operations KYC; snapshot-based reports |
| **Modules** | Notification, Documents, Reporting reads |
| **Database** | Notification, Rider/Vehicle Document, indexes in Master §35 |
| **API** | Inbox, KYC review, report reads |
| **UI** | Admin finance/ops pages stop scanning all orders in the browser |
| **Completion** | Reports sum snapshots. Dedupe notifications. Masked phones in counterpart UIs |

---

## Phase 4 — Cache, workers, realtime (Master §39 Phase 2)

| | |
|---|---|
| **Objective** | Take bursty work off the booking transaction |
| **Modules** | Redis GPS/unread/rate-limit; workers for SMS, PDF, webhooks, daily counters; outbox |
| **Database** | Unchanged money model |
| **API** | WebSocket/push ARCHITECTURE READY |
| **UI** | Live offer / last GPS |
| **Completion** | Last GPS in Redis; invoices/SMS not inside accept transaction |

---

## Phase 5 — Payment provider (ARCHITECTURE READY / PENDING)

| | |
|---|---|
| **Objective** | Real ONLINE PAID |
| **Modules** | Payment webhook adapter |
| **Database** | Existing Payment Transaction + unique provider_event_id |
| **API** | `/webhooks/payments` |
| **UI** | No fake success |
| **Completion** | Signature verified; retries idempotent. Vendor and capture moment must be decided first (**NEEDS DECISION**) |

---

## Phase 6 — Read/write split and later growth (Master §39 Phases 3–4)

| | |
|---|---|
| **Objective** | Reports do not stall accept |
| **Modules** | Read replica; optional later notification/GPS/warehouse split **only if measured** |
| **Database** | Partition readiness for orders, status events, payments, wallet ledger, audit |
| **API** | Accept/pay/wallet stay on primary |
| **UI** | Admin analytics on replica |
| **Completion** | No microservice split of Order vs Wallet vs COD |

Do **not** start with microservices. Do **not** shard on day one.

---

# M. OPEN DECISIONS

## NEEDS DECISION

Only items the Master Architecture itself marks as FUTURE BUSINESS DECISION, TECHNICAL DESIGN OPTION (unpicked), or leaves unspecified. No extra questions.

| # | Item | Master reference | Why it is open |
|---|---|---|---|
| 1 | OTP length (4 vs 6), SMS provider, expiry, max attempts, lockout duration | §7.5, §44 | Challenge table can exist without the policy numbers |
| 2 | Session transport (JWT vs cookie) and exact session TTL | §7.6 | TECHNICAL DESIGN OPTION |
| 3 | Money storage: integer minor units vs `numeric(12,2)` | §43 | Pick one at schema time; use everywhere |
| 4 | Extra multi-stop fee | §13, §44 | Max 3 drops locked; no extra fee today. Do not invent |
| 5 | Owner vs hired multi-driver / multi-vehicle fleet | §10.1, §26.3, §44 | `rider_driver` placeholder is enough |
| 6 | Referral / promo program amounts | §V, §44 | Dummy ₹200 / ₹50 / ₹150 must not be merged |
| 7 | Customer wallet min/max top-up, KYC, booking auto-debit | §9.3, §W, §44 | Ledger can exist; booking does not require debit |
| 8 | Online in first production launch vs cash-first | §E, §44 | Transaction model already supports both |
| 9 | Authorize at booking vs capture at delivery | §E, §12.3, §44 | Integration choice |
| 10 | Payment provider vendor | §E, §44 | Adapter, not a fare rule |
| 11 | Rating: rider→customer, edit, public comments | §X, §44 | Persist customer→rider first |
| 12 | Pickup/drop contacts required at booking? | §Z, §13, §44 | Nullable fields ready |
| 13 | SEARCHING TTL / radius / retry / auto-cancel | §N, §14.3, §44 | Keep searching until cancel or Admin assign |
| 14 | Broadcast vs sequential offers; production offer timeout; max concurrent offers | §O, §14.3, §44 | Offer table + lock ready. 27s is dummy |
| 15 | Statutory SAC / GSTIN / CIN / e-invoice / invoice series legal form | §R, §23, §44 | Fare GST is ₹0; do not invent letterhead IDs |
| 16 | Exact RPO / RTO minutes | §38, §44 | PITR is mandatory; minutes are ops policy |
| 17 | Cash collected from whom if payer ≠ booker (pickup sender vs drop receiver vs account holder) | §17.3, §44 | Record `payer_type`. Current language: trip end / delivery |
| 18 | Admin manually assigns a second live trip to one rider | §10.3, §44 | Automatic second trip is forbidden; manual not decided |
| 19 | Close failed delivery without resend (status / fee) | §14.3, §44 | Do not invent a status or fee |
| 20 | Case A / Case B storage: child order vs related record | §21.2–21.3 | TECHNICAL DESIGN OPTION. Money rules stay |
| 21 | Fare quote TTL duration (number) | §15, §B | “Short TTL” locked; minutes not numbered |
| 22 | Notification inbox scoped by identity vs profile | §28 | TECHNICAL DESIGN OPTION |
| 23 | Audit: one log vs two tables with the same shape | §29 | TECHNICAL DESIGN OPTION |
| 24 | Exact Admin `modules[]` catalog and capabilities of Sub Admin / Support / Manager / Operations beyond §8.2 minimums | §8.1–8.2 | Flags exist; full cell-by-cell staff matrix not locked |
| 25 | GPS sample retention days if Postgres breadcrumbs are stored | §P | Legal retain policy not blocking schema |
| 26 | Auth status extra values beyond active/locked/revoked; KYC step list; bank/UPI verification enum | §7, §27 | Master names the concepts, not every enum label |
| 27 | Chat | §Q, §44 | Not V1 |
| 28 | Scheduled booking product | §U, §44 | Nullable `scheduled_at` only |
| 29 | 2FA required or not | §AA | Optional later |

**Do not treat any row above as a reason to delay the physical schema.** Master §44 and the architecture audit say these wait; columns can exist without the missing policy numbers.

**No critical open money rule remains.** Commission base, resend splits, COD, cancellation configurability, company office, payment splitting, and V1 online+cash **model** are locked.

---

# VERIFICATION AGAINST MASTER SECTIONS 1–46

| Master § | Covered in this blueprint | Locked rule changed? |
|---|---|---|
| 1 Purpose | Documentation only; no code | No |
| 2 Status | Implementation pending backend sequenced | No |
| 3 Sources | Master wins; stale leftovers rejected | No |
| 4 Principles | §C, §H | No |
| 5 Overview | Modular API + Postgres; Redis/workers later | No |
| 6 Modules / write owner | §A, §K | No |
| 7 Identity | §B.1–B.6, §J | No |
| 8 RBAC + COD suspend | §G, §B.5 | No |
| 9 Customer | §B.4, §C.10 | No |
| 10 Rider + money split | §B.5, §C.5, §H | No |
| 11 Admin | §E, §G.2 | No |
| 12 Order hub | §B.30 | No |
| 13 Stops | §B.31 | No |
| 14 Status machine | §D.1 | No invented failed-closed status |
| 15 Fare | §C.1 | No |
| 16 Responsibility / plan / aggregate | §C.3, §B.36–B.37 | No |
| 17 Transactions | §B.38, §C.3 | No |
| 18 COD | §C.4, §H.3 | No |
| 19 Wallet | §C.5, §H.4 | No |
| 20 Cancellation | §C.6 | No |
| 21 Failed delivery / resend | §C.12, §H.6 | No |
| 22 Finance snapshot | §C.2, §B.39 | No |
| 23 Invoice | §C.11, §B.44 | No |
| 24 Config versioning | §B.11–B.17, §E | No |
| 25 Office | §B.17 | No |
| 26 Vehicles | §B.10, §B.18–B.19 | No |
| 27 Documents / bank / UPI | §B.20–B.24 | No |
| 28 Notifications | §B.46 | No V1 chat |
| 29 Audit | §I | No |
| 30 Idempotency | §B.48 | No |
| 31 Concurrency | §C.13 | No |
| 32 Security | §J | No |
| 33 API | §F | No code |
| 34 Postgres posture | §B intro | No DDL |
| 35 Indexes | Listed on entities + Master index list | No |
| 36 Integrity | Embedded in constraints | No |
| 37 Reports | §F.14 | No |
| 38 Backup | PITR required; RPO/RTO **NEEDS DECISION** | No invented minutes |
| 39 Scale | §L Phases 1, 4, 6 | No day-1 microservices |
| 40 Evolution | Versioned config + snapshots | No |
| 41 Scenarios | Flows in §C and §H match the 23 pass cases | No |
| 42 Risks | Rejected old `05` / leftover `18` / fake PAID / unique finance snapshot | No |
| 43 Technical decisions | Recorded; unpicked options → NEEDS DECISION | No |
| 44 Future business decisions | §M only | No silent fills |
| 45 Boundaries | This file is documentation only | No |
| 46 Checklist | All 40 checks remain YES in design | No |

**Silent assumptions introduced?** None intended. Staff RBAC cells that Master did not specify are marked **NEEDS DECISION**, not filled with guessed permissions.

---

**End of IMPLEMENTATION BLUEPRINT**

This file does not modify `MASTER_SYSTEM_ARCHITECTURE.md` or any application, database, API, or UI code.

