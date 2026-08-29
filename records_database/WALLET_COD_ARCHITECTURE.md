# IDHAR UDHAR — WALLET & COD ARCHITECTURE

**Type:** Phase 5 implementation architecture  
**Date:** 2026-08-25  
**Does not modify:** `MASTER_SYSTEM_ARCHITECTURE.md`, PostgreSQL schema, Flutter, Admin UI  

Master §§10.2, 18–19 remain the rule authority. This file describes the running NestJS rider wallet and COD settlement slice.

---

## Two ledgers (do not collapse)

```text
Trip Fare (frozen snapshot)
        ↓  85/15 only uses this
Rider earning (historical)     order_finance_snapshots.rider_amount
Company share                  order_finance_snapshots.company_commission_amount
        ↓
Payment transaction            what happened with the customer's money
        ↓
COD ledger                     company cash the rider is holding
Wallet ledger                  rider available digital money
```

These are three different concepts. A cash collection does not create a second payment row, and it does not mix COD Due into the wallet.

GST on fare remains ₹0.

---

## Rider wallet

Tables: `rider_wallet_accounts` (materialized `available_balance`) and `wallet_ledger_entries` (append-only truth).

- Available balance is never negative (`CHECK available_balance >= 0`).
- Every balance change is the same PostgreSQL transaction as a ledger insert.
- Materialized balance must equal `SUM(CREDIT) − SUM(DEBIT)`.
- Cash-trip rider share is **not** posted here. Physical cash in the rider's hand is not digital available money.

Ledger `entry_type` values used in this phase:

| Type | When |
|---|---|
| `EARNING` | Digital remainder after COD settle-first, from a frozen snapshot |
| `RECHARGE` | Wallet remainder after recharge settle-first |
| `COD_SETTLEMENT` | Not used as a wallet debit in this phase (COD is settled from inflow before credit) |

`PAYOUT`, `ADJUSTMENT`, `CANCELLATION_SHARE`, `RESEND_EARNING` exist in the schema. This phase does not invent product flows for them.

---

## COD Due

Tables: `rider_cod_accounts` (`cod_due`) and `cod_ledger_entries`.

COD Due is money the rider owes the company. It is never stored as a negative wallet. It is never negative (`CHECK cod_due >= 0`).

```text
Trip Fare ₹100 → Rider ₹85, Company ₹15
Customer gives ₹100 cash.

Wallet            = unchanged (₹85 is physical cash, not a ledger credit)
COD Due           += ₹15     (company share held as cash)
```

`companyDueFromCash = GREATEST(0, cash_collected − rider_amount)` using the **frozen** snapshot rider amount, computed in PostgreSQL `NUMERIC(12,2)`.

If cash ≤ rider earning: COD Due does not increase. The unpaid digital remainder is not auto-credited (later online settlement; production capture moment is still a business decision).

---

## 85 / 15 earning

Uses `order_finance_snapshots`. Never recalculates old trips from live Admin sliders.

Locked example: Trip Fare ₹100 → Rider ₹85, Company ₹15, Operations ₹7.50, Profit ₹7.50.

Company operations/profit stay an internal split of the company share. They are not a rider deduction.

---

## COD collection

When a CASH `payment_transactions` row is PAID **and** an ORIGINAL finance snapshot exists **and** a rider is assigned:

- Post `cod_ledger_entries` `INCREASE` / `CASH_COMPANY_SHARE`
- Update `rider_cod_accounts.cod_due`
- Do **not** credit wallet

Phase 4 payment recording without a freeze still does not touch wallet/COD (rider earning is not historically frozen yet).

---

## Digital earning (ADMIN_TEST_TRIGGER seam)

Production capture moment is still unresolved (normally DELIVERED). This phase applies digital earning on the existing freeze seam when:

- ORIGINAL snapshot exists
- rider is assigned
- paid cash = 0
- planned cash = 0 (online-intended trip)

Then rider_amount is an eligible digital inflow: **COD Due is cleared first**, remainder is `wallet_ledger_entries` `EARNING` `CREDIT`.

A cash-planned trip never takes this path, so a cash trip cannot falsely settle its own COD Due through a wallet earning.

---

## Recharge settle-first (LOCKED)

```text
Wallet = ₹85
COD Due = ₹15
Recharge = ₹20

₹15 → COD DECREASE (RECHARGE_SETTLEMENT)
₹5  → wallet CREDIT (RECHARGE)

Wallet = ₹90
COD Due = ₹0
```

The full recharge is **not** credited to the wallet first. Remainder 0 means COD-only (no zero-amount wallet row; ledger amounts must be > 0).

Twin FKs (`related_cod_ledger_id` / `related_wallet_ledger_id`) are set in the same deferred transaction when both a settlement decrease and a wallet remainder exist.

---

## COD settlement endpoint

`POST /v1/rider/cod/settle` remits company cash the rider already holds.

- Amount cannot exceed current COD Due
- COD `DECREASE` with source `RECHARGE_SETTLEMENT` (incoming money that only pays Due; no wallet credit)
- Rejects `COD_SETTLEMENT_EXCEEDS_DUE` rather than pushing remainder into the wallet

---

## ₹100 suspension rule (LOCKED)

Compared in PostgreSQL `NUMERIC(12,2)` against ACTIVE `cod_policy_versions.suspend_threshold`, default **₹100.00** if no ACTIVE row exists.

```text
COD Due >= ₹100  → SUSPENDED_FOR_COD → cannot accept / cannot be offered a new ride
COD Due = ₹99.99 → NOT suspended by this rule
```

`rider_profiles.cod_operational_status` is updated in the same transaction as the COD balance change. Accept and offer also lock the COD account and compare Due to the threshold (stale flag cannot bypass).

Existing assigned trips may finish. No bypass endpoint.

---

## Wallet must never go negative

Debits use:

```sql
UPDATE ... SET available_balance = available_balance - amount
WHERE available_balance >= amount
```

plus the table CHECK. A would-be negative update is rejected (`WALLET_INSUFFICIENT` / CHECK `23514`). This phase does not expose payout/withdraw.

---

## Concurrency

One rider finance lock (wallet row then COD row, plus rider profile) for:

- recharge, settle
- COD collection / digital earning apply
- offer accept / dispatch eligibility

Order money operations lock the order first, then the rider. Two recharges on one rider serialize. No lost update.

---

## Idempotency

`POST /v1/rider/wallet/recharge` and `POST /v1/rider/cod/settle` require `Idempotency-Key`.

- Scope `recharge` / `cod-settlement` (existing `idempotency_keys` CHECK)
- Key `{identity_id}:{header}`
- Same key + same body → original result
- Same key + different body → `IDEMPOTENCY_CONFLICT`

COD `source_txn_id` unique `(cod_account_id, source_txn_id)` backs settlement/collection idempotency.

---

## Immutability

Existing triggers forbid UPDATE/DELETE of `wallet_ledger_entries` and `cod_ledger_entries`. Historical rows are not rewritten. Corrections are new rows (admin adjustment source exists; this phase does not invent a product adjustment UI).

---

## Authorization

Session identity/profile is the owner. Rider APIs do not accept another `rider_profile_id`.

| Actor | Wallet / COD / earnings |
|---|---|
| Rider | Own only |
| Customer | Forbidden |
| Admin | Super Admin, Finance role, or `finance_access` |

Staff without finance access receive `FORBIDDEN`. No unrestricted staff wallet permission.

---

## APIs

| Method | Path |
|---|---|
| GET | `/v1/rider/wallet` |
| GET | `/v1/rider/wallet/ledger` |
| POST | `/v1/rider/wallet/recharge` (`Idempotency-Key`) |
| GET | `/v1/rider/cod` |
| GET | `/v1/rider/cod/ledger` |
| POST | `/v1/rider/cod/settle` (`Idempotency-Key`) |
| GET | `/v1/rider/earnings` |
| GET | `/v1/admin/riders/:id/wallet` |
| GET | `/v1/admin/riders/:id/wallet/ledger` |
| GET | `/v1/admin/riders/:id/cod` |
| GET | `/v1/admin/riders/:id/cod/ledger` |
| GET | `/v1/admin/riders/:id/earnings` |

Money is serialized as two-decimal INR text from PostgreSQL NUMERIC. No FLOAT/DOUBLE authority.

---

## Resend Case A / Case B

Not implemented as a product flow in this phase. Locked formulas are unchanged:

- **Case A:** customer = (rate-sheet base at resend) + ₹10/km; then versioned 85/15 on that amount
- **Case B:** customer ₹10/km, rider ₹8/km, company ₹2/km — **not** 85/15

Use `resend_snapshots` / `extra_rate_versions` when that product slice is built. Do not apply generic 85/15 to Case B.

---

## Unresolved financial policies (unchanged)

- Production finance capture/finalization moment
- Cancellation wallet posting (do not invent; use cancellation snapshots/adjustments when that slice is built)
- Failed-delivery settlement without resend
- Customer wallet auto-debit
- Payout / withdraw product rules
- Admin wallet debit/credit product UI (schema `ADJUSTMENT` / `ADMIN_ADJUSTMENT` exist)
- ONLINE capture (still never faked PAID)

This phase does not silently decide those items.

---

## Out of scope

Redis, Google Maps, FCM, notification workers, Flutter rewiring, Admin UI redesign, production deployment, schema/migrations.
