# IDHAR UDHAR — ADMIN BACKEND INTEGRATION PLAN

**Type:** Phase 8 audit only — Admin is **not** rewired in this phase  
**Date:** 2026-08-25  
**Does not modify:** Admin UI, navigation, Master Architecture, PostgreSQL, migrations  

The Admin web app (`IDHAR_UDHAR_ADMIN/`) remains a mock/Netlify client. Phase 8 only records which screens will later call Nest `/v1`.

---

## Current Admin stack

| Item | Today |
|---|---|
| App | React + Vite (`src/App.jsx`) |
| Auth | `AuthContext` + Netlify `admin-login` / `admin-session` functions |
| Data | `src/data/*` mock files |
| Money / fare / COD | `src/services/fareEngine.js`, `codWallet.js`, `commission.js` — **must not stay authoritative** |
| Vehicle catalog | Netlify `vehicle-categories` function (also used by Flutter catalog helper) |

Backend already exposes Admin JWT (`POST /v1/auth/admin/login`), admin order, finance, wallet, and notification routes. Flutter Phase 8 does not call them.

---

## Screen → future Nest mapping

| Admin screen | Route | Later backend |
|---|---|---|
| Login | `/login` | `POST /v1/auth/admin/login` (not Firebase, not Netlify session as authority) |
| Dashboard | `/dashboard` | Live order/rider counts from list APIs — **no client 85/15** |
| Live operations | `/live` | Orders list + rider location GET (Admin location API if added later) |
| Orders | `/orders` | `GET /v1/admin/orders`, assign, status, cancel |
| Tracking | `/tracking` | Order GET + stops + routing (server distance) |
| Riders / detail | `/riders` | Admin rider profile + wallet/COD/earnings |
| Customers / detail | `/customers` | No dedicated admin customer-list API yet — **do not invent** |
| Verification | `/verification` | KYC tables exist; no full verification API in Phases 1–7 |
| Payments | `/payments` | `GET/POST` payment plan/responsibility/transactions |
| Earnings | `/earnings` | Finance snapshots — display frozen amounts |
| Payouts | `/payouts` | **No payout API yet — keep mock** |
| Coupons / promotions | `/coupons` `/promotions` | No Nest promo API — keep mock |
| Notifications | `/notifications` | Admin can use `/v1/notifications` for own inbox; campaign send is later |
| Support | `/support` | No Nest ticket API — keep mock |
| Reports | `/reports` | Read-only from finance/order APIs later |
| Settings / profile | `/settings` `/profile` | Admin profile GET |
| Vehicles / categories | `/vehicles` `/vehicle-categories` | Catalog is Postgres; **no public list API in Phase 8** |
| Wallet | `/wallet` | `GET /v1/admin/riders/:id/wallet` + COD + recharge/settle |
| Zones | `/zones` | Postgres zones; no admin zone CRUD API yet |
| Invoices | `/invoices` | Invoice rules remain business-decision; no legal invoice API |
| Announcements | `/announcements` | Keep mock until a campaign API exists |

---

## Explicitly out of this phase

- No Admin redesign
- No replacing Netlify functions yet
- No moving fare/85/15/GST/wallet math into the browser
- No Firebase as the application database

**Next Admin slice (not started):** authenticate Admin against Nest, then replace mock stores screen-by-screen using existing `/v1` admin routes only.

---

**End of ADMIN BACKEND INTEGRATION PLAN**
