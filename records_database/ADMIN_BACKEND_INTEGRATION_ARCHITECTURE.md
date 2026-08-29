# IDHAR UDHAR — ADMIN BACKEND INTEGRATION ARCHITECTURE

**Phase:** 9  
**Date:** 2026-08-25  
**Authority:** NestJS `/v1` + PostgreSQL. Admin Web UI is a presentation client.

This document describes the Phase 9 Admin ↔ backend wiring. It does not change locked business rules.

---

## 1. What was implemented

Admin login, session restore, and logout now use Nest JWT (`POST /v1/admin/auth/login`, `GET /v1/auth/session`, refresh, logout) plus `GET /v1/admin/profile` for the fine-grained admin role.

On layout mount (and dashboard refresh), Admin hydrates orders, riders, customers, and (when finance-gated) payments from `/v1`. Order assign / cancel / canonical status hops POST to existing Admin order APIs. Wallet, COD, frozen earnings, payment transactions, and the in-app notification inbox read stored backend values.

Admin JavaScript no longer splits Trip Fare into 85 / 15 / operations / profit for API orders. Those amounts display only from `order_finance_snapshots` (ORIGINAL) when frozen.

---

## 2. Simple business meaning

The Admin console now looks at the same live marketplace database the Customer and Rider apps already use.

A Super Admin or Finance user can see real orders, riders, customers, wallet balances, COD Due, and frozen 85/15/50 numbers. They cannot invent those numbers in the browser. Actions that already existed on the server (assign rider, cancel, legal status hop) go to Nest. Actions that have no server API stay on the screen as local/mock and do not write Postgres.

---

## 3. Admin screens connected

| Screen | Connected? | Notes |
|---|---|---|
| Login / session / header | Yes | Nest email/password. Local Netlify/sub-admin passwords are no longer authority. |
| Dashboard | Yes | Counts and revenue from hydrated API orders/riders/customers. Revenue uses stored trip fare / frozen snapshot, not a JS 85/15 split. |
| Live operations | Yes | Order list from API. “Mark In Transit” POSTs canonical `IN_TRANSIT`. Decorative SVG map stays dummy. |
| Orders list / detail | Yes | List + assign + cancel + status. Create Order modal remains local-only (no Admin create-order API). |
| Tracking | Partial | Counts can follow hydrated orders. Map overlay stays dummy (no Google Maps production). |
| Riders directory / detail | Yes | Directory from API. Wallet / COD / frozen earnings from finance-gated APIs. KYC/bank fields are N/A (no KYC API). Add/edit/suspend remain local overlay. |
| Customers directory / detail | Yes | Directory + order history from API. Addresses not on API. Add/edit remain local overlay. |
| Payments | Yes | Stored `payment_transactions`. Refund has no API — does not mutate authority. |
| Wallet | Yes (read) | Per-rider wallet + COD + ledger. Admin credit/debit/payout POST does not exist — blocked with a message. |
| Earnings | Yes | ORIGINAL finance snapshots. Totals are sums of stored amounts. |
| Notifications inbox | Yes | Admin’s own in-app notices. Composer/campaigns stay mock. |
| Profile | Yes | Email/role from Nest. Name/city overlay stays local. |
| Reports | Yes (from connected lists) | Tables/charts derived from hydrated orders/riders/customers/payments. Not a new reporting API. |

---

## 4. APIs used (existing)

- `POST /v1/admin/auth/login`
- `GET /v1/auth/session`
- `POST /v1/auth/token/refresh`
- `POST /v1/auth/logout`
- `GET /v1/admin/profile`
- `GET /v1/admin/orders`
- `GET /v1/admin/orders/:id`
- `POST /v1/admin/orders/:id/assign`
- `POST /v1/admin/orders/:id/cancel`
- `POST /v1/admin/orders/:id/status`
- `GET /v1/admin/riders/:id/wallet`
- `GET /v1/admin/riders/:id/wallet/ledger`
- `GET /v1/admin/riders/:id/cod`
- `GET /v1/admin/riders/:id/cod/ledger`
- `GET /v1/admin/riders/:id/earnings`
- `GET /v1/notifications`
- `POST /v1/notifications/:id/read`
- `POST /v1/notifications/read-all`

---

## 5. New APIs created

Minimum list endpoints so Admin screens are not forced to N+1 existing per-id calls for directories and ledgers:

| Method | Path | Why |
|---|---|---|
| `GET` | `/v1/admin/riders` | Rider directory |
| `GET` | `/v1/admin/riders/:id` | One rider in that directory |
| `GET` | `/v1/admin/customers` | Customer directory |
| `GET` | `/v1/admin/customers/:id` | One customer |
| `GET` | `/v1/admin/payments` | Recent stored payment transactions (finance-gated) |
| `GET` | `/v1/admin/earnings` | ORIGINAL finance snapshots (finance-gated) |

`GET /v1/admin/orders` list payload was **enriched** with stored customer/rider phone, stop addresses, fare snapshot amounts, and frozen ORIGINAL finance when present. No new money formula.

---

## 6. Files created

- `records_database/ADMIN_BACKEND_INTEGRATION_AUDIT.md`
- `records_database/ADMIN_BACKEND_INTEGRATION_ARCHITECTURE.md` (this file)
- `IDHAR_UDHAR_ADMIN/src/api/config.js`
- `IDHAR_UDHAR_ADMIN/src/api/client.js`
- `IDHAR_UDHAR_ADMIN/src/api/errors.js`
- `IDHAR_UDHAR_ADMIN/src/api/mappers.js`
- `IDHAR_UDHAR_ADMIN/src/api/adminApi.js`
- `IDHAR_UDHAR_ADMIN/src/api/hydrate.js`
- `IDHAR_UDHAR_ADMIN/src/api/mappers.spec.js`
- `IDHAR_UDHAR_ADMIN/src/api/errors.spec.js`
- `backend/src/profiles/admin-directory.controller.ts`
- `backend/src/payments/admin-ledger.controller.ts`
- `backend/test/admin-directory.e2e-spec.ts`

---

## 7. Files modified

Admin: `authService.js`, `AuthContext.jsx`, `AdminLayout.jsx`, `commission.js`, `stores.js`, Login, Dashboard, Orders, LiveOperations, Riders, RiderDetail, Customers, CustomerDetail, Payments, Wallet, Earnings, Notifications, Reports, `.env.example`, `package.json`.

Backend: profiles (directory + identity list queries), orders (admin extras + serialize), payments/finance (admin lists), payments module registration. `finance.repository.ts` restored `findOriginal` after the list method was inserted.

**Not modified:** Customer Flutter, Rider Flutter, `MASTER_SYSTEM_ARCHITECTURE.md`, `records_database/migrations/*`.

---

## 8. Remaining mock screens

Verification KYC, payouts, coupons, promotions, support tickets, settings fare/COD editors, vehicles CRUD, vehicle-category editor (Netlify), zones CRUD, invoices / purchase invoices, announcements composer, notification campaign composer, Admin create-order, Admin wallet recharge/settle/payout, payment refund button.

Tracking / live-ops SVG map remains decorative.

---

## 9. Remaining blockers

| Item | Why it is not invented |
|---|---|
| Admin create order | `POST /v1/orders` is CUSTOMER-only. |
| Admin wallet credit / COD settle / payout | No admin mutation API; rider recharge and server ledgers remain the authority. |
| Refund | No refund endpoint. |
| KYC / vehicles / zones / coupons / tickets | No corresponding Admin APIs. |
| Production GPS map | Google Maps production is out of this phase. |
| Login against empty `admin_profiles` | A real admin row must exist in Postgres (e2e fixtures create these). |

---

## 10. Database changes

**NONE.** No migrations added, applied, reset, dropped, or recreated.

---

## 11. Master Architecture changes

**NONE.** `MASTER_SYSTEM_ARCHITECTURE.md` was not modified.

---

## 12. Tests executed and exact results

| Command | Result |
|---|---|
| Admin `npm test` (`node --test` mapper + error tests) | **2 suites / 7 tests passed** |
| Admin `npm run lint` (oxlint) | **exit 0** (pre-existing warnings only; no errors) |
| Admin `npm run build` (Vite) | **exit 0** — `dist/` produced |
| Backend `npx tsc --noEmit -p tsconfig.build.json` | **exit 0** |
| Backend `npm test` | **16 suites / 58 tests passed** |
| Backend `npm run test:e2e` | **15 suites / 98 tests passed** (includes new `admin-directory.e2e-spec.ts`) |

No Admin browser live login was exercised here (requires a Postgres `admin_profiles` row and a running Nest process).

---

## 13. Phase 1–8 regression results

Backend unit count is unchanged from Phase 8 (**16 / 58**). Backend e2e is Phase 8’s **14 / 96** plus **1 suite / 2 tests** for the new Admin directory and finance-gated payment/earnings lists — **all passed**.

Customer and Rider Flutter were **not modified** in Phase 9, so Flutter analyze/test/APKs were not re-run. Phase 8 Flutter results still stand.

Database was not migrated or reset. Master Architecture was not edited.

---

## 14. What must NOT be started yet

- Phase 10 / production deployment
- Redis GPS
- FCM / production push
- Payment provider + webhooks
- Google Maps production configuration
- Inventing Admin create-order, refund, payout, or KYC APIs
- Moving 85/15/GST/COD/wallet math into Admin JavaScript

---

## 15. Exact recommended next phase

**Stop. Do not start Phase 10 automatically.**

A later phase, only when product asks for it, may add production vendors (FCM, Redis GPS, payment provider, Maps) or remaining Admin screens **after** those APIs and business rules exist.

---

## Auth and money rules (how Admin talks to Nest)

```text
Admin login (email + password)
  → POST /v1/admin/auth/login
  → access JWT (role ADMIN) + refresh
  → GET /v1/admin/profile  (SUPER_ADMIN / FINANCE / …, finance_access)
  → Bearer on every /v1 call; 401 → one in-flight refresh

Orders / riders / customers
  → GET lists, display stored trip_fare and frozen snapshot when present

Wallet / COD / earnings / payments
  → finance-gated GET; amounts are NUMERIC strings from Postgres
```

Dev CORS already allows `http://localhost:5173`. Production Admin builds require `VITE_API_BASE_URL`.
