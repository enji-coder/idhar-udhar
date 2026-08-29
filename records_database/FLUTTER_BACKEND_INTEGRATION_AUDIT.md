# IDHAR UDHAR — FLUTTER / BACKEND INTEGRATION AUDIT

**Type:** Phase 8 pre-implementation audit  
**Date:** 2026-08-25  
**Does not modify:** UI, navigation, Master Architecture, PostgreSQL, migrations  

This file records what the Customer and Rider Flutter apps are today, and what Phase 8 will connect. No screens were redesigned during this audit.

---

## Layout

| App | Entry | State | Navigation |
|---|---|---|---|
| Customer | `lib/customer/customer_main.dart` (`lib/main.dart` default) | Riverpod | `GoRouter` in `customer/core/routing/app_router.dart` |
| Rider | `lib/rider/rider_main.dart` | Riverpod + local prefs | `GoRouter` in `rider/routing/rider_router.dart` |
| Shared package | `idhar_udhar` pubspec | `dio` already listed, unused for Nest | Hive / SharedPreferences / flutter_secure_storage present |

There is **no** Nest `/v1` client today. `dio` is only used by `VehicleCategoryCatalog` against a Netlify Admin function (not PostgreSQL, not `/v1`).

---

## Current API / network layer

| Item | Status |
|---|---|
| NestJS `/v1` HTTP client | Missing |
| Bearer + refresh | Missing |
| `AppConfig.apiBaseUrl` | Hardcoded `dev-api` / `staging-api` / `api.idharudhar.in` placeholders — unused by screens |
| Secure token store | `flutter_secure_storage` in pubspec, unused |
| Customer session | `SessionStorage` + SharedPreferences (phone/name only, no JWT) |
| Rider session | `RiderPrefs.loggedIn` boolean only |

---

## Authentication screens

### Customer

| Screen | File | Today |
|---|---|---|
| Login | `features/authentication/.../login_screen.dart` | 10-digit phone → OTP route. No `POST /auth/otp/request`. |
| OTP | `otp_verification_screen.dart` | **4** boxes. `SessionNotifier.verifyOtp` accepts **any 4 digits**. |
| Profile setup | `profile_setup_screen.dart` | First-login name, local only. No profile PUT (backend has GET only). |
| Splash | `splash_screen.dart` | Hydrates SharedPreferences session → home or login. |

### Rider

| Screen | File | Today |
|---|---|---|
| Login | `rider_login_screen.dart` | Phone validated, then **skips OTP** (`riderEnterAfterAuth`). |
| OTP | `registration/otp_verification_screen.dart` | **6** boxes. Dummy code `DummyRiderData.otp`. Used mainly for registration. |
| Splash | `rider_splash_screen.dart` | `RiderPrefs.isLoggedIn()` → dashboard or login. |

**Phase 8 connect:** `POST /v1/auth/otp/request`, `POST /v1/auth/otp/verify`, `POST /v1/auth/token/refresh`, `POST /v1/auth/logout`, `GET /v1/auth/session`, `GET /v1/customer/profile`, `GET /v1/rider/profile`.

Customer OTP widgets already support `length:` — Phase 8 will pass **6** to match backend development default (`OTP_LENGTH`, still NEEDS DECISION). Same boxes, not a visual redesign.

Name setup stays local: backend has no profile update endpoint.

---

## Order creation / tracking (Customer)

| Screen | Dummy behavior | Backend equivalent |
|---|---|---|
| Pickup / drop | `MockData` locations (Ahmedabad coords on most rows) | Stop payload on `POST /v1/orders` |
| Vehicle | Local catalog + Netlify fallback IDs (`VC-1001`…) | Needs real `vehicle_category_id` UUID — **no catalog list API**. Config `--dart-define=IU_CITY_ID` / `IU_VEHICLE_CATEGORY_ID`. |
| Package | Local labels | Not a Nest resource — keep mock |
| Summary | `FareEngine.quote` + `GeoMath.routeKm` as displayed ₹ | **Replace final fare** with `POST /v1/orders/:id/quote` then confirm |
| Searching | 3s timer then **fake assign** | Poll `GET /v1/orders/:id`; cancel → `POST .../cancel` |
| Assigned / tracking / completed | Local `bookingDraftProvider` | Map `canonical_status` onto existing `MockOrder` for the same screens |
| Orders tab | `MockData.seedOrders()` | `GET /v1/orders` |
| Order details | Session list | `GET /v1/orders/:id` + stops |

Payment-plan UI on package/summary stays **mock** (no Phase 8 payment-plan APIs in the connect list).

---

## Rider offers / orders

| Screen | Dummy behavior | Backend equivalent |
|---|---|---|
| Incoming | `DummyRiderData.incomingOrder` | `GET /v1/rider/offers`; accept/reject |
| Active delivery | Local `DeliveryLifecycleStatus` | `POST /v1/rider/orders/:id/status` with canonical statuses |
| History | Dummy list | Keep mock (no rider history list API) |
| Location | Unused | `POST/GET /v1/rider/location` when a real fix exists — **do not invent GPS** |

Never send `rider_profile_id` as authorization. Session JWT is the authority.

---

## Wallet / COD (Rider)

| UI | Today | Backend |
|---|---|---|
| Wallet balance + COD Due | Local `StateProvider` + `CodEngine` | `GET /v1/rider/wallet`, `GET /v1/rider/cod` |
| Add Money | Local `applyRiderRecharge` | `POST /v1/rider/wallet/recharge` |
| Withdraw | Local decrement | **No payout API — keep mock** |
| Earnings tab | Dummy `RiderEarnings` | `GET /v1/rider/earnings` (map amounts; keep dummy targets/incentives) |
| COD settle | No dedicated button | No extra screen; recharge already settle-first on server |

Customer `wallet_screen.dart` is a **customer wallet** mock. Customer wallet is not a Phase 5/8 Nest API. **Keep mock.**

---

## Notifications

| Surface | Today | Backend |
|---|---|---|
| Dashboard badge + copy | In-memory `CustomerNotice` | `GET /v1/notifications`, unread-count, mark read |
| Profile “Notifications” tile | `onTap: () {}` | Same APIs via a list using existing glass widgets |
| Rider announcements | Dummy company list | Keep mock (campaigns not in `/v1/notifications` product) |
| FCM | Not in pubspec | **Out of scope** |

---

## Models / repositories

- Customer: `mock_models.dart`, `mock_data.dart`, `session_provider.dart`, `booking_draft_provider.dart`
- Rider: `dummy_rider_repository.dart`, `dummy_rider_data.dart`, `rider_finance.dart`
- Shared business math: `lib/shared/business/*` (`FareEngine`, `CodEngine`, 85/15). **Must not remain the fare/wallet authority** where Nest APIs exist.

---

## Firebase

| Artifact | Status |
|---|---|
| `firebase_placeholder.dart` | Stub comments only |
| `firebase_options.dart` / `google-services.json` | Not in app (gitignored / absent) |
| FlutterFire deps | **None** in `pubspec.yaml` |
| Auth | Dummy OTP, not Firebase Auth |

Firebase is **not** the application database. Phase 8 does not add or remove Firebase. FCM may be used later for push only.

---

## Business calculations in Flutter (today)

| Calculation | Where | Phase 8 |
|---|---|---|
| Trip fare from km | `BookingDraft.fareQuote` | Display backend quote instead |
| 85/15, COD engine | `shared/business` | Rider wallet/COD from API; keep library for screens still mock |
| Display IDs | `OrderIds.nextDisplayId()` | Use `display_id` from Nest |
| Vehicle catalog | Netlify + hardcoded `VC-*` | Nest UUID via dart-define; Netlify catalog remains unused for money |

---

## What Phase 8 will connect

Customer: OTP request/verify, session restore/refresh/logout, profile GET, create/list/get/stops/quote/confirm/cancel orders, in-app notifications.

Rider: OTP request/verify (login no longer skips OTP), session, offers accept/reject, order get/status, location GET/POST when a fix exists, wallet/COD/earnings GET + recharge.

## What stays mock

Customer wallet, saved addresses, package categories/sizes, payment plan, invoices, help, rider KYC/documents/UPI/vehicle onboarding, rider history dummy, rider announcements, withdraw, Admin web.

## Catalog gap (not invented)

There is **no** `GET /v1/cities` or vehicle-category list. Create-order requires UUIDs. Phase 8 uses `--dart-define=IU_CITY_ID` and `IU_VEHICLE_CATEGORY_ID` from the operator’s existing Postgres rows (e2e `ensureOrderCatalog` / live `cities` + `vehicle_categories`). Do not add a catalog API in this phase.

---

**End of FLUTTER BACKEND INTEGRATION AUDIT**
