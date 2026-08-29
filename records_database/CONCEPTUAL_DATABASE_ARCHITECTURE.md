# IDHAR UDHAR — CONCEPTUAL DATABASE ARCHITECTURE

**Type:** Conceptual database design only  
**Date:** 2026-08-22  
**Status:** DESIGN — not implemented  
**Database:** PostgreSQL is the intended system of record. This file does **not** create it.

This document is **Step 2** after `MASTER_SYSTEM_ARCHITECTURE.md`.

```text
Business Rules
      ↓
Master System Architecture
      ↓
CONCEPTUAL DATABASE ARCHITECTURE   ← this file
      ↓
Physical PostgreSQL Schema         ← not this phase
      ↓
Backend / API
      ↓
Application Integration
```

**This phase does not include:** SQL, DDL, `CREATE TABLE`, migrations, Prisma/Django/Sequelize models, APIs, Flutter changes, or Admin/React changes.

**This phase does include:** what facts must exist, which entity owns them, what may change, what must never change, and how those facts relate.

---

## Source-of-truth order

If anything disagrees, higher wins. Nothing in this file invents a commercial fee, GST, extra multi-stop charge, dispatch algorithm, or OTP policy.

| Level | Document |
|---|---|
| 1 | `RULES_BOOK.md` |
| 2 | `18_FINAL_BUSINESS_DECISIONS.md` (V1 PRODUCT RULES CONFIRMED, CONFIRMED FINANCIAL MODEL, D2, FINAL STATUS TABLE rows 5 / 12 / 13) |
| 3 | `19_DATABASE_REQUIREMENTS_FROM_FEATURES.md` (ignore leftover `pending_business_rule` on resend) |
| 4 | `FINAL_MASTER_ANALYSIS.md` |
| 5 | `FINAL_DATABASE_AUDIT.md` |
| 6 | `MASTER_SYSTEM_ARCHITECTURE.md` |
| 7 | `OPEN_QUESTIONS.md` |

**Do not copy as specification:** leftover `18` C / D / L / M money table / status table row 3; `04` / `05` single-payment model; `08` invoice tax 5%; unique `(role, phone)` as two independent logins; timestamp-modulo trip IDs; join-by-vehicle-name.

---

# DATABASE REQUIREMENT AUDIT

Before entities: every production fact the database must preserve.

For each group: **what** must exist, **why**, **who owns it**, **what is historical/immutable**, **what may change**.

---

## A. Identity & Authentication

**WHAT**
- One Identity per physical person.
- Normalized unique phone (10-digit / E.164).
- Optional email, unique when present.
- Authentication status (active / locked / revoked).
- OTP challenge: phone, hashed code, expiry, attempt count, resend cooldown, IP.
- Session: identity, active profile type, profile id, issued/expiry, revocation.

**WHY**
One human may be Customer and Rider on the same mobile. Login belongs to the person, not to a role app.

**WHO OWNS IT**
The person owns the identity. The backend owns OTP hashes and sessions. Admin does not store production passwords in the app.

**HISTORICAL / IMMUTABLE**
- OTP is stored as hash, never plaintext.
- Successful auth events may be audited.
- Do not rewrite old session history; revoke by new state.

**MUTABLE**
- Email (when allowed).
- Auth lock / unlock.
- Session revocation.
- Phone is OTP-verified and is **not** editable on Customer Edit Profile (FINAL). Changing phone later would be a future verified process, not a casual edit.

**WHAT THIS PREVENTS**
Two “people” for one phone. Two OTPs. Broken audit (“who is this number?”).

---

## B. Customer

**WHAT**
- Customer Profile attached to Identity.
- Display name (required).
- Email optional until tracking / invoice continue.
- Status (active / deactivated).
- Default city.
- Invoice email when captured.
- Saved addresses.
- Many orders, including many **active** orders.

**WHY**
Booking, tracking, cancel, resend, and invoices need a stable customer, not a phone string.

**WHO OWNS IT**
The customer owns profile fields they may edit (name, email, saved addresses). The company owns the profile id and order history.

**HISTORICAL / IMMUTABLE**
- Past orders keep the customer profile id forever.
- Name/email at invoice time should be copied onto the invoice so a later profile edit does not rewrite old invoices.

**MUTABLE**
- Name, email, saved addresses, default city, active/deactivated.

**Customer wallet**
Architecture-ready. Not required for V1 booking. Booking does **not** auto-debit wallet until a future business decision.

---

## C. Rider

**WHAT**
- Rider Profile attached to Identity.
- Onboarding / KYC status.
- Approval / reject / suspend.
- Online / offline.
- Home city / zone.
- Optional driver record (V1: same person).
- Vehicle link.
- COD Due status (suspended when due ≥ configured threshold; default ₹100).
- Earning wallet and COD account (separate).

**WHY**
Dispatch, accept, cash collection, wallet, and COD suspension hang off the rider profile, not the login phone.

**WHO OWNS IT**
The rider owns online/offline and document uploads. Operations/Admin owns approval and suspension. The backend owns money ledgers.

**HISTORICAL / IMMUTABLE**
- Approval / suspend decisions are audited.
- Money ledgers are append-only.

**MUTABLE**
- Online/offline.
- Home zone.
- Approval status.
- Vehicle assignment.
- Materialized wallet balance and COD Due (always via ledger, never by silent edit).

**V1 behaviour:** one rider login ≈ one driver ≈ one vehicle.  
**FUTURE BUSINESS DECISION:** hired driver / multi-vehicle fleet.

---

## D. Admin / RBAC

**WHAT**
- Admin Profile attached to a staff Identity (normally email + password).
- Role family: Super Admin, Sub Admin, Operations, Finance, Support, Manager.
- Module permissions, finance access, payout-approve flag.
- Optional city scope later.
- Password hash (server-side only).

**WHY**
Admin may change money-affecting configuration. Those writes must be attributable and permission-checked on the API, not only by hiding React routes.

**WHO OWNS IT**
The company owns Admin profiles. Super Admin owns permission grants.

**HISTORICAL / IMMUTABLE**
- Permission changes go to audit (old value / new value).
- Admin password hashes are secrets, not profile display data.

**MUTABLE**
- Role, modules, finance access, payout approve, city scope, active/disabled.

**Do not invent:** a required product path where one human must be Customer + Rider + Admin.

---

## E. Vehicles / Drivers

**WHAT**
- Vehicle Category master (Bike, Auto, Mini Truck, Tempo, Large Tempo, Truck). Join by id, never by the word “Bike”.
- Scooty/scooter = subtype under Bike, not a separate V1 category unless Admin later creates one.
- Vehicle instance: registration, subtype, assigned rider (nullable), documents.
- Optional Rider Driver record (licence holder). V1: same person as rider.

**WHY**
Fare and dispatch use category. History must remember which category was booked even if Admin later renames it.

**WHO OWNS IT**
Admin owns the category catalog. Rider/Admin own vehicle assignment. Rider owns vehicle documents until Operations reviews them.

**HISTORICAL / IMMUTABLE**
- Orders store `vehicle_category_id` **and** a name snapshot.
- Document review decisions are audited.

**MUTABLE**
- Category active/inactive, catalog name, capacity copy.
- Vehicle assignment, registration updates, document replacement.

**FUTURE BUSINESS DECISION:** owner ≠ hired driver as a product.

---

## F. Orders / Trips

**WHAT**
The central business entity. One trip for Customer, Rider, and Admin.

Must hold:
- Internal UUID (time-sortable).
- Unique display ID `IU-{CITY_CODE}-{10-digit sequence}` (example `IU-AMD-0000010421`).
- Customer profile id (required).
- Rider profile id (null until assigned).
- City.
- Vehicle category id + name snapshot.
- Optional assigned vehicle id.
- Canonical current status.
- Optional `parent_order_id` (resend child).
- Optional `scheduled_at` (nullable; not V1).
- Pointers / copies of confirmed trip fare and net payable (the fare snapshot is the authority).
- Created / updated timestamps.

**WHY**
Three apps must mean the same trip. Phone, name, and “Bike” are not keys.

**WHO OWNS IT**
The customer created it. The backend owns status and money. The assigned rider updates progress. Admin may assign/cancel within rules.

**HISTORICAL / IMMUTABLE**
- Display ID never reused.
- Confirmed trip fare never silently changes.
- Parent/child link never rewritten to hide the first trip.

**MUTABLE**
- Current status (via status events).
- `rider_id` (null → assigned; not casually swapped).
- Assigned vehicle when a rider is accepted.

**One customer may have many running trips.**  
**One rider does not automatically take a second live trip.** Manual Admin second assign is a **FUTURE BUSINESS DECISION**.

---

## G. Stops

**WHAT**
Ordered stop rows on the order. Never one comma-separated destination string.

Each stop:
- Order
- Sequence
- Type: PICKUP or DROP
- Address
- Latitude / longitude
- Zone if known
- Nullable contact name / phone
- Arrival / completion information
- Optional proof-of-delivery file reference

**WHY**
Fare uses total route distance. Riders navigate stop by stop. Failed delivery / resend need a real drop location.

**WHO OWNS IT**
The customer supplies addresses at booking. The backend stores them. The rider records arrival/completion.

**HISTORICAL / IMMUTABLE**
- Sequence and booked location should not be silently rewritten after confirm.
- Distance used for fare is copied onto the fare snapshot.

**MUTABLE**
- Arrival / completion timestamps as the trip progresses.
- Contact fields if later collected.

**CONSTRAINT (conceptual)**
Maximum **1 pickup + 1 to 3 drops**. Sequence unique per order.

**FUTURE BUSINESS DECISION:** whether contacts are required at booking. Extra multi-stop fee is **not** invented.

---

## H. Dispatch / Rider Offers

**WHAT**
- Many offers per order.
- Each offer: order, rider, status (pending / rejected / expired / accepted), timestamps.
- At most **one accepted offer** per order.

**WHY**
Two riders can tap Accept at the same time. The database, not the phone, must pick one winner.

**WHO OWNS IT**
The backend creates offers and records accept/reject. Riders only send commands.

**HISTORICAL / IMMUTABLE**
- Offer outcomes are events. Do not erase a lost accept.
- Repeat accept by the **same** rider is idempotent.

**MUTABLE**
- Offer status pending → accepted / rejected / expired.

**Not designed here:** broadcast vs sequential algorithm, production timeout, search radius. Those are **FUTURE BUSINESS DECISIONS**. The offer structure must exist regardless.

---

## I. Order Status History

**WHAT**
- One **current** canonical status on the order.
- Append-only status events: from, to, actor, actor profile, reason, idempotency reference, timestamp.

**WHY**
Apps may show friendlier words. There is only one machine truth.

**WHO OWNS IT**
Only the backend transitions status.

**HISTORICAL / IMMUTABLE**
Status events are never updated or deleted.

**MUTABLE**
Only the order’s current status field, and only by inserting a new event.

**Do not create** Customer Status / Rider Status / Admin Status as independent database truths.

Canonical statuses to preserve (from the locked machine):

CREATED, SEARCHING, OFFERED, ASSIGNED, EN_ROUTE_PICKUP, ARRIVED_PICKUP, PICKED_UP, IN_TRANSIT, NEAR_DROP, DELIVERY_ATTEMPT, DELIVERED, CANCELLED, RECEIVER_UNAVAILABLE, FAILED_DELIVERY, PARCEL_AT_COMPANY_OFFICE, RESEND_REQUESTED, RESEND_IN_PROGRESS, RESEND_COMPLETED.

Offer reject / timeout is an event, then status returns to SEARCHING.

Closing a failed delivery **without** resend is a **FUTURE BUSINESS DECISION**. Do not invent a status or fee.

---

## J. Fare / Quotes / Fare Snapshots

**WHAT**
- Current fare configuration (Admin vehicle rates), versioned.
- Fare Quote: server-calculated, short TTL, before confirm.
- Fare Snapshot: copy of the accepted quote, written at confirm, immutable.

Snapshot must preserve:
- vehicle category
- distance
- base, per km, distance charge, minimum, waiting, surge, toll, parking
- trip fare
- discount
- rounding
- net payable
- GST = 0
- configuration version
- quoted-at / confirmed-at

**WHY**
Old trips must never depend on today’s Admin rates.

**WHO OWNS IT**
Admin owns future rates. The backend owns quotes and snapshots. The customer sees the quote; the customer does not own the calculation.

**HISTORICAL / IMMUTABLE**
Fare Snapshot is insert-only.

**MUTABLE**
Only the **next** fare configuration version.

**IMPORTANT**
Trip Fare and Net Payable are not the same.

```text
Trip Fare     = ₹100
Discount      = ₹10
Net Payable   = ₹90

85/15 uses ₹100, not ₹90.
Rider = ₹85
Company = ₹15
  Operations = ₹7.50
  Net Profit = ₹7.50
```

---

## K. Payment Responsibility

**WHAT**
One responsibility record per order (or per billed order, including a Case A child):
- Applicable **bill** total (usually fare snapshot net payable; extras only if they belong on **this** bill)
- Customer responsibility
- Receiver responsibility
- Who-pays summary: CUSTOMER / RECEIVER / SPLIT

Constraint: customer + receiver = applicable bill total.

**WHY**
WHO PAYS is a different question from HOW THEY PAY and from what was actually collected.

**WHO OWNS IT**
The customer sets it at confirm. The backend stores and validates it.

**HISTORICAL / IMMUTABLE**
The confirmed split is locked. Do not rewrite it because someone paid late.

**MUTABLE**
Nothing silent. A later extra on **this** bill would be an explicit adjustment plus a new responsibility revision — do not invent extras. Resend Case A belongs on the child bill, not by editing the original.

**Receiver is a payer type, not a user table and not a Receiver app.**

---

## L. Payment Plans

**WHAT**
Intended methods and amounts, separate from responsibility and from actual transactions.

V1 methods: ONLINE, CASH.

Per payer, planned online + planned cash = that payer’s responsibility.

Example:

```text
Total bill = ₹100
Responsibility: Customer ₹50, Receiver ₹50
Plan:
  Customer ₹30 Online + ₹20 Cash
  Receiver ₹50 Cash
```

**WHY**
A plan is intention. It must not mark money PAID.

**WHO OWNS IT**
The customer (and later a receiver payment flow) declares the plan. The backend stores it.

**HISTORICAL / IMMUTABLE**
The confirmed plan is the original intention. Collections do not overwrite it.

**MUTABLE**
Not used as a running balance. Actuals live on transactions.

---

## M. Payment Transactions

**WHAT**
One row per real payment attempt or cash collection:
- Order
- Payer type: CUSTOMER | RECEIVER
- Method: ONLINE | CASH (WALLET later without rewriting history)
- Amount
- Transaction status: PENDING | PAID | FAILED | REFUNDED
- Provider reference
- Idempotency key
- Created by (customer / rider / admin / webhook / system)
- Timestamps

**WHY**
Several payments can exist on one trip. A single `paymentMethod` field is not the model.

**WHO OWNS IT**
Backend + payment provider webhooks + rider/admin cash confirm.

**HISTORICAL / IMMUTABLE**
A PAID or FAILED row is not overwritten. Refund = new row (direction refund).

**MUTABLE**
PENDING → PAID / FAILED by provider or timeout. That is a controlled status change on the same attempt, not a rewrite of amount.

**Aggregate status** (Customer, Receiver, Overall) is **derived** from PAID transactions:

| Status | Meaning |
|---|---|
| UNPAID | Paid = 0 |
| PARTIALLY_PAID | 0 < paid < owed |
| PAID | Paid equals owed after normal rounding |

Overpay is not silent PAID. It needs an adjustment or refund record.

Online PAID requires verified provider confirmation. **Do not fake success.** Provider and capture moment remain **FUTURE BUSINESS DECISIONS**. The transaction model is ready now.

---

## N. Rider Wallet

**WHAT**
- Wallet Account: one per rider, materialized available balance.
- Wallet Ledger: append-only credits and debits.

Example ledger meanings (not a fee list): EARNING (digital), RECHARGE, COD_SETTLEMENT, PAYOUT, CANCELLATION_SHARE, RESEND_EARNING, ADJUSTMENT.

**WHY**
Available money the rider can use or withdraw later. Never a place to store “I owe the company.”

**WHO OWNS IT**
The rider owns the account. Finance/Super Admin may adjust with audit. The backend posts every change.

**HISTORICAL / IMMUTABLE**
Ledger rows are never edited or hard-deleted.

**MUTABLE**
Materialized balance only, and only in the same database transaction as the ledger insert. Balance ≥ 0.

**Cash-trip rider share is physical cash. It is not posted as a wallet earning and must not settle that trip’s own COD Due.**

---

## O. COD Ledger

**WHAT**
- COD Account: one per rider, materialized COD Due ≥ 0.
- COD Ledger: append-only increases (company share held as cash) and decreases (settlements).

Locked cash picture:

```text
Trip Fare ₹100 → Rider ₹85, Company ₹15
Customer pays ₹100 cash

Physical cash = ₹100
Rider earning = ₹85   (physical, not a wallet credit)
COD Due       = ₹15
Wallet        = unchanged (does NOT become −₹15)
```

If cash collected ≤ rider earning: COD Due += ₹0. The platform may still owe the rider a digital remainder later.

**WHY**
The rider is holding company money. That is a debt to the company, not a negative wallet.

**WHO OWNS IT**
The company owns the receivable. The rider must settle it. The backend posts the ledger.

**HISTORICAL / IMMUTABLE**
Ledger rows never edited.

**MUTABLE**
Materialized COD Due only via ledger. Due ≥ 0.

**Settlement sources (digital only):** later online earning, cancellation rider share, wallet recharge, other marked digital inflows.

```text
COD Due ₹60 + recharge ₹100 → settle ₹60, wallet ₹40
COD Due ₹15 + later online earning ₹85 → settle ₹15, wallet ₹70
```

**COD Due ≥ threshold (FINAL default ₹100):** rider cannot accept **new** rides. Existing assigned trip can finish.

---

## P. Finance / 85-15

**WHAT**
- Payment Settings Version: rider %, company %, operations % of commission. Defaults 85 / 15 / 50.
- Finance Snapshot on the order when P&L is frozen (normally DELIVERED; also terminal cancel/fail as needed).

Snapshot preserves:
- Trip Fare (confirmed)
- Rider % / Company % / Operations % of commission
- Rider amount / Company amount / Operations amount / Profit amount
- Payment settings version
- Snapshot kind: ORIGINAL | REVERSAL | ADJUSTMENT_FREEZE
- Frozen-at timestamp

**WHY**
Reports must sum frozen facts. They must never re-run today’s Admin sliders on old trips.

**WHO OWNS IT**
The company / finance module. Not the customer. Not the rider.

**HISTORICAL / IMMUTABLE**
Original snapshot is never updated. Reversal = new row.

**MUTABLE**
Only the next Payment Settings Version.

**Timing (from locked `18` B, not invented):**
- Fare (Trip Fare) is locked at confirm.
- P&L freeze uses the payment-settings version **in force at freeze time**, applied to that locked Trip Fare. It does not re-quote the ride. It does not use settings published **after** freeze.

**Who pays and how they pay do not change this split.**  
Operations is an internal company allocation from the company share. It is **not** a rider deduction and **not** a vendor bill.

---

## Q. Cancellation

**WHAT**
- Cancellation Configuration Version, **separate** for Customer and Rider.
- Per stage: enabled, fee, rider %, company %.
- Default fee ₹0.
- Order Cancellation Snapshot at cancel time, even when fee is ₹0.

Stages used today:
- Before rider accepts
- After rider accepts
- After rider reaches pickup
- After pickup
- During delivery / in transit

**WHY**
Admin may turn fees on later. Yesterday’s ₹0 cancel must stay ₹0.

**WHO OWNS IT**
Admin owns rules. The backend applies the version in force at cancel and writes the snapshot.

**HISTORICAL / IMMUTABLE**
Snapshots and old rule versions.

**MUTABLE**
Only the next published rule version.

**NOT automatically 85/15.** Rider % + Company % = 100.  
Rider share of a fee is credited immediately, then COD settlement runs if digital.

Admin may cancel until a terminal status. That is operational power. A **fee** comes only from a snapshotted versioned rule. Do not invent a separate Admin fee schedule.

If cancelled before trip-fare P&L freeze: do not invent 85/15 earnings. If a freeze already existed and must be undone: insert a reversal finance snapshot.

---

## R. Failed Delivery

**WHAT**
Failed delivery is **not** cancellation.

Store:
- Original order
- Reason (V1: `receiver_unavailable`)
- Office location snapshot (address, lat, lng, office version)
- Office distance km
- Timestamps

**WHY**
The parcel went to the company office. Distance and reason must survive an office move.

**WHO OWNS IT**
The rider reports receiver unavailable. The backend records the event. Admin owns the office.

**HISTORICAL / IMMUTABLE**
The event and the office snapshot used for km.

**MUTABLE**
Nothing about the original fare. Original 85/15 stays.

---

## S. Company Office

**WHAT**
Versioned Admin office: address, latitude, longitude, city, effective dates, created by.

**WHY**
Apps must not keep a hardcoded office as authority. Failed-delivery km uses the office that applied that day.

**WHO OWNS IT**
Admin (Super Admin write).

**HISTORICAL / IMMUTABLE**
Published versions used by events are never edited in place.

**MUTABLE**
Only by publishing a new version.

V1: one active office per launch city (Ahmedabad / `AMD`). More cities = more records later.

---

## T. Resend

**WHAT**
A resend snapshot (and, for Case A, typically a related child order). Never overwrite the original fare or original 85/15.

**Case A — original trip already ended**

```text
Customer pays = rate-sheet base at resend time + (₹10 × km)
That combined amount uses normal 85/15
Example: base ₹100 + 5 km → ₹150; Rider ₹127.50; Company ₹22.50
         then operations/profit from that ₹22.50 using snapshotted 50% rule
```

**Case B — original trip not ended**

```text
Customer pays = ₹10 × km
Rider         = ₹8 × km
Company       = ₹2 × km
Not 85/15
Example: 5 km → customer ₹50, rider ₹40, company ₹10
```

Must preserve: case, distance, base used (Case A), customer amount, rider amount, company amount, rate/settings versions, parent order link.

**WHY**
Resend is new money. The first trip’s memory must stay intact.

**WHO OWNS IT**
The customer requests resend. The backend snapshots rates **at resend time**.

**HISTORICAL / IMMUTABLE**
Resend snapshot. Original fare snapshot.

**MUTABLE**
Resend progress status (requested / in progress / completed) via status events.

**TECHNICAL DESIGN OPTION (recommended conceptual choice, not a new money rule):**
- Case A → child Order with `parent_order_id` (new bill, new fare snapshot, new 85/15).
- Case B → Resend Snapshot on the **same** operational order (trip still live).

Either storage shape is allowed by architecture as long as original snapshots are never overwritten.

---

## U. Invoice

**WHAT**
A financial document, not a reprint of the display ID.

Preserve:
- Unique invoice number (separate series from `IU-AMD-…`)
- Order internal id + display id
- Trip Fare, discount, extras, rounding, billed applicable amount
- Customer paid, Receiver paid
- GST on fare = ₹0
- Payment summary
- Status: draft / issued / cancelled
- Issue timestamp
- Optional PDF file reference
- Emailed-to

**WHY**
Support and the customer need a stable bill. Invoice total is the **full** bill, not one payer’s share.

**WHO OWNS IT**
The company issues it. The customer may download it. A worker generates PDF.

**HISTORICAL / IMMUTABLE**
Issued amounts are copied from snapshots. Retry returns the **same** invoice number and the same amounts.

**MUTABLE**
Status draft → issued → cancelled. Email send flags. PDF file pointer after generation.

**FUTURE BUSINESS DECISION:** SAC, GSTIN, CIN, e-invoice IRN. Do not invent them. Do not treat them as required columns for fare correctness.

Issue after delivered and after P&L freeze for a completed trip. PDF/email failure does not un-pay a payment.

---

## V. Admin Configuration Versions

**WHAT**
Every setting that can change future money or historical operational calculations has:
- Current published version
- Historical superseded versions
- Effective period
- Created by
- Published status (draft / active / superseded)

At minimum:
- Fare rates
- Payment settings (85/15/50)
- Cancellation rules (customer ≠ rider)
- COD threshold (FINAL default ₹100; still version)
- Company office
- Resend rates (FINAL ₹10 / ₹8 / ₹2; still version)
- Office handover rate (FINAL ₹8/km; still version)
- Enabled payment methods

**WHY**
Admin will change tomorrow’s prices. Yesterday’s trips must not move.

**WHO OWNS IT**
Super Admin publishes. System stores versions.

**HISTORICAL / IMMUTABLE**
A published version already pointed to by an order/quote/snapshot is never edited in place.

**MUTABLE**
Drafts. The next published version.

---

## W. Bank / UPI

**WHAT**
- Rider bank account: holder name, masked account, IFSC / bank, encrypted or tokenized secret, verification status.
- Rider UPI: masked VPA, verification status.

**WHY**
Payout destination. Not a wallet balance.

**WHO OWNS IT**
The rider owns the destination. Finance may reveal full details with audit.

**HISTORICAL / IMMUTABLE**
Old payout destinations stay for past payouts (snapshot on the payout, or retain superseded rows).

**MUTABLE**
Current destination. Never log full account numbers. Never store card PAN/CVV (cards are not bank rows).

---

## X. Rider KYC / Documents

**WHAT**
- Document metadata in PostgreSQL: type, status (uploaded / approved / rejected), file reference, reviewer, timestamps.
- Actual file bytes in object storage.
- Vehicle documents follow the same pattern.

**WHY**
Operations must approve riders without stuffing PDFs into money tables.

**WHO OWNS IT**
Rider uploads. Operations/Super Admin reviews.

**HISTORICAL / IMMUTABLE**
Review decisions audited. Do not hard-delete approved KYC metadata needed for compliance without a legal policy.

**MUTABLE**
Status uploaded → approved / rejected. Replacement upload = new document row or new file version, not silent byte overwrite of history.

Customer KYC is **not** required for V1 booking.

---

## Y. Notifications

**WHAT**
- Persisted inbox item: recipient (identity or profile — technical option), title/body, type, order reference if any, read/unread, unique notification id for dedupe.
- Unread counter (can be derived or cached later).

**WHY**
Failed delivery, offers, and COD suspend need a record, not only a disappearing banner.

**WHO OWNS IT**
The system writes. The user marks read.

**HISTORICAL / IMMUTABLE**
The original send is not rewritten.

**MUTABLE**
Read / unread.

No V1 chat. Calls mask counterpart numbers. Full phone is Admin/RBAC only.

---

## Z. Audit

**WHAT**
Append-only who / what / when / which entity / old value / new value / why.

Must cover: Admin settings, fare, cancellation, wallet, COD, finance, refund, rider approval/suspension, permissions, financial adjustments.

**WHY**
A reviewer must reconstruct a money or permission change without guessing.

**WHO OWNS IT**
System write only. Super Admin read.

**HISTORICAL / IMMUTABLE**
Never update. Never hard-delete financial audit.

**MUTABLE**
Nothing.

---

## AA. Idempotency

**WHAT**
A remembered first successful side effect:
- Scope + key
- Actor
- Request hash
- Resulting entity id / response
- Created at

**WHY**
Mobile networks retry. Webhooks retry. Workers retry.

**WHO OWNS IT**
The backend.

**HISTORICAL / IMMUTABLE**
The first record stays. Same key + same request → return original result. Same key + different request → reject.

**MUTABLE**
Optional expiry for non-financial keys later. Money keys should live with the financial retention policy.

Mandatory scopes: create order, accept rider, payment, payment webhook, recharge, COD settlement, cancel, resend, invoice generation, status updates.

---

## AB. Reporting / Reconciliation

**WHAT**
The database must make these comparisons possible without recalculating old money from live Admin settings:

| Compare | Purpose |
|---|---|
| Wallet balance vs wallet ledger | Catch silent balance edits |
| COD Due vs COD ledger | Catch silent due edits |
| Responsibility vs sum of PAID transactions | Catch unpaid / overpay |
| Finance snapshots vs expected distribution from **snapshotted** percents × Trip Fare | Catch freeze bugs |
| Invoice vs fare/finance/payment snapshots | Catch document drift |

**WHY**
Ledgers and snapshots are the memory. Reports sum them.

**WHO OWNS IT**
Finance / system jobs. Admin browser must not download every order to compute Today.

**HISTORICAL / IMMUTABLE**
Source facts. Daily aggregate counters (later) are derived, not a second money truth.

**MUTABLE**
Phase-2 daily counters can be rebuilt from snapshots.

Purchase invoices (real vendor spend) stay **separate** from the 50% operations allocation. Do not design them as part of the trip 85/15.

---

# CONCEPTUAL ENTITY MODEL

Every entity below answers: **what real problem does this solve?**  
If two names would store the same fact, they are one entity.

---

## ENTITY: Identity

**Purpose:** One physical person and one authentication identity.

**Owner:** The person (login). Backend owns secrets.

**Important facts:** identity id; normalized phone; optional email; authentication status.

**Primary identity:** Identity id (UUID).

**Relationships:** 0..1 Customer Profile; 0..1 Rider Profile; 0..1 Admin Profile; many OTP Challenges; many Sessions.

**Mutable:** email (when allowed), lock status.  
**Phone:** not a casual profile edit.

**Soft delete:** allowed (deactivate). Never erase if orders exist — deactivate instead.

**Historical snapshot:** not a money snapshot. Name/email copied onto invoices when issued.

**Rules:**
- Phone unique.
- Email unique when present.
- One identity can have multiple profiles.
- Authentication secrets are not duplicated onto profiles.
- Older notes about unique `(role, phone)` meant “both roles allowed,” **not** two independent logins.

---

## ENTITY: OTP Challenge

**Purpose:** Server-side proof that this phone requested a login code.

**Owner:** Backend.

**Important facts:** identity or phone; code hash (never plaintext); expiry; attempt count; resend cooldown; IP.

**Primary identity:** Challenge id.

**Relationships:** Identity (or phone before identity exists).

**Mutable:** attempt count, consumed flag.  
**Immutable:** the hash of the issued code.

**Soft delete / normal delete:** expired challenges may be removed or retained hashed for rate-limit. Not a financial record.

**Historical snapshot:** no.

**FUTURE BUSINESS DECISION:** 4 vs 6 digits, SMS provider, lifetime, max attempts, lockout duration. Columns can exist without those policy numbers.

---

## ENTITY: Session

**Purpose:** A logged-in period bound to one identity and one active profile.

**Owner:** Backend.

**Important facts:** identity id; active profile type; profile id; issued/expiry; refresh token hash; revoked.

**Primary identity:** Session id.

**Relationships:** Identity; one of the three profiles as the active profile.

**Mutable:** revoked, expiry.  
**Immutable:** which identity it was issued to.

**Delete:** revoke; old sessions may be purged after expiry. Not financial.

**Historical snapshot:** no. Auth audit can record login/logout.

**Why separate from Identity:** one person can have a Customer-app session and a Rider-app session. Tokens must not grant the other app’s APIs.

---

## ENTITY: Customer Profile

**Purpose:** Marketplace-customer role data. Not login secrets.

**Owner:** The customer for editable fields. Company for the id.

**Important facts:** identity id; display name; email; status; default city; invoice email.

**Primary identity:** Customer profile id.

**Relationships:** Identity (required); many Orders; many Saved Addresses; optional Customer Wallet.

**Mutable:** name, email, addresses, status.  
**Immutable:** identity link.

**Soft delete:** deactivate. Do not hard-delete if orders exist.

**Historical snapshot:** invoice copies name/email at issue.

**Rules:** at most one customer profile per identity. Orders use **this** id, not identity id, not phone.

---

## ENTITY: Rider Profile

**Purpose:** Delivery-worker role data. Not login secrets.

**Owner:** Rider for online/offline and uploads. Admin for approval.

**Important facts:** identity id; KYC/approval status; online/offline; home city/zone; COD suspend flag or derived state; vehicle link.

**Primary identity:** Rider profile id.

**Relationships:** Identity; optional Driver; optional Vehicle; Wallet Account; COD Account; many Offers; many assigned Orders; Documents; Bank; UPI.

**Mutable:** online, approval, home zone, vehicle.  
**Immutable:** identity link.

**Soft delete:** deactivate.

**Historical snapshot:** no money snapshot here. Money lives on ledgers.

**Rules:** at most one rider profile per identity. Orders use **this** id when assigned.

**COD Due ≥ threshold ⇒ cannot accept new offers.** Existing trip can finish.

---

## ENTITY: Admin Profile

**Purpose:** Staff control-plane role.

**Owner:** Company.

**Important facts:** identity id; role; module permissions; finance access; payout approve; optional city scope; active.

**Primary identity:** Admin profile id.

**Relationships:** Identity; created configuration versions; audit as actor.

**Mutable:** role and permissions (audited).  
**Immutable:** identity link.

**Soft delete:** disable account.

**Historical snapshot:** permission changes in Audit Log.

**Why not merged with Identity:** staff login is usually email/password; marketplace login is phone OTP. Mixing would put Admin modules on a delivery token.

---

## ENTITY: Customer Saved Address

**Purpose:** Reusable pickup/drop addresses.

**Owner:** Customer.

**Important facts:** customer profile; label; address; lat/lng; zone; default flags.

**Primary identity:** Address id.

**Relationships:** Customer Profile. Orders copy location onto Stops; they do not depend on this row remaining forever.

**Mutable:** yes.  
**Soft delete:** allowed.

**Historical snapshot:** not required. Stop rows hold the booked location.

**Why it exists:** customers save addresses.  
**Why it is not Stop:** a stop belongs to one order.

---

## ENTITY: City

**Purpose:** Launch geography and display-ID city code.

**Owner:** Admin / company.

**Important facts:** city id; name; code (`AMD`); active.

**Primary identity:** City id.

**Relationships:** many Zones; many Orders; Company Office Versions; display-id sequence conceptually scoped here.

**Mutable:** name, active.  
**Code:** treat as stable; do not recycle codes.

**Soft delete:** deactivate.

**Historical snapshot:** display id already embeds the code used at create.

**FINAL:** first launch Ahmedabad. Multi-city schema from day one. Surat dummy is not a second launch city unless later confirmed.

---

## ENTITY: Zone

**Purpose:** Service area under a city (Navrangpura, Satellite, Maninagar, Bopal, Naroda, Gota, SG Highway, …).

**Owner:** Admin.

**Important facts:** city; name; boundary or operational label; active.

**Primary identity:** Zone id.

**Relationships:** City; Rider home zone; Stop zone.

**Mutable:** name, active.  
**Soft delete:** deactivate.

**Why it exists:** availability and ops maps are city/zone, not one national pool.

---

## ENTITY: Vehicle Category

**Purpose:** Sellable vehicle type. Source of truth for booking and fare class.

**Owner:** Admin.

**Important facts:** category id; stable code/name; active; capacity/size copy; not Scooty as its own V1 category.

**Primary identity:** Category id.

**Relationships:** Fare Configuration Versions (rates for this category); Orders (id + name snapshot); Vehicles.

**Mutable:** catalog fields, active.  
**Immutable:** id. Orders keep name snapshot.

**Soft delete:** deactivate. Never delete if orders reference it.

**Why not a string on the order:** “Bike” vs “Scooty” vs “Three Wheeler” already caused mock join loss.

---

## ENTITY: Fare Configuration Version

**Purpose:** A published rate sheet. Current rates for **future** quotes. Old versions remain.

**Owner:** Super Admin publish.

**Important facts:** version; status draft/active/superseded; effective from/until; created by; payload of per-category rates (base, per km, minimum, waiting, surge, toll, parking, and related catalog numbers).

**Primary identity:** Fare configuration version id.

**Relationships:** created by Admin Profile; referenced by Fare Quotes and Fare Snapshots.

**Mutable:** drafts only.  
**Immutable:** once published and used.

**Never delete** published versions.

**Historical snapshot:** this **is** the historical configuration. Orders still **copy** numbers onto Fare Snapshot so they do not depend on this row remaining readable, but they keep the version id for audit.

**Current vs historical:** one entity, many versions. Current = active. Historical = superseded. Do not create two entities.

---

## ENTITY: Payment Settings Version

**Purpose:** Versioned 85 / 15 / 50 (and any later published percents).

**Owner:** Super Admin.

**Important facts:** rider %; company %; operational % of commission; version; effective period; created by; published status.

**Primary identity:** Payment settings version id.

**Relationships:** Finance Snapshots; Admin publisher.

**Mutable:** drafts.  
**Immutable:** published versions used by freezes.

**Never delete.**

**Constraint:** rider % + company % = 100. All three percentages ≥ 0 and ≤ 100.

**Why separate from Fare Configuration:** fare rupees and P&L percents are different facts and can change on different days.

---

## ENTITY: Payment Method Policy Version

**Purpose:** Which methods Admin has enabled (Cash, Online, and later Wallet/UPI/Card/NetBanking labels).

**Owner:** Super Admin.

**Important facts:** enabled methods; version; effective period; created by.

**Primary identity:** Policy version id.

**Relationships:** used at booking validation; not a substitute for actual Payment Transactions.

**Mutable:** drafts / next version.  
**Immutable:** published versions.

**Why separate from Payment Settings:** “cash is on” is not “85/15.” Mixing them would hide a method change inside a P&L version.

**FUTURE BUSINESS DECISION:** cash-only first launch vs online in first production. The policy version can start with Cash enabled.

---

## ENTITY: Cancellation Configuration Version

**Purpose:** Published cancellation table for **one actor** (CUSTOMER or RIDER) for a set of stages.

**Owner:** Super Admin.

**Important facts:** actor; version; effective period; created by; per-stage enabled, fee, rider %, company %.

**Primary identity:** Cancellation configuration version id.

**Relationships:** Cancellation Snapshots; Admin publisher.

**Mutable:** drafts / next version.  
**Immutable:** published versions.

**Never delete** published versions.

**Why one entity (not two tables that are different shapes):** customer and rider are the same shape, different actor. They are **separate version streams**, not one mixed table of “whoever.”

**Constraint:** on every stage row, rider % + company % = 100. Invalid cannot be published.

**Default fee ₹0** until Admin enables a charge.

---

## ENTITY: COD Policy Version

**Purpose:** Version the suspend threshold. FINAL default today is ₹100.

**Owner:** Super Admin.

**Important facts:** threshold amount; version; effective period; created by.

**Primary identity:** COD policy version id.

**Relationships:** used at accept-time check; referenced on suspend audit.

**Mutable:** next version.  
**Immutable:** published versions.

**Why version a “final” ₹100:** so a later change does not pretend old suspends used a different number.

---

## ENTITY: Resend And Office Rate Version

**Purpose:** Version the locked extra per-km rates so a later edit cannot rewrite old failed-delivery money.

**Owner:** Super Admin.

**Important facts (defaults FINAL today):**
- Case A extra: ₹10 / km (plus rate-sheet base; 85/15 applies to the combined customer amount)
- Case B: customer ₹10 / km, rider ₹8 / km, company ₹2 / km
- Office handover: ₹8 / km to rider (not 85/15)

**Primary identity:** Extra rate version id.

**Relationships:** Failed Delivery compensation; Resend Snapshots.

**Mutable:** next version.  
**Immutable:** published versions.

**Why one entity not three:** these numbers are one failed-delivery family. Splitting them does not add a new business meaning. The snapshot still copies the exact numbers used.

---

## ENTITY: Company Office Version

**Purpose:** The Admin-configured office used as failed-delivery destination.

**Owner:** Super Admin.

**Important facts:** address; lat; lng; city; version; effective period; created by; published status.

**Primary identity:** Office version id.

**Relationships:** City; copied onto Failed Delivery.

**Mutable:** next version.  
**Immutable:** published versions already snapshotted onto events.

**Never delete** versions used by failed deliveries.

---

## ENTITY: Vehicle

**Purpose:** A real vehicle that can be assigned to a rider.

**Owner:** Rider / Admin fleet.

**Important facts:** category; registration; subtype (bike/scooter when relevant); assigned rider (nullable); active.

**Primary identity:** Vehicle id.

**Relationships:** Vehicle Category; Rider Profile (nullable); Vehicle Documents; optional link from assigned Order.

**Mutable:** assignment, registration corrections.  
**Soft delete:** deactivate.

**Why rider_id nullable:** Admin may have unassigned vehicles.

---

## ENTITY: Rider Driver

**Purpose:** Licence-holder record so owner ≠ driver can be stored later without redesign.

**Owner:** Rider account.

**Important facts:** rider profile; name; mobile; date of birth; licence reference.

**Primary identity:** Driver id.

**Relationships:** Rider Profile (V1 typically 1:1, same person).

**Mutable:** details until verified.  
**Soft delete:** allowed if unused.

**FUTURE BUSINESS DECISION:** hired drivers / multi-vehicle owner. This entity is a placeholder, not a fleet product.

**Why not merged into Rider Profile:** licence holder can later differ from the login person. Merging would force a redesign.

---

## ENTITY: Stored File

**Purpose:** Metadata for a file in object storage. Not the bytes.

**Owner:** Uploader + system.

**Important facts:** storage key; content type; size; checksum; purpose (KYC, POD, invoice PDF); created by.

**Primary identity:** File id.

**Relationships:** Rider Documents; Vehicle Documents; Invoice PDF; optional stop POD.

**Mutable:** virus-scan status.  
**Immutable:** storage key of an issued invoice PDF.

**Never store file binary in PostgreSQL** unless a later legal hold forces it. There is no such rule today.

**Soft delete:** metadata retained for KYC/invoice; bytes follow storage lifecycle.

---

## ENTITY: Rider Document

**Purpose:** KYC document metadata and review state.

**Owner:** Rider uploads; Operations reviews.

**Important facts:** rider profile; document type; file id; status uploaded/approved/rejected; reviewer; timestamps.

**Primary identity:** Document id.

**Relationships:** Rider Profile; Stored File.

**Mutable:** status.  
**Replacement:** new row or new file, not silent history wipe.

**Soft delete:** hide from rider UI; do not erase approved compliance metadata without policy.

---

## ENTITY: Vehicle Document

**Purpose:** RC / insurance / related vehicle paper metadata.

**Owner:** Rider / Operations.

**Important facts:** vehicle; type; file id; status; reviewer.

**Primary identity:** Vehicle document id.

**Relationships:** Vehicle; Stored File.

Same mutability and delete rules as Rider Document.

---

## ENTITY: Rider Bank Account

**Purpose:** Payout destination.

**Owner:** Rider; Finance reveal.

**Important facts:** rider profile; holder name; masked account; bank/IFSC; encrypted or tokenized secret; status; is current.

**Primary identity:** Bank account id.

**Relationships:** Rider Profile; Payouts (future) snapshot the destination used.

**Mutable:** current flag.  
**Immutable:** do not edit a row that already paid out — supersede it.

**Never delete** rows used for payouts. Mask in normal UI.

---

## ENTITY: Rider UPI

**Purpose:** UPI payout / collection destination.

**Owner:** Rider; Finance reveal.

**Important facts:** rider profile; masked VPA; tokenized value; status; is current.

**Primary identity:** UPI id.

**Relationships:** Rider Profile.

Same protection and delete rules as Bank Account.

---

## ENTITY: Rider Wallet Account

**Purpose:** One available-money account per rider.

**Owner:** Rider; backend posts.

**Important facts:** rider profile; materialized available balance (≥ 0).

**Primary identity:** Wallet account id.

**Relationships:** Rider Profile 1:1; many Wallet Ledger rows.

**Mutable:** balance only via ledger.  
**Never delete.**

**Historical snapshot:** the ledger is the history.

**Why not store COD here:** COD Due is company money held as cash. Putting −₹15 in the wallet lies about available money.

---

## ENTITY: Wallet Ledger

**Purpose:** Append-only source of truth for wallet money.

**Owner:** System.

**Important facts:** wallet account; direction credit/debit; amount; type; related order/payment/recharge; created at; actor.

**Primary identity:** Ledger entry id.

**Relationships:** Wallet Account; optional Order; optional Payment Transaction; optional COD Ledger twin (settlement).

**Immutable.** Never update. Never hard-delete.

**Soft delete:** no.

**Why append-only:** two completions at once must not lose a credit. History can be replayed to rebuild balance.

---

## ENTITY: Rider COD Account

**Purpose:** One COD Due account per rider. Always ≥ 0.

**Owner:** Company receivable; backend posts.

**Important facts:** rider profile; materialized COD Due.

**Primary identity:** COD account id.

**Relationships:** Rider Profile 1:1; many COD Ledger rows.

**Mutable:** due only via ledger.  
**Never delete.**

**Accept check:** if due ≥ active COD Policy threshold → reject new accept.

---

## ENTITY: COD Ledger

**Purpose:** Append-only COD increases and settlements.

**Owner:** System.

**Important facts:** COD account; direction increase/decrease; amount; source (cash company share, recharge settlement, digital earning settlement); related order or recharge; created at.

**Primary identity:** COD ledger entry id.

**Relationships:** COD Account; optional Order; optional Wallet Ledger (settlement twin).

**Immutable.** Never hard-delete.

**Settlement is not a third money entity.** It is a COD Ledger decrease plus, when remainder exists, a Wallet Ledger credit. One business event, two ledger posts, one rider-finance lock.

**Why this prevents the −₹15 bug:** wallet is never asked to represent company debt.

---

## ENTITY: Customer Wallet Account (ARCHITECTURE READY)

**Purpose:** Optional prepaid / promo balance. **Not required for V1 booking.**

**Owner:** Customer; backend if enabled.

**Important facts:** customer profile; available balance ≥ 0.

**Primary identity:** Customer wallet id.

**Relationships:** Customer Profile 1:1 if created; Customer Wallet Ledger.

**FUTURE BUSINESS DECISION:** min/max top-up, KYC, auto-debit at booking.

**Do not invent auto-debit as a V1 rule.**

---

## ENTITY: Customer Wallet Ledger (ARCHITECTURE READY)

**Purpose:** Append-only customer wallet movements if that wallet is enabled.

Same immutability as rider Wallet Ledger. Dummy ₹420 / ₹50 promo are **not** official program amounts.

---

## ENTITY: Order

**Purpose:** The canonical trip. Central business entity.

**Owner:** Customer created it. Backend owns canonical facts.

**Important facts:**
- Internal UUID
- Unique display id
- Customer profile id
- Rider profile id (null until assigned)
- City
- Vehicle category id + name snapshot
- Optional vehicle id
- Canonical current status
- Optional parent order (resend child)
- Optional scheduled_at (not V1)
- Convenience copies of trip fare / payable (authority = Fare Snapshot)
- Created / updated

**Primary identity:** Order UUID. Display id is a unique secondary identity.

**Relationships:** see Relationship Map.

**Mutable:** current status, rider assignment, assigned vehicle.  
**Immutable:** display id, customer, city used in display id, parent link, confirmed fare (via snapshot).

**Never hard-delete.** Soft cancel is a status, not a delete.

**Why UUID + display id:** humans need `IU-AMD-0000010421`. Databases need a key that does not collide and is not a name.

---

## ENTITY: Order Stop

**Purpose:** One pickup or drop on an order, in sequence.

**Owner:** Booked by customer; progress by rider.

**Important facts:** order; sequence; type; address; lat/lng; zone; nullable contacts; arrival/completion; optional POD file.

**Primary identity:** Stop id.

**Relationships:** Order; Zone; optional Stored File.

**Mutable:** arrival/completion, POD.  
**Immutable after confirm:** sequence, type, booked coordinates/address (do not silently rewrite the route).

**Never delete** stops of a confirmed order. Draft booking stops may be replaced before confirm.

**Constraints:** one pickup; 1..3 drops; unique sequence per order.

---

## ENTITY: Order Status Event

**Purpose:** Append-only history of the one canonical status machine.

**Owner:** Backend.

**Important facts:** order; from; to; actor type; actor profile id; reason; idempotency reference; timestamp.

**Primary identity:** Event id.

**Relationships:** Order; Idempotency Record.

**Immutable.** Never delete.

**Why not three status columns:** UI labels can differ. Truth cannot.

---

## ENTITY: Order Offer

**Purpose:** A rider was offered this order. Accept uses a lock.

**Owner:** Backend.

**Important facts:** order; rider profile; status pending/rejected/expired/accepted; created/responded timestamps.

**Primary identity:** Offer id.

**Relationships:** Order; Rider Profile.

**Mutable:** pending → terminal offer status.  
**Immutable:** order + rider pair history.

**Never delete** (needed to explain who lost the race).

**Constraints:** at most one ACCEPTED offer per order. Same rider re-accept is idempotent.

---

## ENTITY: Fare Quote

**Purpose:** Server-calculated price **before** confirm. Short life.

**Owner:** Backend.

**Important facts:** customer; city; category; distance; line numbers; trip fare; discount; net payable; fare config version; expiry.

**Primary identity:** Quote id.

**Relationships:** Customer Profile; Fare Configuration Version; becomes Fare Snapshot if confirmed.

**Mutable:** unused after expiry.  
**Immutable:** numbers of an issued quote until it expires.

**Normal delete:** expired unused quotes may be purged. Confirmed quotes live on as snapshots.

**Why separate from Fare Snapshot:** a quote can die unused. A snapshot is a locked order fact.

---

## ENTITY: Fare Snapshot

**Purpose:** The exact fare used when the customer confirmed.

**Owner:** System, at confirm.

**Important facts:** order; config version; vehicle category + name; distance; stop count; base; per km; distance charge; minimum; waiting; surge; toll; parking; trip fare; discount; rounding; net payable; tax = 0; confirmed at.

**Primary identity:** Fare snapshot id. One per order (a child Case A order has its own).

**Relationships:** Order 1:1; Fare Configuration Version.

**Immutable.** Never delete.

**Historical snapshot:** this **is** the snapshot.

**What it prevents:** Admin publishes new Bike rates; last week’s trip jumps from ₹100 to ₹120.

---

## ENTITY: Payment Responsibility

**Purpose:** Who owes how much of **this bill**.

**Owner:** Set at confirm by customer; stored by backend.

**Important facts:** order; bill total; customer amount; receiver amount; who-pays summary.

**Primary identity:** Responsibility id. One per billed order.

**Relationships:** Order 1:1.

**Immutable after confirm** for that bill.  
**Never delete.**

**Constraint:** customer + receiver = bill total.  
**Bill total is not the 85/15 base.**

**Why separate from transactions:** owed ≠ paid.

---

## ENTITY: Payment Plan

**Purpose:** How each payer **intends** to pay.

**Owner:** Customer at confirm.

**Important facts:** order; customer planned online; customer planned cash; receiver planned online; receiver planned cash.

**Primary identity:** Plan id. One per billed order.

**Relationships:** Order 1:1; Payment Responsibility (same bill).

**Immutable after confirm** as intention.  
**Never delete.**

**Constraint:** per payer, planned methods sum to that payer’s responsibility.

**Why not columns on Responsibility:** “owes ₹50” and “plans ₹30 online + ₹20 cash” are different facts. Merging them brings back a single `paymentMethod`.

**Why not the same as Transactions:** the plan does not become PAID.

V1 methods are ONLINE and CASH. A future WALLET method adds a planned amount without rewriting old plans.

---

## ENTITY: Payment Transaction

**Purpose:** One actual payment attempt or cash collection.

**Owner:** Backend / provider / rider or admin cash confirm.

**Important facts:** order; payer type; method; amount; PENDING|PAID|FAILED|REFUNDED; provider ids; idempotency key; actor; timestamps.

**Primary identity:** Transaction id.

**Relationships:** Order N; optional webhook uniqueness on provider event id.

**Mutable:** only attempt status PENDING → PAID/FAILED.  
**Amount and payer are not rewritten.** Refund = new row.

**Never hard-delete.**

**Do not store UNPAID / PARTIALLY_PAID / PAID on this row as the trip status.** Those are aggregates.

**Never store card PAN/CVV.**

---

## ENTITY: Finance Snapshot

**Purpose:** Frozen P&L for a trip component. Insert-only.

**Owner:** Finance module at freeze.

**Important facts:** order; kind ORIGINAL | REVERSAL | ADJUSTMENT_FREEZE; trip fare; rider %; company %; operations %; rider amount; company amount; operations amount; profit amount; payment settings version; frozen at.

**Primary identity:** Finance snapshot id. **Many per order allowed.**

**Relationships:** Order 1:N; Payment Settings Version.

**Immutable.** Never delete. Never unique-per-order in a way that blocks a reversal row.

**One rupee, one business fact:** cancellation / resend / office extra live on their own snapshots. A finance freeze row may **copy** that fact for P&L reports. Do not store the same rupee as three independent truths.

---

## ENTITY: Cancellation Snapshot

**Purpose:** The exact cancel rule applied to this order.

**Owner:** System, at cancel.

**Important facts:** order; stage; actor; allowed; fee; rider %; company %; rider amount; company amount; rule version; timestamp.

**Primary identity:** Cancellation snapshot id. One cancel event per cancelled order.

**Relationships:** Order; Cancellation Configuration Version.

**Immutable.** Never delete. Write even when fee is ₹0.

**Why separate from Finance Snapshot:** cancel money uses cancel shares, not 85/15.

---

## ENTITY: Failed Delivery

**Purpose:** Receiver unavailable and parcel path to office. Not a cancel.

**Owner:** Rider reports; backend stores.

**Important facts:** order; reason `receiver_unavailable`; office version + address/lat/lng copy; office distance km; timestamps.

**Primary identity:** Failed delivery id. One per such event on the original order.

**Relationships:** Order; Company Office Version; Order Adjustment (office compensation money).

**Immutable** event facts.  
**Never delete.**

**Original 85/15 is not touched.**

---

## ENTITY: Order Adjustment

**Purpose:** One extra money fact that is not the original Trip Fare and not a rewrite of it.

**Owner:** System or audited Admin.

**Important facts:** order; type (OFFICE_COMPENSATION, ADMIN_ADJUSTMENT, OVERPAY_CORRECTION, …); amount; who it is for (rider/company/customer); rate version; distance if relevant; reason; actor; timestamp.

**Primary identity:** Adjustment id.

**Relationships:** Order; optional Failed Delivery; optional Finance Snapshot copy for P&L.

**Immutable.** Never delete. Correction = new adjustment.

**Office compensation:** distance × snapshotted ₹8/km, to the rider, **not** 85/15.

**Why separate from Fare Snapshot:** confirmed Trip Fare must not jump from ₹100 to ₹108 in place.

---

## ENTITY: Resend Snapshot

**Purpose:** Case A or Case B money and linkage. Never overwrites original fare.

**Owner:** System, at resend request / confirm.

**Important facts:** original order; optional child order; case A or B; distance; Case A base fare; customer amount; rider amount; company amount; fare version (Case A); extra-rate version; payment settings version if Case A 85/15; request status.

**Primary identity:** Resend snapshot id.

**Relationships:** original Order; optional child Order; Resend And Office Rate Version.

**Immutable** money fields.  
**Mutable:** progress status only via order status events.  
**Never delete.**

**Recommended shape (technical, not a new fee):**
- Case A: child Order + this snapshot pointing at both.
- Case B: this snapshot on the original Order only.

---

## ENTITY: Invoice

**Purpose:** Issued financial document for a billed order.

**Owner:** Company.

**Important facts:** invoice number; order; status draft/issued/cancelled; issued at; copied trip fare, discount, extras, billed total; customer paid; receiver paid; GST 0; PDF file; emailed to.

**Primary identity:** Invoice id. Invoice number unique secondary.

**Relationships:** Order; Stored File; Invoice Lines.

**Mutable:** status, PDF pointer, email flags.  
**Immutable:** issued amounts and invoice number.

**Never hard-delete issued invoices.** Cancel status exists.

**Retry is idempotent:** same order + invoice type → same number and amounts.

---

## ENTITY: Invoice Line

**Purpose:** Copied display lines (trip fare, discount, rounding, extra locked charges) so the PDF does not recompute from live Admin rates.

**Owner:** Invoice at issue.

**Important facts:** invoice; line type; label; amount.

**Primary identity:** Line id.

**Relationships:** Invoice.

**Immutable** after issue.  
**Never delete** independently of invoice retention.

**If a trip has only the standard fare lines, they can live as fields on Invoice.** Lines exist so extras (office compensation on an internal copy, Case A child extras) are not stuffed into one total with no memory.

Invoice Line is optional when Invoice already stores the standard copied totals. It is **not** a second money truth.

---

## ENTITY: Order Rating

**Purpose:** Customer rates the rider after delivery.

**Owner:** Customer writes; rider profile shows aggregate.

**Important facts:** order; from profile; to profile; stars 1–5; optional comment; created at.

**Primary identity:** Rating id.

**Relationships:** Order; Customer Profile; Rider Profile.

**Mutable:** **FUTURE BUSINESS DECISION** whether a rating can be edited. Until then, treat as insert-once.

**Soft delete:** no public erase of a completed rating without a later policy.

**Constraint:** one rating per order per direction.

**FINAL from current product:** persist customer → rider.  
**FUTURE BUSINESS DECISION:** rider → customer, edit, public comments. Schema may keep a nullable opposite direction without requiring Rider UI.

---

## ENTITY: Notification

**Purpose:** Persisted inbox item so a user can see what happened after the banner is gone.

**Owner:** System writes; user marks read.

**Important facts:** recipient identity or profile; type; title/body; optional order id; unique notification id; read flag; created at.

**Primary identity:** Notification id (also the dedupe id).

**Relationships:** Identity or Profile; optional Order.

**Mutable:** read/unread.  
**Immutable:** original send.

**Soft delete:** user may hide; do not use hide as a money erase.

**TECHNICAL DESIGN OPTION:** scope inbox by identity (one inbox for both apps) or by profile (Customer inbox ≠ Rider inbox). Either works. Profile-scoped is clearer when one human has two jobs.

**No V1 chat entity.**

---

## ENTITY: Audit Log

**Purpose:** Append-only answer to who / what / when / which entity / old / new / why.

**Owner:** System write. Super Admin read.

**Important facts:** actor identity; actor profile; role; action; entity type; entity id; old value; new value; reason; request id; timestamp; IP / user agent when useful.

**Primary identity:** Audit id.

**Relationships:** logical pointer to any entity; not a foreign key that blocks deletes (financial rows are not deleted anyway).

**Immutable.** Never update. Never hard-delete financial audit.

**TECHNICAL DESIGN OPTION:** one log with a category, or two logs (Admin / financial) with the same shape. One log is simpler.

**Must cover:** fare publish, payment settings publish, cancellation publish, office change, wallet adjustment, COD adjustment, order financial adjustment, permission change, rider approve/reject/suspend, refund.

---

## ENTITY: Idempotency Record

**Purpose:** If the same request is sent twice, the money or status operation runs once.

**Owner:** Backend.

**Important facts:** scope; key; actor; request hash; result entity id / result payload; created at.

**Primary identity:** (scope, key) unique.

**Relationships:** the first created Order, Offer accept, Payment, Invoice, etc.

**Immutable** after insert.  
**Same key + same request hash → return original result.**  
**Same key + different request hash → reject.**

**Never hard-delete** records that protect money. Non-money keys may expire later.

**Scopes that must exist:** create order; accept rider; payment create; payment webhook (provider event id); recharge; COD settlement `(rider, source_txn)`; cancel; resend; invoice generate; status update.

---

## ENTITY: Rider Location Sample (ARCHITECTURE READY, not a money entity)

**Purpose:** Optional sampled breadcrumb for later history. Hot last point lives in Redis, not as the system of record.

**Owner:** Assigned rider while online on an active trip.

**Important facts:** rider; order; lat/lng; recorded at.

**Primary identity:** Sample id.

**Relationships:** Rider Profile; Order.

**Mutable:** no. Append-only samples.  
**Normal delete / retain:** later legal retention policy. Not blocking conceptual money design.

**Do not write every GPS ping into PostgreSQL.** Interval 3–8 seconds in Redis is the live design.

---

## Entities deliberately not created

| Tempting name | Why it is not an entity |
|---|---|
| Customer Login + Rider Login | Would invent two people for one phone. Identity already solves this. |
| Receiver Profile / Receiver App user | Receiver is a payer type on the trip. No Receiver application. |
| Customer Status / Rider Status / Admin Status | UI labels only. One canonical status + events. |
| Single Payment row | Cannot express split who-pays / how-they-pay / actuals. |
| Combined Wallet+COD account | Would force negative wallet. |
| CurrentFareConfig + HistoricalFareConfig | Same entity, different version status. |
| COD Settlement table | Settlement is a ledger posting pair, not a third balance. |
| Chat Message | Not V1. |
| Referral / Promo program tables with ₹200 / ₹50 / ₹150 | Dummy amounts are not one program. **FUTURE BUSINESS DECISION.** |
| Purchase Invoice inside 85/15 | Vendor spend is a separate company AP concept. Not trip P&L. |
| Fleet Owner Company | **FUTURE BUSINESS DECISION.** Rider Driver is enough. |
| Failed-closed status entity | Invented. Close-without-resend is a future decision. |

---

# IDENTITY / PROFILE MODEL

```text
IDENTITY  (one person, one login, unique phone)
    │
    ├── CUSTOMER PROFILE   (optional, at most one)
    ├── RIDER PROFILE      (optional, at most one)
    └── ADMIN PROFILE      (optional, staff; not required on marketplace identities)
```

**WHAT:** Phone belongs to Identity. Role data belongs to the profile.  
**WHY:** The same mobile may be Customer and Rider.  
**HOW:** OTP authenticates Identity. The app opens the matching profile. Session claims include identity id + profile type + profile id.  
**PREVENTS:** Duplicate humans, split wallets by accident, “which user_id is this phone?”, Admin modules on a rider token.

Example:

```text
Identity          I-9F2A…     phone +91 98XXXXXX10
Customer Profile  C-…         books trips
Rider Profile     R-…         delivers trips
```

Orders store **C-…** as booker and **R-…** as rider. They never store the phone as a foreign key.

A person with both profiles:

- Customer App → Customer Profile only
- Rider App → Rider Profile only

That is **authorization**, not a second phone number.

Admin is normally a **staff identity** (email + password). Do not invent a rule that one human must or must not be all three.

---

# ORDER AS THE CENTRAL ENTITY

```text
ORDER  (UUID + display IU-AMD-##########)
  ├── Customer Profile          (required)
  ├── Rider Profile             (null until assigned)
  ├── City / Zone (via stops)
  ├── Vehicle Category          (id + name snapshot)
  ├── Vehicle                   (optional, assigned rider vehicle)
  ├── Stops                     (1 pickup + 1..3 drops)
  ├── Offers                    (many; one accepted)
  ├── Status (current) + Status Events
  ├── Fare Quote (before confirm) → Fare Snapshot (at confirm)
  ├── Payment Responsibility
  ├── Payment Plan
  ├── Payment Transactions
  ├── Finance Snapshot(s)
  ├── Cancellation Snapshot     (if cancelled)
  ├── Failed Delivery           (if any)
  ├── Order Adjustment          (office extra, audited fix)
  ├── Resend Snapshot           (if any)
  ├── Child Order               (Case A technical option)
  ├── Invoice
  ├── Rating
  ├── Audit / Idempotency references
```

**Internal UUID:** all foreign keys.  
**Display ID:** humans and support. Unique. Never the only join key.  
**Invoice number:** a third unique series. Never equal to the display ID.

Never join on phone, customer name, or vehicle name.

---

# STOP MODEL

```text
ORDER
  stop sequence 0   PICKUP
  stop sequence 1   DROP
  stop sequence 2   DROP     (optional)
  stop sequence 3   DROP     (optional)
```

Each stop is its own record. Fare distance = sum of ordered legs, copied onto the Fare Snapshot.

**Constraints:**
- Exactly one PICKUP
- At least one DROP, at most three DROPs
- Sequence unique per order
- Contacts nullable until a future decision requires them

**Do not store** `"Ahmedabad, Gandhinagar, Surat"` as one text field.

---

# ORDER STATUS MODEL

```text
ORDER ── current canonical status
ORDER ── * status events (append-only)
```

Each event preserves: from, to, actor, actor profile, reason, idempotency reference, timestamp.

Happy path:

```text
CREATED → SEARCHING → OFFERED → ASSIGNED
→ EN_ROUTE_PICKUP → ARRIVED_PICKUP → PICKED_UP
→ IN_TRANSIT → NEAR_DROP → DELIVERY_ATTEMPT → DELIVERED
```

Failed delivery (not cancel):

```text
DELIVERY_ATTEMPT → RECEIVER_UNAVAILABLE → FAILED_DELIVERY
→ PARCEL_AT_COMPANY_OFFICE → RESEND_REQUESTED
→ RESEND_IN_PROGRESS → RESEND_COMPLETED
```

If Case A is a child order: the original keeps its ended status. The child has its own status. Do not rewrite the original to RESEND_COMPLETED in a way that hides the first trip.

Terminal in the current machine: DELIVERED, CANCELLED, RESEND_COMPLETED.

---

# DISPATCH / OFFER MODEL

```text
One order  →  many rider offers
             →  at most one ACCEPTED
```

**WHAT must be safe:** Rider A and Rider B accept at the same moment.

**HOW (conceptual, not SQL):**

```text
Begin one unit of work
  Lock the order
  If status is not offerable (OFFERED / SEARCHING as allowed) → reject
  If an accepted offer already exists → reject
  If this rider’s COD Due ≥ threshold → reject
  If this rider is offline or not approved → reject
  If this rider already has an automatic second live trip → reject
  Mark this offer ACCEPTED
  Set order.rider_id and status ASSIGNED
  Write status event
End unit of work
```

Second rider gets a clean “already accepted.”  
Same rider retry is idempotent.

**Order locking** means: only one accept (or cancel) can commit at a time on that order.  
**Accepted-offer uniqueness** means: the database will not allow two ACCEPTED offers.  
**Rider availability** means: online + approved + not COD-suspended + no automatic second live trip.  
**COD suspension check** happens **inside** the same accept unit of work, not only on the Rider home screen.

Broadcast vs sequential offer creation is a **future decision**. This model does not need that algorithm to be correct.

Cancel vs accept: lock the order first. Cannot accept a cancelled order. Cannot cancel with the wrong stage snapshot after accept has already committed.

---

# FARE MODEL

```text
Admin Fare Configuration Version   (future rates)
        ↓ used at quote time
Fare Quote                         (TTL)
        ↓ customer confirms
Fare Snapshot                      (immutable for that order)
```

Engine (FINAL, no GST, no invented multi-stop fee):

```text
distance_charge = per_km × total_route_km
trip_fare       = max(initial_minimum, base + distance_charge + waiting + surge + toll + parking)
net_total       = round(trip_fare − discount)
```

85/15 uses **trip_fare**, not net_total.

Later extras (resend, cancel fee, office) are new lines / child bills / adjustments. They do not silently edit Trip Fare from ₹100 to ₹110.

---

# PAYMENT DATABASE MODEL

Three separate concepts — plus a derived aggregate.

## A. Payment Responsibility — who owes

```text
Bill ₹90 (Trip Fare ₹100 − discount ₹10)
Customer ₹50
Receiver ₹40   ← invalid if they do not sum to ₹90
```

## B. Payment Plan — how they intend to pay

```text
Customer ₹30 Online + ₹20 Cash
Receiver ₹40 Cash
```

## C. Payment Transactions — what actually happened

```text
Txn 1  Customer ONLINE  ₹30  PENDING → PAID (provider)
Txn 2  Customer CASH    ₹20  PAID (rider confirm)
Txn 3  Receiver CASH    ₹40  still missing → overall PARTIALLY_PAID
```

**WHY they are separate**

| Concept | Question | If mixed with the others |
|---|---|---|
| Responsibility | Who should pay? | A late cash collection would look like the split changed |
| Plan | How did they intend to pay? | Intention would be mistaken for money received |
| Transaction | What moved? | One `paymentMethod` cannot hold three real payments |
| Aggregate | Is the bill finished? | A single PENDING row would be labelled PARTIALLY_PAID |

**Aggregate** UNPAID / PARTIALLY_PAID / PAID is computed from **PAID** transactions vs responsibility. It is not stored as the only payment row.

Invoice total stays the full bill. Customer Paid and Receiver Paid are separate figures.

---

# COD + WALLET DATABASE MODEL

```text
Rider Profile
  ├── Wallet Account  →  Wallet Ledger
  └── COD Account     →  COD Ledger
```

These are **two books**, not two names for one number.

## Locked cash trip

```text
Trip Fare ₹100
Rider earning ₹85
Company ₹15  (operations ₹7.50 + profit ₹7.50 live inside that ₹15)

Customer pays ₹100 cash
```

Ledger picture:

```text
Wallet Ledger     : no row for this cash earning
COD Ledger        : +₹15  (company share held as cash)
Wallet balance    : unchanged
COD Due           : ₹15
Physical cash     : ₹100 in the rider’s hand
```

**WHAT:** The rider holds ₹100. ₹85 is theirs. ₹15 is the company’s.  
**WHY:** Available wallet is money they can spend or withdraw. They cannot spend the company’s ₹15.  
**HOW:** Increase COD Due. Do not post −₹15 to wallet. Do not post +₹85 to wallet for this cash trip.  
**PREVENTS:** Wallet showing −₹15, and a later false “settlement” of this trip against itself.

## Later digital earning (settle COD first)

```text
COD Due ₹15
Online trip rider share ₹85  (digital, eligible)

In one rider-finance lock:
  COD Ledger     −₹15  settlement
  Wallet Ledger  +₹70  remaining earning
Result:
  COD Due = ₹0
  Wallet  = previous + ₹70
```

## Recharge

```text
COD Due ₹60
Recharge ₹100

COD Ledger    −₹60
Wallet Ledger +₹40
```

## Eligible earning vs cash earning

| Inflow | Goes to wallet first? | Settles COD? |
|---|---|---|
| Cash collected on a trip | No. Physical. | No. That trip’s company share **creates** COD Due. |
| Later online / digital earning | After COD | Yes |
| Rider cancel-fee share (digital) | After COD | Yes |
| Wallet recharge | After COD | Yes |

## Payout

Payout debits **Wallet** only, and only if available balance covers it.  
Payout does **not** reduce COD Due.  
If COD Due ≥ threshold, accept is blocked; payout rules stay a finance operation on wallet, not a mixing of ledgers.

## Suspend

```text
If COD Due ≥ active COD Policy threshold (default ₹100)
  → rider cannot accept NEW offers
  → existing assigned trip can finish
```

---

# FINANCE MODEL

85/15 applies to **confirmed Trip Fare**.

```text
Trip Fare ₹100
Rider 85% = ₹85
Company 15% = ₹15
  Operations 50% of ₹15 = ₹7.50
  Net Profit 50% of ₹15 = ₹7.50
```

Preserve on Finance Snapshot: trip fare, rider %, company %, operations %, rider amount, company amount, operations amount, profit amount, payment settings version.

**Immutable.** Reversal = new record.

Who pays and how they pay do not change these numbers.

Operations is not a rider deduction and not a vendor bill.

---

# CANCELLATION MODEL

```text
Cancellation Configuration Version (CUSTOMER stream)
Cancellation Configuration Version (RIDER stream)
        ↓ used at cancel time
Cancellation Snapshot (even if fee = ₹0)
```

Old cancel records never change when Admin publishes version N+1.

---

# FAILED DELIVERY + OFFICE + RESEND

```text
Failed Delivery          (reason, office copy, km)
Company Office Version   (Admin location)
Order Adjustment         (₹8/km rider; not 85/15)
Resend Snapshot          (Case A or Case B amounts + versions)
Optional child Order     (Case A)
```

Failed delivery ≠ cancellation.  
Do not overwrite original fare.

---

# INVOICE MODEL

Invoice is separate from Order.  
Invoice number ≠ display ID.  
Built from snapshots. Never rebuilt from today’s Admin configuration.  
GST on fare = ₹0.  
Full billed total, plus Customer Paid and Receiver Paid.

---

# ADMIN CONFIGURATION VERSIONING

Pattern for every money-affecting setting:

```text
version
status (draft / active / superseded)
effective_from
effective_until (optional)
created_by
created_at
payload
```

| Configuration | Current | Historical | Why versioned |
|---|---|---|---|
| Fare rates | Active Fare Configuration Version | Superseded versions | Old Trip Fare stays |
| Payment settings 85/15/50 | Active Payment Settings Version | Superseded | Old P&L stays |
| Cancellation rules | Active version per actor | Superseded | Old fee/shares stay |
| COD threshold | Active COD Policy Version | Superseded | Old suspends stay explainable |
| Company office | Active office per city | Superseded | Old km / ₹8 stay |
| Resend + office rates | Active extra-rate version | Superseded | Old ₹10/₹8/₹2/₹8 stay |
| Enabled payment methods | Active method policy | Superseded | Old bookings stay valid under the policy they used |

Published configuration already used by an order is **never edited in place**.

---

# KYC / DOCUMENTS / BANK / UPI

```text
PostgreSQL: metadata + status + masked display + token/encrypted pointer
Object storage: file bytes
```

Sensitive values are masked in normal UI. Full reveal is Finance/RBAC + audit.

---

# AUDIT MODEL

Append-only. Never hard-delete financial audit.

Answers: WHO, WHAT, WHEN, WHICH ENTITY, OLD VALUE, NEW VALUE, WHY.

---

# IDEMPOTENCY MODEL

```text
Same scope + key + same request  → original result
Same scope + key + different request → reject
```

Protects: create order, accept, payment, webhook, recharge, COD settlement, cancel, resend, invoice, status updates.

---

# DELETE POLICY

| Class | Entities | Reasoning |
|---|---|---|
| **1. Never hard-delete** | Order, Stop (confirmed), Status Event, Offer, Fare Snapshot, Payment Responsibility, Payment Plan, Payment Transaction, Finance Snapshot, Cancellation Snapshot, Failed Delivery, Resend Snapshot, Order Adjustment, Invoice (issued), Wallet Ledger, COD Ledger, Wallet/COD Accounts, Audit Log, money Idempotency Records, published Config Versions used by orders | These are financial or legal memory. Erasing them rewrites history. |
| **2. Soft delete / deactivate** | Identity, Profiles, Saved Address, City, Zone, Vehicle Category, Vehicle, Documents (hide), Bank/UPI (supersede), Notification (hide), Admin Profile | The person or catalog item may leave, but old orders still point at the id. |
| **3. Normal delete allowed** | Expired unused Fare Quotes, expired OTP Challenges, revoked expired Sessions, unused draft config versions never published, unused draft invoice never issued | No settled money depends on them. |

Financial facts and historical snapshots are never hard-deleted.

---

# RELATIONSHIP MAP

```text
Identity
  │
  ├── Customer Profile
  │     ├── Saved Addresses
  │     ├── (optional) Customer Wallet → Customer Wallet Ledger
  │     └── Orders (booked)
  │
  ├── Rider Profile
  │     ├── Rider Driver (optional)
  │     ├── Vehicle ── Vehicle Documents
  │     ├── Rider Documents ── Stored File
  │     ├── Bank Account
  │     ├── UPI
  │     ├── Wallet Account ── Wallet Ledger
  │     ├── COD Account ── COD Ledger
  │     ├── Offers
  │     └── Orders (assigned)
  │
  └── Admin Profile
        ├── publishes Fare / Payment / Cancel / Office / COD / Extra-rate / Method versions
        └── appears on Audit Log as actor

City ── Zones
City ── Company Office Versions
City ── Orders (display id city code)
Vehicle Category ── Fare Configuration Version (rates)
Vehicle Category ── Vehicles
Vehicle Category ── Orders (id + name snapshot)
```

Order expansion:

```text
Order
  ├── Customer Profile
  ├── Rider Profile (nullable)
  ├── City
  ├── Vehicle Category (+ name snapshot)
  ├── Vehicle (optional)
  ├── Stops (1 pickup + 1..3 drops)
  ├── Offers (*)
  ├── Status Events (*)
  ├── Fare Snapshot (1)
  ├── Payment Responsibility (1)
  ├── Payment Plan (1)
  ├── Payment Transactions (*)
  ├── Finance Snapshots (1..*)
  ├── Cancellation Snapshot (0..1)
  ├── Failed Delivery (0..1)
  ├── Order Adjustments (*)
  ├── Resend Snapshot (0..1)
  ├── parent Order / child Order (Case A)
  ├── Invoice (0..1 issued)
  ├── Rating (0..1 customer→rider)
  └── Idempotency / Audit references
```

Money chain (one trip):

```text
Fare Snapshot (Trip Fare locked)
  → Payment Responsibility (who owes the bill)
  → Payment Plan (how they intend)
  → Payment Transactions (what was paid)
  → Finance Snapshot (85/15 on Trip Fare; ops/profit from company share)
  → Wallet Ledger + COD Ledger (only the correct digital/cash posts)
  → Invoice (full bill, separate paid lines)
```

---

# CARDINALITY

| Relationship | Cardinality |
|---|---|
| Identity → Customer Profile | 1 : 0..1 |
| Identity → Rider Profile | 1 : 0..1 |
| Identity → Admin Profile | 1 : 0..1 |
| Identity → OTP Challenge | 1 : N |
| Identity → Session | 1 : N |
| Customer Profile → Saved Address | 1 : N |
| Customer Profile → Orders | 1 : N |
| Customer Profile → Customer Wallet | 1 : 0..1 |
| Customer Wallet → Customer Wallet Ledger | 1 : N |
| Rider Profile → Driver | 1 : 0..1 |
| Rider Profile → Vehicle (V1 typical) | 1 : 0..1 (schema allows Admin unassigned vehicles; a vehicle has 0..1 rider) |
| Vehicle → Rider Profile | N : 0..1 |
| Rider Profile → Rider Document | 1 : N |
| Vehicle → Vehicle Document | 1 : N |
| Rider Profile → Bank Account | 1 : N (one current) |
| Rider Profile → UPI | 1 : N (one current) |
| Rider Profile → Wallet Account | 1 : 1 |
| Wallet Account → Wallet Ledger | 1 : N |
| Rider Profile → COD Account | 1 : 1 |
| COD Account → COD Ledger | 1 : N |
| Rider Profile → Offers | 1 : N |
| Rider Profile → assigned Orders | 1 : N |
| City → Zone | 1 : N |
| City → Company Office Version | 1 : N |
| City → Order | 1 : N |
| Vehicle Category → Vehicle | 1 : N |
| Vehicle Category → Order | 1 : N |
| Admin Profile → published config versions | 1 : N |
| Fare Configuration Version → Quotes / Snapshots | 1 : N |
| Payment Settings Version → Finance Snapshots | 1 : N |
| Cancellation Configuration Version → Cancellation Snapshots | 1 : N |
| Order → Stops | 1 : N (2..4 rows) |
| Order → Status Events | 1 : N |
| Order → Offers | 1 : N |
| Order → accepted Offer | 1 : 0..1 |
| Order → Fare Quote used | 1 : 0..1 |
| Order → Fare Snapshot | 1 : 1 after confirm |
| Order → Payment Responsibility | 1 : 1 after confirm |
| Order → Payment Plan | 1 : 1 after confirm |
| Order → Payment Transactions | 1 : N |
| Order → Finance Snapshots | 1 : N |
| Order → Cancellation Snapshot | 1 : 0..1 |
| Order → Failed Delivery | 1 : 0..1 |
| Order → Order Adjustments | 1 : N |
| Order → Resend Snapshot | 1 : 0..1 |
| Order → child Orders | 1 : 0..N (typically 0..1 Case A) |
| Child Order → parent Order | N : 0..1 |
| Order → Invoice | 1 : 0..1 issued (retry returns same) |
| Invoice → Invoice Lines | 1 : N |
| Order → Rating (per direction) | 1 : 0..1 |
| Order → Stored File (POD) | via Stop 0..N |
| Document / Invoice → Stored File | N : 1 |
| Rider / Admin → Notifications | 1 : N |
| Any entity → Audit Log | 1 : N |
| Scope+key → Idempotency Record | 1 : 1 |

There is **no N:N** marketplace join that needs a separate “customer_rider” table. The Order is the join.

---

# IMMUTABILITY MAP

| Entity | Mutable? | Historical Snapshot? | Why |
|---|---|---|---|
| Identity | Limited | No | Phone is login; deactivate instead of rewrite history |
| OTP Challenge | Attempts only | No | Secret, short-lived |
| Session | Revoke | No | Auth, not money |
| Customer / Rider / Admin Profile | Yes (non-money) | Invoice copies name/email | Role data changes; old trips keep profile id |
| Saved Address | Yes | No | Stops hold booked location |
| City / Zone / Vehicle Category | Soft | Name snapshot on order | Catalog can be renamed |
| Vehicle / Driver | Yes | No | Assignment changes |
| Fare Configuration Version | Draft only | Yes (the version itself) | Future rates |
| Payment Settings Version | Draft only | Yes | Future 85/15 |
| Payment Method Policy Version | Draft only | Yes | Methods on/off |
| Cancellation Configuration Version | Draft only | Yes | Future fees |
| COD Policy Version | Draft only | Yes | Threshold history |
| Resend And Office Rate Version | Draft only | Yes | Extra ₹/km history |
| Company Office Version | Draft only | Yes | Copied onto failed delivery |
| Rider Document / Vehicle Document | Status | Audit of review | KYC workflow |
| Stored File | Scan status | Invoice PDF frozen | Bytes in object storage |
| Bank / UPI | Supersede current | Snapshot on payout | Masked secrets |
| Rider Wallet Account | Balance via ledger | Ledger is history | Fast read only |
| Wallet Ledger | **No** | **Yes** | Money fact |
| Rider COD Account | Due via ledger | Ledger is history | Fast read + suspend check |
| COD Ledger | **No** | **Yes** | Money fact |
| Order | Status / rider | Display id frozen | Hub row |
| Order Stop | Arrival only | Booked location frozen | Route memory |
| Order Status Event | **No** | **Yes** | History |
| Order Offer | Pending → terminal | Outcome kept | Accept race |
| Fare Quote | Expires | Becomes snapshot if used | Pre-confirm |
| Fare Snapshot | **No** | **Yes** | Locked Trip Fare |
| Payment Responsibility | **No** after confirm | **Yes** | Who owed |
| Payment Plan | **No** after confirm | **Yes** | Intention |
| Payment Transaction | Status of attempt only | **Yes** | Actual money |
| Finance Snapshot | **No** | **Yes** | P&L fact |
| Cancellation Snapshot | **No** | **Yes** | Fee/shares used |
| Failed Delivery | **No** | **Yes** | Office/km |
| Order Adjustment | **No** | **Yes** | Extra money fact |
| Resend Snapshot | Progress via status only | **Yes** | Case A/B amounts |
| Invoice | Status / PDF / email | Amounts frozen | Document |
| Invoice Line | **No** after issue | **Yes** | Copied lines |
| Order Rating | Future decision | Insert-once until decided | One per direction |
| Notification | Read flag | Body frozen | Inbox |
| Audit Log | **No** | **Yes** | Who/what/old/new |
| Idempotency Record | **No** | **Yes** | First side effect |
| Rider Location Sample | **No** | Optional retain | Not money |

---

# CONSTRAINTS — CONCEPTUAL ONLY

No SQL. These are rules the future schema must make hard to violate.

| Constraint | Why it matters |
|---|---|
| Identity phone unique | One login person |
| Identity email unique when present | One inbox / recovery target |
| At most one Customer / Rider / Admin profile per identity | No duplicate roles |
| Order display id unique globally | Three apps show the same human id |
| Invoice number unique | Documents cannot collide |
| Order customer_id is Customer Profile, never Identity or phone | Same human can also be the rider |
| Order rider_id is Rider Profile or null | Same reason |
| Unique stop sequence per order | Route order is defined |
| Maximum 3 drop stops; exactly 1 pickup | Locked booking rule |
| One accepted offer per order | Two riders cannot both win |
| Fare snapshot exists before the trip is money-binding | Searching without a locked fare is unsafe |
| Customer responsibility + Receiver responsibility = applicable **bill** total | Invalid ₹60+₹30 on a ₹100 bill |
| Per payer, planned methods sum to that payer’s responsibility | Plan cannot invent a different bill |
| Aggregate PAID only when sum(PAID txns) equals owed after rounding | Silent overpay |
| Online PAID only with provider confirmation | Fake success |
| Unique provider webhook event | Double pay |
| Unique idempotency key per scope | Double order / double accept / double credit |
| Payment settings rider % + company % = 100 | Invalid 85/15 publish |
| All payment-setting percents between 0 and 100 | Same |
| Cancellation rider % + company % = 100 | Invalid cancel publish |
| Wallet available balance ≥ 0 | Negative wallet forbidden |
| COD Due ≥ 0 | Due is not a credit |
| Wallet change happens with a ledger row | Silent balance edit |
| COD change happens with a COD ledger row | Silent due edit |
| At most one ORIGINAL finance snapshot per trip-fare component | History stays one story; reversals are extra rows |
| Published config version used by an order is not edited in place | Old money stays |
| GST on fare snapshot and invoice = 0 | Locked fare tax |

---

# INDEX REQUIREMENTS — CONCEPTUAL ONLY

No actual indexes. These are query patterns the physical schema must support.

| Query pattern | What the index supports |
|---|---|
| Customer order history | This customer’s orders newest first |
| Customer active trips | This customer + non-terminal status (many actives allowed) |
| Rider active / history | This rider + status + time |
| Rider incoming offers | This rider + pending offers |
| Admin city operations | This city + status + time |
| Display ID lookup | Support types `IU-AMD-0000010421` |
| Order offers | All offers for this order; winner check |
| Payment transactions by order | Responsibility vs paid reconciliation |
| Unique provider event | Webhook retry |
| Wallet ledger by account + time | Rider statement |
| COD ledger by account + time | Due statement |
| COD suspended riders | Riders whose due ≥ threshold (or a stored suspend flag kept in sync) |
| Invoice number lookup | Download / support |
| Invoice by order | Idempotent generate |
| Audit by entity | Who changed this fare version / this wallet |
| Idempotency by scope + key | Retry lookup |
| Status events by order + time | Timeline |
| Failed delivery / resend by order | Office and Case A/B retrieval |
| Unique accepted offer per order | Accept race |

Use time + id cursors for lists. Do not plan deep `OFFSET` pages as the long-term pattern.

---

# SCALABILITY

Design for a future 10M+ users. **Do not shard on day one. Do not create microservices for this model.**

The conceptual model assumes:

- PostgreSQL as system of record
- Real transactions (accept + COD check + status in one unit of work)
- Connection pooling
- Read replicas later (Admin reports / history)
- Partitioning later (by time) for huge append-only tables
- Redis later (last GPS, unread, rate limit, short cache)
- Workers later (SMS, invoice PDF, webhooks, daily totals)

| Data likely to become very large | Why | Why append-only helps |
|---|---|---|
| Orders | Every booking | Old months can be partitioned; current status stays on the hub row |
| Status Events | Several per order | Insert-only; never updated; easy to partition by time |
| Payment Transactions | Several per order | Insert-only attempts; webhooks add rows, not rewrites |
| Wallet Ledger | Every earning/recharge/payout | Balance can be materialized; history is replayable |
| COD Ledger | Every cash company share and settlement | Same |
| Audit Logs | Every Admin/money write | Never updated; archive by time |

Append-only means yesterday’s page of rows is frozen. Partitioning later does not require rewriting money logic.

Keep Order + Wallet + COD on the **same** primary database for V1. Splitting them early creates split-brain money.

---

# RECONCILIATION

| Compare | What a mismatch catches |
|---|---|
| Wallet balance vs sum(Wallet Ledger) | Someone edited the balance without a ledger row, or a posting failed halfway |
| COD Due vs sum(COD Ledger) | Same for company debt |
| Payment Responsibility vs sum(PAID transactions) by payer | Under-collection, over-collection, or a PAID mark without a row |
| Finance Snapshot vs snapshotted percents × confirmed Trip Fare | Freeze coded the wrong 85/15, or used discounted ₹90 by mistake |
| Invoice vs Fare Snapshot + extras + paid totals | PDF shows ₹50 as “total” on a ₹100 bill, or today’s rates leaked in |
| Office Adjustment vs distance × snapshotted ₹8 | Wrong km or live rate used |
| Resend Snapshot vs Case A/B formulas and versions | Case B run through 85/15, or original fare overwritten |
| Cancellation Snapshot vs rule version | Fee taken from a later Admin table |

Reconciliation **never** means: run `calculateDistribution(old_trip_fare, todays_admin_settings)`.

---

# DATABASE ARCHITECTURE AUDIT

Reviewed against, in order: `RULES_BOOK.md` → `18` confirmed / D2 / status table 5, 12, 13 → `19` (ignore leftover pending resend split) → `FINAL_MASTER_ANALYSIS.md` → `FINAL_DATABASE_AUDIT.md` → `MASTER_SYSTEM_ARCHITECTURE.md` → `OPEN_QUESTIONS.md`.

Stale leftovers were not treated as rules.

| Area | Status | Finding |
|---|---|---|
| Identity vs two logins | PASS | One Identity, optional Customer + Rider profiles. Older `(role, phone)` uniqueness is treated as “both roles allowed,” not two humans. |
| Order hub + UUID + display id | PASS | Internal UUID + unique `IU-{CITY}-{10 digits}`. Invoice number is a separate series. |
| Stops | PASS | Ordered rows; max 3 drops; no comma-separated destination. |
| Canonical status + history | PASS | One current status + append-only events. No per-app status tables. |
| Fare quote vs snapshot | PASS | Quote TTL; snapshot at confirm copies rates. Trip Fare ≠ Net Payable. |
| 85/15 base | PASS | Confirmed Trip Fare. Discount does not reduce rider share. Operations from company share only. |
| Finance freeze timing | PASS | Fare locked at confirm. P&L uses payment-settings version in force at freeze (`18` B). After freeze, no live recalc. |
| Payment three-layer model | PASS | Responsibility, Plan, Transactions, plus derived aggregates. |
| COD vs Wallet | PASS | Separate accounts and ledgers. Cash picture ₹100 / ₹85 / ₹15. Cash earning not posted to wallet. |
| COD suspend ₹100 | PASS | Checked at accept inside the order lock. Threshold versioned. |
| Cancellation | PASS | Default ₹0; customer ≠ rider; shares = 100%; snapshot even at ₹0; not auto 85/15. Leftover `18` C ignored. |
| Failed delivery ≠ cancel | PASS | Reason, office snapshot, ₹8/km adjustment. |
| Resend Case A / Case B | PASS | Amounts and versions stored. Original fare not overwritten. Leftover `19` pending-split ignored. |
| Case A storage shape | FUTURE BUSINESS DECISION / TECHNICAL DESIGN OPTION | Child order vs related record does not change money. This design **recommends** child order for Case A and same-order snapshot for Case B. |
| Invoice | PASS | Separate number; full bill; GST ₹0; built from snapshots; idempotent retry. |
| Config versioning | PASS | Fare, 85/15, cancel, COD threshold, office, extra ₹/km, methods. Published versions not edited in place. |
| KYC / files / bank / UPI | PASS | Metadata in Postgres; bytes in object storage; masked secrets. |
| Audit + idempotency | PASS | Append-only audit; scope+key idempotency for all listed money/status operations. |
| Delete policy | PASS | Financial facts never hard-deleted. |
| Dispatch algorithm | FUTURE BUSINESS DECISION | Offer + lock + one winner is designed. Broadcast vs sequential, TTL, radius remain open and do not block this model. |
| OTP policy numbers | FUTURE BUSINESS DECISION | Challenge entity exists without choosing 4 vs 6, provider, expiry, lockout. |
| Owner vs hired driver | FUTURE BUSINESS DECISION | Rider Driver placeholder only. |
| Customer wallet auto-debit / KYC limits | FUTURE BUSINESS DECISION | Architecture-ready ledger; booking does not require debit. |
| Rating both ways | FUTURE BUSINESS DECISION | Customer→rider persisted; opposite direction optional. |
| Pickup/drop contacts required | FUTURE BUSINESS DECISION | Nullable stop contacts. |
| Extra multi-stop fee | FUTURE BUSINESS DECISION | Not invented. |
| Statutory SAC / GSTIN / e-invoice | FUTURE BUSINESS DECISION | Fare GST remains ₹0. |
| Close failed delivery without resend | FUTURE BUSINESS DECISION | No invented status or fee. |
| Cash collected from whom if payer ≠ booker | FUTURE BUSINESS DECISION | `payer_type` is stored. No pickup-vs-drop fee invented. |
| Money storage integer vs numeric | FUTURE BUSINESS DECISION / TECHNICAL DESIGN OPTION | Pick one rule at physical schema time; use it everywhere. Does not change entities. |
| Notification inbox scope | TECHNICAL DESIGN OPTION | Identity vs profile inbox. Not a money risk. |
| Live gateway / capture moment / vendor | FUTURE BUSINESS DECISION | Transaction model already supports PENDING until provider confirm. Do not fake PAID. |
| Stale `04`/`05`/`08`/`18` leftovers | PASS | Not used as specification. |
| Invented entities | PASS | No Receiver app, no chat, no merged dummy referral program, no failed-closed status. |
| Finance snapshot uniqueness | PASS | Multiple rows per order allowed so reversals are possible. |
| Reconciliation | PASS | Wallet, COD, payments, finance, invoice each have a compare path. |
| 10M growth path | PASS | Postgres + transactions now; replicas/partitions/Redis/workers later; no day-1 shard or microservice split. |

No fake issues were added. Remaining opens are the same non-critical items already listed in `OPEN_QUESTIONS.md`.

**No CORRECTION REQUIRED** against locked business rules. The conceptual model can represent every locked money and identity rule without mixing facts.

---

# IDHAR UDHAR — CONCEPTUAL DATABASE DESIGN

## 1. Entity catalog

Identity, OTP Challenge, Session, Customer Profile, Rider Profile, Admin Profile, Saved Address, City, Zone, Vehicle Category, Vehicle, Rider Driver, Stored File, Rider Document, Vehicle Document, Rider Bank Account, Rider UPI, Rider Wallet Account, Wallet Ledger, Rider COD Account, COD Ledger, optional Customer Wallet + ledger, Fare Configuration Version, Payment Settings Version, Payment Method Policy Version, Cancellation Configuration Version, COD Policy Version, Resend And Office Rate Version, Company Office Version, Order, Order Stop, Order Status Event, Order Offer, Fare Quote, Fare Snapshot, Payment Responsibility, Payment Plan, Payment Transaction, Finance Snapshot, Cancellation Snapshot, Failed Delivery, Order Adjustment, Resend Snapshot, Invoice, Invoice Line, Order Rating, Notification, Audit Log, Idempotency Record. Optional later: Rider Location Sample.

## 2. Entity responsibilities

- **Identity / session / OTP** — who is logged in.
- **Profiles** — what that person is allowed to do in each app.
- **Catalog + versioned config** — tomorrow’s rates and rules.
- **Order + stops + status + offers** — the trip.
- **Fare snapshot** — what the trip was supposed to cost.
- **Responsibility / plan / transactions** — who owed, how they intended, what was paid.
- **Finance / cancel / resend / adjustment snapshots** — how money was split after the fact.
- **Wallet vs COD ledgers** — rider available money vs company cash held.
- **Invoice** — the document.
- **Audit + idempotency** — proof and retry safety.

## 3. Relationships

See Relationship Map. The Order is the hub. Identity never appears as the order’s customer or rider foreign key.

## 4. Cardinalities

See Cardinality table. Important: Customer 1:N Orders (including many active). Order 1:N Offers but 1:0..1 accepted. Order 1:N Finance Snapshots. Rider 1:1 Wallet and 1:1 COD.

## 5. Ownership

Customers own bookings and editable profile fields. Riders own online state and uploads. Admin owns configuration publish and operations. The backend owns status, money, ledgers, invoices, audit, and idempotency.

## 6. Mutable vs immutable

Master and profile data may change. Snapshots, ledgers, payments, status events, and audit do not. Current status and materialized balances change only by appending the matching history row.

## 7. Snapshot architecture

| Snapshot | When written | Never |
|---|---|---|
| Fare Snapshot | Confirm | Recalculate from new rates |
| Payment Responsibility / Plan | Confirm | Overwrite because someone paid |
| Finance Snapshot | Delivered or terminal cancel/fail; reversals later | Update the original row |
| Cancellation Snapshot | Cancel | Use today’s cancel table on old trips |
| Failed Delivery + office copy | Receiver unavailable | Move the old office pin |
| Resend Snapshot | Resend | Overwrite original fare |
| Order Adjustment | Office extra / audited fix | Edit the original Trip Fare |

## 8. Financial architecture

85/15 on confirmed Trip Fare. Company 15% then 50/50 operations and profit. Who pays does not matter. Reports sum snapshots.

## 9. Wallet / COD architecture

Two accounts, two ledgers. Cash company share increases COD. Cash rider share stays physical. Digital inflows settle COD first, then wallet. Suspend at threshold. Wallet never negative because of COD.

## 10. Configuration versioning

One versioned entity per setting family. Current = active version. Historical = superseded. Publish creates N+1. Do not edit N in place.

## 11. Audit

Append-only who/what/when/old/new/why on Admin and money writes.

## 12. Idempotency

Scope + key + request hash. Same retry returns the first result. Different body with the same key is rejected.

## 13. Constraints

Money sums, unique winners, unique public ids, non-negative wallet and COD, profile foreign keys, GST 0. See constraint list.

## 14. Index requirements

Customer/rider/admin lists, display id, offers, payments, ledgers, COD suspend, invoice, audit, idempotency. See index list.

## 15. Reconciliation

Balance vs ledger; due vs ledger; owed vs paid; freeze vs snapshotted percents; invoice vs snapshots.

## 16. Scalability considerations

Correct modular Postgres first. Partition and replica later. Do not shard Order away from Wallet and COD.

## 17. Delete policy

Never hard-delete financial facts or snapshots. Soft-deactivate masters and people. Purge only expired unused quotes, OTPs, and sessions.

---

## How to read a complicated money trip

**WHAT** happened: a customer booked, a rider collected cash, the company is owed ₹15.  
**WHY** the database uses so many records: each record answers one question (fare, who owes, what was paid, rider available money, company cash held, P&L).  
**HOW** they stay true: snapshots and ledgers are insert-only; Admin publishes new versions instead of editing old ones.  
**WHAT PROBLEM IT PREVENTS:** last month’s trip changing when someone moves a slider today, or a wallet that pretends the rider owes money by going negative.

---

# FINAL STATUS

Every locked business rule in `RULES_BOOK` and the confirmed sections of `18` has a home in this model:

- One identity, many profiles
- One canonical order and status
- Stops as rows
- Fare snapshot ≠ live rates
- Trip Fare ≠ net payable; 85/15 on Trip Fare
- Responsibility ≠ plan ≠ transaction ≠ aggregate
- Wallet ≠ COD
- Cancel ≠ failed delivery
- Resend Case A / Case B stored explicitly
- Invoice ≠ trip id
- Versioned configuration
- Append-only audit and ledgers
- Idempotent money and accept

Remaining items are non-critical product/ops choices. They do not block a safe physical schema. Physical schema must still pick integer vs numeric, and may implement Case A as a child order (recommended) or as a related record.

---

DATABASE ARCHITECTURE STATUS:

READY FOR PHYSICAL POSTGRESQL SCHEMA
