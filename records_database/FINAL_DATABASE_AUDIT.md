# FINAL DATABASE AUDIT

**Type:** Read-only documentation audit  
**Folder:** `records_database/`  
**Date:** 2026-08-21  

No application code was modified. No existing documentation was modified except this file. PostgreSQL was not implemented.

**Authoritative FINAL sources**

- `RULES_BOOK.md`
- `FINAL_MASTER_ANALYSIS.md`
- `18_FINAL_BUSINESS_DECISIONS.md` — V1 PRODUCT RULES CONFIRMED, CONFIRMED FINANCIAL MODEL, D2 PAYMENT RESPONSIBILITY, FINAL STATUS TABLE rows 5 / 12 / 13
- `OPEN_QUESTIONS.md`
- `19_DATABASE_REQUIREMENTS_FROM_FEATURES.md`

**Non-authoritative unless they match the sources above**

- Inner text of `01` / `02` / `03` (historical discovery)
- Body of `17_OPEN_DECISIONS.md` (banner is current; numbered list is stale)
- `04_UNIFIED_ENTITY_RELATIONSHIPS.md`
- `05_DATABASE_SCHEMA_BLUEPRINT.md`
- Leftover sections inside `18`: C, D (single-method bullets), L, M money table, status table row 3

---

## 1. Audit Result

**PASS WITH WARNINGS**

The FINAL business rules required for PostgreSQL design are documented and consistent in the authoritative sources.

Older files and leftover sections still describe superseded payment, cancellation, resend, and GST models. Those leftovers are documentation hygiene problems, not missing product decisions.

PostgreSQL, live payment gateway, Receiver app, and live Customer/Rider/Admin sync are correctly documented as **not implemented**.

**DATABASE DOCUMENTATION IS READY FOR POSTGRESQL DESIGN** if design uses the authoritative sources above and does not copy `05`, `04`, `17` body, or leftover `18` C / L / M as the specification.

---

## 2. Verified Business Rules

| Final rule | Status | Notes |
|---|---|---|
| Trip Fare → 85% Rider / 15% Company | VERIFIED | `RULES_BOOK` Financial Rules; `18` CONFIRMED FINANCIAL MODEL |
| 85/15 based on confirmed Trip Fare, not payer amount, not discounted payable | VERIFIED | ₹100 fare / ₹10 discount → customer pays ₹90; rider still ₹85 |
| Customer can pay 100% | VERIFIED | `18` D2 |
| Receiver can pay 100% | VERIFIED | `18` D2 |
| Customer + Receiver can split payment | VERIFIED | Sum must equal applicable total |
| One payer can split Online + Cash | VERIFIED | Example: Customer ₹50 Online + ₹50 Cash |
| Multiple payment transactions supported | VERIFIED | Single `paymentMethod` is not source of truth |
| Payment responsibility ≠ actual payment transaction | VERIFIED | WHO PAYS / HOW THEY PAY / owed / paid are separate |
| UNPAID / PARTIALLY_PAID / PAID | VERIFIED | Customer, Receiver, and overall trip |
| COD Due separate from Rider Earning Wallet | VERIFIED | |
| Wallet never negative because of COD Due | VERIFIED | |
| Eligible earnings settle COD Due | VERIFIED | |
| Recharge first clears COD Due | VERIFIED | |
| COD Due ≥ ₹100 suspends Rider | VERIFIED | Rider cannot accept new rides |
| Default cancellation fee = ₹0 | VERIFIED | Until Admin enables/configures |
| Admin controls cancellation | VERIFIED | Stage-wise enable / charge / shares |
| Customer and Rider cancellation rules are separate | VERIFIED | |
| Cancellation rider share + company share = 100% | VERIFIED | Invalid config cannot be saved |
| Resend Case A = Base Fare + ₹10/km with normal 85/15 | VERIFIED | Original trip already ended |
| Resend Case B = ₹10/km customer, ₹8/km rider, ₹2/km company | VERIFIED | Original trip not ended; not 85/15 |
| Historical transactions immutable | VERIFIED | |
| Admin setting changes must not modify historical transactions | VERIFIED | New versions only |
| Canonical Trip/Order ID | VERIFIED | Display `IU-{CITY}-{10-digit}`; UUID planned as Postgres PK |
| Canonical internal trip status | VERIFIED | Apps may show different wording |
| Invoice total remains the full applicable amount | VERIFIED | Customer Paid / Receiver Paid shown separately |
| PostgreSQL not implemented | VERIFIED | |
| Live payment gateway not implemented | VERIFIED | Do not fake success |
| Receiver app not implemented | VERIFIED | Architecture records receiver amounts on the trip |
| Customer/Rider/Admin live sync not implemented | VERIFIED | Separate mock stores |

Who pays and how they pay does **not** change the 85/15 split.

---

## 3. Database Entities Required

These are required by FINAL rules. Absence from `04`/`05` is a **POSTGRESQL IMPLEMENTATION REQUIREMENT**, not a missing business rule.

| Entity | Purpose |
|---|---|
| `customer` / `rider` / `admin_user` | Role-scoped accounts. Unique `(role, phone)` for customer/rider |
| `order` | Canonical trip. UUID PK + unique `display_id`. `customer_id`, nullable `rider_id` |
| `order_stop` | Ordered pickup/drops. Never comma-separated destinations |
| `order_status_event` | Canonical status history |
| `order_offer` | Rider accept lock |
| `vehicle_category` + `fare_config_version` | Admin rates |
| `order_fare_snapshot` | Confirmed Trip Fare and rate copy at booking confirm |
| `payment_settings_version` | 85/15/50 versions |
| `order_finance_snapshot` | Immutable rider/company/opex/profit freeze |
| `order_payment_responsibility` | Customer amount + Receiver amount = applicable total |
| `payment_transaction` | One row per actual payment. Payer type + method + amount + status |
| `wallet` | Rider earning wallet (available). Never used to store COD Due as a negative number |
| `wallet_transaction` | Append-only ledger |
| `rider_cod_due` / COD ledger | Money rider owes company. ≥ 0. Separate from wallet |
| `cod_settlement` event | Auto-settle from eligible earning or recharge |
| `cancellation_rule` | Admin config: actor, stage, enabled, fee, rider%, company% |
| `order_cancellation_snapshot` | Fee and shares frozen on that trip |
| `company_office` | Address, latitude, longitude |
| `failed_delivery` | Receiver unavailable, office distance, ₹8/km rider extra |
| `resend_request` / related order | Case A or Case B amounts; `parent_order_id` |
| `order_adjustment` | Office compensation, resend charge (not mixed into original 85/15) |
| `invoice` | Full transaction total; separate paid lines; invoice number ≠ trip id |
| `audit_log` | Admin writes to rates, cancellation, office, payment settings |
| `idempotency_key` | Create-order, accept, payment, webhook |

Receiver is a **payer type on the trip**, not a required user-application table.

---

## 4. Required Relationships

```text
customer 1 ── * order
rider    1 ── * order                 (null until assigned)
order    1 ── * order_stop
order    1 ── * order_status_event
order    1 ── 1 order_fare_snapshot
order    1 ── 1 order_payment_responsibility
order    1 ── * payment_transaction
order    1 ── 0..* order_finance_snapshot     (original freeze + reversal rows)
order    0..1 parent_order                    (resend)
order    0..1 failed_delivery / resend_request
rider    1 ── 1 earning wallet
rider    1 ── 1 COD Due ledger
admin    ── * payment_settings_version
admin    ── * cancellation_rule (customer table ≠ rider table)
admin    ── 1..* company_office
order    ── invoice
```

Constraints required by FINAL rules:

- `customer_responsibility + receiver_responsibility = applicable total`
- cancellation `rider_share + company_share = 100`
- payment settings `rider_percentage + company_percentage = 100`
- wallet available balance ≥ 0
- COD Due ≥ 0
- snapshots are insert-only

**POSTGRESQL IMPLEMENTATION REQUIREMENT:** `05` currently has `order_finance_snapshot.order_id UNIQUE`, which blocks a reversal row on the same order.

---

## 5. Payment Architecture Check

| Requirement | Documented FINAL | Blueprint `05` / `04` |
|---|---|---|
| WHO PAYS: Customer / Receiver / split | YES | NO |
| HOW THEY PAY: Online / Cash / split | YES | Partial (single method enum) |
| Multiple transactions per trip | YES | NO (singular `payment`) |
| Responsibility ≠ transaction | YES | NO |
| UNPAID / PARTIALLY_PAID / PAID | YES | Different enum: pending / paid / failed / refunded |
| Invoice total = full amount | YES | Invoice has total; paid-split fields not specified |
| Live gateway | NOT implemented | N/A |

**POSTGRESQL IMPLEMENTATION REQUIREMENT:** implement `order_payment_responsibility` + append-only `payment_transaction` (`payer_type`, `method` ONLINE\|CASH, `amount`, `status`, `provider_txn_id`, timestamps). Do not use one `order.payment_method` column as the complete source of truth.

PARTIALLY_PAID is an **aggregate** status (payer or trip). A single transaction row should be unpaid / paid / failed / refunded.

Online capture remains ARCHITECTURE READY / PAYMENT PROVIDER INTEGRATION PENDING. That does not block table design.

---

## 6. COD Architecture Check

| Requirement | Documented FINAL |
|---|---|
| COD Due ≠ earning wallet | YES |
| Never represent COD Due as negative wallet | YES |
| Auto-settle from eligible rider earnings | YES |
| Recharge clears COD Due first | YES |
| Suspend when COD Due ≥ ₹100 | YES |
| Full cash example: ₹100 cash, rider ₹85 → COD Due ₹15 | YES |
| Mixed cash below earning → COD Due ₹0 | YES |

**POSTGRESQL IMPLEMENTATION REQUIREMENT:** add an explicit COD Due ledger. `05` only has `wallet.available_balance` / `pending_balance`. `14` still mentions `cash_in_hand` without COD Due.

---

## 7. Financial Architecture Check

| Requirement | Documented FINAL |
|---|---|
| One 85/15 calculation on confirmed Trip Fare | YES |
| Payer mix does not change 85/15 | YES |
| Company 15% then 50% operations / 50% profit | YES |
| Operations not deducted from rider | YES |
| Settings versioned | YES |
| Reports sum snapshots, never live settings on old rows | YES |
| Cancellation not auto 85/15 | YES |
| Resend Case B not 85/15 | YES |
| Office handover ₹8/km not 85/15 | YES |
| GST ₹0 on fare | YES |

**POSTGRESQL IMPLEMENTATION REQUIREMENT:** persist `payment_settings_version` and copy percents/amounts onto `order_finance_snapshot`. Do not recompute historical P&L from current Admin settings.

---

## 8. Historical Snapshot Check

FINAL requires snapshots for financially confirmed/settled trips. Admin later changes must not rewrite them.

| Snapshot | When | Required contents |
|---|---|---|
| Fare snapshot | Booking confirm | Confirmed Trip Fare, distance, vehicle, parcel, rate version, discount, additional charges, net payable |
| Finance snapshot | Delivered or terminal cancel/fail | Trip Fare, rider%, company%, opex%, rider amount, company amount, version id, timestamp |
| Payment snapshot | Confirm + collections | Responsibility, paid amounts, methods, transactions, overall status |
| Cancellation snapshot | If cancelled | Stage, actor, fee, rider/company shares and amounts, rule version |
| Resend / failed-delivery snapshot | If applicable | Case A or B, distance, charges, rider/company amounts, office compensation |
| COD snapshot / ledger | If cash collected | Cash collected, COD Due created, later settlements as new rows |

`19` and `FINAL_MASTER` §6–8 list these. `05` covers fare + finance 85/15 only.

**POSTGRESQL IMPLEMENTATION REQUIREMENT:** extend snapshots beyond the original 85/15 freeze; keep them immutable.

---

## 9. Customer / Rider / Admin Linking Check

| Requirement | Status |
|---|---|
| One canonical trip/order ID for all three apps | VERIFIED as a rule |
| UUID PK + unique display_id | VERIFIED as planned Postgres model |
| `customer_id` and `rider_id` on the same order | VERIFIED |
| Admin operates on the same order | VERIFIED as a rule |
| One canonical internal status; UIs map labels | VERIFIED |
| Live row sync across apps today | NOT implemented |
| Receiver application | NOT implemented; do not create one to store who pays |

**POSTGRESQL IMPLEMENTATION REQUIREMENT:** one `order` row is the join point. Apps must not keep unrelated copies without FKs. No name-based joins.

---

## 10. Contradictions Found

These are leftover texts that contradict the FINAL lock. The FINAL lock wins.

### Cancellation

- FINAL: default ₹0, Admin-configurable, customer ≠ rider, shares = 100% (`18` golden 1, status table #12).
- STALE: `18` C and status table #3 still say cancelled orders have no cancellation fee and zero rider/company forever.
- STALE: `17` item 3 still says V1 has no cancellation fee.

### Resend

- FINAL: Case A 85/15 on base + ₹10/km; Case B ₹10 / ₹8 / ₹2 (`18` 5–6, status table #13).
- STALE: `18` M money table still says resend split requires a business decision.
- STALE: `17` items 13 and 30 still mark the ₹10/km split as open.
- STALE: `19` still says `order_adjustment.distribution_status = pending_business_rule` where needed.

### Payment

- FINAL: split who-pays / how-they-pay; multiple transactions; UNPAID / PARTIALLY_PAID / PAID (`18` D2).
- STALE: `18` D still says persist `order.cod` and `payment.method = cash`, and pending until delivered then paid.
- STALE: `04` / `05` still model a single `payment` row.

### GST / invoice tax

- FINAL: GST ₹0 on fare.
- STALE: `08` still says invoice tax 5%. Inner `03` discovery also says invoice tax default 5% (historical).

### Canonical status set

- FINAL: `FINAL_MASTER` includes failed-delivery / office / resend statuses.
- STALE: `00` happy-path list and `14` mapping table omit several of those statuses.

None of these reopen a FINAL rule. They would cause a wrong PostgreSQL design if copied.

---

## 11. Missing Requirements

Missing from the **schema blueprint**, not missing as business rules. All are **POSTGRESQL IMPLEMENTATION REQUIREMENT**.

1. Payment responsibility entity/columns
2. Multiple `payment_transaction` rows with payer type and method
3. Derived or stored customer_paid, receiver_paid, outstanding, overall payment status
4. COD Due ledger separate from earning wallet
5. COD settlement rows
6. Cancellation rule tables (customer vs rider) with versioning
7. Cancellation snapshot on the order
8. `company_office`
9. Failed-delivery / resend entities with Case A / Case B stored explicitly
10. Finance snapshot fields for payment, cancel, resend, COD (not only 85/15)
11. Receiver stored as payer/stop data, not as a new app
12. Finance snapshot reversal without mutating the original row
13. Failed-delivery / resend values in the canonical status enum used by `order.status`

`01`–`03` inner reports are outdated discovery. They are marked superseded at the top. That is expected historical documentation, not a missing FINAL rule.

---

## 12. Remaining Genuine Decisions

From `OPEN_QUESTIONS.md`. **No critical items.** Do not re-open finalized payment, COD, cancellation, or resend rules.

Non-critical only:

| Topic | Why it does not block financial schema |
|---|---|
| OTP length / SMS provider | Auth challenge columns can exist without choosing 4 vs 6 |
| Extra multi-stop fee | Do not invent. Max 3 drops already locked |
| Owner vs hired driver | Optional `rider_driver` already planned |
| Referral / promo program | Do not merge dummy amounts |
| Wallet KYC / min–max top-up | Ledger can exist without limits |
| Rating both ways | Later |
| Pickup/drop contacts required? | Nullable stop contact fields |
| Dispatch TTL / offer strategy | Offer table already planned |
| Statutory invoice SAC / e-invoice | Fare GST is ₹0; legal header later |

Online payment **provider and capture moment** are integration choices. The transaction model already supports UNPAID until a provider confirms.

---

## 13. PostgreSQL Readiness

| Item | Ready |
|---|---|
| FINAL money / payment / COD / cancel / resend / snapshot rules | YES |
| Honest “not implemented yet” status for Postgres, gateway, Receiver app, live sync | YES |
| `05` schema blueprint as copy-paste DDL | NO |
| Blocking unknown business rule for core money columns | NO |

PostgreSQL is planned and **not built**. That gap is expected. It is a **POSTGRESQL IMPLEMENTATION REQUIREMENT**, not a documentation defect in the FINAL rules.

---

## 14. Final Recommendation

Use this order when designing PostgreSQL:

1. `RULES_BOOK.md`
2. `18` V1 PRODUCT RULES CONFIRMED + CONFIRMED FINANCIAL MODEL + D2
3. `19_DATABASE_REQUIREMENTS_FROM_FEATURES.md` (ignore leftover `pending_business_rule` on resend)
4. `FINAL_MASTER_ANALYSIS.md` field list
5. `05` only as a starting list of identity / order / wallet / audit tables, then extend

Do not implement:

- a single trip `payment_method` as complete truth
- COD Due as a negative wallet
- cancellation as permanently ₹0 with no Admin tables
- resend split as unknown
- invoice tax 5% on fare
- a Receiver application

**DATABASE DOCUMENTATION IS READY FOR POSTGRESQL DESIGN.**

---

## Short summary

FINAL business rules are consistent. PostgreSQL is not built. The old schema blueprint is behind the FINAL payment, COD, cancellation, and resend model. Design from `RULES_BOOK` / `18` D2 / `19`, not from leftover sections. No new business questions are required to start PostgreSQL design.
