# 20 — GST & Company Financial Reporting

Additive feature. It does not change the 85/15 split, the 50% operational
allocation, or any existing financial record.

## What is taxed

GST applies to the **company commission only**.

```text
Trip Fare 100.00
  ├── Rider Share            85.00   (unchanged, payment_settings_versions)
  └── Company Commission     15.00   (unchanged)
        ├── GST                       ← this feature
        ├── Operational Cost  7.50    (50% of commission, unchanged)
        └── Company Profit            = commission − GST − operational cost
```

GST on the **customer trip fare stays 0**. That was already decided in
`18_FINAL_BUSINESS_DECISIONS.md`, and `order_fare_snapshots.tax` remains 0.
`tax_config_versions.applies_to` is locked to `COMPANY_COMMISSION` by a CHECK
constraint so a row here can never be read as a customer fare tax.

## Calculation basis — stated, never assumed

The basis is stored per configuration version and copied onto every order, and
is reported next to every amount. Three values are supported:

| Basis | Meaning | Taxable amount | GST amount |
| --- | --- | --- | --- |
| `EXCLUSIVE` | GST computed on top of the commission and funded from it | commission | `ROUND(commission × rate / 100, 2)` |
| `INCLUSIVE` | The commission already contains GST | `ROUND(commission × 100 / (100 + rate), 2)` | commission − taxable |
| `NONE` | No GST | commission | 0 |

Default seeded configuration: **18.00% EXCLUSIVE**, pending CA verification.
On a 15.00 commission that is 2.70 GST and 4.80 profit. This is the software's
configured treatment, not a legal opinion; change the version to change it.

A 0 rate must be published with the `NONE` basis, so a zero-GST period is an
explicit statement rather than a silently missing value.

## Where the numbers come from

Backend and database only. The Admin panel displays them and never recomputes.

- Revenue basis: exactly one `ORIGINAL` row in `order_finance_snapshots` per
  order, already unique by `finance_snap_one_original`.
- `order_tax_snapshots` freezes the rate, basis and derived amounts for that
  snapshot, inside the same transaction as the finance freeze. Insert-only,
  enforced by `forbid_update_delete()`.
- Report date basis is `order_finance_snapshots.frozen_at`, grouped in
  `Asia/Kolkata`, and labelled `FINANCE_FREEZE` in the response.

The identical GST expression lives in one place per language:
`gst-sql.ts` for SQL and `gst-math.ts` for TypeScript, with matching unit tests.

## Historical stability

Publishing a new rate inserts version N+1 and supersedes the previous one;
`protect_published_config()` blocks edits to a published payload. Because each
order carries its own frozen tax snapshot, a rate change never moves a past
report. Backdating `effective_from` is rejected for the same reason.

Orders frozen before this feature existed have no tax snapshot. They resolve
against the version effective at their `frozen_at`, and the response flags them
with `tax_frozen: false`.

## Deliberately out of scope

These are company money but do not follow the 85/15 split, so mixing them into
this report would break its arithmetic. They are excluded and the response says
so in its `scope` field:

- `resend_snapshots.company_amount`
- `order_cancellation_snapshots.company_amount`
- `order_adjustments`

Also, to avoid double counting: payment transactions, wallet ledger entries and
the COD ledger are **never summed as revenue**. Payments appear only as a
derived collection status (`UNPAID` / `PARTIALLY_PAID` / `PAID`), computed on
the same owed basis the payments module uses — the responsibility split when it
exists, otherwise the confirmed bill. A partially collected order still reports
its full commission.

## Interfaces

- `GET /v1/admin/reports/gst` — summary, per-period groups, paginated records.
- `GET /v1/admin/reports/gst/export` — two-sheet xlsx (Summary, Transactions)
  built in the backend from the same SQL, honouring the same filters.
- `GET|POST /v1/admin/tax-config` — read and publish versions.

Access reuses the existing admin finance ACL. Reading requires finance access;
publishing a version requires `SUPER_ADMIN` or `FINANCE`. Report runs, exports
and configuration changes are written to `audit_logs` with
`category = 'FINANCIAL'`.
