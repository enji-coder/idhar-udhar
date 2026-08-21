# IDHAR UDHAR — FINAL BUSINESS DECISION REFERENCE

**Status:** Living business-rule lock. Product features in Customer / Rider / Admin mock apps follow these rules. **PostgreSQL schema is still not implemented.**

**Last application re-analysis:** 2026-08-21 (final business-rule alignment). Current mock-app behavior: `FINAL_MASTER_ANALYSIS.md`. Simple rules: `RULES_BOOK.md`. Remaining unknowns: `OPEN_QUESTIONS.md` (no critical items). This file stays the V1 lock for future database work.

This file is the decision lock before database implementation.  
It does not rewrite `01`–`17`. Those remain discovery and blueprint.

**Sources used:** `records_database/00`–`17`, Customer app, Rider app, Admin panel, `Project_Documentation` functional/feature/scope docs.  
**Rule used:** If existing product + apps + architecture already determine the answer, it is finalized. If a money, legal, or operational rule is not defined, it is marked `⚠️ REQUIRES BUSINESS DECISION`. No invented fees, GST rates, SAC codes, or referral amounts.

---

## V1 PRODUCT RULES CONFIRMED (2026-08-21)

These are now confirmed business rules. Existing UI/theme remains frozen.

1. **No cancellation charges** in V1 **until Admin enables them**. Default fee is ₹0. Cancellation is Admin-configurable by stage, with **separate** customer and rider tables. Rider% + Company% must equal 100%. Cancellation is **not** auto 85/15.
2. **Failed delivery ≠ cancellation.** Receiver unavailable is a valid failed-delivery reason.
3. Company office is **Admin-configurable** (address, latitude, longitude). Apps must use the configured office, not a permanent hardcoded placeholder.
4. Original trip fare still uses **85/15** (and 50% operational allocation of commission) on **confirmed Trip Fare**, not on discounted payable. That snapshot is **immutable**.
5. **Resend Case B** (original rider trip **not** ended): customer ₹10/km; rider ₹8/km; company ₹2/km. Not 85/15.
6. **Resend Case A** (original rider trip **ended**): current rate-sheet base fare + ₹10/km. Both parts use normal 85/15.
7. Rider office handover extra for taking a parcel to office remains ₹8/km and is **not** 85/15.
8. Same mobile number may exist as **Customer and Rider** role accounts. Uniqueness is `(role, phone)`, never global phone.
9. One customer may create **multiple orders**, including multiple **active** orders. One rider does **not** automatically accept multiple simultaneous deliveries.
10. Booking may be **Single Location** or **Multiple Locations**. Stops are ordered rows with stable IDs and sequence — never a comma-separated string.
11. Multi-stop **extra fees** are not defined. Fare uses Admin fare table over total route distance. **Maximum delivery locations = 3** (customer may choose 2 or 3).
12. **NO GST** on customer fare. Flow: trip fare → discount → subtotal → rounding → net total.
13. Vehicle fare table is **Admin-controlled** with versioned snapshots. Historical orders do not move when Admin publishes a new version.
14. Customer / Rider / Admin must show the **same canonical order** (id + status + money). Mock apps share Dart/JS rule engines. **There is still no shared production database** — live row linking is **IMPLEMENTATION PENDING BACKEND**.
15. **WHO PAYS** (Customer / Receiver / split) is separate from **HOW THEY PAY** (Online / Cash / split). Partial payment **is supported**. Multiple payment transactions per trip. Status is UNPAID / PARTIALLY_PAID / PAID. A single `paymentMethod` field is not the source of truth.
16. COD Due is **not** a negative wallet. Eligible earnings and wallet recharge settle COD Due first. Rider is **suspended** when COD Due ≥ ₹100.
17. Existing UI/theme is frozen. Features were added with existing components only.

---

## CONFIRMED FINANCIAL MODEL (MUST NOT CHANGE)

This rule is final. Admin Payment Settings remain the configuration surface. Defaults:

| Setting | Default | Meaning |
|---|---|---|
| `rider_percentage` | 85% | Rider share of **ride amount** |
| `company_commission_percentage` | 15% | Company share of **ride amount** |
| `operational_cost_percentage_of_commission` | 50% | Taken **only from company commission** |

Validation before save:

- `rider_percentage + company_commission_percentage = 100%`
- All three percentages are numeric, `>= 0`, `<= 100`
- Reject save if the sum rule fails

Example (authoritative):

```text
Trip Fare                           = ₹100
Discount (customer)                 = ₹10
Customer pays                       = ₹90

Rider receives (85% of Trip Fare)   = ₹85
Company commission (15%)            = ₹15
Operational cost allocation (50% of ₹15) = ₹7.50
Actual company profit               = ₹15 − ₹7.50 = ₹7.50
```

**85/15 is never run on the discounted payable.** A ₹10 discount does not reduce the rider to ₹76.50.

**The operational cost is not deducted from the rider.** Rider share remains ₹85 in this example.

Formula:

```text
rider_amount           = ride_amount × rider_percentage / 100
company_commission     = ride_amount × company_commission_percentage / 100
operational_allocation = company_commission × operational_cost_percentage_of_commission / 100
actual_profit          = company_commission − operational_allocation
```

`Operational Cost Allocation` is an internal P&L allocation.  
It is **not** a vendor bill. `purchase_invoices` record actual expenses separately. Never add them into this allocation, and never use this allocation as if it were a paid vendor invoice.

Settings are versioned (`payment_settings_version`). Changing settings later must not rewrite old orders.

---

## HISTORICAL FINANCIAL SNAPSHOT (MANDATORY)

Admin may change percentages later. Historical orders must not be recalculated.

Each financially relevant order keeps an **immutable** `order_finance_snapshot` containing at least:

- ride / order amount
- rider percentage
- company commission percentage
- operational cost percentage (of commission)
- rider amount
- company commission amount
- operational cost amount
- actual profit amount
- applicable taxes / fees where relevant (copied, not recomputed)
- `payment_settings_version_id` / calculation version
- snapshot timestamp

Reports **must** sum snapshots.  
Reports **must never** re-run `calculateDistribution(order.amount, liveSettings)` on old rows.

If a snapshot must be reversed (refund / cancel after freeze), add a reversal row or a cancelled-finance flag. **Do not mutate the original snapshot.**

---

## A. Order ID

**Status:** ✅ FINALIZED

**Evidence (updated 2026-08-21):**

- **Target display format is unchanged:** `IU-{CITY_CODE}-{10-digit sequence}` (example `IU-AMD-0000010421`).
- **Current Customer new bookings** use `OrderIds.nextDisplayId()` in `lib/shared/business/order_ids.dart` (this format). Older Customer timestamp-modulo IDs (`IU-{ms % 100000}`) are **retired in code**.
- **Still mixed in demos:** Customer seed orders may still show short IDs; Rider dummy IDs like `IU10248`; Admin `composeOrderCode` still uses a shorter numeric pad (`IU-AMD-10421`). Production must show **one** display ID everywhere.

ADR-015 already rejected timestamp-modulo IDs.

**Canonical internal ID**

- PostgreSQL primary key = **UUID v7** (time-sortable, globally unique at any scale)
- All Customer / Rider / Admin relationships use this UUID
- Never join on display names, vehicle names, or formatted codes

**Canonical display ID** (shown in all three apps)

- Unique secondary key `display_id`
- Format: `IU-{CITY_CODE}-{10-digit sequence}`
- Launch example: `IU-AMD-0000010421`
- `CITY_CODE` comes from the city master (`AMD` = Ahmedabad)
- Sequence is a database sequence / bigint, **not** timestamp modulo
- Unique constraint on `display_id` globally
- 10 digits supports far beyond millions of orders without reuse

Rider `IU10248` and Admin `IU-AMD-10421` (short pad) remain **demo formats**. Production shows one 10-digit display ID everywhere.

Invoice numbers are a **separate** unique series (`invoice_number`), not the order UUID.

---

## B. Finance snapshot timing

**Status:** ✅ FINALIZED

| Event | What is written | When |
|---|---|---|
| Fare quote | `fare_quote` | Before confirm; server-calculated; TTL |
| Booking confirmation | `order_fare_snapshot` (copy of accepted quote) | When the customer confirms the booking |
| Payment | `payment` row | Cash: pending until collected at delivery. Online: intent/authorize at confirm when online is enabled; webhook updates status |
| P&L freeze | immutable `order_finance_snapshot` | When the financial outcome is final — **normally `delivered`** |
| Rider payout | `payout` | After freeze, for online earnings; not at quote time |
| Cancel / fail | snapshot per policy in **C / M** | When the order becomes terminal `cancelled` or `failed` |

Quote at confirm is binding for the customer-facing fare lines.  
P&L freeze uses the settings version **in force at freeze time**, copied onto the snapshot. It does not re-quote the ride, and it does not use later Admin settings.

---

## C. Cancelled / Failed orders

**Status:** ✅ FINALIZED for V1 money (no cancel fees). Failed-delivery extras are in **M**.

### Cancellation (not the same as failed delivery)

| Item | Final V1 rule |
|---|---|
| Cancellation fee | **₹0**. No rider compensation, waiting fee, pickup fee, or post-assignment fee |
| Rider earning | ₹0 |
| Company commission | ₹0 |
| Operational allocation | ₹0 |
| Actual profit | ₹0 |
| Financial snapshot | Required. Keep original ride amount for display; zero the split |
| Who may cancel | Unchanged from current apps: customer until accept; Admin until terminal; rider rejects offers only |

### Failed delivery (receiver unavailable)

See **M**. Original 85/15 snapshot **stays**. Additional ₹8/km rider office compensation is a **separate** component. Customer resend ₹10/km is a **separate** charge with **no invented split**.

---

## D. COD / Cash

**Status:** ✅ FINALIZED (support + cash handling). Payer identity at stop is noted below.

**Evidence:** Product FR-C-051 / Feature List: cash is MVP, “at trip end”. Admin methods include Cash. Admin `normalizeOrder`: Cash is `Pending` until `Delivered`. Admin `riderWallet.js`: delivered Cash jobs create rider `cashInHand` from the **rider share**, not from live settings recomputation once a snapshot exists. Customer COD toggle exists on the draft but is not copied onto `MockOrder` today.

**Final rules**

- Cash / COD **is supported in production**
- Persist `order.cod` and `payment.method = cash`
- Collection point: **drop / delivery (trip end)**
- Customer payment status: `pending` until delivered, then `paid`
- Rider collects **cash portions** at delivery. Online portions are not rider cash-in-hand.
- If the whole amount is cash: rider collects the full ride amount; COD Due = cash collected − rider earning (₹100 cash / ₹85 earning → ₹15)
- Mixed cash below rider earning does **not** create COD Due
- Rider `cash_in_hand` tracks the rider’s frozen share (85% in the default example)
- Company commission from cash jobs is **owed by the rider** and netted against online payouts
- COD does not change the fare by itself in current apps; do not add a COD surcharge unless business later defines one

**Not invented, therefore not assumed as a paid extra:** cash handling fee, COD convenience fee.

`⚠️ REQUIRES BUSINESS DECISION` only if the paying person is not the booker: whether cash is collected from the **pickup sender**, the **drop receiver**, or always from the **customer account holder**. Current copy says “COD” and FR says trip end; that is treated as drop collection unless you override it.

---

## D2. PAYMENT RESPONSIBILITY  **FINAL**

**Previous rule (historical, superseded):** “Partial payment is not supported / only one payment method on the trip.”

**FINAL RULE:**

- Customer can pay **100%**
- Receiver can pay **100%**
- Or Customer + Receiver can **split** the applicable total
- A single payer may split **their own** share across supported methods (example: Customer ₹50 Online + ₹50 Cash)
- Payment responsibility, payment method, and actual payment transactions are **separate concepts**
- `customer_responsibility + receiver_responsibility` must equal the applicable final amount
- Track UNPAID / PARTIALLY_PAID / PAID for Customer, Receiver, and overall trip
- Track paid amounts separately from responsibilities
- Invoice total remains the full transaction amount
- Online provider success is **not faked**. Receiver online is **ARCHITECTURE READY / PAYMENT PROVIDER INTEGRATION PENDING**

Payer type: `CUSTOMER` | `RECEIVER`  
Payment method: `ONLINE` | `CASH`

---

## E. Online payment

**Status:** ⚠️ REQUIRES BUSINESS DECISION (V1 gateway on/off + capture moment)

**Finalized architecture (do not wait to design this):**

| Topic | Rule |
|---|---|
| Methods Admin already has | UPI, Card, Net Banking, Wallet, Cash |
| Settings | Super Admin can enable/disable methods |
| Card PAN / CVV / full card number | **Never stored** |
| Provider secrets | Server env only |
| Payment row | amount, method, direction charge\|refund, status pending\|paid\|failed\|refunded, `provider_txn_id`, `idempotency_key` |
| Webhooks | Signature-verified; update `payment.status`; retry via worker if order update fails |
| Idempotency | Unique key on create-order, top-up, accept-offer, webhook event id |
| Failed payment | Order does not enter searching until a successful cash selection or a successful/authorized online payment (when online is enabled) |
| Pending payment | Allowed while waiting for webhook; do not dispatch as paid |
| Refund | New `payment` row direction=refund; original row not overwritten |

Product Feature List places **UPI / online as V1.1** and **cash as MVP**. Admin already operates all methods in the mock panel. Schema must support all methods on day one.

**Still requires business confirmation:**

- Is online payment in **first production launch**, or cash-only first?
- If online is on: **authorize at booking** vs **capture at delivery**
- Which provider (Razorpay is mentioned as an example only — do not lock a vendor here)

---

## F. Ride amount vs invoice amount

**Status:** ⚠️ REQUIRES BUSINESS DECISION — **BLOCKING**

These are **different numbers**. They must be stored as separate columns.

| Layer | What it is | Current code |
|---|---|---|
| 1. Base delivery / ride amount | Vehicle/base + (eventual) distance/weight/surcharges | Customer dummy `FareBreakdown` lines; Admin `order.amount` used as “Delivery Charge” |
| 2. Additional charges | Packaging, fragile, platform fee, etc. | Customer dummy: fragile ₹30 vs ₹15, platform ₹10. Admin invoice: packaging heuristic ₹0–₹40 |
| 3. Tax | GST-style % | Customer dummy 5% of subtotal **inside** `order.fare`. Admin invoice 5% of (delivery + packaging) **on top of** `order.amount` |
| 4. Invoice total | Grand total billed to customer | Admin `buildInvoice().total` |

**Conflict — do not silently pick one:**

- Admin commission (`commission.js`) splits **`order.amount`** (treated as delivery charge). Invoice then adds packaging + tax.
- Customer confirm stores **`order.fare`**, which **already includes dummy tax**.

So today, 85/15 is applied to Admin delivery charge, not invoice grand total — but Customer’s stored fare is not the same basis.

**You must confirm the commission base:**

1. **Ride / delivery amount only** (Admin commission behaviour), **or**
2. **Invoice grand total** (delivery + extras + tax)

Until this is confirmed, `ride_amount` on the finance snapshot has an ambiguous meaning.

Schema can still store all four layers (`base`, `additional`, `tax`, `invoice_total`) plus `commission_base` once you choose. The freeze formula cannot be correctly coded without the choice.

---

## G. Operational cost

**Status:** ✅ FINALIZED

Matches the confirmed financial model.

- Company commission = 15% of ride amount (default, configurable)
- Operational allocation = 50% of **company commission** (default, configurable)
- Profit = commission − operational allocation
- **Not** an extra rider deduction
- **Not** the same as `purchase_invoices` (vendor/maintenance/insurance/parts)
- Reports: `SUM(snapshot.operational_cost)` is allocation; AP spend is a separate report from purchase invoices
- Do not double-count

---

## H. Owner / Driver model

**Status:** ⚠️ REQUIRES BUSINESS DECISION (fleet / multi-driver)

**Evidence:** Rider registration collects **Rider profile** and a **separate Driver Details** screen (name, mobile, DOB, licence). Dummy data uses the same person. Admin binds one rider to one vehicle; vehicles may be unassigned. There is no fleet-owner company entity in the Rider app.

**Finalized for schema (does not wait):**

- `rider` = login identity that goes online and receives offers
- `rider_driver` exists so owner ≠ driver can be stored (licence holder)
- `vehicle.rider_id` nullable
- V1 default behaviour in the current app: **one rider login = one driver = one vehicle** (same person)

**Still requires business confirmation:**

- Can a vehicle owner hire a different driver on the same rider account?
- Can one owner operate **multiple drivers** / multiple vehicles under one business account?
- If yes, is the login the owner, the driver, or both?

Do not implement a fleet-owner product until that is confirmed. Keep `rider_driver` so the schema does not have to be redesigned.

---

## I. Geography

**Status:** ✅ FINALIZED

**Evidence:** Admin dashboard, orders, zones, and company address are Ahmedabad. Customer dummy includes one Surat address. Product scope: launch 1–2 cities; multi-city in the data model now; inter-city freight out of MVP.

**Final rules**

- First launch city: **Ahmedabad**
- City code: `AMD`
- Zones already modelled: Navrangpura, Satellite, Maninagar, Bopal, Naroda, Gota, SG Highway
- Schema: `city` → `zone` (service area) → rider home zone + order pickup/drop zone
- Vehicle availability is per category **and** must be filterable by city/zone (do not assume one national pool)
- Architecture supports multiple cities from day one even if only Ahmedabad is live
- Surat in Customer dummy is **not** a second launch city unless you later confirm it

---

## J. OTP

**Status:** ⚠️ REQUIRES BUSINESS DECISION (length, provider, lockout)

**Existing dummy behaviour (not production policy):**

| App | Length | Demo code | Resend UI | Attempts / lockout | Expiry |
|---|---|---|---|---|---|
| Customer | 4 digits | any 4 digits accepted | 30 seconds | none | none |
| Rider | 6 digits | `123456` | 30 seconds | none | none |

**Finalized production architecture:**

- OTP is created and verified **only on the server**
- Store `code_hash`, never plaintext
- SMS sent by server provider (not from the app)
- Resend cooldown: **30 seconds** (both apps already use this)
- Rate-limit by phone + IP
- Do not expose OTP secrets in logs, Admin UI, or this documentation beyond the dummy values already in discovery

**Still requires business confirmation:**

- One production length for both apps (4 vs 6 conflict)
- SMS provider
- OTP lifetime (dummy has none)
- Max verify attempts
- Lockout duration after failures

---

## K. Customer email

**Status:** ✅ FINALIZED

Preserve existing Customer UX.

- Profile email is **optional** at signup / edit
- Email **is required before Track Delivery** if still empty (invoicing prompt)
- Email is **not** required before booking or searching
- Delivered orders copy email onto invoice flags (`invoiceEmail`)
- Phone number is not editable in Edit Profile (OTP-verified)

Do not make email mandatory at booking unless you later override this.

---

## L. Cancellation rules

**Status:** ⚠️ REQUIRES BUSINESS DECISION (charges after rider is moving)

**Finalized from current apps (who may cancel, no invented fee):**

| Actor | Allowed in current product | Production mapping |
|---|---|---|
| Customer | `searching` or `assigned` only (`canCancel`). Hidden after `accepted` | Allow cancel until rider has **accepted the offer** (canonical `assigned` after accept). After `en_route_pickup` / pickup, customer cancel is **not** in the current app |
| Rider | Reject incoming offer. No cancel on active delivery | Offer reject / timeout returns order to `searching`. No mid-trip rider cancel UI today |
| Admin | Cancel until terminal (`orderRules.cancel`) | Admin may cancel until `delivered` / `cancelled` / `failed` |
| After assignment, before accept | Customer can still cancel | No fee in current product |
| After accept / pickup | Customer UI hides cancel; Admin can still cancel | **Fee not defined** |

Cancel reasons already in Admin (no amounts): Customer Request, Rider Issue, Operational Issue, Payment Issue, Other.  
`cancelled_by`: customer \| rider \| admin.

Refund: see **C**. No cancellation charge exists in code. FR-C-042 says a fee *may* apply — that is not a defined amount.

**You must confirm** if any of these should bill the customer or compensate the rider:

- cancel after assignment
- cancel after acceptance
- cancel after pickup

Until confirmed: **no cancellation charge**.

---

## M. Failed delivery

**Status:** ✅ FINALIZED for V1 operational flow and the two published rates.

This is **not** cancellation.

### Flow

```text
Delivery attempt
  → Receiver unavailable
  → Failed delivery
  → Parcel taken to company office
  → Customer notified
  → Customer decision: Resend (office → original drop) or other Admin-supported resolution
```

Do not invent extra commercial outcomes.

### Money

| Component | Rule |
|---|---|
| Original trip finance | Immutable 85/15 snapshot. Do not recompute. |
| Rider office compensation | `office_distance_km × ₹8`. **Not** 85/15. Separate row. |
| Customer resend charge | `office → original drop km × ₹10`. Separate from original fare. **Split is ⚠️ REQUIRES BUSINESS DECISION — do not invent.** |
| GST | Not applied |

### Data

Preserve original order. Resend is a related delivery leg with `parent_order_id`. Company office is Admin-managed (`REQUIRES BUSINESS CONFIGURATION` for the live pin). Reason V1: `receiver_unavailable`.

---

## N. No rider found

**Status:** ⚠️ REQUIRES BUSINESS DECISION (timeout / radius / auto-cancel)

**Finalized:**

- After confirm, order is `searching`
- Admin **may assign** a rider (`orderRules.assign`)
- Offer reject / expiry returns to `searching` (canonical `offer_rejected`)
- Customer 3-second auto-assign is **demo only** and is not production dispatch

**Not defined (do not invent numbers):**

- How long to keep searching before auto-cancel
- Whether search radius expands, and by how much
- How many dispatch retries
- Whether the customer is charged (should remain **not charged** until a fee is defined)

Until confirmed: keep searching until customer/admin cancel, or admin assigns. Auto-cancel TTL is a later config, not a hardcoded business fee.

---

## O. Dispatch

**Status:** ⚠️ REQUIRES BUSINESS DECISION (broadcast vs sequential + production timeout)

**Finalized consistency rules (required at any scale):**

- Backend creates `order_offer` rows
- Accept uses `SELECT FOR UPDATE` + unique accepted offer per order
- First valid accept wins; later accepts fail
- Duplicate accept of the same offer is idempotent
- Customer, Rider, Admin never decide the winner locally

**Dummy only (not production policy):** Rider incoming timer **27 seconds**; one dummy offer; no broadcast algorithm.

**Still requires business confirmation:**

- Sequential offers vs broadcast to N nearby riders
- Production offer timeout (27s is UI demo)
- Maximum concurrent pending offers per order
- Maximum concurrent pending offers per rider

---

## P. Live GPS

**Status:** ✅ FINALIZED

From `07_REALTIME_ARCHITECTURE.md` and current permissions (location exists; no location model yet).

| Rule | Production |
|---|---|
| Who publishes | Assigned rider, while **online and on an active trip** (or Admin is explicitly tracking that rider) |
| Interval | 3–8 seconds, throttled. Not 1 Hz × all riders |
| Customer visibility | Assigned rider on that live order only |
| Admin visibility | Live ops map by city/zone |
| Idle / offline | No high-frequency GPS write |
| Hot store | Redis last point, TTL ~30s |
| History | Sampled breadcrumbs / status-change points; not every ping forever |
| Privacy | Precise trail is not a public feed; retain per later legal policy (open item 40 in `17_OPEN_DECISIONS.md` is not blocking schema) |

---

## Q. Communication

**Status:** ✅ FINALIZED

| Channel | Rule |
|---|---|
| In-app chat | **Not V1.** Message buttons are empty. Feature List: chat is V1.1. Schema may omit chat messages now |
| Call | Production must **not** expose raw counterpart numbers in the apps. Rider already masks customer (`+91 ******3210`). Customer currently shows a full dummy rider phone — treat as demo. Use masked calling / relay when implemented |
| Notifications | Persist per-user inbox + unread counter; FCM for background; dedupe by notification id |
| Privacy | Rider sees masked customer; Customer sees masked rider; Admin list views keep `masking.js` behaviour; full numbers only with RBAC |

---

## R. GST / Invoice legal

**Status:** ✅ NO GST on V1 fare. Legal identifiers still need verification.

**Fare rule:** GST is **not** applied. Dummy 5% tax is retired. Customer flow is trip fare → discount → subtotal → rounding → net total.

SAC, GSTIN, CIN, invoice series, and e-invoice IRN remain **⚠️ REQUIRES BUSINESS DECISION** before live statutory invoices. Company legal fields in Admin `company.js` must be verified with the real entity.

---

## S. Fare calculation

**Status:** ✅ Admin-controlled table is the source of truth. Per-km original-trip tariff values are Admin-editable (demo seeds are not a commercial lock). Multi-stop extra fees are **⚠️ REQUIRES BUSINESS DECISION**.

Fields: Vehicle Category, Base Fare, Per KM Charge, Initial Minimum, Waiting, Surge, Toll, Parking, Weight Capacity, Size.

Engine (no GST, no invented multi-stop fee):

```text
distance_charge = per_km × total_route_km (sum of ordered stops)
trip_fare       = max(initial_minimum, base + distance_charge + waiting + surge + toll + parking)
net_total       = round(trip_fare − discount)
```

Every financially relevant order stores the fare config **version** used at quote time.

Dummy Customer `weightKg × 4` + 5% tax is **retired**.

---

```text
baseFare        = vehicle.baseFare          # Bike 79, Scooty 89, Auto 149, Truck 699, …
distanceCharge  = weightKg × 4, clamped 20–400   # NAME IS DISTANCE; FORMULA IS WEIGHT
vehicleCharge   = fragile ? 30 : 15
platformFee     = 10
subtotal        = base + distanceCharge + vehicleCharge + platform
tax             = subtotal × 5%
total           = subtotal + tax
```

Two-wheeler copy “Parcel size not more than 36 CM” is **not enforced** against size IDs (Medium is 60 cm). Fragile is collected then dropped from `MockOrder`.

**Production (final architecture):**

- Fare is **server-calculated**
- Quote API persists line items, then `order_fare_snapshot` at confirm
- Maps/distance provider is required for real distance; dummy `distanceCharge` is not distance
- Line types the schema must support: base fare, distance charge, weight charge, vehicle surcharge, fragile charge, platform fee, tax, discount/coupon, other charges
- Admin catalog does **not** currently send prices; production categories need fare config, not hardcoded Flutter values

**You must confirm** the real base/distance/weight/surcharge/tax rules. Until then, dummy numbers stay dummy.

---

## T. Vehicle categories

**Status:** ✅ FINALIZED

**Source of truth:** Admin vehicle-category master (stable IDs). Never join Customer / Rider / Admin data by name (`Bike` vs `Three Wheeler` vs `Auto`).

Current master (Netlify seed; production should migrate these to UUIDs, keeping a unique `code` if needed):

| Stable catalog name | Current Admin id | Customer / Rider mapping |
|---|---|---|
| Bike | `VC-1001` | Customer Bike + **Scooty** (mock extra currently name-mapped to Bike) |
| Auto | `VC-1002` | Customer “Three Wheeler” |
| Mini Truck | `VC-1003` | Customer legacy Pickup maps here by name helper |
| Tempo | `VC-1004` | Admin catalog |
| Large Tempo | `VC-1005` | Admin catalog |
| Truck | `VC-1006` | Customer Truck; legacy Car currently name-mapped to Truck (lossy — do not keep that join) |

**Not separate V1 categories unless Admin later creates them:**

| Name | Treatment |
|---|---|
| Scooty / Scooter | **Not a category.** `two_wheeler_subtype` on the **vehicle**: `bike` \| `scooter`. Bookable customer type follows category **Bike** |
| Van | Appears in some Admin vehicle type lists, **not** in the VC master. Do not join on “Van” |
| Car | Customer legacy only; **not** in VC master |
| Pickup | Customer legacy name; production category is **Mini Truck** (`VC-1003`) unless you later add a distinct category |

Orders store `vehicle_category_id` (UUID) + a name snapshot for history.  
Adding a new sellable type is an Admin create, not a string in Flutter.

---

## U. Scheduled booking

**Status:** ✅ FINALIZED

- No scheduled-booking UI
- `scheduledAt` exists on the Customer draft/order and is unused
- **Not V1.** Keep `order.scheduled_at` **nullable** for a future release. Do not build scheduler/dispatch for it now
- Not removed from schema (nullable support only)

---

## V. Referral / Promotion

**Status:** ⚠️ REQUIRES BUSINESS DECISION

These are **three different dummy values**. Do not merge them.

| Source | Amount | Nature |
|---|---|---|
| Customer dashboard invite banner | ₹200 wallet | Copy only; no referral model |
| Customer wallet seed txn | ₹50 “Promotional credit” | Dummy ledger row |
| Admin Promotions | “Refer & Earn ₹150” | Dummy campaign `PR-102` |
| Admin coupon `AMD50` | ₹50 off | Coupon, not referral |

Feature List tags **Referral program as Future**.

Schema may include `promotion` / `coupon` / `referral_code` with a configurable amount.  
**Do not ship ₹200, ₹50, or ₹150 as the official program** until you pick one (or confirm they are separate products: invite bonus vs promo credit vs refer-and-earn).

---

## W. Wallet

**Status:** ⚠️ REQUIRES BUSINESS DECISION (limits, KYC, auto-debit)

**Finalized:**

- Purpose: customer prepaid balance + promotional credits; rider earnings / payouts / cash-in-hand accounting
- Ledger is **append-only** `wallet_transaction`
- Balance changes only in the same DB transaction as the ledger insert
- Top-up methods already shown: UPI apps / net banking / card (labels only today)
- Debit: only when a confirmed business rule says so (today **booking does not debit** the wallet)
- Refund to wallet if the original payment was wallet
- Negative balance: **not allowed** unless you later confirm credit
- Never store card numbers on the wallet

**Dummy only:** Customer balance ₹420, Rider ₹2450, top-up snackbar with no amount.

**You must confirm:**

- Minimum top-up
- Maximum top-up
- Whether wallet KYC is required above a threshold
- Whether booking **auto-debits** wallet when method = wallet
- Whether promotional credit is spend-restricted

---

## X. Rating

**Status:** ⚠️ REQUIRES BUSINESS DECISION (rider → customer, edit, public comments)

**Finalized from FR-C-043 + Admin order fields + Rider profile aggregate:**

- Customer rates rider after delivery: **1–5 stars**, optional comment
- One rating **per order per direction** (unique constraint)
- Rider profile shows aggregate `rating_avg`
- Customer completion stars today are **decorative** (not saved) — production must persist them
- Rider app does **not** currently rate the customer; Admin mock orders have both `customerRating` and `riderRating`

**You must confirm:**

- Does the rider rate the customer in V1?
- Can a rating be edited?
- Are comments visible on the public rider profile or only internally?

Until confirmed: persist customer→rider ratings; keep rider→customer as a nullable schema direction without requiring the Rider UI.

---

## Y. Invoice

**Status:** ✅ FINALIZED (document lifecycle). Legal contents follow **R**.

| Topic | Rule |
|---|---|
| PDF generation | Server/worker, not the Admin browser as source of truth |
| Storage | Private object + `invoice.pdf_file_id` |
| Email | Worker; use customer invoice email; persist `emailed_to` |
| Download | Customer + Admin via authorized signed URL |
| Status | draft \| issued \| cancelled |
| Retry | Worker retries PDF/email; do not mark payment failed because PDF failed |
| Issue time | After delivered (and after P&L freeze) |
| Legal lines | From company snapshot; **R** must be confirmed before live issue |

Admin already generates a preview PDF and download. That UI remains; production files live in object storage.

---

## Z. Pickup / Drop contacts

**Status:** ⚠️ REQUIRES BUSINESS DECISION (required vs optional)

**Evidence:** Customer booking does **not** collect pickup/drop contact name or phone. Admin instructions sometimes include a person (“Ask for Rohan”). Rider order uses string addresses only.

**Finalized for architecture:** `order_stop` includes nullable:

- `contact_name`
- `contact_phone`

so logistics can store them without a later redesign.

**You must confirm** whether production booking **requires**:

- pickup contact name
- pickup contact phone
- drop contact name
- drop contact phone

Until confirmed: keep current Customer UX (not required). Do not block booking on missing contacts.

---

## AA. Admin security

**Status:** ✅ FINALIZED

| Topic | Rule |
|---|---|
| Admin passwords | Argon2id (or equivalent) **server-side only**. Never in the React bundle or this repo as production secrets |
| Seed `adminAccounts.js` | Demo only; rotate; do not copy into backend env as live passwords |
| Secrets | DB, Redis, S3, SMS, payment, JWT, webhook signing — **environment / secret manager only** |
| Sessions | HttpOnly Secure SameSite cookie and/or short-lived access JWT + hashed refresh |
| RBAC | Existing Admin roles enforced **on the API** (`permissions.js` is the matrix, not the only gate) |
| Audit | Append-only `audit_log` for Admin writes |
| 2FA | Optional later (Admin Settings already has a dummy toggle). Not required to create schema |
| Customer/Rider auth | Phone OTP; no Admin modules |

Never copy credentials from `Project_Documentation/000_info.txt` or seed files into application code.

---

## FINAL STATUS TABLE

| # | Decision | Status | Final Rule / Required Action |
|---|---|---|---|
| 1 | Order ID | ✅ FINALIZED | UUID v7 PK; display `IU-{CITY}-{10-digit sequence}`; same ID in all apps; no timestamp modulo |
| 2 | Finance snapshot | ✅ FINALIZED | Quote + fare snapshot at confirm; P&L snapshot at delivered (or terminal cancel/fail); reports use snapshots only |
| 3 | Cancelled orders | ✅ FINALIZED (V1) | Zero rider/commission/opex/profit + snapshot; **no cancellation fee** |
| 4 | COD / Cash | ✅ FINALIZED | Supported; collect at delivery; rider cash-in-hand = frozen rider share; commission netted from payouts. Confirm payer if not the booker |
| 5 | Online payment | ✅ FINALIZED | WHO PAYS ≠ HOW THEY PAY. Customer / Receiver / split. Online / Cash / split per payer. Multiple payment transactions. UNPAID / PARTIALLY_PAID / PAID. Live gateway is **ARCHITECTURE READY / PAYMENT PROVIDER INTEGRATION PENDING**. Do not fake success |
| 6 | Ride vs invoice amount | ✅ FINALIZED | **85/15 applies to confirmed Trip Fare only.** Discount, rounding, and extra lines do not change the 85/15 base |
| 7 | Operational cost | ✅ FINALIZED | 50% of company commission; not a rider deduction; not a purchase invoice |
| 8 | Owner / Driver | ⚠️ REQUIRES BUSINESS DECISION | V1 app = one login/driver/vehicle; schema keeps `rider_driver`. **Confirm hired drivers / multi-vehicle owner** |
| 9 | Geography | ✅ FINALIZED | Launch Ahmedabad; zones under city; multi-city schema from day one |
| 10 | OTP | ⚠️ REQUIRES BUSINESS DECISION | Hashed server OTP; 30s resend. **Confirm 4 vs 6 digits, provider, expiry, attempts, lockout** |
| 11 | Customer email | ✅ FINALIZED | Optional on profile; required before tracking/invoice continue; not required to book |
| 12 | Cancellation rules | ✅ FINALIZED | Admin stage-wise config. Customer ≠ rider. Default fee ₹0. Shares must sum to 100%. Not auto 85/15. Rider share credited immediately then COD-settled |
| 13 | Failed delivery / resend | ✅ FINALIZED | Case A ended: base + ₹10/km at 85/15. Case B active: ₹10/₹8/₹2 per km. Office handover extra still ₹8/km not 85/15 |
| 14 | No rider found | ⚠️ REQUIRES BUSINESS DECISION | Admin assign allowed; 3s demo assign is not production. **Confirm TTL, retry, radius** |
| 15 | Dispatch | ⚠️ REQUIRES BUSINESS DECISION | DB lock + one accepted offer. **Confirm broadcast vs sequential, timeout, max concurrent offers** |
| 16 | Live GPS | ✅ FINALIZED | 3–8s on active trip; Redis last point; customer sees assigned rider only |
| 17 | Communication | ✅ FINALIZED | No V1 chat; masked calling; persisted/deduped notifications |
| 18 | GST / Invoice legal | ✅ NO GST on fare; legal IDs open | Fare has no GST. **Confirm SAC, GSTIN, series, e-invoice before live statutory invoices** |
| 19 | Fare calculation | ✅ Admin table; multi-stop fee open | Admin fare fields + snapshot. **Do not invent extra multi-stop fees** |
| 20 | Vehicle categories | ✅ FINALIZED | Admin master IDs only. Scooter/Scooty = Bike subtype. Van/Car not V1 categories |
| 21 | Scheduled booking | ✅ FINALIZED | Future; nullable `scheduled_at`; no V1 UI |
| 22 | Referral / Promotion | ⚠️ REQUIRES BUSINESS DECISION | ₹200 vs ₹50 vs ₹150 are separate dummies. **Do not merge without a chosen program** |
| 23 | Wallet | ⚠️ REQUIRES BUSINESS DECISION | Append-only ledger; no negative balance. **Confirm min/max top-up, KYC, auto-debit** |
| 24 | Rating | ⚠️ REQUIRES BUSINESS DECISION | Customer→rider 1–5 + optional comment, one per order. **Confirm rider→customer, edit, visibility** |
| 25 | Invoice | ✅ FINALIZED | Worker PDF + private storage + email + signed download; legal fields wait on #18 |
| 26 | Pickup / Drop contacts | ⚠️ REQUIRES BUSINESS DECISION | Nullable contact fields on stops. **Confirm if required at booking** |
| 27 | Admin security | ✅ FINALIZED | Server password hash, env secrets, RBAC, audit; 2FA optional later |

**Count:** 21 finalized · remaining items are non-critical (OTP provider, referral program, dispatch TTL, statutory SAC). **Commission base, resend split, COD, cancellation, company office, payment splitting, and V1 online+cash are finalized.**

---

## BLOCKING DECISIONS BEFORE DATABASE CREATION

**None remaining for money columns.** 85/15 applies to confirmed Trip Fare. Extra charges (resend, cancellation) are stored as separate snapshot lines.

Optional later (not separate tables): OTP length, referral amounts, chat, 2FA.

---

## ARCHITECTURE GUARANTEES

These are mandatory for implementation after this document is approved.

### Database

PostgreSQL is the production source of truth.

### Applications

Customer, Rider, and Admin never directly share local storage.  
All production communication goes through the backend API.

### IDs

All cross-app relationships use stable UUID / database IDs.  
Never use display names for relationships.

### Finance

Historical financial snapshots are immutable.  
Admin percentage changes never rewrite old orders.  
Operational allocation comes from company commission only.

### Orders

Backend owns canonical order status transitions.

### Payments

Payment provider callbacks use webhook + idempotency protection.  
Card numbers and payment credentials are never stored.

### Wallet

Wallet transactions are append-only.

### Notifications

Notifications are persisted and deduplicated.

### Reports

Reports use database/worker aggregates and historical finance snapshots.  
They never scan all orders in the Admin browser and never recompute old money from live settings.

### Scaling

Architecture must support:

`100K users → 1M users → millions of orders`

without redesigning the core data model (UUID keys, city/zone, versioned settings, snapshots, cursors, Redis for hot GPS/unread, workers for invoices and rollups).

---

## STOP

No database, backend, app, UI, or deploy work is included in this step.  
Implementation waits for explicit approval, and for the blocking commission-base decision above.
