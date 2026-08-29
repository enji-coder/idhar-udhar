# IDHAR UDHAR — FLUTTER / BACKEND INTEGRATION ARCHITECTURE

**Phase:** 8  
**Date:** 2026-08-25  
**Authority:** NestJS `/v1` + PostgreSQL. Flutter is a presentation client.

This document describes the Phase 8 client architecture. It does not change locked business rules.

---

## API architecture

Shared package path: `idhar_udhar/lib/shared/api/`

| Piece | Role |
|---|---|
| `ApiConfig` | Base URL from `--dart-define=API_BASE_URL`. Dev defaults: Android emulator `http://10.0.2.2:3000`, Chrome/desktop `http://localhost:3000`. Release builds **require** `API_BASE_URL` — production is never hardcoded. Catalog UUIDs: `IU_CITY_ID`, `IU_VEHICLE_CATEGORY_ID`. |
| `ApiClient` | Dio, JSON, Bearer header, single-flight refresh on 401, request logging only when not `kReleaseMode`. |
| `TokenStore` | `flutter_secure_storage` for access + refresh. Not SharedPreferences. |
| `AuthApi` / `OrdersApi` / `RiderApi` / `WalletApi` / `NotificationsApi` / `ProfilesApi` | Typed `/v1` calls |
| `ApiErrorMapper` | `{ error: { code, message, details, request_id } }` → existing UI copy. SQL/database text is never shown. `request_id` kept on the exception. |

Secrets (JWT pepper, DB password, SMS keys) stay on the server. Flutter only stores session tokens.

Create-order and wallet recharge send `Idempotency-Key`.

---

## Authentication flow

1. Login collects 10-digit phone.
2. `POST /v1/auth/otp/request` `{ phone, actor_type: CUSTOMER|RIDER }`.
3. Existing OTP screen collects **6** digits (backend development default `OTP_LENGTH`; still a business decision). Same OTP widgets; `length` parameter only.
4. `POST /v1/auth/otp/verify` → access + refresh stored securely.
5. `GET /v1/customer/profile` or `GET /v1/rider/profile`.
6. First-login **name** remains local (no profile PUT). Overlay `display_name` when the backend has one.
7. Splash: if a refresh token exists, `GET /v1/auth/session` (client refreshes access if needed). Invalid session → login. Do not treat SharedPreferences-only dummy login as authenticated.
8. Logout: `POST /v1/auth/logout` + clear tokens.

Rider login no longer skips OTP.

---

## Token lifecycle

```
access JWT (short TTL) + refresh (hashed in Postgres sessions)
        │
        ├─ attached as Authorization: Bearer
        └─ 401 on a non-auth path → POST /v1/auth/token/refresh (one in-flight)
              ├─ success → retry original request
              └─ failure → clear tokens → login
```

---

## Customer API mapping

| UI | API |
|---|---|
| Login | `POST /v1/auth/otp/request` |
| OTP | `POST /v1/auth/otp/verify` |
| Splash restore | `GET /v1/auth/session` + profile |
| Profile display | `GET /v1/customer/profile` |
| Booking confirm | `POST /v1/orders` → `POST /v1/orders/:id/quote` (empty body) → `POST /v1/orders/:id/confirm` |
| Searching | poll `GET /v1/orders/:id`; cancel `POST /v1/orders/:id/cancel` |
| Orders tab | `GET /v1/orders` |
| Order details | `GET /v1/orders/:id` (+ stops when present) |
| Notifications | list / unread / read / read-all / preferences |

**Fare:** displayed trip fare after quote is the backend `trip_fare`. Flutter `FareEngine` is not the authority for confirmed money.

`city_id` / `vehicle_category_id` come from dart-define (no catalog list API).

---

## Rider API mapping

| UI | API |
|---|---|
| Login / registration OTP | request + verify with `actor_type=RIDER` |
| Incoming | `GET /v1/rider/offers`; accept/reject |
| Active delivery | `POST /v1/rider/orders/:id/status` with canonical hops (UI “Mark delivered” chains `NEAR_DROP` → `DELIVERY_ATTEMPT` → `DELIVERED`) |
| Location | `POST/GET /v1/rider/location` when a real fix exists — no invented GPS |
| Wallet / COD | GET wallet, COD, ledgers; recharge; settle available |
| Earnings | `GET /v1/rider/earnings` (amounts). Dummy targets/incentives remain dummy. |
| Notifications | same `/v1/notifications*` as customer |

Authorization is the rider JWT. Flutter never sends `rider_profile_id` as an authority.

---

## Notification API mapping

In-app only. No FCM in this phase.

`GET /v1/notifications`, `GET /v1/notifications/unread-count`, `POST /v1/notifications/:id/read`, `POST /v1/notifications/read-all`, `GET/PUT /v1/notification-preferences`.

---

## Wallet / COD API mapping

Display `available_balance` and `cod_due` from the server. **Wallet ≠ COD Due.**

Recharge uses `POST /v1/rider/wallet/recharge` (server settle-first). Withdraw remains mock (no payout API).

---

## Error handling

Central mapper in `api_exception.dart`. Snackbars/inline errors use existing widgets. `request_id` is on `ApiException` for debugging (logs), not raw SQL.

---

## Mock-data strategy

Replace dummy **only** where a Nest equivalent exists.

**Still mock:** customer wallet, saved addresses, package categories/sizes, payment-plan UI, invoices, help, rider KYC/documents/UPI/vehicle onboarding, rider history/announcements, withdraw, Netlify vehicle catalog, Admin web.

---

## Firebase boundary

The Flutter apps do **not** ship FlutterFire. `firebase_placeholder.dart` is unused comments. Auth is Nest OTP, not Firebase Auth. Firebase is not the application database. FCM may be added later for push only.

---

## Future Admin integration boundary

See `ADMIN_BACKEND_INTEGRATION_PLAN.md`. Phase 8 does not rewire Admin. Admin must later use Nest as money/session authority the same way Flutter now does.

---

## Local CORS / cleartext

Development Nest CORS allows `http://localhost`, `127.0.0.1`, and `10.0.2.2` on any port so Flutter Chrome can call `/v1`. Android debug manifest allows cleartext to `10.0.2.2`.

---

**End of FLUTTER BACKEND INTEGRATION ARCHITECTURE**
