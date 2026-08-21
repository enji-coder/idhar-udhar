# DATABASE REQUIREMENTS FROM V1 FEATURES

**Status:** Discovery only. **Do not create PostgreSQL, migrations, or production schema in this phase.**

**Current-system narrative (2026-08-21):** `FINAL_MASTER_ANALYSIS.md`. Requirements below remain valid for the **future** schema (multi-stop rows, multi-active customer orders, failed delivery, role-scoped phones, fare/finance snapshots).

These requirements were found while implementing failed delivery, multi-stop booking, multi-active customer orders, role-scoped phones, and Admin fare configuration. The next dedicated database-architecture phase must cover them.

## Must-support relationships

| Requirement | Notes |
|---|---|
| `customer` → many `order` | No unique-active-order constraint |
| `order` → many ordered `order_stop` | Stable UUID + `sequence`. Pickup + N drops. Never comma-separated destinations |
| `order` → failed-delivery state | Canonical statuses including receiver_unavailable, parcel_at_company_office |
| Failed delivery reason | V1 enum includes `receiver_unavailable` |
| Company office destination | Admin-managed location master (Settings → Company Office). Flutter uses `CompanyOffice.current` / `PlatformRules` |
| Failed delivery office distance | Stored km used for ₹8 compensation |
| Rider failed-delivery compensation | Separate financial component; not 85/15 |
| Customer resend request | Status: not_decided / requested / in_progress / completed |
| Resend charge | Separate ₹10/km component. **Case A** (trip ended): plus rate-sheet base fare; both 85/15. **Case B** (trip active): ₹8/km rider + ₹2/km company |
| Original order ↔ resend | `parent_order_id` / `original_order_id`. Do not overwrite the original |
| Customer active order list | Query by customer + non-terminal statuses |
| Role-scoped phones | Unique `(account_role, phone)`. Customer and Rider may share a number |
| Fare configuration | Admin vehicle category fare table |
| Fare configuration version | New version on Admin save; never mutate old versions |
| Historical fare snapshot | Copied onto the order at quote/confirm |
| Financial snapshot | Immutable original 85/15. Additive compensation/resend rows |
| Payment responsibility | customer_responsibility + receiver_responsibility = total |
| Payment transactions | Multiple rows per order: payer_type, method, amount, status, provider_txn_id |
| Payment status | UNPAID / PARTIALLY_PAID / PAID for customer, receiver, overall |

## Suggested future tables (not created)

- `account` or separate `customer_account` / `rider_account` with role-scoped unique phone
- `order`, `order_stop`, `order_status_event`
- `failed_delivery`, `resend_request`
- `company_office`
- `fare_config_version`
- `order_fare_snapshot`
- `order_finance_snapshot`
- `order_payment_responsibility`
- `payment_transaction` (append-only; payer_type + method + status)
- `order_adjustment` (office compensation, resend charge) with `distribution_status = pending_business_rule` where needed
- Idempotency keys for create-order, accept, pickup, delivery-attempt, receiver-unavailable, office-drop, resend, payment

## Do not do yet

No migrations. No PostgreSQL. No production API. Next phase: dedicated database architecture analysis using this file plus `18_FINAL_BUSINESS_DECISIONS.md`.
