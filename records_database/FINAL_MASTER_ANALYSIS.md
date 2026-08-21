# IDHAR UDHAR — FINAL MASTER ANALYSIS

**Date:** 2026-08-21 (business-rule alignment)  
**Primary current-system document.** Simple language: `RULES_BOOK.md`. Locked rules: `18_FINAL_BUSINESS_DECISIONS.md`.

Legend used below:

| Label | Meaning |
|---|---|
| **FINAL BUSINESS RULE** | Product lock. Do not contradict. |
| **CURRENTLY IMPLEMENTED** | Present in mock/local apps |
| **ARCHITECTURE READY** | Engines/fields exist; not a live shared database |
| **IMPLEMENTATION PENDING BACKEND** | Needs PostgreSQL/API before the three apps share real rows |
| **NOT YET IMPLEMENTED** | Rule exists; UI or persistence still incomplete |

**PostgreSQL is not implemented. Firebase is not a live database.**

---

## 1. Project overview

Three clients: Customer Flutter (`idhar_udhar` customer flavor), Rider Flutter (rider flavor), Admin React (`IDHAR_UDHAR_ADMIN`).

They still use **separate mock stores**. Shared **rule engines** are the source of financial truth:

- Dart: `idhar_udhar/lib/shared/business/` (`fare_engine`, `finance`, `payment`, `cod`, `cancellation`, `failed_delivery` / `ResendEngine`, `order_lifecycle`)
- JS: `IDHAR_UDHAR_ADMIN/src/services/` (`fareEngine.js`, `commission.js`, `paymentPlan.js`, `codWallet.js`, `cancellationRules.js`, `failedDelivery.js`)

Do not add a fourth engine.

---

## 2. Current architecture

**CURRENTLY IMPLEMENTED:** in-memory / SharedPreferences / Admin localStorage + Netlify admin login + vehicle-categories.

**PLANNED ARCHITECTURE:** PostgreSQL + API + Redis + object storage (`00`, `05`).

**IMPLEMENTATION PENDING BACKEND:** a Customer booking does not appear in Rider or Admin automatically. Canonical `tripId` / `customerId` / `riderId` fields exist on mock models so a backend can join them later.

---

## 3–5. Applications (current)

**Customer — CURRENTLY IMPLEMENTED (mock):** login/OTP demo, booking 1–3 drops, confirmed trip fare, who-pays + how-they-pay on summary (Customer/Receiver/split, Online/Cash/split), cancel dialog using Admin default rules, resend Case A/B copy, canonical display ID `IU-AMD-##########`, historical fare fields on the order. Online stays UNPAID (no fake success).

**Rider — CURRENTLY IMPLEMENTED (mock):** registration UI, accept/reject, delivery stepper, trip/customer/receiver payment + status on incoming/details/active, earning wallet vs COD Due, recharge settles COD first, suspend at COD Due ≥ ₹100, cancel uses rider Admin rules (default disabled), company office from `PlatformRules` / Admin store. Mixed cash below earning does not create COD Due.

**Admin — CURRENTLY IMPLEMENTED (client mock):** Settings tabs for company office and stage-wise cancellation (customer ≠ rider, 100% share validation), payment 85/15/50 on trip fare, wallet table shows earning wallet + COD Due, order drawer shows trip fare / customer vs receiver responsibility / paid / outstanding / UNPAID·PARTIALLY_PAID·PAID / transactions / rider / company / cancel / resend, new order IDs padded to 10 digits, finance snapshot not overwritten. New orders are UNPAID (do not fake online Paid).

---

## 6–8. Database

**CURRENTLY IMPLEMENTED:** no Firestore, no Postgres. Mock records only.

**FINAL BUSINESS RULE / ARCHITECTURE READY fields:**

```text
canonical trip/order id
customerId, riderId
canonical status
confirmed trip fare + rate snapshot
discount, additional charges, net payable
payment responsibility (customer / receiver)
customer paid, receiver paid, outstanding
payment transactions (payer type, method, status)
payment status UNPAID / PARTIALLY_PAID / PAID
rider gross earning, available wallet
company amount
COD due, COD settlement
cancellation config snapshot + amounts + shares
resend charge, distance, rider/company resend amounts
company office address/lat/lng
timestamps
```

**PLANNED:** UUID v7 PK + `display_id` unique (`18` A).

---

## 9. Authentication

**CURRENTLY IMPLEMENTED:** dummy OTP / Netlify admin cookie.  
**IMPLEMENTATION PENDING BACKEND:** real OTP, hashed admin passwords, role claims.

---

## 10. Permissions

Unchanged app matrix: customers book; riders accept; admin configures. Finance pages stay RBAC-gated. COD suspension blocks rider accept in the Rider app.

---

## 11. Trip lifecycle

**FINAL BUSINESS RULE:** one canonical machine (`CanonicalOrderStatus` in `order_lifecycle.dart`).

Customer / Rider / Admin **display labels** differ. Admin still stores human labels for mock rows and now also `canonicalStatus` on create.

**NOT YET IMPLEMENTED:** all three UIs rewritten onto a single stored enum. Mapping functions exist.

Canonical values in use: created, searching, offered, assigned, enRoutePickup, arrivedPickup, pickedUp, inTransit, nearDrop, deliveryAttempt, delivered, cancelled, receiverUnavailable, failedDelivery, parcelAtCompanyOffice, resendRequested, resendInProgress, resendCompleted.

---

## 12. Fare calculation

**FINAL + CURRENTLY IMPLEMENTED** in `FareEngine` / `fareEngine.js`. GST = 0. No extra multi-stop fee.

Confirmed quote is copied onto the order (`tripFare`, `fare` = payable). Live Admin rates must not rewrite that copy.

---

## 13. Financial distribution

**FINAL:** 85/15 on **Trip Fare**. Company 15% then 50% operations / 50% profit.

**CURRENTLY IMPLEMENTED:** Dart `FinanceEngine`, Admin `calculateDistribution` using `tripFare`. Customer UI does not show 85/15 (correct). Rider shows trip/rider/company lines.

**ARCHITECTURE READY:** immutable `financeSnapshot`. Admin will not overwrite an existing snapshot. Reports should sum snapshots.

**IMPLEMENTATION PENDING BACKEND:** one shared snapshot table.

---

## 14. Invoice

**FINAL:** GST ₹0. Invoice number ≠ trip id.

**CURRENTLY IMPLEMENTED:** Admin PDF/HTML taxRate 0. Customer demo “sent” copy.

---

## 15. Payment

**FINAL BUSINESS RULE:** WHO PAYS (Customer / Receiver / split) is separate from HOW THEY PAY (Online / Cash / split). Partial payment is supported. Multiple transactions per trip. Status UNPAID / PARTIALLY_PAID / PAID. 85/15 still uses Trip Fare only. Invoice total stays the full amount.

**CURRENTLY IMPLEMENTED:** Dart `payment.dart`, Admin `paymentPlan.js`, Customer booking payment UI, Rider payment breakdown on incoming/details/active, Admin order drawer + invoice paid lines. New online allocations stay UNPAID.

**ARCHITECTURE READY / PAYMENT PROVIDER INTEGRATION PENDING:** live UPI/card capture; receiver online charge. Do not fake success.

**Receiver app:** **NOT YET IMPLEMENTED.** Architecture records receiver amounts on the trip. Do not create a new Receiver application.

**IMPLEMENTATION PENDING BACKEND:** shared payment ledger across Customer / Rider / Admin.

---

## 16. Wallet / COD

**FINAL:** Earning wallet, COD Due, settlement are separate. Never negative. Recharge and eligible earnings settle COD first. Suspend at ≥ ₹100.

**CURRENTLY IMPLEMENTED:** Rider providers + dashboard/wallet UI; Admin `codWallet.js` + wallet table; Dart `CodEngine`.

**IMPLEMENTATION PENDING BACKEND:** ledger across apps.

---

## 17. Rates

Admin Vehicle Categories remain the editor. Demo per-km often 0.

---

## 18. Profile

Unchanged except financial/COD surfaces. No theme change.

---

## 19. Notifications

Still mock. Unrelated; not redesigned.

---

## 20. Documents

Rider KYC still local. Unrelated.

---

## 21. Admin configuration

**CURRENTLY IMPLEMENTED:** Settings → Payment distribution, Company Office, Cancellation (customer + rider stages).

---

## 22. Security

Do not publish secrets. Admin demo passwords stay in Admin code, not in this folder.

---

## 23. Recent changes (this alignment)

| Change | Status |
|---|---|
| 85/15 on trip fare | FINAL + engines + tests |
| COD Due / settlement / suspend ₹100 | FINAL + Rider + Admin wallet |
| Stage-wise cancellation Admin UI | CURRENTLY IMPLEMENTED (localStorage) |
| Customer/Rider cancel quotes | CURRENTLY IMPLEMENTED against default/Admin-shaped config |
| Resend Case A / Case B | FINAL + engines + Customer dialog |
| Company office Admin fields | CURRENTLY IMPLEMENTED (localStorage) |
| Canonical 10-digit display IDs | CURRENTLY IMPLEMENTED for new IDs |
| Live shared order bus | IMPLEMENTATION PENDING BACKEND |

---

## 24. Conflicts (old docs → current)

| Old | Current |
|---|---|
| ₹10/km resend split undefined | Case A 85/15; Case B ₹8/₹2 |
| Cancellation permanently ₹0 | Default ₹0, Admin-configurable |
| Company office placeholder forever | Admin-editable |
| 85/15 on `order.amount` / payable | 85/15 on confirmed Trip Fare |
| Negative wallet for COD | Forbidden |

---

## 25. Open questions

See `OPEN_QUESTIONS.md`. **No critical open questions.**

---

## 26. Final confirmed business decisions

See `18_FINAL_BUSINESS_DECISIONS.md` and `RULES_BOOK.md` Golden Rules.

Cross-app live data: **ARCHITECTURE READY / IMPLEMENTATION PENDING BACKEND.**
