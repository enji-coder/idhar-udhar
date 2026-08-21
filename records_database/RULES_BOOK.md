# IDHAR UDHAR RULES BOOK

This book explains the **final business rules** in simple language.

The apps are still demo/mock in many places. The rules below are what the product has decided. Where the three apps are not yet sharing one live database, that is noted.

---

## Basic Rules

- IDHAR UDHAR is a delivery platform: **Customer** books, **Rider** delivers, **Admin** runs the company.
- A customer cannot do rider work. A rider cannot do admin work.
- One trip has **one ID** for everyone. Example: `IU-AMD-0000010421`.
- The trip has **one hidden status** in the system. Each app may show friendlier words.
- There is **no GST** on the trip fare.
- Old completed trips never change when Admin later changes prices.
- WHO PAYS (Customer / Receiver) is separate from HOW THEY PAY (Online / Cash).
- Customer and Receiver may split the bill. A payer may also split their own share across Online and Cash.

---

## Customer Rules

### Account

- Log in with a 10-digit mobile number and OTP (demo OTP is not a real SMS).
- Name is required. Email is optional until tracking/invoice.
- Customer can edit name and email, save addresses, and log out.

### Booking

- Choose pickup, then 1 drop or 2–3 drops, then vehicle, then parcel details.
- See **Trip Fare** and **Amount payable** before confirming.
- Choose **who pays**: Customer, Receiver, or both.
- If both pay, the two amounts must add up to the total.
- Choose **how** each payer pays: Online, Cash, or Online + Cash.
- After confirm, that Trip Fare is locked for this trip.
- Online is recorded as UNPAID until a real payment provider confirms. The app does not fake a successful charge.

### Cancellation

- The fee depends on **this trip’s stage** and **Admin’s customer cancellation setting**.
- Before cancel, the app shows the fee, or says cancellation is not available.
- Default fee is **₹0** until Admin sets a charge.

### Resend

- If the receiver was not available, the customer may request a resend.
- **Ride ended** (parcel at office): pay current base fare **plus** ₹10 per km.
- **Ride still active**: pay **₹10 per km** only (special split, not 85/15).

---

## Rider Rules

### Account

- Register with documents, vehicle, bank, and UPI (demo).
- Go online to see delivery requests.
- If **COD Due is ₹100 or more**, the rider is **suspended** and cannot accept new rides.

### Money (keep these separate)

- **Earning Wallet** — money the rider can use. Never below ₹0.
- **COD Due** — money the rider owes the company from cash collections.
- **Settlement** — new earnings first pay off COD Due, then the rest goes to the wallet.

### Wallet recharge

- If the rider adds ₹100 and COD Due is ₹60: ₹60 clears the company, ₹40 stays in the wallet.

### Cancellation

- Rider cancel rules are **separate** from customer rules.
- If Admin has not enabled rider cancel at that stage, the rider cannot cancel.
- If a rider cancel fee has a rider share, that share is credited immediately and then follows COD settlement.

---

## Receiver Rules

- There is **no separate Receiver app** today.
- The architecture still records receiver payment responsibility and receiver payment transactions on the same trip.
- Receiver UI in a dedicated app is **ARCHITECTURE READY / IMPLEMENTATION PENDING**.
- Receiver may pay 100%, pay nothing, or split with the customer.
- Receiver may pay Online or Cash (or both). Receiver online payment provider is **not connected**. Do not fake success.

---

## Admin Rules

- Admin sets vehicle rates, 85/15 split, company office location, and cancellation rules.
- Admin can see the same trip ID, trip fare, who pays, how they pay, paid amounts, outstanding, payment status (UNPAID / PARTIALLY_PAID / PAID), rider amount, company amount, COD, cancellation, and resend figures.
- Changing today’s rates does **not** rewrite yesterday’s trips.
- Customer cancellation and rider cancellation are edited as **two separate tables**.
- For every cancellation row: **Rider % + Company % = 100**. Invalid rows cannot be saved.

---

## Trip Rules

Typical flow:

```text
Customer confirms
→ Searching
→ Rider assigned / accepted
→ Going to pickup
→ Pickup
→ In transit
→ Delivered
```

Failed delivery (receiver not available) is **not** cancellation. The rider takes the parcel to the **Admin company office**.

One customer may have many running trips. One rider should not auto-take a second live trip.

---

## Fare Rules

```text
Trip Fare
↓
Discount
↓
Subtotal
↓
Rounding
↓
Amount the customer pays
```

**GST = ₹0.**

85/15 uses **Trip Fare**, not the amount after discount.

Example:

```text
Trip Fare = ₹100
Discount = ₹10
Customer pays = ₹90

Rider = ₹85
Company = ₹15
```

If a later extra charge is needed, it is shown as its own line. The confirmed Trip Fare does not silently jump from ₹100 to ₹110.

---

## Payment Rules

**FINAL:** Partial / split payment **is supported**.

Do not mix these ideas:

| Concept | Meaning |
|---|---|
| WHO PAYS | Customer, Receiver, or both |
| HOW THEY PAY | Online, Cash, or both for that payer |
| RESPONSIBILITY | How much each payer **owes** |
| ACTUAL PAYMENT | How much each payer **has paid** |
| PAYMENT STATUS | UNPAID, PARTIALLY_PAID, or PAID |

Customer responsibility + Receiver responsibility **must equal** the applicable total.

A payer may split their own share:

```text
Total = ₹100
Customer responsibility = ₹100
Customer Online = ₹50
Customer Cash = ₹50
```

Customer and Receiver may both pay:

```text
Total = ₹100
Customer: ₹30 Online + ₹20 Cash
Receiver: ₹50 Cash
```

Invalid:

```text
Total = ₹100
Customer = ₹60
Receiver = ₹30
```

because 60 + 30 is not 100.

Status example:

```text
Customer responsibility ₹50, customer paid ₹50
Receiver responsibility ₹50, receiver paid ₹0
Overall = PARTIALLY_PAID
```

One trip may have **several payment transactions**. A single `paymentMethod` field is not the full story.

Invoice **total stays the full trip/order amount**. Customer Paid and Receiver Paid are shown separately. Do not show ₹50 as the trip total when the trip is ₹100.

Online payment in the current apps is a **demo allocation**, not a live payment gateway.

**ARCHITECTURE READY / PAYMENT PROVIDER INTEGRATION PENDING.** Do not fake a successful online payment.

---

## COD Rules

Cash example:

Cash collected by the rider that is more than rider earning becomes COD Due:

```text
₹100 cash collected, rider earning ₹85 → COD Due ₹15
₹50 cash collected, rider earning ₹85 → COD Due ₹0 (platform still owes the rider the rest)
```

The wallet must **not** show −₹15.

When the rider later earns ₹85 online:

```text
₹85 pays COD Due
Wallet available = ₹0
COD Due left = ₹0 if due was ₹15, or remaining due if due was larger
```

If COD Due ≥ ₹100, the rider cannot accept new rides until COD Due is cleared.

---

## Cancellation Rules

- Default charge is **₹0**.
- Admin can turn a stage on/off and set the charge.
- Stages used today:
  - Before rider accepts
  - After rider accepts
  - After rider reaches pickup
  - After pickup
  - During delivery / in transit
- Customer rules and rider rules are independent.
- Cancellation money is **not** automatically 85/15. Admin sets the two percentages. They must add to 100%.
- Rider share of a cancellation fee is credited at once, then COD settlement applies if needed.

---

## Resend Rules

**Case A — original trip already ended**

```text
Customer pays = Base fare + (₹10 × km)
That money uses normal 85/15
```

Example: base ₹100 + 5 km → ₹150. Rider ₹127.50. Company ₹22.50.

**Case B — original trip not ended**

```text
Customer pays = ₹10 × km
Rider = ₹8 × km
Company = ₹2 × km
```

Example: 5 km → customer ₹50, rider ₹40, company ₹10.

---

## Wallet Rules

- Rider earning wallet cannot be negative.
- Recharge first pays COD Due, then the rest is wallet.
- Customer wallet in the current app is still a **demo balance**.

---

## Financial Rules

```text
Trip Amount (Trip Fare)
↓
Rider 85%
↓
Company 15%
   ├── 50% operations (company books only)
   └── 50% net profit
```

₹100 trip: rider ₹85, company ₹15, operations ₹7.50, profit ₹7.50.

Who pays and how they pay **does not change** this split.

Operations is **not** taken from the rider.

---

## Historical Transaction Rules

- When a trip is confirmed, the fare and rates used at that time are stored.
- Completed/settled trips keep those numbers forever.
- Admin may change future prices. Old trips stay as they were.

---

## Important Golden Rules

1. 85/15 is on **Trip Fare**, not on discounted payable.
2. Confirmed Trip Fare does not silently change.
3. One canonical trip ID. One canonical status. Three apps must mean the same trip.
4. Rider 85%, company 15%, then 50/50 inside company commission.
5. GST = ₹0 on fare.
6. Wallet never negative. COD Due is a separate number.
7. COD Due ≥ ₹100 suspends the rider.
8. Recharge and new earnings settle COD Due first.
9. Cancellation is Admin-configured, default ₹0, customer ≠ rider, percentages = 100%.
10. Resend Case A = 85/15 on base + ₹10/km. Case B = ₹8/₹2 per km.
11. Company office comes from Admin settings.
12. Old trips are never recalculated.
13. WHO PAYS and HOW THEY PAY are separate. Split payment is allowed. Customer + Receiver amounts must equal the total.
14. Until a real backend exists, each app’s demo data is local — the **rules** are shared even if the **rows** are not yet live-linked.
