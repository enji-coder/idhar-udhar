# Architecture — Customer App (current)

App-local architecture notes. Full product specs live in `../../Project_Documentation/`.  
**Status source of truth:** `../../Project_Documentation/PROJECT_STATUS.md` (reviewed 2026-08-08; Milestone 2 tooling applied).

---

## 1. Current architecture (preserve)

```
idhar_udhar/lib/
├── main.dart                 # ProviderScope + MaterialApp.router
├── config/                   # AppConfig, Environment, constants, Firebase stub
├── core/
│   ├── theme/                # Tokens + AppTheme (source of truth)
│   ├── widgets/              # Design-system primitives
│   ├── animations/           # Motion primitives
│   ├── routing/              # go_router (AppRoutes / AppRouter)
│   ├── constants/            # AssetPaths
│   ├── utils/                # Responsive helpers
│   ├── extensions/           # empty
│   └── services/             # empty
├── shared/
│   ├── theme/                # Re-exports core tokens
│   └── widgets/              # Kit composites (cards, chrome, feedback)
└── features/<feature>/       # Feature modules (many shells)
```

| Concern | Choice already in project |
|---------|---------------------------|
| State | `flutter_riverpod` (bootstrap only today) |
| Navigation | `go_router` |
| Networking (future) | `dio` (declared, unused) |
| Models (future) | `freezed` / `json_serializable` / `equatable` |
| Local storage (future) | `hive`, `shared_preferences`, `flutter_secure_storage` |
| UI | Glassmorphism + soft cards; Poppins via `google_fonts` |

**Rule:** Do not introduce a parallel design system or second router/state solution. Prefer `lib/core` primitives; use `lib/shared` for composites. Feature screens may import either barrel; keep completed screens on `core` unless migrating deliberately.

---

## 2. Navigation today (implemented)

```
/splash
  → /login                         # mobile number only
  → /otp?phone=                    # any 6-digit dummy OTP
  → /profile-setup                 # first-time name (skipped if known)
  → /location-permission           # education → home
  → /home/dashboard | orders | wallet | profile
  → /book/pickup → drop → vehicle → package → summary
  → /book/searching → rider-assigned → tracking → completed
  → /orders/:id · /profile/edit · /help
```

Returning user (in-memory mock): skip `/profile-setup` when that phone already has a name.

---

## 3. Dummy data strategy (planned)

Introduce a replaceable layer (suggested paths — create when implementing):

```
lib/core/data/mock/          # or lib/shared/data/mock/
  mock_customers.dart
  mock_vehicles.dart
  mock_bookings.dart
  mock_locations.dart
  mock_riders.dart
  mock_notifications.dart
```

Feature repositories / Riverpod providers should depend on abstractions so UI does not hardcode lists. Later swap mock → API without rewriting screens.

---

## 4. Logo

| Item | Path |
|------|------|
| **Only approved logo** | `assets/logos/idhar_udhar_logo.png` |
| Constant | `AssetPaths.logo` |

PNG already includes brand mark + “IDHAR UDHAR” wordmark. `TopLogo` defaults to `showWordmark: false`. Never generate/replace this file.

---

## 5. 3D asset family (registered)

Shipped under `assets/images/3d/` and declared in `pubspec.yaml`.  
Catalog: `docs/design_system/ASSETS_3D.md`.

| Constant | File |
|----------|------|
| `truck` | `idhar_udhar_delivery_truck.png` |
| `bike` | `idhar_udhar_delivery_bike.png` |
| `auto` | `idhar_udhar_auto_rickshaw.png` |
| `car` | `idhar_udhar_car.png` |
| `pickupTruck` | `idhar_udhar_pickup_truck.png` |
| `parcel` / `parcelStack` | parcel PNGs |
| `rider` / `searchingRider` / `deliveryProgress` | character / status |
| `locationPin` / `invite` / `movingItems` | UX / marketing |

Use `AssetPaths.*` only — no duplicated path strings in widgets.

---

## 6. Implementation milestones

| # | Milestone | Outcome |
|---|-----------|---------|
| 1 | Audit + docs | Done (this review) |
| 2 | Tooling + design system polish | **Done** — `google_fonts` ^6.3, Gradle 8.14 / AGP 8.7 / compileSdk 36 / Java 17 on JBR 21, 3D `AssetPaths` + pubspec, TopLogo default, color doc sync |
| 3 | Auth UI (mock) | **Done** — phone → OTP → name → location → home |
| 4 | Dashboard | **Done** — home + vehicle strip + recent/active |
| 5 | Location + booking entry | **Done** — pickup / drop UI |
| 6 | Vehicle / service | **Done** — 3D vehicle selection |
| 7 | Confirm / status | **Done** — summary → searching → assigned → tracking → completed |
| 8 | Account surfaces | **Done** — orders, wallet, profile, edit, help |
| 9 | Consistency pass | Glass, spacing, motion, copy |
| 10 | Validate | format, analyze, test, build, overflow check |

After each milestone: `dart format`, `flutter analyze`, `flutter test`, fix blockers, continue.

---

## 7. Future backend integration points (do not build yet)

- Auth: replace mock OTP with Firebase / SMS provider; wire SMS Retriever / iOS autofill  
- Session: `flutter_secure_storage` / Hive for tokens + profile  
- Booking: Dio repositories behind same Riverpod interfaces as mocks  
- Maps / live location: separate services under `core/services` or feature `data/`  
- FCM, payments, admin — after customer UI stability  

Firebase steps remain in `docs/firebase/SETUP.md`.
