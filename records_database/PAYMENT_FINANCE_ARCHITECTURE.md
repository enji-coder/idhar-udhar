# IDHAR UDHAR — PAYMENT & FINANCE ARCHITECTURE

**Type:** Phase 4 implementation architecture  
**Date:** 2026-08-25  
**Does not modify:** `MASTER_SYSTEM_ARCHITECTURE.md`, PostgreSQL schema, Flutter, Admin UI  

Master §§16–17 and §22 remain the rule authority. This file describes the running NestJS payment/finance foundation.

---

## Four facts (do not collapse)

```text
Confirmed Trip Fare (order_fare_snapshots.trip_fare)
        ↓  85/15/50 only uses this
Payment responsibility   who owes the BILL (usually net payable)
        ↓
Payment plan             how they intend to pay (not PAID)
        ↓
Payment transaction(s)   what actually happened (many rows)
        ↓
Derived payment status   UNPAID / PARTIALLY_PAID / PAID
        ↓
Finance snapshot         immutable 85/15/50 P&L freeze
```

WHO PAYS ≠ HOW THEY PAY ≠ a transaction ≠ aggregate status.

---

## Payment responsibility

Table: `order_payment_responsibilities` (1:1 per order, immutable after insert).

`who_pays`: CUSTOMER | RECEIVER | SPLIT  

Constraint: `customer_responsibility + receiver_responsibility = applicable_bill_total`.

The bill is fare snapshot **net payable**. It is **not** the 85/15 base.

SPLIT requires both amounts > 0 and the sum equal to the bill.

---

## Payment plan

Table: `order_payment_plans` (1:1, immutable). Intention only.

Per payer: planned ONLINE + planned CASH = that payer’s responsibility (DB trigger).

Plan is not a payment and does not mark money PAID.

Cash vs online launch policy is **unresolved**. If an ACTIVE `payment_method_policy_versions` row exists, it is honored. If none exists, both methods remain allowed (no invented default).

---

## Payment transaction

Table: `payment_transactions`. Many per order.

| Field | Values |
|---|---|
| payer_type | CUSTOMER / RECEIVER |
| method | ONLINE / CASH |
| direction | CHARGE / REFUND |
| transaction_status | PENDING / PAID / FAILED / REFUNDED |

UNPAID / PARTIALLY_PAID / PAID are **not** transaction statuses.

ONLINE CHARGE is stored PENDING. The unconfigured provider records an intent only. It never marks ONLINE PAID (no Razorpay/Stripe/Paytm; no fake capture).

CASH CHARGE is PAID when the assigned rider or an admin confirms collection.

FAILED is an ONLINE attempt recorded by admin. It does not count toward paid.

---

## Derived payment status

Computed from successful money only:

```text
net_paid(payer) = SUM(PAID CHARGE) − SUM(REFUNDED REFUND)
```

| Status | Rule |
|---|---|
| UNPAID | paid = 0 (and owed > 0) |
| PARTIALLY_PAID | 0 < paid < owed, or paid ≠ owed (overpay is not silent PAID) |
| PAID | paid equals owed after NUMERIC(12,2) formatting |

Computed for Customer, Receiver, and Overall. Not stored as a mutable order column.

---

## Refunds

A refund is a **new** row: `direction = REFUND`, `transaction_status = REFUNDED`.

The original PAID charge is not rewritten. No payment-provider refund API.

Refund amount cannot exceed that payer’s net successful payments.

---

## 85 / 15 / 50

Applies to **confirmed Trip Fare** only. Not invoice total, not payable, not GST, not who paid.

Defaults from ACTIVE `payment_settings_versions` (never hardcoded as production config; never edit a published version in place).

PostgreSQL NUMERIC rounding (same remainder rule as the shared FinanceEngine):

```text
rider      = ROUND(trip_fare × rider% / 100, 2)
company    = ROUND(trip_fare − rider, 2)
operations = ROUND(company × ops% / 100, 2)
profit     = ROUND(company − operations, 2)
```

Locked example: Trip Fare ₹100 → Rider ₹85, Company ₹15, Operations ₹7.50, Profit ₹7.50.

Operations is an internal allocation **from the company share**. It is not a rider deduction.

GST on fare remains ₹0.

Exact halfway paise tie-break beyond this remainder rule is still **NEEDS BUSINESS DECISION**. This phase does not invent a new one.

---

## Finance snapshot

Table: `order_finance_snapshots`. Insert-only. `order_id` is not unique. One ORIGINAL per order (partial unique index). Reversal = a later new row (not implemented as a product flow in this phase).

Copied at freeze: trip fare, percents, amounts, `payment_settings_version_id`, `frozen_at`.

Historical amounts are never recalculated from live Admin sliders.

**Capture moment:** Master says normally DELIVERED; the exact production event is still a business decision. This phase does **not** auto-freeze on DELIVERED.

`POST /v1/admin/orders/:id/finance/freeze` is a labeled **ADMIN_TEST_TRIGGER** so tests and later lifecycle code can call the same service. It is not the locked production moment.

---

## Immutability

UPDATE/DELETE of finance snapshots, responsibility, and plan is forbidden by existing triggers.

Payment transaction identity/money columns are immutable. PENDING may move to PAID or FAILED only. Refunds are new rows.

---

## Idempotency and concurrency

Money POST `/payment/transactions` requires `Idempotency-Key`.

- Scope `payment` in `idempotency_keys` (key `{identity_id}:{order_id}:{header}`)
- Unique `(order_id, idempotency_key)` on `payment_transactions`

Same key + same body → original row. Same key + different body → `IDEMPOTENCY_CONFLICT`.

Concurrent identical collections lock the order row (`FOR UPDATE`) before insert, then apply remaining-owed checks for PAID charges.

---

## Authorization

Session identity/profile is the owner. Client-supplied customer_id / rider_id is not trusted.

| Actor | Payment |
|---|---|
| Customer | Own order: set responsibility/plan; ONLINE intent; read |
| Rider | Assigned (or offered) read; assigned rider may confirm CASH |
| Admin | Read; CASH collection; FAILED online attempt; refund; test freeze |

---

## Out of scope (this phase)

Rider wallet settlement, COD due/settlement, recharge, wallet suspension, production payment provider, Redis, FCM, Google Maps, Flutter/Admin redesign.

Wallet and COD tables are unused here on purpose.

---

## Unresolved business decisions (unchanged)

- Cash-first vs online launch
- Authorize-at-booking vs capture-at-delivery
- Payment provider vendor
- Production finance capture moment (DELIVERED vs other terminal events)
- 85/15 paise halfway tie-break beyond the existing remainder rule
