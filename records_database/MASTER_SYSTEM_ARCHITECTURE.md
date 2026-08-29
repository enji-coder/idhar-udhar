# IDHAR UDHAR — MASTER SYSTEM ARCHITECTURE

**Type:** System architecture blueprint (design only)  
**Date:** 2026-08-22  
**Last audited:** 2026-08-22  
**Status:** ARCHITECTURE DESIGN — audited and corrected; not implemented  
**Audience:** Future backend, database, security, and product teams

This document designs the **correct long-term production architecture** for IDHAR UDHAR.

It is **not** a copy of the current mock apps.  
It is **not** a copy of older schema blueprints (`04`, `05`).  
It is **not** a PostgreSQL implementation.

PostgreSQL, APIs, payment providers, and live Customer ↔ Rider ↔ Admin sync are **not built today**.

---

## 1. Document Purpose

This document answers one question:

> If IDHAR UDHAR must become a real production system that is financially correct, auditable, secure, and able to grow toward 10 million+ users, what architecture should we build?

It exists so that later PostgreSQL design, API design, and implementation do **not** invent business rules, do **not** revive stale documents, and do **not** treat mock app shortcuts as production truth.

This document does **not**:

- write application code
- create tables or migrations
- choose a payment vendor
- invent fees, GST, or extra multi-stop charges
- redesign UI or themes

---

## 2. Architecture Status

| Layer | Status |
|---|---|
| Final business rules | LOCKED |
| Shared mock rule engines (Dart / Admin JS) | CURRENTLY IMPLEMENTED |
| Customer / Rider / Admin UIs | CURRENTLY IMPLEMENTED as separate mock stores |
| Shared production database | NOT IMPLEMENTED |
| Backend / API | NOT IMPLEMENTED |
| Live payment gateway | ARCHITECTURE READY / PAYMENT PROVIDER INTEGRATION PENDING |
| Receiver application | NOT IMPLEMENTED and not required |
| PostgreSQL schema | FUTURE IMPLEMENTATION (next dedicated phase) |
| This architecture | AUTHORITATIVE DESIGN for that next phase |

Legend used in this file:

| Label | Meaning |
|---|---|
| **FINAL BUSINESS RULE** | Product lock. Architecture must support it. |
| **CURRENTLY IMPLEMENTED** | Exists in mock/local apps today |
| **ARCHITECTURE READY** | Designed now; not live |
| **IMPLEMENTATION PENDING BACKEND** | Needs API + PostgreSQL |
| **FUTURE IMPLEMENTATION** | Later phase |
| **TECHNICAL DESIGN OPTION** | Engineering choice, not a new business rule |
| **FUTURE BUSINESS DECISION** | Not finalized. Do not invent. |

---

## 3. Source-of-Truth Documents

If documents disagree, use this order. **Higher level wins.**

| Level | Documents | Use |
|---|---|---|
| **1 — Final business rules** | `RULES_BOOK.md`, `18_FINAL_BUSINESS_DECISIONS.md` (V1 PRODUCT RULES CONFIRMED, CONFIRMED FINANCIAL MODEL, D2, FINAL STATUS TABLE rows 5 / 12 / 13) | Must follow |
| **2 — Final requirements** | `19_DATABASE_REQUIREMENTS_FROM_FEATURES.md`, `FINAL_MASTER_ANALYSIS.md` | Must support |
| **3 — Audit** | `FINAL_DATABASE_AUDIT.md` | Confirms what is locked vs stale |
| **4 — Current discovery** | `01`, `02`, `03` Customer / Rider / Admin discovery | Discovery only |
| **5 — Historical blueprints** | `00`, `04`–`16`, body of `17_OPEN_DECISIONS.md`, leftover `18` sections C / D / L / M money table / status table row 3 | Do not copy if they conflict |

**Do not use as specification:**

- leftover `18` C (cancelled trips permanently ₹0 forever)
- leftover `18` D (one `payment.method` as the whole payment model)
- leftover `18` L (cancellation still “not defined”)
- leftover `18` M (resend split still open)
- `04` / `05` single `payment` row
- `08` invoice tax 5%
- any “join by vehicle name” or timestamp-modulo trip ID

Current application code was inspected **for discovery only**:

- Dart engines: `idhar_udhar/lib/shared/business/`
- Admin engines: `IDHAR_UDHAR_ADMIN/src/services/`
- Customer / Rider / Admin screens and mock repositories

Those engines encode the locked rules. They are **not** the production database.

Remaining genuine unknowns: `OPEN_QUESTIONS.md`. **No critical items.**

---

## 4. Business Principles

These principles are FINAL. Architecture must make them hard to violate.

1. **85/15 is on confirmed Trip Fare**, not on discounted payable, not on who paid, not on cash vs online.
2. **Confirmed Trip Fare does not silently change.**
3. **One canonical trip** for Customer, Rider, and Admin: one internal ID, one display ID, one status machine.
4. **Company 15% then 50/50 operations vs profit.** Example: Trip Fare ₹100 → Rider ₹85, Company ₹15 → Operations ₹7.50, Net Profit ₹7.50. Operations is an internal allocation **from the company share only**. It is not a rider deduction and not a vendor bill.
5. **GST on fare = ₹0.**
6. **WHO PAYS and HOW THEY PAY are separate.** Split payment is allowed. Multiple payment transactions per trip.
7. **Wallet never goes negative because of COD.** COD Due is a separate ledger.
8. **COD Due ≥ ₹100 suspends the rider** from accepting new rides.
9. **Recharge and eligible earnings settle COD Due first.**
10. **Cancellation is Admin-configured**, default ₹0, customer rules ≠ rider rules, rider% + company% = 100%, not auto 85/15.
11. **Failed delivery is not cancellation.**
12. **Resend Case A** (original trip ended) = current base fare + ₹10/km, normal 85/15.
13. **Resend Case B** (original trip not ended) = customer ₹10/km, rider ₹8/km, company ₹2/km. Not 85/15.
14. **Office handover extra** = ₹8/km to the rider. Not 85/15.
15. **Historical money never recalculates** from today’s Admin settings.
16. **One physical person may be Customer and Rider** on the same mobile number. Authentication identity and role profiles are separate.
17. **Receiver is a payer on the trip**, not a required third application.
18. **Until a backend exists**, apps may keep local demo data. The **rules** are already shared. The **rows** are not live-linked.

---

## 5. System Overview

IDHAR UDHAR is a last-mile delivery platform.

```text
Customer App          Rider App             Admin Panel
     │                    │                      │
     └──────── HTTPS /v1 + realtime ─────────────┘
                          │
                    Backend API
                    (modular monolith)
                          │
          ┌───────────────┼────────────────┐
          │               │                │
     PostgreSQL         Redis*        Object storage*
     (source of         (hot GPS,      (KYC, POD,
      truth)             cache,         invoice PDF)
                         rate limit)
          │
     Workers / jobs*
     (webhooks, invoices, SMS, dispatch, daily reports)

* Redis, object storage, and workers are ARCHITECTURE READY.
  Phase 1 can start with API + PostgreSQL only.
```

**What exists today**

- Three clients with mock data
- Shared financial / payment / COD / cancel / resend engines
- Admin Netlify login + vehicle-category HTTP for the catalog
- No shared production database

**Target**

- One backend owns writes
- PostgreSQL is the only financial source of truth
- Apps never join each other through local storage, names, or phone numbers

---

## 6. Application Architecture

### 6.1 Clients

| Client | Responsibility | Must not do |
|---|---|---|
| Customer Flutter | Book, pay plan, track, cancel if allowed, request resend, view own invoices | Calculate production fare as authority; accept riders; change 85/15 |
| Rider Flutter | Go online, accept/reject, update trip progress, collect cash portions, see wallet + COD Due | Choose the winning accept locally if another rider also accepted; change company settings |
| Admin React | Configure, operate, support, finance, reports | Recalculate old trips from live settings; store production secrets in the browser |

### 6.2 Backend shape — TECHNICAL DESIGN OPTION

**Start with one modular backend**, not a mesh of microservices.

Suggested modules inside one deployable API:

- Identity & session
- Customer
- Rider
- Admin / RBAC
- Catalog (vehicles, cities, zones)
- Order / dispatch
- Fare
- Payment
- Wallet & COD
- Finance snapshot
- Invoice
- Notification
- Audit
- Files
- Reporting read APIs

**Why one modular backend first**

- One transaction can cover accept + status + finance + wallet
- One team can ship V1 without distributed-transaction pain
- Modules can later become services if a real bottleneck appears

**What this prevents**

- Fake “scale” that splits wallet, COD, and orders into three services and then loses money on retries

### 6.3 Source of writes

**FINAL architectural rule:** only the backend changes order status, money, wallet, COD, and invoices.

Clients send **commands**.  
The backend applies **rules**.  
PostgreSQL stores **facts**.

---

## 7. Identity & Authentication Architecture

### 7.1 The problem

One physical person may use:

- Customer App
- Rider App

with the **same mobile number**.

If we create `customers.phone UNIQUE` and `riders.phone UNIQUE` as two logins, we get:

- two OTPs for one person
- two “users” that are actually one human
- broken audit (“who is this phone?”)
- later corporate / KYC / wallet problems

### 7.2 The model

```text
IDENTITY  (one person, one login)
    │
    ├── CUSTOMER PROFILE   (optional)
    ├── RIDER PROFILE      (optional)
    └── ADMIN PROFILE      (optional, staff)
```

Example:

```text
Identity     U-9F2A…     phone +91 98XXXXXX10
Customer     C-…         same identity
Rider        R-…         same identity
```

**WHAT:** Authentication identity is separate from application role/profile.  
**WHY:** The same human is one account, two jobs.  
**HOW:** Phone OTP authenticates the identity. Each app then opens the matching profile.  
**PREVENTS:** Duplicate people, split wallets by accident, “which user_id is this phone?”  
**SCALES:** One identity table can hold 10M+ people. Profiles are created only when that role is used.

### 7.3 What is unique

| Thing | Uniqueness | Meaning |
|---|---|---|
| Identity phone | Unique (normalized 10-digit / E.164) | One login person |
| Identity email | Unique when present | Optional for customers; typical for admin |
| Customer profile | Unique per identity | At most one customer profile |
| Rider profile | Unique per identity | At most one rider profile |
| Admin profile | Unique per identity | Staff only |

This implements FINAL rule: same mobile may be Customer **and** Rider.

Older notes that say “unique `(role, phone)`” meant “the same phone may exist in both roles.” They did **not** mean two independent logins. This architecture keeps **one identity per phone**, then attaches profiles.

It does **not** invent a third “super user” who can do everything in every app.

V1 Admin login is normally a **staff identity** (email + password). Putting an Admin profile on a Customer/Rider identity is **not** a required product path. Do not invent a rule that one human must or must not be all three.

### 7.4 App authorization

| App | Required profile | Allowed work |
|---|---|---|
| Customer | Customer profile | Book and manage own trips |
| Rider | Rider profile | Deliver; never book as rider |
| Admin | Admin profile | Operate the company |

A person with both Customer and Rider profiles:

- logs into Customer App → acts only as customer
- logs into Rider App → acts only as rider

**FINAL (product):** a customer cannot do rider work inside the Customer app. A rider cannot do admin work.  
**ARCHITECTURE:** that is **authorization**, not a second phone number.

### 7.5 Authentication methods

| Actor | Method today | Production |
|---|---|---|
| Customer | Dummy 4-digit OTP | Server OTP, hashed, SMS provider |
| Rider | Dummy OTP / skipped login in places | Same identity OTP |
| Admin | Netlify / demo password | Server password hash (Argon2id or equivalent) + session |

**FUTURE BUSINESS DECISION:** OTP length (4 vs 6), SMS provider, expiry, max attempts, lockout.  
**ARCHITECTURE READY now:** store `otp_challenge` with `code_hash`, phone, expiry, attempt count, cooldown. Never store plaintext OTP.

### 7.6 Sessions

**TECHNICAL DESIGN OPTION:**

- Customer / Rider: short-lived access token + rotating refresh token, or app-bound session
- Admin: HttpOnly Secure SameSite cookie, or short access JWT + hashed refresh
- Claims include `identity_id` + `active_profile_type` + `profile_id`
- Admin tokens never grant Customer/Rider APIs and vice versa

### 7.7 What not to do

- Do not make two independent auth users for one phone
- Do not use phone number as a foreign key
- Do not put Admin modules on Customer/Rider tokens
- Do not keep production passwords in app code or `000_info.txt`

---

## 8. Role & Permission Architecture

### 8.1 Role families

| Family | Roles | Where enforced |
|---|---|---|
| Marketplace | Customer, Rider | API object checks |
| Company staff | Super Admin, Sub Admin, Operations, Finance, Support, Manager | API RBAC |

Admin module flags already exist in the mock panel (`modules[]`, `financeAccess`, `payoutApprove`). Production must enforce them **on the API**, not only by hiding React routes.

### 8.2 Object-level rules (minimum)

| Object | Who may read/write |
|---|---|
| Order | Customer: own. Rider: offered or assigned. Admin: by RBAC |
| Wallet | Owner + Finance/Super Admin |
| Bank / UPI | Owner (masked) + Finance |
| KYC documents | Owner + Operations/Super Admin |
| Payment settings / cancellation rules / office | Super Admin write |
| Audit log | Super Admin read; system write only |

### 8.3 Rider suspension is a role constraint

If COD Due ≥ ₹100, the rider profile is **SUSPENDED_FOR_COD**.

Effect:

- cannot accept new offers
- can still see existing assigned trip and wallet
- Admin can see the reason

This is FINAL, not a UI-only flag.

---

## 9. Customer Architecture

### 9.1 Customer profile

Holds marketplace-customer data, not login secrets.

Typical facts:

- identity_id
- display name (required)
- email (optional until tracking / invoice continue — FINAL)
- status (active / deactivated)
- default city
- invoice email captured when required

Phone lives on **identity**, not as a second unique customer login.

### 9.2 Customer capabilities

- Many orders, including **multiple active orders** (FINAL)
- Saved addresses
- Booking: pickup + 1 to 3 drops
- Payment responsibility plan at confirm
- Cancel only when the cancellation rule for that actor + stage is enabled
- Request resend after failed delivery

### 9.3 Customer wallet

**CURRENTLY IMPLEMENTED:** demo balance in the Customer app.  
**ARCHITECTURE READY:** a customer wallet + ledger can exist.  
**FUTURE BUSINESS DECISION:** min/max top-up, KYC, whether booking auto-debits wallet.

Until that decision: **booking does not require wallet debit**. Do not invent auto-debit as a business rule.

### 9.4 What the customer never owns

- 85/15 calculation authority
- Other customers’ orders
- Rider COD Due
- Admin configuration

---

## 10. Rider Architecture

### 10.1 Rider profile

Holds delivery-worker data:

- identity_id
- onboarding / KYC status
- online / offline
- home city / zone
- approval / reject / suspend
- COD Due status
- vehicle link
- optional driver record

V1 product behaviour: **one rider login ≈ one driver ≈ one vehicle**.  
Schema keeps a separate driver record so a later fleet model does not require a redesign.

**FUTURE BUSINESS DECISION:** hired driver vs owner, multi-vehicle fleet.

### 10.2 Rider money (keep separate)

| Concept | Meaning | Can it go negative? |
|---|---|---|
| Earning wallet (available) | Money the rider can use / withdraw later | No |
| COD Due | Money the rider owes the company from cash collections | No (always ≥ 0) |
| Physical cash in rider’s hand | Operational note of cash collected | Not the ledger source of truth |

Eligible **digital** earnings and recharge **never** credit the wallet before COD Due is reduced.

Cash collected on a trip is **physical cash**, not a wallet credit. Do not run that trip’s rider share through the wallet as if it were an online earning. That would falsely settle the same trip’s COD Due and invent a digital credit the rider does not have.

### 10.3 Rider work rules

- Must be online and not COD-suspended to accept
- One rider does **not automatically** take a second live trip (FINAL). Whether Admin may manually assign a second live trip is a **FUTURE BUSINESS DECISION**. Do not invent “always allowed” or “always forbidden.”
- Cancel only if Admin enabled rider cancel at that stage
- Rider share of a cancellation fee is credited immediately, then COD settlement runs

---

## 11. Admin Architecture

Admin is the company control plane.

### 11.1 Admin profile

- identity_id (usually email login)
- role
- module permissions
- financeAccess
- payoutApprove
- city scope if later needed

### 11.2 Admin write surfaces that must be versioned

| Surface | Why versioned |
|---|---|
| Fare / vehicle-category rates | Old trips keep old rates |
| Payment settings 85/15/50 | Old P&L stays frozen |
| Cancellation rules | Old cancels keep old fee/shares |
| Company office | Failed-delivery distance uses the office that applied |
| COD suspend threshold | Default ₹100 is FINAL today; still snapshot if ever changed |

Admin **creates a new version**. Admin does **not** edit yesterday’s version in place.

### 11.3 Admin may

- Assign a rider while searching
- Cancel until a terminal status
- See the same trip ID, fare, payers, payments, rider/company amounts, COD, cancel, resend
- Adjust money only through **audited adjustment commands**, never by editing a snapshot

### 11.4 Admin must not

- Recalculate historical reports from live settings
- Store card PAN/CVV
- Embed production secrets in the React app

---

## 12. Order / Trip Architecture

The **order (trip)** is the central business transaction.

Everything money-related hangs off it.

```text
IDENTITY
   ├── CUSTOMER PROFILE ── * ORDERS
   └── RIDER PROFILE    ── * ORDERS (rider_id null until assigned)

ORDER
   ├── stops (1 pickup + 1..3 drops)
   ├── status + status history
   ├── rider offer(s)
   ├── fare snapshot
   ├── payment responsibility   (who owes how much)
   ├── payment plan             (how they intend to pay)
   ├── payment transactions     (what was actually paid)
   ├── finance snapshot(s)
   ├── invoice
   ├── cancellation snapshot (if cancelled)
   ├── failed delivery (if any)
   ├── resend request / child order (if any)
   ├── adjustments (office extra, resend, audited fixes)
   └── audit / idempotency references
```

### 12.1 Identifiers

| ID | Role |
|---|---|
| Internal UUID (time-sortable, e.g. UUID v7) | Primary key. All foreign keys use this. |
| Display ID `IU-{CITY}-{10 digits}` | Human ID. Example: `IU-AMD-0000010421` |
| Invoice number | Separate unique series. Never equal to trip ID |

**WHAT:** UUID inside, display ID outside.  
**WHY:** Display IDs are for humans and support. UUIDs are for scale and joins.  
**HOW:** Database sequence for the 10-digit part; city code from city master (`AMD` = Ahmedabad).  
**PREVENTS:** Timestamp-modulo collisions, Admin `IU-AMD-10421` vs Rider `IU10248` forever.  
**SCALES:** 10 digits is enough for very large volume; UUID does not run out.

Never join on:

- customer name
- phone
- “Bike”
- formatted display ID as the only key

### 12.2 Order facts (conceptual)

- customer_id → **Customer profile** (required). Not identity_id. Not phone.
- rider_id → **Rider profile** (null until assigned). Not identity_id. Not phone.
- city_id
- vehicle_category_id + name snapshot
- canonical status
- display_id
- confirmed trip fare and payable (copied from fare snapshot)
- parent_order_id (resend child only)
- scheduled_at **nullable** (not V1; do not build a scheduler now)
- created/updated timestamps

One customer may have many running trips.  
One rider does **not automatically** receive a second live trip.

### 12.3 Quote vs confirmed order

```text
Fare quote (short TTL, server-calculated)
        ↓ customer confirms
Order created + fare snapshot copied
        ↓ payment plan stored
Searching / dispatch
```

If online payment is later enabled, **do not dispatch as paid** until the provider confirms. That capture moment is a **FUTURE BUSINESS DECISION**. The transaction model is ready now.

### 12.4 Four payment ideas — do not mix them

**WHAT:** One order has four different payment facts.  
**WHY:** “Who should pay,” “how they planned to pay,” “what money actually moved,” and “is the bill finished?” are different questions.  
**HOW:** store each separately.  
**PREVENTS:** a single `order.payment_method` becoming the whole payment system.

| Idea | Question it answers | Example |
|---|---|---|
| Responsibility | Who **owes** how much? | Customer ₹50, Receiver ₹50 |
| Plan | How do they **intend** to pay? | Customer ₹50 Online + ₹0 Cash |
| Transaction | What **actually** happened? | One ONLINE row ₹50 PENDING → PAID |
| Aggregate status | Is that payer / the order finished? | Customer PAID, Receiver UNPAID, Overall PARTIALLY_PAID |

### 12.5 Conceptual entities (not SQL tables)

Every name below exists because a locked rule or a safety need requires it. This is **not** a CREATE TABLE list.

| Concept | Why it exists |
|---|---|
| Identity | One login person |
| Customer profile / Rider profile / Admin profile | Roles on that person |
| City / zone | Display ID + service area |
| Vehicle category + fare config version | Admin rates |
| Vehicle + optional driver | Rider fleet facts |
| Rider document / bank / UPI | KYC and payout |
| Company office version | Failed-delivery destination |
| Payment settings version | 85/15/50 history |
| Cancellation rule version | Customer ≠ rider, default ₹0 |
| Resend / office rate version | ₹10 / ₹8 / ₹2 and ₹8/km stay historically correct if later edited |
| Order | Canonical trip |
| Order stop | Ordered pickup/drops |
| Order offer | Accept lock |
| Order status event | History; never overwrite |
| Fare quote / fare snapshot | Confirm locks Trip Fare |
| Payment responsibility | Who owes |
| Payment plan | Intended methods/amounts |
| Payment transaction | Actual money movement |
| Wallet + wallet ledger | Rider available money |
| COD ledger + COD settlement | Money rider owes company |
| Finance snapshot | Immutable 85/15 (and reversals as new rows) |
| Cancellation snapshot | Fee/shares used that day |
| Failed delivery + office compensation | Not a cancel |
| Resend request / related order | Case A or Case B |
| Order adjustment | One extra money fact (office, audited fix) |
| Invoice | Financial document ≠ trip ID |
| Notification | Inbox / push |
| Audit log | Who changed what |
| Idempotency record | Same retry does money once |
| OTP challenge | Hashed, not plaintext |

Do not add extra entities only because they sound sophisticated.

---

## 13. Multi-Stop Architecture

**FINAL:** Single location or multiple locations. Maximum **3** delivery locations. Customer may choose 2 or 3 drops.

```text
ORDER
  stop sequence 0  PICKUP
  stop sequence 1  DROP
  stop sequence 2  DROP   (optional)
  stop sequence 3  DROP   (optional)
```

Each stop is its own record:

- order_id
- sequence
- type (pickup / drop)
- address text + structured fields as available
- latitude / longitude
- zone_id if known
- nullable contact name / phone (**FUTURE BUSINESS DECISION** whether required at booking)
- arrival / completion timestamps when they happen

**Never store** `"Ahmedabad, Gandhinagar, Surat"` as one destination string.

**FUTURE BUSINESS DECISION:** extra fee for extra stops.  
**FINAL today:** fare uses Admin fare table over **total route distance**. Do not invent a stop fee.

Distance for fare = sum of ordered legs.  
That distance is copied onto the fare snapshot.

---

## 14. Status & Lifecycle Architecture

### 14.1 One internal machine

Apps may show different words. The database stores **one** canonical status.

Canonical statuses (from the current shared machine — keep this set):

| Internal status | Typical Customer label | Typical Rider label | Typical Admin label |
|---|---|---|---|
| CREATED | Searching for rider | — | Pending |
| SEARCHING | Searching for rider | — | Pending |
| OFFERED | Rider assigned | Incoming request | Assigned |
| ASSIGNED | Rider assigned | Trip accepted | Rider Accepted |
| EN_ROUTE_PICKUP | Rider is on the way | Going to pickup | Rider Arriving |
| ARRIVED_PICKUP | Rider arriving | Arrived at pickup | Out for Delivery |
| PICKED_UP | Parcel picked up | Package picked up | Picked Up |
| IN_TRANSIT | In transit | Going to drop | In Transit |
| NEAR_DROP | Near destination | Near drop | Near Drop |
| DELIVERY_ATTEMPT | Delivery attempt | Delivery attempt | Delivery Attempt |
| DELIVERED | Delivered | Delivered | Delivered |
| CANCELLED | Cancelled | Cancelled | Cancelled |
| RECEIVER_UNAVAILABLE | Receiver unavailable | Receiver unavailable | Receiver Unavailable |
| FAILED_DELIVERY | Receiver unavailable | Failed delivery | Failed Delivery |
| PARCEL_AT_COMPANY_OFFICE | Parcel at company office | At office | At Company Office |
| RESEND_REQUESTED | Resend requested | Resend requested | Resend Requested |
| RESEND_IN_PROGRESS | Resend in progress | Resend in progress | Resend In Progress |
| RESEND_COMPLETED | Resend completed | Resend completed | Resend Completed |

Happy path:

```text
CREATED → SEARCHING → OFFERED → ASSIGNED
→ EN_ROUTE_PICKUP → ARRIVED_PICKUP → PICKED_UP
→ IN_TRANSIT → NEAR_DROP → DELIVERY_ATTEMPT → DELIVERED
```

Failed delivery path (not cancel):

```text
DELIVERY_ATTEMPT → RECEIVER_UNAVAILABLE → FAILED_DELIVERY
→ PARCEL_AT_COMPANY_OFFICE → RESEND_REQUESTED
→ RESEND_IN_PROGRESS → RESEND_COMPLETED
```

Also: OFFER_REJECTED / offer timeout returns to SEARCHING (event, then status SEARCHING).

### 14.2 Status history

Every change writes an **append-only status event**:

- order_id
- from_status
- to_status
- actor (customer / rider / admin / system)
- actor_id
- reason
- idempotency key
- timestamp

The order row holds **current** status for fast queries.  
History is never overwritten.

### 14.3 Transition rules

- Backend is the only legal transitioner
- Invalid transition is rejected
- Duplicate event with the same idempotency key is ignored
- Terminal statuses in the current machine: DELIVERED, CANCELLED, RESEND_COMPLETED
- What happens if Admin closes a failed delivery **without** resend is a **FUTURE BUSINESS DECISION**. Do not invent a new status or a fee for it.

**FUTURE BUSINESS DECISION:** how long SEARCHING lasts before auto-cancel; broadcast vs sequential offers.

**Case A vs Case B status:** If Case A is stored as a **child order**, the original order keeps its ended status (usually DELIVERED / PARCEL_AT_COMPANY_OFFICE). The child has its own status. Do not rewrite the original to RESEND_COMPLETED in a way that hides the first trip. If Case B stays on the same operational order, add resend snapshots and status events; still do not overwrite the original fare snapshot.

---

## 15. Fare Architecture

### 15.1 Current configuration vs snapshot

```text
Admin fare config version  (editable future rates)
        ↓ used at quote time
Fare quote
        ↓ customer confirms
Order fare snapshot        (immutable for that order)
```

**FINAL engine (no GST, no invented multi-stop fee):**

```text
distance_charge = per_km × total_route_km
trip_fare       = max(initial_minimum, base + distance_charge + waiting + surge + toll + parking)
net_total       = round(trip_fare − discount)
```

85/15 uses **trip_fare**, not net_total.

Example (this is the locked money picture):

```text
Trip Fare              ₹100
Discount               ₹10
Customer / bill pays   ₹90

Rider                  ₹85     (85% of Trip Fare, NOT of ₹90)
Company                ₹15     (15% of Trip Fare)
  Company Operations   ₹7.50   (50% of the ₹15 company share)
  Company Net Profit   ₹7.50   (the other 50% of ₹15)
```

Operations is **not** subtracted from the rider. The rider stays ₹85.

### 15.2 Fare snapshot contents

Copy, do not reference live rates:

- config version id
- vehicle category id + name
- distance km + stop count
- base, per-km, distance charge, minimum, waiting, surge, toll, parking
- trip fare
- discount
- rounding
- net payable
- tax = 0
- quoted-at / confirmed-at

Later Admin rate changes create **version N+1**. Order snapshots stay on version N.

### 15.3 Extra lines after confirm

If something is added later (resend, cancellation fee, office extra), it is a **new line / adjustment / related order**, not a silent edit of Trip Fare from ₹100 to ₹110.

---

## 16. Payment Responsibility Architecture

WHO PAYS is not HOW THEY PAY.

### 16.1 Responsibility (what is owed)

One responsibility record per order:

- applicable **bill** total — usually fare snapshot **net payable** (Trip Fare − discount + rounding). Extra charges belong here only if they are on **this** order’s bill, not if they belong to a child resend order.
- customer_responsibility
- receiver_responsibility
- constraint: **customer + receiver = applicable bill total**
- who_pays summary: CUSTOMER / RECEIVER / SPLIT

**Do not use this bill total as the 85/15 base.**

```text
Trip Fare ₹100  →  85/15  →  Rider ₹85, Company ₹15
Discount  ₹10
Bill      ₹90   →  Customer/Receiver responsibility sums to ₹90
```

Invalid:

```text
Total ₹100
Customer ₹60
Receiver ₹30
```

Valid:

```text
Total ₹100
Customer ₹50
Receiver ₹50
```

### 16.2 Planned methods (how they intend to pay)

Store the **plan** separately from actual transactions:

- customer planned online amount
- customer planned cash amount
- receiver planned online amount
- receiver planned cash amount

Per payer: planned online + planned cash **must equal** that payer’s responsibility.  
The plan is intention only. It does not mark money PAID.

A payer may split:

```text
Customer ₹50 Online + ₹50 Cash
```

or

```text
Customer ₹30 Online + ₹20 Cash
Receiver ₹50 Cash
```

### 16.3 Aggregate payment status

Derived from **paid transactions**, not from the plan.

For Customer, Receiver, and Overall:

| Status | Meaning |
|---|---|
| UNPAID | Paid = 0 |
| PARTIALLY_PAID | 0 < paid < owed |
| PAID | Paid equals owed (after normal rounding). Overpay is not silent PAID — it needs an explicit adjustment or refund record. |

Example:

```text
Customer owes ₹50, paid ₹50
Receiver owes ₹50, paid ₹0
Overall = PARTIALLY_PAID
```

Invoice **total stays ₹100**. Customer Paid and Receiver Paid are separate lines.

**Never** use one `order.payment_method` column as the full truth.

---

## 17. Payment Transaction Architecture

### 17.1 One row per real payment attempt / collection

Each transaction has:

- id
- order_id
- payer_type: CUSTOMER | RECEIVER
- method: ONLINE | CASH (V1). Architecture can add WALLET later without rewriting history
- amount
- **transaction status:** PENDING | PAID | FAILED | REFUNDED
- provider reference
- idempotency key
- timestamps
- created_by (customer / rider / admin / webhook / system)

Do **not** put UNPAID / PARTIALLY_PAID / PAID on the transaction row as the only status. Those are **aggregates**.

### 17.2 Online

**ARCHITECTURE READY / PAYMENT PROVIDER INTEGRATION PENDING.**

Rules that are already FINAL:

- Do not mark ONLINE as PAID without verified provider confirmation
- Do not fake success in apps
- Card PAN / CVV are never stored
- Provider secrets live in a secret manager, not the database row
- Refund = new transaction (direction refund), original row stays

**FUTURE BUSINESS DECISION:** launch cash-only vs online in first production; authorize-at-booking vs capture-at-delivery; which provider.

### 17.3 Cash

Cash collection creates a PAID cash transaction when the rider (or Admin) confirms collection.

Cash does not change 85/15.

**FUTURE BUSINESS DECISION:** if the payer is the receiver (or not the booker), whether cash is collected from the pickup sender, the drop receiver, or always from the customer account holder. Current product language treats collection as **trip end / delivery** unless later overridden. Do not invent a cash handling fee.

### 17.4 Multiple transactions are normal

```text
Order ₹100
Txn 1  Customer ONLINE  ₹50  PENDING → PAID (webhook)
Txn 2  Customer CASH    ₹20  PAID (rider confirm)
Txn 3  Receiver CASH    ₹30  PAID (rider confirm)
```

Reconciliation compares:

- sum(PAID) by payer vs responsibility
- sum(PAID) overall vs applicable total

---

## 18. COD Architecture

COD Due is **not** the earning wallet.

### 18.1 Meaning

When the rider collects cash that includes the company’s share, the rider is holding company money.

```text
Trip Fare ₹100 → Rider ₹85, Company ₹15
  (Company Operations ₹7.50, Net Profit ₹7.50 — still from the ₹15, not from the rider)

Customer gives ₹100 cash to the rider.

Rider physical cash   = ₹100
Rider earning         = ₹85
COD Due               = ₹15   (rider owes company)
Wallet                = unchanged (does NOT become −₹15)
```

The rider is holding ₹100 in hand. ₹85 is their earning. ₹15 is company money they must settle later. That ₹15 is **COD Due**, not a negative wallet.

If cash collected is **less than or equal to** rider earning:

```text
₹50 cash, rider earning ₹85
COD Due += ₹0
Company still owes the rider the unpaid digital remainder through later online settlement
```

Do not invent a COD surcharge.

### 18.2 Two ledgers

| Ledger | What it records |
|---|---|
| Rider wallet ledger | Credits and debits of **available** money |
| COD ledger | Increases (company share held as cash) and decreases (settlements) |

COD Due materialized balance = sum(COD increases) − sum(COD settlements). Always ≥ 0.

### 18.3 Settlement

Eligible **digital** inflows that settle COD first:

- rider share from **online** (or other non-cash) completed work
- rider share of a cancellation fee
- wallet recharge
- any later eligible **digital** earning the finance module marks as “settles COD”

The rider share from **this cash trip** is physical cash. It is **not** posted as a wallet earning and it must **not** settle this trip’s own COD Due.

```text
COD Due ₹60
Recharge ₹100
→ ₹60 COD settlement
→ ₹40 wallet credit
```

```text
COD Due ₹15
Later online earning ₹85
→ ₹15 COD settlement
→ ₹70 wallet credit
```

### 18.4 Suspension

If COD Due ≥ ₹100:

- rider cannot accept new rides
- existing trip can finish
- Admin sees suspended-for-COD

Threshold ₹100 is FINAL today. Store it as configuration with versioning so a later change does not rewrite history.

### 18.5 What this prevents

- Negative wallet “because COD”
- Mixing “cash in hand” with “available balance”
- Double settlement of the same earning

---

## 19. Wallet & Ledger Architecture

### 19.1 Rider earning wallet

- Materialized `available_balance` for fast reads
- **Source of truth = append-only ledger**
- Nightly / on-demand reconcile: balance must equal sum(credits) − sum(debits)

Ledger entry types (examples, not a business fee list):

- EARNING
- COD_SETTLEMENT (debit against earning or recharge)
- RECHARGE
- PAYOUT
- ADJUSTMENT (Admin, audited)
- CANCELLATION_SHARE
- RESEND_EARNING

Every balance change happens in the **same database transaction** as the ledger insert.

### 19.2 Concurrency

Lock the rider finance row (wallet + COD) for:

- earning freeze
- COD create
- recharge
- payout
- Admin adjustment

**WHAT:** one serialized money gate per rider.  
**WHY:** two deliveries completing at once must not skip COD or double-credit.  
**PREVENTS:** lost updates, negative balance, double settlement.  
**SCALES:** row lock is per rider, not global. 10M users do not lock each other.

### 19.3 Customer wallet

Architecture-ready, not required for V1 booking.  
Same ledger pattern if enabled. No negative balance unless a future credit product is explicitly decided.

---

## 20. Cancellation Architecture

### 20.1 FINAL rules

- Default fee = ₹0
- Admin controls cancellation
- Customer table ≠ Rider table
- Per stage: enabled, fee, rider share %, company share %
- Rider % + Company % = 100
- Not automatically 85/15
- Snapshot the rule used on that cancel
- Rider share is credited immediately, then COD settlement applies

Ignore leftover text that says “V1 has no cancellation fee forever.”

### 20.2 Stages (do not invent extra ones)

- Before rider accepts
- After rider accepts
- After rider reaches pickup
- After pickup
- During delivery / in transit

### 20.3 Versioned rules

```text
cancellation_rule_version
  actor: CUSTOMER | RIDER
  stage
  enabled
  fee
  rider_share_percent
  company_share_percent
  version
  effective_from
  created_by / created_at
```

Admin save = new version. Old versions remain.

### 20.4 Order cancellation snapshot

On cancel:

- stage
- actor
- allowed? (if not enabled → reject)
- fee
- rider/company percents and amounts
- rule version id
- timestamp

If fee is ₹0, still write the snapshot (fee 0, shares as configured). That is how we prove the old rule later.

Admin may cancel until a terminal status. That is an **operational** power. A cancellation **fee** is charged only from a **versioned rule** snapshotted at cancel time. Do not invent a separate Admin fee schedule.

Finance:

- If cancelled before a trip-fare P&L freeze, do not invent 85/15 earnings
- If a fee exists, fee uses **cancellation shares**, not 85/15
- If a trip-fare snapshot already existed and must be reversed, **insert a reversal snapshot**. Do not edit the original.

---

## 21. Failed Delivery & Resend Architecture

Failed delivery ≠ cancellation.

### 21.1 Failed delivery

V1 reason: `receiver_unavailable`.

Flow:

```text
Delivery attempt
  → receiver unavailable
  → failed delivery
  → rider takes parcel to Admin company office
  → customer notified
  → customer may request resend
```

Store:

- original order_id
- reason
- office location snapshot (address, lat, lng, office version)
- office distance km
- rider office compensation = distance × ₹8 (**not** 85/15)
- timestamps

Office compensation is an **order adjustment**, not a rewrite of original 85/15.

### 21.2 Resend Case A — original rider trip has ended

Customer pays:

```text
rate-sheet base fare in force at resend time + (₹10 × km)
```

That combined amount uses **normal 85/15**. Snapshot the fare version and the 85/15 settings used **at resend**, not the original trip’s fare, and not a later Admin change.

Example: base ₹100 + 5 km → customer ₹150; rider ₹127.50; company ₹22.50 (then company operations/profit from that ₹22.50 using the snapshotted 50% rule).

**TECHNICAL DESIGN OPTION:** store Case A as a **child order** (`parent_order_id`) or as a related resend record on the original. Either way:

- original Trip Fare snapshot is never overwritten
- original 85/15 snapshot is never overwritten
- resend money is a new fact

### 21.3 Resend Case B — original rider trip has not ended

Customer pays ₹10/km.  
Rider receives ₹8/km.  
Company receives ₹2/km.  
**Not** 85/15.

Example: 5 km → customer ₹50, rider ₹40, company ₹10.

**TECHNICAL DESIGN OPTION:** keep Case B on the same order as status + snapshots, or attach a related resend record. Money must still be snapshotted as Case B. Do not mix it into the original Trip Fare and do not apply 85/15 to Case B.

### 21.4 What must be stored

- resend case (A or B)
- distance
- base fare used (Case A)
- customer charge
- rider amount
- company amount
- rate / settings versions used
- parent_order_id
- never overwrite the original order’s fare snapshot

---

## 22. Financial Snapshot Architecture

Money that has been decided is a **fact**.

### 22.1 Snapshot family

| Snapshot | When | Immutable? |
|---|---|---|
| Fare snapshot | Booking confirm | Yes |
| Payment responsibility | Confirm (updated only by adding transactions, not by rewriting history) | Plan is locked; collections append |
| Finance snapshot (85/15 P&L) | Normally DELIVERED; also terminal cancel/fail as needed | Yes |
| Cancellation snapshot | On cancel | Yes |
| Failed-delivery / resend snapshot | When those events happen | Yes |
| COD ledger rows | When cash creates due or settlement runs | Yes (append-only) |

### 22.2 Finance snapshot fields (minimum)

- order_id
- snapshot_kind: ORIGINAL | REVERSAL | ADJUSTMENT_FREEZE
- trip / ride amount (confirmed Trip Fare)
- rider %
- company %
- operational % of commission
- rider amount
- company commission amount
- operational amount
- profit amount
- payment_settings_version_id
- frozen_at

**One order may have more than one finance snapshot row.**  
The original row is never updated.

One rupee of extra money has **one** business fact (cancellation snapshot, resend snapshot, or office adjustment). A finance freeze row, if needed, **copies** that fact for P&L reports. Do not store the same rupee three times as three independent truths.

Reports:

```text
SUM(snapshot amounts) WHERE kind and not reversed
```

Never:

```text
calculateDistribution(old_order.trip_fare, todays_admin_settings)
```

### 22.3 Who pays does not change P&L

Customer ₹100 cash, Receiver ₹100 online, or ₹50/₹50 — if Trip Fare is ₹100, rider is still ₹85, company is still ₹15, operations ₹7.50, profit ₹7.50.

---

## 23. Invoice Architecture

An invoice is a **financial document**, not the trip ID reprint.

### 23.1 Rules

- Invoice number ≠ trip ID
- Show **Trip Fare**, discount, extras, and the **billed applicable amount**
- That billed total is the full customer/receiver bill — not one payer’s share (do not print ₹50 as the invoice total when the bill is ₹100)
- Show Customer Paid and Receiver Paid separately
- GST on fare = ₹0
- Do **not** require GST charges, SAC, GSTIN, or e-invoice. Those remain **FUTURE BUSINESS DECISION** for legal letterhead
- Built from snapshots, not live Admin rates
- PDF generated by a worker, stored privately
- Email failure does not un-pay a payment
- Retrying invoice generation returns the **same** invoice number and the same snapshot amounts (idempotent)

### 23.2 Contents (conceptual)

- invoice number, issue time, status (draft / issued / cancelled)
- order display id + internal id
- optional legal letterhead placeholders only (**FUTURE BUSINESS DECISION:** GSTIN, SAC, e-invoice — do not invent and do not treat as required)
- trip fare, discount, additional locked charges, rounding, payable
- payer breakdown
- payment transactions summary
- payment status
- rider/company lines are internal; customer invoice should not be forced to show 85/15 unless product later asks

Issue after delivered (and after P&L freeze) for a completed trip.  
Cancelled / failed documents follow the snapshot that actually applied.

---

## 24. Admin Configuration & Versioning

Any setting that can change future money must be versioned.

```text
version
status (draft / active / superseded)
effective_from
effective_until (optional)
created_by
created_at
payload (the actual numbers)
```

Examples:

- Fare / vehicle category rates
- 85 / 15 / 50 payment settings
- Cancellation rules
- Company office
- COD suspend threshold (₹100 is FINAL today; still version it)
- Resend / office per-km rates (Case A/B and ₹8/km office extra are FINAL today; still version them so a later edit cannot rewrite old trips)
- Enabled payment methods (cash / online)

**Rule:** never overwrite a version that orders already pointed to.

Audit every publish.

---

## 25. Company Office Architecture

**FINAL:** Admin configures address, latitude, longitude. Apps must not keep a permanent hardcoded office as authority.

Store:

- current office version
- address
- lat / lng
- city
- effective dates
- created_by

Failed delivery copies the **office snapshot** onto the event so a later office move does not change old km and ₹8 compensation.

Multiple offices later (more cities) can be added as more records. V1 can have one active office per launch city.

---

## 26. Vehicle Architecture

### 26.1 Category is the sellable type

Admin vehicle-category master is the source of truth.

Join by **category id**, never by the word `"Bike"` or `"Auto"`.

Scooty / scooter is a **vehicle subtype** under Bike, not a separate V1 category unless Admin later creates one.

Orders store:

- vehicle_category_id
- category name snapshot
- optional vehicle_id of the assigned rider vehicle

### 26.2 Vehicle instance (rider)

- belongs to a rider (nullable if unassigned in Admin fleet)
- registration / RC fields
- subtype (bike / scooter) when relevant
- documents

### 26.3 Driver

Optional driver record so owner ≠ driver can be stored later.  
V1 app: same person. This is an architecture placeholder, not a fleet product.

**FUTURE BUSINESS DECISION:** multi-driver fleet.

---

## 27. Document / Bank / UPI Architecture

### 27.1 Documents (Rider KYC)

- metadata in PostgreSQL
- file bytes in object storage
- status: uploaded / approved / rejected
- virus scan ARCHITECTURE READY
- Admin Operations approves

### 27.2 Bank / UPI

- rider payout destination
- encrypt or tokenize at rest
- display masked
- never log full account numbers
- Finance-only full reveal with audit

### 27.3 Customer documents

Not required for V1 booking. Do not invent KYC as mandatory.

---

## 28. Notification Architecture

**CURRENTLY IMPLEMENTED:** mock banners / in-app copy.  
**ARCHITECTURE READY:**

- per-user inbox (**TECHNICAL DESIGN OPTION:** scope by identity or by profile)
- unread counter
- dedupe by notification id
- push (FCM or equivalent) for background
- Admin campaigns via workers

No V1 in-app chat (FINAL).  
Calls must **mask** counterpart numbers. Raw phone reveal is Admin/RBAC only.

Do not block architecture on chat.

---

## 29. Audit Log Architecture

Append-only. Never update. Never hard-delete.

Minimum fields:

- actor identity + profile + role
- action
- entity type + entity id
- old value
- new value
- reason (where Admin is asked for one)
- request id
- timestamp
- IP / user agent where useful

Must audit:

- fare publishes
- payment settings publishes
- cancellation rule publishes
- office changes
- wallet adjustments
- COD adjustments
- order financial adjustments
- admin permission changes
- rider approve / reject / suspend
- refunds

Financial audit + Admin audit can be one log with a `category`, or two tables with the same shape. **TECHNICAL DESIGN OPTION.** The requirement is: a reviewer can answer who/what/when/old/new.

---

## 30. Idempotency Architecture

Retries will happen. Money must not double.

**Idempotency means:** if the same request is accidentally sent twice, the system performs the money (or status) operation only once.

### 30.1 Where idempotency is mandatory

| Operation | Key idea |
|---|---|
| Create order | Client idempotency key |
| Rider accept | offer_id + rider_id |
| Payment create | client key |
| Payment webhook | provider event id (unique) |
| Wallet recharge | client key + provider id |
| COD settlement | (rider_id, source_txn_id) unique |
| Cancel | order_id + actor + attempt key |
| Resend request | order_id + case |
| Invoice generate | order_id + invoice type unique; retry returns the same invoice |
| Status update | event idempotency key |
| Cancel vs accept | whoever commits the order lock first wins; the other fails cleanly |

### 30.2 How

Store idempotency records:

- key
- actor
- request hash
- response / resulting entity id
- created_at

Same key + same body → return original result.  
Same key + different body → reject.

**WHAT:** remember the first successful side effect.  
**WHY:** mobile networks retry.  
**PREVENTS:** two orders, two accepts, two credits.  
**SCALES:** unique index lookups, not full table scans.

---

## 31. Concurrency & Transaction Safety

### 31.1 Operations that need a real database transaction

| Operation | Lock / constraint | Failure if skipped |
|---|---|---|
| Two riders accept one order | Lock order + unique accepted offer | Double assignment |
| Rider accept while COD ≥ ₹100 | Check COD inside the same transaction | Suspended rider takes a job |
| Status transition | Compare-and-set current status | Impossible jumps / lost updates |
| Cash confirm + COD Due | Lock rider finance | Wrong due |
| Online earning + COD settle | Lock rider finance | Double wallet or leftover due |
| Recharge | Lock rider finance | Due not cleared |
| Webhook PAID | Unique provider event | Double pay |
| Cancel + fee credit | Lock order + rider finance | Double fee |
| Finance snapshot freeze | Insert-only; unique original kind per component | Mutated history |
| Invoice issue | Unique invoice for that order type | Two invoice numbers |
| Cancel vs accept at the same time | Lock the order first; cannot accept a cancelled order; cannot cancel an already-assigned order unless the cancel rule for that new stage allows it | Rider assigned after customer thought they cancelled, or cancel after accept with the wrong snapshot |
| Two status updates at once | Compare-and-set: update only if current status is still the expected from_status | Lost updates / illegal jumps |
| Recharge and earning at once | Same rider finance lock as other money | Double settle or skipped COD |
| Two webhooks at once | Unique provider event id + lock the payment row | Double PAID |

### 31.2 Accept race (must-win design)

```text
BEGIN
  lock order
  if status not OFFERED/SEARCHING → reject
  if another accepted offer exists → reject
  insert/accept offer as ACCEPTED
  set rider_id, status ASSIGNED
  write status event
COMMIT
```

Second rider gets a clean “already accepted” error.  
Repeat accept by the **same** rider is idempotent.

### 31.3 What we prevent

- double earning
- double payment
- double settlement
- double acceptance
- accept after cancel (or cancel after accept using the wrong stage)
- negative wallet
- duplicate webhook effects
- duplicate invoices

---

## 32. Security Architecture

### 32.1 Authentication

- OTP hashed server-side
- Admin passwords hashed server-side
- Rate-limit OTP and login by phone + IP
- Session revocation
- Separate tokens per app profile

### 32.2 Authorization

- RBAC for Admin
- Object-level checks for orders, wallets, files
- Never trust client-sent “I am finance”, “I am the rider”, or a client-chosen profile id
- Server loads identity and profile from the **session**, then checks the object (this order, this wallet, this file)

### 32.3 Data protection

- TLS in transit
- Encrypt/tokenize bank and national IDs at rest
- Mask phones in counterpart UIs
- No secrets in git, app binaries, or Admin JS
- Secret manager for DB, SMS, payment, JWT, webhook signing

### 32.4 Application safety

- Parameterized SQL only
- Input validation at API edge
- Webhook signature verification
- Idempotency on money APIs
- Signed, short-lived download URLs for invoices and KYC
- Fraud watches: many failed OTPs, many unpaid online intents, unusual COD spikes

### 32.5 What not to store

- Card PAN / CVV
- Raw OTP
- Payment provider private keys
- Signing keystores in the database

---

## 33. API Architecture — HIGH LEVEL ONLY

One versioned HTTPS API, e.g. `/v1`.

### 33.1 Style

**TECHNICAL DESIGN OPTION:** resource-oriented HTTPS JSON.

Suggested resource groups:

- `/auth` — OTP, session, logout
- `/me` — identity + profiles
- `/customer/orders` — create, read, cancel, resend
- `/customer/addresses`
- `/rider/offers` — incoming, accept, reject
- `/rider/orders/{id}` — status commands
- `/rider/wallet` — balance, ledger, recharge
- `/admin/orders` — search, assign, cancel
- `/admin/settings/fare|payments|cancellation|office`
- `/admin/riders` — approve, suspend
- `/webhooks/payments` — provider only
- `/invoices/{id}` — authorized download

Realtime (**ARCHITECTURE READY**):

- WebSocket or equivalent for offer + live order + last GPS
- Push for background
- Admin dashboard: short-interval aggregate poll, not “download all orders every second”

### 33.2 API rules

- Backend validates fare; client quote is advisory
- Backend transitions status
- Pagination is cursor-based on all lists
- Every money POST requires an idempotency key

No detailed endpoint catalog in this file. That is a later API contract phase.

---

## 34. PostgreSQL Architecture — HIGH LEVEL ONLY

PostgreSQL is the **system of record**.

This section is not DDL.

### 34.1 Why PostgreSQL

- Relational orders, stops, payments, and ledgers fit SQL
- Transactions and constraints match money
- Proven at large scale with replicas and partitioning
- FINAL audit already said: design from rules, then implement Postgres

### 34.2 Design posture

- UUID primary keys (time-sortable)
- Unique display_id
- Foreign keys for all relationships
- Check constraints for:
  - customer_responsibility + receiver_responsibility = total
  - cancellation shares = 100
  - payment setting percentages = 100
  - wallet ≥ 0
  - COD Due ≥ 0
- Append-only ledgers and snapshots
- Soft delete for master data (customers, riders, categories)
- **No hard delete** of financial rows

### 34.3 What not to implement from old blueprints

- one payment row per order as complete truth
- COD as negative wallet
- unique finance snapshot that blocks reversals
- invoice tax 5%
- two unrelated unique phones as two humans

### 34.4 Connection management

- Connection pool (PgBouncer or equivalent) in front of Postgres
- Short transactions
- Workers use a separate pool from API

Firebase is **not** the production database.

---

## 35. Indexing Strategy

Design indexes for the queries the business actually runs.

| Need | Index idea |
|---|---|
| Customer order list | (customer_id, created_at desc) |
| Customer active trips | (customer_id, status) where status not terminal |
| Rider active / history | (rider_id, status, created_at desc) |
| Dispatch offers | (order_id), (rider_id, status) |
| Admin city ops | (city_id, status, created_at desc) |
| Display ID lookup | unique display_id |
| Payment webhook | unique provider_event_id |
| Payment by order | (order_id, created_at) |
| Wallet ledger | (wallet_id, created_at) |
| COD due list / suspend | (cod_due) or filtered status on rider |
| Idempotency | unique (scope, key) |
| Audit by entity | (entity_type, entity_id, created_at) |

Use cursor pagination (`created_at, id`), not `OFFSET` for deep pages.

Partition **readiness** (not day-1 action): orders, status events, payment transactions, wallet transactions, audit logs by month/created_at once volume justifies it.

---

## 36. Data Integrity Rules

1. Identity is the only login entity. Profiles do not have independent passwords.
2. Orders belong to **customer profile** id. rider_id is **rider profile** id or null. Never identity_id, name, or phone.
3. Stops are rows with sequence. Sequence is unique per order.
4. One accepted offer per order.
5. Fare snapshot exists before searching becomes money-binding.
6. Responsibility sums to the applicable **bill** total. That bill total is not the 85/15 base. Planned methods per payer sum to that payer’s responsibility.
7. Transaction PAID online requires provider confirmation.
8. Aggregate payment status is computed from PAID transactions.
9. 85/15 uses fare snapshot trip fare.
10. Finance snapshots are insert-only.
11. Wallet change ⇔ ledger row in one transaction.
12. COD Due change ⇔ COD ledger row in one transaction.
13. Cancellation shares = 100 and come from a versioned rule.
14. Resend Case A/B stored explicitly.
15. Invoice shows Trip Fare and the full billed amount; never one payer’s share as the invoice total. GST on fare = ₹0.
16. Display ID unique; invoice number unique; neither is the PK.
17. Soft-delete masters; never erase money.
18. Admin config changes are new versions.

---

## 37. Reporting & Analytics Architecture

Reports must not lock or rewrite transactional tables more than necessary.

### 37.1 What reports must be able to answer

- Total / completed / cancelled / failed trips
- Trip Fare, discounts, extras
- Rider earnings
- Company commission, operations allocation, net profit
- COD outstanding and settlements
- Wallet movements
- Collections: cash vs online
- Customer vs Receiver paid
- Resend volume and Case A vs B
- Cancellation fees collected

### 37.2 How

**Phase 1:** SQL over snapshots + ledgers with date filters and indexes.  
**Phase 2:** worker-maintained daily counters (city, day, status, fare, commission).  
**Phase 3:** read replica or warehouse if Admin analytics starts hurting bookings.

**Rule:** reports sum **snapshots and ledgers**, never live Admin percentages on old orders.

Admin browser must not download the entire order table to compute Today/Week/Month.

Purchase invoices (real vendor spend) stay **separate** from the 50% operations allocation.

---

## 38. Backup & Disaster Recovery

Financial data is more important than cache.

| Control | Requirement |
|---|---|
| Automated backups | Daily full + continuous WAL for point-in-time recovery |
| Retention | Keep financial PITR longer than cache/redis |
| Replica | Streaming replica as soon as production has real money |
| Restore tests | Practice restore on a schedule; an untested backup is a hope |
| Integrity checks | Reconcile wallet vs ledger; COD vs ledger; snapshot vs payments |
| Secrets | Backed up in secret manager, not in SQL dumps as plaintext if avoidable |
| Redis / GPS | Rebuildable; not the recovery target |
| Object storage | Versioned KYC / invoice files; separate from DB backup |
| RPO / RTO | Set before launch. **FUTURE BUSINESS / OPS DECISION** for exact minutes. Architecture assumes PITR is mandatory for Postgres |

If a region fails: promote replica, point API at new primary, replay pending webhooks using idempotency.

---

## 39. 10M+ User Scalability Strategy

Do **not** start with microservices.

### Phase 1 — Correct modular core

- One API
- PostgreSQL
- Strong constraints, indexes, idempotency
- Cursor pagination
- Connection pooling

**Why:** correctness first. 10M users on a wrong money model is a disaster.

### Phase 2 — Cache and background work

- Redis: last GPS, unread counts, short dashboard cache, rate limits
- Workers: SMS, invoice PDF, webhooks, daily stats, campaign fan-out
- Outbox pattern for “DB commit then notify”

**Why:** take bursty and slow work off the booking transaction.

### Phase 3 — Read / write separation

- Read replica for Admin reports and history
- Keep accept / pay / wallet on primary

**Why:** reporting should not stall rider accept.

### Phase 4 — Split only where measured

Candidates **if** a real bottleneck exists:

- Notification service
- GPS ingest
- Analytics warehouse

Do **not** split Order vs Wallet vs COD early. Those must stay transactional.

### Horizontal notes

- Stateless API instances behind a load balancer
- Shard-by-user is **not** day-1
- Partition large append-only tables by time when they are huge
- Hot rider locks stay per rider — that is the intended contention grain

---

## 40. Future Evolution Strategy

The model should allow these **without rewriting old money**:

| Future | How the architecture absorbs it |
|---|---|
| More cities / countries | city/country masters; display ID city code; office per city |
| More vehicle categories | Admin create; orders keep id + name snapshot |
| More payment providers | provider column + webhook adapters; old txns stay |
| More methods | new method enum value; old rows unchanged |
| Promotions / referrals | separate program tables; amounts not hardcoded from dummy ₹200/₹50/₹150 |
| Subscriptions / corporate | new payer account type **later**; do not invent now |
| Receiver app | already a payer_type; app can appear without schema rewrite |
| Ratings | one rating per order per direction when product decides |
| Scheduling | nullable scheduled_at already reserved |
| New financial model | new settings version; old snapshots remain 85/15 history |

Never “upgrade history” by recalculating 2026 trips with 2028 rates.

---

## 41. Scenario Validation

### Scenario 1 — Same person Customer + Rider

Same phone → one identity → customer profile + rider profile.  
Customer app cannot accept rides. Rider app cannot book as a customer.  
**Pass.**

### Scenario 2 — Customer pays full amount

If Trip Fare ₹100 and no discount: responsibility customer ₹100.  
Rider ₹85, company ₹15, operations ₹7.50, profit ₹7.50.  
**Pass.**

### Scenario 3 — Receiver pays full amount

Responsibility: customer 0, receiver 100. 85/15 unchanged. Receiver app not required.  
**Pass.**

### Scenario 4 — Customer + Receiver split

Responsibility 50 + 50. If receiver unpaid: overall PARTIALLY_PAID. Invoice still shows the full bill, plus Customer Paid / Receiver Paid.  
**Pass.**

### Scenario 5 — Customer Online + Cash split

Two transactions. Online stays PENDING until provider confirms.  
COD Due depends on **cash collected vs rider earning**, not on “online exists”.  
**Pass.**

### Scenario 6 — COD collection

Trip Fare ₹100, cash ₹100: physical cash ₹100, earning ₹85, COD Due ₹15, wallet unchanged.  
That ₹85 cash earning is not posted to wallet and does not settle this COD Due.  
**Pass.**

### Scenario 7 — COD Due reaches ₹100

Rider cannot accept **new** rides. Existing assigned trip can finish.  
**Pass.**

### Scenario 8 — Recharge while COD is due

COD Due ₹100, recharge ₹150 → settle ₹100, wallet ₹50.  
**Pass.**

### Scenario 9 — Two riders accept simultaneously

Order lock + unique accepted offer. One wins.  
**Pass.**

### Scenario 10 — Duplicate payment webhook

Unique provider event id. Second delivery is a no-op.  
**Pass.**

### Scenario 11 — Admin changes fare

Old fare snapshot + finance snapshot unchanged. Reports use snapshots.  
**Pass.**

### Scenario 12 — Admin changes cancellation rule

New version only. Already-cancelled trips keep their snapshot.  
**Pass.**

### Scenario 13 — Cancellation with ₹0 fee

Allowed if that actor/stage is enabled. Snapshot still written (fee 0). No 85/15 earning invented.  
**Pass.**

### Scenario 14 — Cancellation with configured fee

Fee uses snapshotted rider%/company%, not 85/15. Rider share credited, then COD settlement if digital.  
**Pass.**

### Scenario 15 — Failed delivery

Not a cancel. Original 85/15 stays. Reason `receiver_unavailable`.  
**Pass.**

### Scenario 16 — Office handover

₹8/km to rider, not 85/15. Office lat/lng snapshotted.  
**Pass.**

### Scenario 17 — Resend Case A

Original ended. Customer pays **resend-time** base + ₹10/km. 85/15 on that resend amount. Original fare untouched.  
**Pass.**

### Scenario 18 — Resend Case B

Original not ended. ₹10 / ₹8 / ₹2 per km. Not 85/15. Original fare untouched.  
**Pass.**

### Scenario 19 — Invoice generation retry

Same invoice number, same snapshot amounts. PDF/email failure does not un-pay.  
**Pass.**

### Scenario 20 — Wallet + COD concurrent transactions

One rider finance lock. No double settle, no negative wallet.  
**Pass.**

### Scenario 21 — Historical report after Admin configuration changes

Reports sum snapshots and ledgers. Live settings are ignored for old rows.  
**Pass.**

### Scenario 22 — Same order viewed by Customer / Rider / Admin

Same UUID, same display ID, same status, same money facts. Labels may differ.  
**Pass.**

### Scenario 23 — 10M+ user growth

Modular monolith, indexes, cursors, per-rider locks, later workers/Redis/replicas/partitions. Not instant microservices.  
**Pass as a growth path.**

---

## 42. Architecture Risks

| Risk | Severity | Mitigation |
|---|---|---|
| Implementing from old `05` / leftover `18` C–D–L–M | High | This document + RULES_BOOK win |
| Mock apps remain source of truth too long | High | Backend becomes only writer |
| Faking online PAID | High | Forbidden until provider webhook |
| Mixing transaction status with aggregate status | High | Two different fields |
| Unique finance snapshot blocking reversals | High | Multiple snapshot rows |
| COD stored as negative wallet | High | Separate COD ledger |
| Two identities per phone | High | Identity + profiles |
| Dispatch algorithm undecided | Medium | Lock + offer table ready; algorithm is a later decision |
| OTP / SMS provider undecided | Medium | Challenge table ready |
| Statutory invoice legal IDs undecided | Medium | Invoice structure ready; do not invent GSTIN/SAC |
| Extra multi-stop fee undecided | Low | Do not add a fee |
| Reporting on primary under load | Medium | Aggregates + replica later |
| Over-splitting into microservices | High | Modular monolith first |
| Untested backups | High | Scheduled restore drills |

---

## 43. Technical Decisions

These are architecture choices that implement FINAL rules. They are **not** new commercial fees.

| Decision | Choice |
|---|---|
| Database | PostgreSQL as system of record |
| Backend | Modular monolith first |
| Identity | One identity, many profiles |
| Order PK | UUID (time-sortable) + unique display_id |
| Money | Integer minor units **or** numeric(12,2) with a single rule — TECHNICAL DESIGN OPTION at schema time. Pick one and use it everywhere |
| Snapshots | Insert-only; reversals are new rows |
| Payments | Responsibility + many transactions |
| COD | Own ledger; wallet never negative from COD |
| Config | Versioned; never mutate published versions used by orders |
| Realtime | WS/push ARCHITECTURE READY; not required to start schema |
| Cache | Redis later for GPS/unread/rate-limit |
| Files | Object storage for KYC / POD / invoice PDF |
| API pages | Cursor pagination |
| Accept | Transaction + lock + unique winner |
| Webhooks | Signature + unique event id |
| Secrets | Environment / secret manager only |
| Firebase DB | Not used as production store |

---

## 44. Future Business Decisions

Do **not** treat these as decided.

| Topic | Why it waits |
|---|---|
| OTP length, SMS provider, expiry, lockout | Auth columns can exist without the policy numbers |
| Extra multi-stop fee | Max 3 drops locked; no extra fee today |
| Owner vs hired multi-driver fleet | Optional driver record is enough |
| Referral / promo program | Dummy ₹200 / ₹50 / ₹150 must not be merged |
| Customer wallet KYC / min-max / auto-debit | Ledger can exist without limits |
| Online in first launch vs cash-first | Transaction model already supports both |
| Authorize at booking vs capture at delivery | Integration choice |
| Payment provider vendor | Adapter, not a business fare rule |
| Rating rider→customer, edit, public comments | Customer→rider can persist first |
| Pickup/drop contacts required? | Nullable fields ready |
| Search TTL / radius / broadcast vs sequential | Offer table + locks ready |
| Statutory SAC / GSTIN / e-invoice | Fare GST is ₹0; legal header later |
| Exact RPO/RTO minutes | Ops policy |
| Chat | Not V1 |
| Scheduled booking product | Nullable timestamp only |
| Cash collected from whom if payer ≠ booker | Architecture records payer_type; do not invent pickup vs drop as a fee rule |
| Admin manually assigns a second live trip to one rider | Auto second trip is forbidden; manual second trip not decided |
| Close failed delivery without resend | No invented status or fee |

---

## 45. Implementation Boundaries

### Do now (this document only)

- Treat this file as the architecture blueprint for the next PostgreSQL design phase

### Do next (separate approved phase)

- Design actual PostgreSQL schema from **this file + RULES_BOOK + 18 D2 + 19**
- Then API contracts
- Then replace mocks as the backend becomes the writer

### Do not do from this document

- No application code changes
- No Flutter / React / Node implementation
- No CREATE TABLE / migrations
- No payment vendor contract
- No UI/theme work
- No inventing fees
- No Receiver app
- No microservices split
- No rewrite of existing `records_database` files

### Honest current vs future

| Item | Now |
|---|---|
| Shared engines | CURRENTLY IMPLEMENTED |
| Shared rows | IMPLEMENTATION PENDING BACKEND |
| Gateway | ARCHITECTURE READY / PENDING |
| Postgres | FUTURE IMPLEMENTATION |
| 10M users | DESIGNED FOR, not operating today |

---

## 46. FINAL ARCHITECTURE CHECKLIST

| # | Check | Result |
|---|---|---|
| 1 | Identity ≠ role profile | YES |
| 2 | Same phone can be Customer + Rider | YES |
| 3 | Order is the hub; UUID + display ID | YES |
| 4 | Stops are ordered rows; max 3 drops | YES |
| 5 | One canonical status + history | YES |
| 6 | Fare version ≠ fare snapshot | YES |
| 7 | 85/15 on confirmed Trip Fare | YES |
| 8 | Discount does not reduce rider share | YES |
| 9 | WHO PAYS ≠ HOW THEY PAY | YES |
| 10 | Many payment transactions | YES |
| 11 | Aggregate UNPAID / PARTIALLY_PAID / PAID | YES |
| 12 | Transaction PENDING / PAID / FAILED / REFUNDED | YES |
| 13 | Online PAID only after provider confirm | YES |
| 14 | COD Due ≠ wallet | YES |
| 15 | Wallet never negative from COD | YES |
| 16 | Recharge / earnings settle COD first | YES |
| 17 | Suspend at COD Due ≥ ₹100 | YES |
| 18 | Cancellation Admin-versioned, default ₹0, shares = 100% | YES |
| 19 | Cancel ≠ failed delivery | YES |
| 20 | Resend Case A 85/15; Case B ₹8/₹2 | YES |
| 21 | Office extra ₹8/km separate | YES |
| 22 | Historical snapshots immutable | YES |
| 23 | Invoice number ≠ trip ID; full total | YES |
| 24 | GST on fare = ₹0 | YES |
| 25 | Admin config versioned | YES |
| 26 | Company office Admin-owned | YES |
| 27 | Vehicle joins by id, not name | YES |
| 28 | Audit who/what/old/new/when | YES |
| 29 | Idempotency on money and accept | YES |
| 30 | Accept race serialized | YES |
| 31 | Webhook double-delivery safe | YES |
| 32 | Security: OTP hash, RBAC, secrets manager | YES |
| 33 | Modular monolith, not instant microservices | YES |
| 34 | Reports from snapshots | YES |
| 35 | Backup / PITR required for money | YES |
| 36 | 10M path without breaking history | YES |
| 37 | No invented business fees | YES |
| 38 | Stale 04/05/18 leftovers not revived | YES |
| 39 | Receiver is a payer, not an app | YES |
| 40 | Apps are not the source of truth | YES |

---

## Connected chain (read this as one system)

```text
Identity
  → Customer / Rider / Admin profiles
    → Order (UUID + IU-AMD-##########)
      → Stops, status events, offers
        → Fare snapshot (Trip Fare locked)
          → Payment responsibility (who owes) + payment plan (how they intend)
            → Payment transactions (who paid, how, PENDING/PAID/FAILED/REFUNDED)
              → Finance snapshot (85/15 on Trip Fare; ops/profit from company share)
                → Wallet ledger + COD ledger
                  → Invoice (full total, separate paid lines)
                    → Audit + reports from facts, not from today’s settings
```

If that chain stays intact, IDHAR UDHAR can grow from mock apps to a production financial system without rebuilding its memory every time Admin changes a rate.

---

**End of MASTER SYSTEM ARCHITECTURE (corrected body)**

The audit trail below records what was reviewed and changed. It does **not** replace sections 1–46.

---

# MASTER ARCHITECTURE AUDIT

Reviewed against, in order: `RULES_BOOK.md` → `18_FINAL_BUSINESS_DECISIONS.md` (confirmed / D2 / status table 5, 12, 13) → `19_DATABASE_REQUIREMENTS_FROM_FEATURES.md` → `FINAL_MASTER_ANALYSIS.md` → `FINAL_DATABASE_AUDIT.md` → `OPEN_QUESTIONS.md` → this architecture.

Stale leftovers (`18` C / D / L / M money table, `04`/`05` single payment, `08` 5% GST) were **not** treated as rules.

| # | Area | Status | Finding | Required Correction |
|---|---|---|---|---|
| 1 | Financial examples | CORRECTION REQUIRED | 85/15 on Trip Fare was correct, but several worked examples omitted Company Operations ₹7.50 / Net Profit ₹7.50. A later implementer could treat operations as a rider deduction or forget it. | Show the full ₹100 → ₹85 / ₹15 → ₹7.50 / ₹7.50 picture wherever fare P&L is taught. |
| 2 | COD physical cash | CORRECTION REQUIRED | Text said the rider “keeps ₹85 as earning (physical cash).” Locked example is physical cash ₹100, earning ₹85, COD Due ₹15. | Use the locked cash picture. Wallet unchanged. |
| 3 | COD vs wallet posting | CORRECTION REQUIRED | “Eligible earnings settle COD first” could be read as posting the cash-trip ₹85 into the wallet, which would wrongly settle that trip’s own ₹15 due. Shared `CodEngine` already treats cash company due separately. | State: cash-trip rider share is physical, not a wallet credit, and does not settle that trip’s COD Due. |
| 4 | Payment bill vs 85/15 base | CORRECTION REQUIRED | Responsibility “applicable total” was described as net payable. That is right for **who owes**, but someone could use ₹90 as the 85/15 base. | Explicitly split bill total (responsibility) from Trip Fare (85/15). |
| 5 | Payment plan missing on the order map | CORRECTION REQUIRED | Responsibility, transactions, and aggregates existed. The intended-method **plan** was in §16.2 but not named on the order diagram. User requirement: responsibility ≠ plan ≠ transaction ≠ aggregate. | Add payment plan to the order map and add a four-layer table. |
| 6 | Aggregate PAID formula | CORRECTION REQUIRED | “Paid ≥ owed” allowed silent overpay to count as PAID. | PAID only when paid equals owed after rounding. Overpay needs adjustment/refund. |
| 7 | Identity vs old `(role, phone)` notes | CLARIFICATION REQUIRED | One-identity model is correct and matches the locked “same phone may be Customer and Rider” rule. Older audit text about unique `(role, phone)` could be copied as two logins. | Explain that `(role, phone)` was “both roles allowed,” not two auth users. |
| 8 | Order foreign keys | CORRECTION REQUIRED | `customer_id` / `rider_id` were not explicitly profile ids. Using `identity_id` on the order would blur booker vs rider for one human. | FKs are Customer profile and Rider profile. Never identity, name, or phone. |
| 9 | Invented failed-closed status | CORRECTION REQUIRED | §14.3 invented a “failed-closed” terminal if Admin closes without resend. | Remove it. Mark close-without-resend as FUTURE BUSINESS DECISION. No invented fee. |
| 10 | Second live trip wording | CLARIFICATION REQUIRED | “At most one active delivery unless a later rule changes” could be read as a new lock. FINAL text is: rider does **not automatically** take a second live trip. | Match FINAL wording. Manual Admin second assign = FUTURE BUSINESS DECISION. |
| 11 | Resend Case A storage | TECHNICAL DESIGN OPTION | “Usually a new related order” sounded like a hidden product rule. | Mark child-order vs related record as a technical option. Money rules stay the same. |
| 12 | Case A rate timing | CORRECTION REQUIRED | “Current rate-sheet” was correct but easy to confuse with the **original** trip fare or a later Admin edit. | Snapshot the rate sheet **at resend time**. Never overwrite the original fare snapshot. |
| 13 | Resend/office rate versioning | CORRECTION REQUIRED | Fare, 85/15, cancel, and office were versioned. ₹10/₹8/₹2 and office ₹8/km were FINAL numbers but not listed as versioned config. | Version those rates too, like the ₹100 COD threshold. |
| 14 | Cancel vs accept race | CORRECTION REQUIRED | Accept-vs-accept and cancel+fee were listed. Cancel-at-the-same-moment-as-accept was not. | Lock the order. First commit wins. No accept of a cancelled order. |
| 15 | Concurrent money races | CORRECTION REQUIRED | Rider finance lock existed, but recharge+earning together, two webhooks together, and two status updates were not all spelled out. | Add those rows to the concurrency table. |
| 16 | Invoice meaning | CLARIFICATION REQUIRED | “Full applicable amount” could be read as Trip Fare, or as one payer’s share, or as requiring GSTIN. | Invoice shows Trip Fare + billed total. Not one payer’s share. GST ₹0. SAC/GSTIN/e-invoice remain FUTURE BUSINESS DECISION. Invoice retry is idempotent. |
| 17 | One rupee, three records | CLARIFICATION REQUIRED | Adjustment + resend snapshot + finance freeze could be implemented as three independent truths. | One business fact; finance freeze may copy it for P&L. |
| 18 | Admin cancel fees | CLARIFICATION REQUIRED | Admin may cancel until terminal. A separate Admin fee table was not locked. | Fee only from a versioned snapshotted rule. Do not invent an Admin fee schedule. |
| 19 | Conceptual entity list | CORRECTION REQUIRED | Needed entities were spread across chapters. A future schema designer could invent extras or miss payment plan. | Add a conceptual entity catalog. Not SQL. |
| 20 | Idempotency language | CORRECTION REQUIRED | Mechanism was right; the simple definition was thin. | Add: if the same request is sent twice, money runs once. |
| 21 | Client role claims | CORRECTION REQUIRED | “Do not trust I am finance” was present; profile impersonation was not explicit. | Session decides identity/profile. Then object-level checks. |
| 22 | Cash collection point | FUTURE BUSINESS DECISION | Collection at delivery was implied. 18 still asks who pays if not the booker. | Record payer_type. Do not invent pickup-vs-drop as a fee. |
| 23 | OTP / dispatch / promo / wallet KYC / capture moment / provider | FUTURE BUSINESS DECISION | Already marked. No change to a FINAL rule. | Leave open. |
| 24 | Money storage integer vs numeric | TECHNICAL DESIGN OPTION | Already marked. | Leave open; pick one at schema time. |
| 25 | Modular monolith | PASS | Correct and not over-engineered. | None. |
| 26 | Identity model | PASS (after #7) | One identity, many profiles. | Clarified only. |
| 27 | 85/15 base | PASS (after #1 and #4) | Confirmed Trip Fare, not discounted payable. | Examples completed. |
| 28 | Cancellation model | PASS (after #18) | Default ₹0, Admin, customer ≠ rider, shares = 100%, not auto 85/15. | Admin fee clarification only. |
| 29 | Failed delivery ≠ cancel | PASS | Office ₹8/km not 85/15. | None beyond Case A/B clarity. |
| 30 | Historical immutability | PASS (after #13) | Insert-only snapshots; new Admin versions. | Version resend/office rates. |
| 31 | No stale 04/05/18 leftovers revived | PASS | Document already rejected those. | None. |
| 32 | No invented GST | PASS | Fare GST ₹0. Legal IDs optional/future. | Invoice wording tightened. |

No fake issues were added beyond the real ones above.

---

# REQUIRED ARCHITECTURE CORRECTIONS

Each item below was applied in sections 1–46. **None of these change a locked business rule.** They only stop the architecture from being misread or from missing a safety net.

### Correction 1 — Complete the 85/15/50 example

1. **Problem:** Examples stopped at Rider ₹85 / Company ₹15.  
2. **Why:** Operations could be taken from the rider by mistake.  
3. **Correct:** Trip Fare ₹100 → Rider ₹85, Company ₹15 → Operations ₹7.50, Profit ₹7.50. Operations comes only from the company share.  
4. **Source:** `RULES_BOOK` Financial Rules; `18` CONFIRMED FINANCIAL MODEL.  
5. **Changes business rules?** No.

### Correction 2 — COD cash picture

1. **Problem:** “Keeps ₹85 as physical cash” hid that the rider is holding ₹100.  
2. **Why:** Wallet/COD implementers need the locked three numbers.  
3. **Correct:** Physical cash ₹100, earning ₹85, COD Due ₹15, wallet unchanged.  
4. **Source:** `RULES_BOOK` COD Rules; this audit’s COD section.  
5. **Changes business rules?** No.

### Correction 3 — Cash earning is not digital earning

1. **Problem:** Generic “eligible earnings settle COD” could include the cash trip’s own ₹85.  
2. **Why:** That would credit a wallet the rider does not have and erase COD Due incorrectly.  
3. **Correct:** Only digital inflows settle COD. Cash company share increases COD Due. Cash rider share stays physical.  
4. **Source:** `RULES_BOOK` / `CodEngine.addCashCompanyDue`.  
5. **Changes business rules?** No.

### Correction 4 — Bill total ≠ 85/15 base

1. **Problem:** Responsibility total (often ₹90) sat next to 85/15 without a hard fence.  
2. **Why:** Discount must not reduce rider share.  
3. **Correct:** Responsibility sums to the bill. 85/15 always uses confirmed Trip Fare.  
4. **Source:** `18` CONFIRMED FINANCIAL MODEL; `18` FINAL STATUS TABLE #6.  
5. **Changes business rules?** No.

### Correction 5 — Name the payment plan

1. **Problem:** Plan existed in prose, not on the order map.  
2. **Why:** A single `payment_method` could come back.  
3. **Correct:** Responsibility, plan, transactions, aggregates are four facts. Planned methods per payer sum to that payer’s responsibility.  
4. **Source:** `18` D2; `RULES_BOOK` Payment Rules.  
5. **Changes business rules?** No.

### Correction 6 — PAID means equal, not greater-or-equal

1. **Problem:** `paid ≥ owed`.  
2. **Why:** Silent overpay.  
3. **Correct:** PAID when paid equals owed after rounding. Extra money is an adjustment or refund.  
4. **Source:** Architecture safety; does not invent a new fee.  
5. **Changes business rules?** No.

### Correction 7 — Profile foreign keys

1. **Problem:** Order ids were not clearly profile ids.  
2. **Why:** One identity with two profiles would break “who booked / who delivered.”  
3. **Correct:** `customer_id` = Customer profile. `rider_id` = Rider profile.  
4. **Source:** Identity instruction + `18` #8.  
5. **Changes business rules?** No.

### Correction 8 — Remove invented failed-closed status

1. **Problem:** New terminal status was sketched.  
2. **Why:** Not a locked rule.  
3. **Correct:** FUTURE BUSINESS DECISION. No fee invented.  
4. **Source:** `OPEN_QUESTIONS.md`; do not invent.  
5. **Changes business rules?** No.

### Correction 9 — Resend Case A snapshot timing and storage option

1. **Problem:** “Current rate-sheet” + “usually a child order” mixed a technical choice with a money rule.  
2. **Why:** Original fare could be overwritten, or child order could be treated as mandatory product.  
3. **Correct:** Snapshot rates at resend time. Child order is a TECHNICAL DESIGN OPTION. Original snapshots stay.  
4. **Source:** `18` V1 rules 5–6; historical snapshot rule.  
5. **Changes business rules?** No.

### Correction 10 — Version resend/office rates

1. **Problem:** FINAL rupee-per-km rates were not in the versioned-config list.  
2. **Why:** A later Admin edit could rewrite history.  
3. **Correct:** Version them. Today’s numbers stay the locked defaults.  
4. **Source:** Historical transaction rules.  
5. **Changes business rules?** No.

### Correction 11 — Cancel/accept and other races

1. **Problem:** Missing races: cancel vs accept, recharge vs earning, two webhooks, two status updates, invoice retry.  
2. **Why:** Double assignment or dirty cancel snapshots.  
3. **Correct:** Order lock + rider finance lock + unique webhook id + compare-and-set status + unique invoice.  
4. **Source:** `18` O dispatch consistency; financial safety.  
5. **Changes business rules?** No.

### Correction 12 — Invoice, idempotency language, client claims, entity catalog

1. **Problem:** Easy to misread invoice total; idempotency not in plain words; client could send a fake profile; entities were scattered.  
2. **Why:** Future PostgreSQL work would invent or miss pieces.  
3. **Correct:** Tightened invoice; plain idempotency sentence; session-based authz; conceptual entity list.  
4. **Source:** `RULES_BOOK` invoice/payment; `18` Y, AA; this audit’s entity list.  
5. **Changes business rules?** No.

---

# FINAL ARCHITECTURE VALIDATION

| Check | Result |
|---|---|
| Business rules preserved | YES |
| Financial rules preserved | YES |
| COD model correct | YES |
| Payment model correct | YES |
| Identity model correct | YES |
| Order lifecycle correct | YES |
| Cancellation model correct | YES |
| Failed delivery/resend correct | YES |
| Historical money protected | YES |
| Auditability protected | YES |
| Concurrency protected | YES |
| Idempotency protected | YES |
| Security protected | YES |
| 10M+ growth path reasonable | YES |
| No invented business rules | YES |
| No stale architecture revived | YES |

**ARCHITECTURE STATUS: READY FOR NEXT PHASE**

Next phase (separate approval): PostgreSQL schema design from **this corrected file + RULES_BOOK + 18 D2 + 19**.  
No application code, UI, APIs, migrations, or tables were created in this audit.
