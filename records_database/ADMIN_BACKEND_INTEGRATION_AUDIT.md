# IDHAR UDHAR — ADMIN BACKEND INTEGRATION AUDIT

**Type:** Phase 9 pre-implementation audit  
**Date:** 2026-08-25  
**Does not modify:** Admin UI, Flutter, Master Architecture, PostgreSQL, migrations  

This file records what the Admin web app is today, which Nest `/v1` endpoints already exist, and the minimum change proposed per screen. No screens were redesigned during this audit.

---

## Layout

| Item | Path / fact |
|---|---|
| Admin root | `IDHAR_UDHAR_ADMIN/` (React + Vite, port **5173**) |
| Router | `src/App.jsx` |
| Auth | `src/context/AuthContext.jsx` + `src/services/authService.js` |
| Session today | Netlify `/.netlify/functions/admin-login` / `admin-session` / `admin-logout`, plus **local** `authenticateSubAdmin` + `sessionStorage` |
| Data | In-memory `createEntityStore` in `src/services/stores.js`, seeded from `src/data/*` |
| Money JS (must not stay authoritative) | `src/services/fareEngine.js`, `commission.js`, `codWallet.js`, `riderWallet.js`, `dashboardMetrics.js` |
| Vehicle catalog | Netlify `vehicle-categories` function + local `src/data/vehicleCategories.js` |
| Tests | **None** (`package.json` has `dev` / `build` / `lint` only) |
| Nest auth JWT | `POST /v1/admin/auth/login` → access + refresh. Session role is always JWT `ADMIN`. Fine-grained role lives on `admin_profiles.role` via `GET /v1/admin/profile` (`SUPER_ADMIN`, `SUB_ADMIN`, `OPERATIONS`, `FINANCE`, `SUPPORT`, `MANAGER`, `finance_access`, `payout_approve`, `modules`) |
| CORS | Dev Nest already allows loopback (`localhost` / `127.0.0.1` / `10.0.2.2`) any port; `CORS_ORIGIN` includes `http://localhost:5173` |

There is **no** Nest HTTP client in Admin today.

---

## Mock / static data sources

| Source | Used by |
|---|---|
| `src/data/mockData.js` | Orders, riders, customers, tickets, transactions, payouts, inbox seed, map pins, metrics |
| `src/data/vehicles.js` / `zones.js` / `invoices.js` / `wallet.js` / `announcements.js` / `notifications.js` / `earnings.js` / `adminAccounts.js` / `companyOffice.js` / `logisticsSeed.js` | Matching screens + stores |
| `src/services/stores.js` | Persistent localStorage entity stores wrapping the seeds |
| `src/services/adminUsers.js` | Local sub-admin passwords (not Postgres) |
| `src/hooks/useMockLoader.js` | Fake loading delay |
| Netlify functions | Super-admin login against env `ADMIN_EMAIL` / `ADMIN_PASSWORD`; vehicle-categories |

---

## Existing Nest endpoints relevant to Admin

| Endpoint | Sufficient for |
|---|---|
| `POST /v1/admin/auth/login` | Login (email/password → JWT). **Not** Netlify. |
| `GET /v1/auth/session` | Restore session |
| `POST /v1/auth/token/refresh` | Access expiry |
| `POST /v1/auth/logout` | Logout |
| `GET /v1/admin/profile` | Role, modules, finance_access, payout_approve, email |
| `GET /v1/admin/orders` | Order list (no fare/finance on list payload today) |
| `GET /v1/admin/orders/:id` | Detail + stops + `fare_snapshot` if confirmed |
| `GET /v1/admin/orders/:id/route` | Server distance for tracking |
| `POST /v1/admin/orders/:id/assign` | Assign rider (`rider_profile_id`) |
| `POST /v1/admin/orders/:id/offers` | Offer to rider |
| `POST /v1/admin/orders/:id/cancel` | Cancel |
| `POST /v1/admin/orders/:id/status` | Canonical status hop |
| `GET /v1/orders/:id/payment` | Payment plan/status (ADMIN allowed) |
| `GET /v1/orders/:id/payment/transactions` | Per-order transactions |
| `GET /v1/orders/:id/finance` | Frozen 85/15/50 snapshots |
| `POST /v1/admin/orders/:id/finance/freeze` | Test freeze seam only — **not** production capture |
| `GET /v1/admin/riders/:id/wallet` | Wallet balance (finance-gated) |
| `GET /v1/admin/riders/:id/wallet/ledger` | Wallet ledger |
| `GET /v1/admin/riders/:id/cod` | COD Due (Wallet ≠ COD) |
| `GET /v1/admin/riders/:id/cod/ledger` | COD ledger |
| `GET /v1/admin/riders/:id/earnings` | Frozen rider earnings for one rider |
| `GET /v1/notifications*` | Admin **inbox** (own notifications). Not campaign send. |
| `GET/PUT /v1/notification-preferences` | Inbox preferences |

JWT `@Roles('ADMIN')` is the marketplace actor. Screen RBAC must still honour `admin_profiles.role` / `finance_access` from profile GET (already how wallet endpoints gate finance).

---

## Screen matrix

| # | Admin screen | Route | Current data source | Required backend data | Existing API | Sufficient? | Missing endpoint | Proposed minimal change |
|---|---|---|---|---|---|---|---|---|
| 1 | Login | `/login` | Netlify + local `adminAccounts` passwords | Email/password → Nest session | `POST /v1/admin/auth/login` | Yes | None | Replace `authService` with Nest JWT; stop treating Netlify/local passwords as authority. Keep Login **visuals**. Map profile `role` to existing `ROLES` labels. |
| 2 | Session / header | layout | `sessionStorage` / Netlify cookie | Profile + tokens | `GET /v1/auth/session`, `GET /v1/admin/profile`, refresh, logout | Yes | None | Secure token store (memory + `sessionStorage` for refresh). Bearer on every call. |
| 3 | Dashboard | `/dashboard` | `orderStore` + `riderStore` + `customerStore` + **JS** `buildDashboardMetrics` / `calculateOrderFinance` | Counts from live rows; **revenue from frozen snapshots / fare snapshot, never JS 85/15** | `GET /v1/admin/orders` (counts). Finance via `GET /v1/orders/:id/finance` (N+1) | Partial — list has no money | Optional: include stored `fare_snapshot` / original finance on admin order list (same tables, no new rule) | Wire stores to API. Dashboard KPIs: order/rider/customer **counts** from lists. Revenue KPI = **sum of backend `trip_fare` / frozen `rider_amount` already returned**, not `commission.js`. |
| 4 | Live Operations | `/live` | `orderStore` + `riderStore` | Live canonical statuses | `GET /v1/admin/orders` | Yes (status map) | None | Filter mapped live statuses. Keep table/drawer UI. |
| 5 | Orders | `/orders` | `orderStore` + JS finance attach | List, detail, assign, cancel, status | Admin order GET/POST as above; payment/finance GET | Yes for ops. Fare on **detail** yes (`fare_snapshot`). List fare: enhance list **or** load finance in drawer only. | None required if drawer fetches GET `:id` + payment + finance | Map `canonical_status` → existing UI labels (`Pending`/`Assigned`/…). Assign uses UUID `rider_profile_id` from rider directory (see #8). **Create Order modal:** `POST /v1/orders` is **CUSTOMER-only**. Do **not** invent Admin create-order. Keep modal as remaining mock/local overlay **or** leave it non-persisting to Postgres. |
| 6 | Order detail drawer | (orders) | Mock order + `attachFinanceSnapshot` | Stops, fare snapshot, payment, finance freeze | `GET /v1/admin/orders/:id`, payment, finance | Yes | None | Display backend `trip_fare`, GST `0`, frozen rider/company/ops/profit. Remove JS 85/15 for displayed money. |
| 7 | Tracking | `/tracking` | Decorative SVG + `mapStops` / `trackingPins` | Optional: live orders + `GET .../route` | Route GET exists | Decorative map is **not** Google Maps. Route API is enough for a text/stats strip. | Do not invent live map tiles | Keep existing map **artwork**. Optionally drive counts/list from admin orders. Do **not** add Google Maps production config. |
| 8 | Riders list | `/riders` | `riderStore` seed | Directory: id, phone, KYC/approval/online, city | **No list API** | No | **`GET /v1/admin/riders`** (read-only `rider_profiles` + identity phone). Not a new business rule. | Add directory GET. Map `approval_status` / `online_status` onto existing badges. Rider has **no display_name** in schema — show phone + short id, do not invent names. Disable create/edit/delete that would invent profile writes. |
| 9 | Rider detail | `/riders/:id` | Mock rider + local earnings | Profile + wallet + COD + earnings | Wallet/COD/earnings GET exist **if** `rider_profile_id` known | Partial without list/get profile | **`GET /v1/admin/riders/:id`** directory (not wallet) | Same controller prefix as wallet; Nest can keep `:id/wallet` more specific. Finance fields only if `finance_access`. |
| 10 | Customers list | `/customers` | `customerStore` + JS `spent` | Directory: name, phone, email, status | **No list API** | No | **`GET /v1/admin/customers`** read-only | Add directory GET. Order counts from admin orders join, not invented “spent”. Do not invent customer-wallet API. |
| 11 | Customer detail | `/customers/:id` | Mock | Profile + their orders | Orders list filter by `customer_profile_id` | Partial | **`GET /v1/admin/customers/:id`** | Read-only profile + orders already listed for admin. |
| 12 | Verification | `/verification` | `verifications` seed | KYC rows | Tables exist; **no verification API** | No | **Do not invent** KYC approve/reject API | **Keep mock.** |
| 13 | Payments | `/payments` | `paymentStore` seed | Transactions / aggregate status | Per-order `GET /v1/orders/:id/payment` | No global list | **`GET /v1/admin/payments`** — read existing `payment_transactions` (and order display_id). Display backend status. No client GST. | Minimal list query. Keep UI tabs; map statuses. Refund **action** has no Nest refund API — keep refund button inert or mock, document blocker. |
| 14 | Wallet | `/wallet` | `walletStore` + **JS** `buildRiderWallets` | Per-rider wallet + COD | `GET /v1/admin/riders/:id/wallet` + `/cod` + ledgers | Yes **per rider** after directory exists | No admin **recharge/settle** POST (rider-only) | Table from rider list + wallet/COD GET. **Do not** sum in JS. Add-money / withdraw UI: no admin payout/recharge API — **keep those actions mock or disable persistence**. Ledger tab: fetch ledgers for selected rider. |
| 15 | Earnings | `/earnings` | `earnings` seed + **JS** `calculateDistribution` | Frozen `rider_amount` / `company_commission_amount` | Per-rider `GET .../earnings` | No fleet list | **`GET /v1/admin/earnings`** — `SELECT` existing `order_finance_snapshots` ORIGINAL rows (same numbers as rider earnings). | Replace chart **totals** with summed **backend fields**, not `commission.js`. Keep chart chrome. |
| 16 | Payouts | `/payouts` | `payoutStore` | Payout batches | **None** | No | **Do not invent** | **Keep mock.** |
| 17 | Coupons | `/coupons` | `couponStore` | Promo codes | **None** | No | **Do not invent** | **Keep mock.** |
| 18 | Promotions | `/promotions` | `promotionStore` | Campaigns | **None** | No | **Do not invent** | **Keep mock.** |
| 19 | Notifications | `/notifications` | Campaign store + inbox seed | Inbox: in-app notifications | `GET /v1/notifications` etc. | Inbox yes. Composer/send **no** | Do not invent campaign broadcast | Inbox tab → Nest. **Composer tab stays mock.** |
| 20 | Support | `/support` | `ticketStore` | Tickets | **None** | No | **Do not invent** | **Keep mock.** |
| 21 | Reports | `/reports` | JS joins of mock stores | Export of live ops/finance | Orders + finance/payments reads | Partial | No dedicated report API | Drive from connected order/finance lists where available; keep export chrome. Do not recalculate 85/15. |
| 22 | Settings | `/settings` | Local payment defaults, cancellation, office, **adminUserStore** | Live payment_settings are server-side; **no admin settings write API** | None for fare config write | No | **Do not invent** fare/COD threshold editors against DB | **Keep mock** for pricing/roles CRUD. Profile/session already Nest. |
| 23 | Profile | `/profile` | Auth user + localStorage overlay | `GET /v1/admin/profile` | Yes | No profile PUT | Display Nest email/role. Keep local name overlay (same as Flutter). |
| 24 | Vehicles | `/vehicles` | `vehicleStore` | Fleet vehicles | Tables exist; **no vehicle CRUD API** | No | **Do not invent** | **Keep mock.** |
| 25 | Vehicle categories | `/vehicle-categories` | Netlify + local | Catalog in Postgres | **No public/admin list in Phases 1–8** | No | Optional read-only `GET /v1/admin/catalog/vehicle-categories` — **only if needed to label orders**. No write API. | Prefer names already on order `vehicle_category_name` snapshot. Keep category **editor** mock/Netlify. |
| 26 | Zones | `/zones` | `zoneStore` | Zones table | **No zone CRUD** | No | **Do not invent** | **Keep mock.** |
| 27 | Invoices / Purchase invoices | `/invoices` `/purchase-invoices` | invoice stores | Legal invoice | **No invoice API** (business decision) | No | **Do not invent** | **Keep mock.** Invoice preview on orders may show backend trip fare as amount only. |
| 28 | Announcements | `/announcements` | `announcementStore` | Campaigns | **None** | No | **Do not invent** | **Keep mock.** |
| 29 | UPI settings | redirect | — | — | — | — | Redirect already to `/payments`. |

---

## Auth / RBAC mapping

| Admin UI `ROLES` | `admin_profiles.role` |
|---|---|
| Super Admin | `SUPER_ADMIN` |
| Sub Admin | `SUB_ADMIN` |
| Operations | `OPERATIONS` |
| Finance | `FINANCE` |
| Support | `SUPPORT` |
| Manager | `MANAGER` |

Existing UI `can()` / `canAccessPath()` stay. Server remains authority for money and order mutations. Finance wallet/COD already requires `SUPER_ADMIN` \| `FINANCE` \| `finance_access`.

Do **not** keep `authenticateSubAdmin` as a second authority after Nest login is wired.

---

## API client (proposed, Admin only)

- Env base URL (`VITE_API_BASE_URL`), default `http://localhost:3000` in development — never hardcode production.
- `fetch` or thin wrapper; JSON; Bearer; refresh on 401; map `{ error: { code, message, request_id } }`.
- Do **not** copy Flutter code. Do **not** put JWT pepper or DB secrets in the SPA.

---

## Status mapping (display only)

Backend `canonical_status` → existing Admin labels (no new statuses):

| Canonical | Admin UI label |
|---|---|
| `CREATED`, `SEARCHING`, `OFFERED` | Pending |
| `ASSIGNED` | Assigned |
| `EN_ROUTE_PICKUP`, `ARRIVED_PICKUP` | Rider Arriving |
| `PICKED_UP` | Picked Up |
| `IN_TRANSIT`, `NEAR_DROP`, `DELIVERY_ATTEMPT` | In Transit |
| `DELIVERED`, `RESEND_COMPLETED` | Delivered |
| `CANCELLED` | Cancelled |
| `FAILED_DELIVERY`, `RECEIVER_UNAVAILABLE` | Failed |
| `PARCEL_AT_COMPANY_OFFICE` | Parcel At Company Office |
| `RESEND_REQUESTED`, `RESEND_IN_PROGRESS` | Resend Requested |

Status **actions** must send canonical `to_status`, not the label.

---

## New APIs allowed in Phase 9 (read-only / directory only)

Only if implementation proceeds:

1. `GET /v1/admin/riders` (+ optional `:id` profile)
2. `GET /v1/admin/customers` (+ optional `:id` profile)
3. `GET /v1/admin/payments` — list stored payment transactions
4. `GET /v1/admin/earnings` — list stored ORIGINAL finance snapshots

Optional enrichment (not a new path): include stored fare/finance fields on `GET /v1/admin/orders` list.

**Not allowed:** payout, coupon, ticket, KYC decision, zone CRUD, fare-settings write, admin create-order, FCM, Redis, payment provider, Google Maps production.

---

## Blockers (do not invent)

- SMS/OTP N/A for Admin (password login).
- No admin create-order (customer `POST /v1/orders` only).
- No payout / coupon / support ticket / KYC workflow / zone CRUD / invoice legal / announcement send APIs.
- No admin wallet recharge/settle/payout POST.
- Rider GPS for Admin map: rider location is in-memory, rider-scoped GET only — do not invent Admin GPS broadcast.
- Settings must not publish fare config from the browser.

---

## Explicitly out of this audit’s implementation until the audit is accepted

This document does not change Admin source, Nest, Flutter, migrations, or Master Architecture.

---

**End of ADMIN BACKEND INTEGRATION AUDIT**
