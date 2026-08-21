# PAYMENT & FINANCIAL ARCHITECTURE

**Current engines (2026-08-21):** Dart `finance.dart` + `payment.dart` + `cod.dart` + `cancellation.dart` and Admin `commission.js` / `paymentPlan.js` / `codWallet.js` / `cancellationRules.js`. **85/15 uses confirmed Trip Fare, not discounted payable.** **WHO PAYS ≠ HOW THEY PAY.** Split payment is FINAL. Snapshots must not be overwritten. See `FINAL_MASTER_ANALYSIS.md`.

## Business rule (authoritative)

Configurable (Admin Payment Settings), **not hardcoded in schema defaults only**:

```
rider_amount              = ride_amount × rider_share_percent / 100
company_commission        = ride_amount × company_commission_percent / 100
                          = ride_amount − rider_amount  (must sum to 100%)
operational_cost          = company_commission × operational_cost_percent / 100
actual_profit             = company_commission − operational_cost
```

Example ₹100 / 85 / 15 / 50: rider ₹85, commission ₹15, opex ₹7.50, profit ₹7.50.

Admin already implements this in `commission.js` (`PAYMENT_DEFAULTS`, `calculateDistribution`, `attachFinanceSnapshot`). Production must persist **versions + snapshots**, which localStorage does not.

---

## Payment responsibility (FINAL)

Do not store only `order.paymentMethod`.

```text
Trip / Order
    ↓
Payment Responsibility
    ├── Customer Responsibility
    └── Receiver Responsibility
Payment Transactions
    ├── Customer → Online
    ├── Customer → Cash
    └── Receiver → Cash
```

`customer_responsibility + receiver_responsibility = applicable total`.

Each payment row: order_id, payer_type (CUSTOMER|RECEIVER), method (ONLINE|CASH), amount, status (UNPAID|PARTIALLY_PAID|PAID), provider_txn_id (nullable), timestamps.

Overall order status is derived from paid vs due. Invoice total remains the full amount.

**ARCHITECTURE READY / PAYMENT PROVIDER INTEGRATION PENDING** for live online capture. Do not fake success.

---

## Settings versioning

`payment_settings_version` row per change:

- percents, `effective_from`, `created_by`, `created_at`  
- previous version closed with `effective_to`  
- audit_log before/after  

Current Admin Settings has **no effective date, no updated-by, no history**. That is a gap to close in backend, not in UI this step.

---

## Freeze / snapshot

When an order becomes financially final (`delivered`, or cancelled/failed per policy):

Write **immutable** `order_finance_snapshot` copying:

- `payment_settings_version_id`  
- percents used  
- ride_amount (customer payment for the ride; GST/packaging may be invoice-only — see open questions)  
- rider_amount, company_commission, operational_cost, actual_profit  

Reports **sum snapshots**, never `calculateDistribution(order.amount, getPaymentSettings())` for historical rows.

Admin code already prefers `order.financeSnapshot` if present — production makes that mandatory after freeze.

---

## Ledgers (do not store only `order.totalAmount`)

| Record | Role |
|---|---|
| order.amount / fare snapshot | What customer was quoted |
| payment | Gateway/cash/wallet movement + provider_txn_id + status |
| wallet_transaction | Customer/rider book |
| order_finance_snapshot | Internal P&L split |
| payout | Rider settlement of **online** earnings |
| invoice | Tax invoice to customer (may include packaging + GST) |
| purchase_invoice | Company vendor spend (not ride P&L) |

Double-entry optional later; Day 1: **append-only wallet_transaction + freeze snapshot + payment row**. Wallet updates in the **same DB transaction** as the ledger insert.

---

## Cash vs online (from Admin `riderWallet.js`)

- **Cash COD:** rider may hold `cash_in_hand` (customer paid rider). Company may net this against payouts.  
- **Online/UPI/card/wallet:** company collects; rider `pending_payout` until payout Paid.  

Rider app currently shows estimated earnings plus trip/customer/receiver payment and COD Due. Backend must still persist the snapshot 85%.

---

## Payment methods (Admin)

Supported charge methods for a trip: **Online** and **Cash**. Admin mock still has UPI/Card/Wallet labels; those map to Online. A trip may have mixed methods. Customer booking collects who pays and how they pay. Live gateway is **not** connected.

## Refunds

`payment` direction refund; wallet credit if original wallet; invoice status cancelled/refunded; finance snapshot policy for cancelled (Admin currently zeros rider/company split). **Do not mutate original snapshot** — add `reversal` row or `cancelled_finance` flag per policy (open: full vs partial).

## Invoices vs commission

Invoice tax 5% + packaging (invoiceService) is **customer GST**, not operational_cost. Keep separate columns. Company GSTIN/CIN live on `company_profile` copied into invoice snapshot.

## Idempotency & webhooks

Provider webhooks update `payment.status`. If webhook succeeds and order update fails: retry worker, payment remains source for “money in”. Outbox table for events.

## What Admin reports should sum

`SUM(order_finance_snapshot.ride_amount)` as GMV/revenue (excluding cancelled/failed per `dashboardMetrics.isRevenueOrder`).  
Rider earnings: `SUM(rider_amount)` + incentives table later.  
Profit: `SUM(actual_profit)`.
