# 27 — Development Phases

> Implementation phases for engineering. **No code is produced in the documentation phase.** Each phase lists objective, features, screens, backend, Firebase, dependencies, deliverables, and complexity.

Complexity scale: **S** (small) · **M** (medium) · **L** (large) · **XL** (extra large)

---

## Phase 0 — Documentation & Kickoff

| Field | Detail |
|-------|--------|
| **Objective** | Align stakeholders; freeze MVP scope and design tokens |
| **Features** | N/A (docs only) |
| **Screens** | N/A |
| **Backend** | N/A |
| **Firebase** | Project naming & region decisions |
| **Dependencies** | None |
| **Deliverables** | `Project_Documentation/` (30 files); sign-off checklist |
| **Complexity** | M |

---

## Phase 1 — Monorepo & Design System Foundation

| Field | Detail |
|-------|--------|
| **Objective** | Create scalable Flutter workspace and brand UI kit |
| **Features** | App shells, flavors (dev/stg/prod), theme, shared packages |
| **Screens** | Blank home per app; component gallery (internal) |
| **Backend** | Repo `backend/functions` scaffold only |
| **Firebase** | Create dev project; add FlutterFire config placeholders |
| **Dependencies** | Flutter SDK, Melos (optional), `google_fonts`, `flutter_riverpod`, `go_router`, `responsive_framework` |
| **Deliverables** | `apps/customer_app`, `apps/rider_app`, `packages/iu_*`; CI analyze pipeline |
| **Complexity** | L |

---

## Phase 2 — Customer Splash, Onboarding & Auth

| Field | Detail |
|-------|--------|
| **Objective** | Ship premium first-run and authentication for customers |
| **Features** | Splash, onboarding 1–3, login, register, OTP, forgot password, remember me, T&Cs |
| **Screens** | Splash; Onboarding×3; Login; Register; OTP; Forgot Password; Reset Password |
| **Backend** | Auth cloud function for role seed (optional) |
| **Firebase** | Auth (email/phone); Firestore `users`; Storage profiles; Crashlytics; FCM token save |
| **Dependencies** | `firebase_*`, `flutter_secure_storage`, `shared_preferences`, `pinput` (or custom OTP), `lottie`, `cached_network_image` |
| **Deliverables** | Working auth against emulator/dev; glass UI matching guidelines |
| **Complexity** | L |

---

## Phase 3 — Location Permission & Customer Shell

| Field | Detail |
|-------|--------|
| **Objective** | Trust-first location gating + post-auth navigation shell |
| **Features** | Location permission education; Geolocator; Home shell; Profile stub; Settings stub |
| **Screens** | Location Permission; Home; Profile; Settings |
| **Backend** | None critical |
| **Firebase** | Persist permission flags in user prefs / profile |
| **Dependencies** | `geolocator`, `permission_handler` |
| **Deliverables** | Permission flow; bottom nav shell |
| **Complexity** | M |

---

## Phase 4 — Maps, Places & Booking Funnel (Customer)

| Field | Detail |
|-------|--------|
| **Objective** | Complete booking draft → fare → confirm |
| **Features** | Pickup/drop map+search; parcel type; weight; vehicle selection; fare estimate; coupons; booking create |
| **Screens** | Pickup; Drop; Parcel; Weight; Vehicle; Fare/Coupon; Confirm; Searching |
| **Backend** | `calculateFare`, `applyCoupon`, `createBooking` Functions |
| **Firebase** | `bookings`, `vehicle_categories`, `coupons`, `fares_config`, `cities` |
| **Dependencies** | `google_maps_flutter`, Places/Directions (via Dio), `dio`, `freezed`, `json_serializable`, `hive` |
| **Deliverables** | E2E booking creation in `searching`; fare breakdown UI |
| **Complexity** | XL |

---

## Phase 5 — Rider Auth, KYC & Vehicle

| Field | Detail |
|-------|--------|
| **Objective** | Enable verified riders to become eligible for jobs |
| **Features** | Rider auth; document upload; vehicle registration; KYC status screens |
| **Screens** | Rider Login/Register/OTP; Document Upload; Vehicle Form; KYC Pending/Rejected |
| **Backend** | `onKycSubmitted`; admin approve path (console) |
| **Firebase** | `riders`, Storage `kyc/`; claims `role=rider` |
| **Dependencies** | `image_picker`, `firebase_storage`, same auth stack |
| **Deliverables** | Rider cannot go online until approved |
| **Complexity** | L |

---

## Phase 6 — Matching, Accept/Reject & Trip Lifecycle (Rider)

| Field | Detail |
|-------|--------|
| **Objective** | Operational marketplace loop for riders |
| **Features** | Online/Offline; location stream; job request UI; accept/reject; trip states; pickup/delivery confirmation |
| **Screens** | Rider Home; Incoming Request; Active Trip; Confirmation |
| **Backend** | Matching engine; `respondToJob`; expiry tasks; status transitions |
| **Firebase** | Rider geo fields; booking status machine; FCM high-priority requests |
| **Dependencies** | `geolocator`, FCM, Functions client |
| **Deliverables** | Accept binds rider; status progresses with confirmations |
| **Complexity** | XL |

---

## Phase 7 — Navigation, Live Tracking & Notifications

| Field | Detail |
|-------|--------|
| **Objective** | Real-time visibility for both sides |
| **Features** | Google Navigation launch / in-app nav helper; customer live tracking; ETA; FCM for all trip events |
| **Screens** | Customer Tracking; Rider Navigation helper; Notifications list |
| **Backend** | `onBookingStatusChanged` → FCM; location write throttle |
| **Firebase** | FCM; trip location docs; Crashlytics custom keys |
| **Dependencies** | `url_launcher` / Maps intents; `firebase_messaging` |
| **Deliverables** | Customer sees moving rider; pushes received on background/foreground |
| **Complexity** | L |

---

## Phase 8 — Payments, History, Ratings, Earnings, Wallet

| Field | Detail |
|-------|--------|
| **Objective** | Close the money and reputation loops |
| **Features** | Cash payment mark; fare breakdown; history; ratings; rider earnings dashboard; wallet ledger view; help tickets |
| **Screens** | Payment; History; Trip Detail; Rating; Earnings; Wallet; Support |
| **Backend** | `markCashReceived`; rating aggregate; ledger writes |
| **Firebase** | `payments`, `ratings`, `wallets`, `support_tickets` |
| **Dependencies** | Hive cache for history; charts optional later |
| **Deliverables** | Completed trip → paid → rated; rider earnings update |
| **Complexity** | L |

---

## Phase 9 — Hardening, Security Rules, Performance, UAT

| Field | Detail |
|-------|--------|
| **Objective** | Production readiness |
| **Features** | App Check; rules audit; offline banners; error polish; analytics events; force-update hook |
| **Screens** | Error/empty polish across apps; Force Update |
| **Backend** | Rate limits; idempotency; monitoring alerts |
| **Firebase** | App Check enforce; budget alerts; staging full clone test |
| **Dependencies** | Firebase Performance (optional), analytics |
| **Deliverables** | UAT sign-off; store builds; runbooks |
| **Complexity** | L |

---

## Phase 10 — Pilot Launch

| Field | Detail |
|-------|--------|
| **Objective** | Soft launch in one city |
| **Features** | City geofence; ops KYC process; support escalation |
| **Screens** | Out-of-service messaging |
| **Backend** | Production Functions deploy; SMS/OTP quotas |
| **Firebase** | Prod project; Crashlytics monitoring |
| **Dependencies** | Store accounts, maps billing, SMS |
| **Deliverables** | Public pilot; KPI dashboard (manual OK) |
| **Complexity** | M |

---

## Phase 11 — V1.1 Enhancements (Post-MVP)

| Field | Detail |
|-------|--------|
| **Objective** | Online payments, social login, chat, Remote Config, Admin kickoff |
| **Features** | Razorpay (or chosen gateway); Google/Apple login; in-app chat; saved addresses; incentives |
| **Screens** | Payment checkout; Chat; Admin wireframes start |
| **Backend** | Payment webhooks; chat moderation basics |
| **Firebase** | Remote Config; additional indexes |
| **Dependencies** | Gateway SDK; web admin stack TBD |
| **Deliverables** | V1.1 store release |
| **Complexity** | XL |

---

## Phase Dependency Graph

```
P0 → P1 → P2 → P3 → P4 → P7 → P8 → P9 → P10 → P11
          P5 → P6 ↗
```

P4 (customer booking) and P5–P6 (rider) proceed in parallel after P1–P2 foundations.
