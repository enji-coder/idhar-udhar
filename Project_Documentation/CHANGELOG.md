# IDHAR UDHAR — Changelog

> Records work that **exists in the repository today**.  
> No speculative future entries. Dates are approximate from documentation / delivery markers where git history is not cited.

Format inspired by [Keep a Changelog](https://keepachangelog.com/).

---

## [Unreleased]

### Changed — Premium depth / glass visual pass (2026-08-08)

- Multi-layer `GlassEffect` (blur, gradient fill, inner highlight, rim, soft elevation, optional ambient glow).
- Depth levels: subtle / normal / hero via `GlassDepthLevel`.
- Soft diffuse shadows + orange/navy ambient glows; cinematic navy dashboard background.
- Floating glass bottom nav; upgraded vehicle cards with glow + selection elevation.
- Applied across auth, dashboard, booking, orders, wallet, profile screens.

### Added — Customer UI full pass (2026-08-08)

- Phone-only login (removed password / remember / forgot / social).
- First-time profile setup (name) with mock session.
- Home shell bottom nav: Dashboard, Orders, Wallet, Profile.
- Full booking UI: pickup → drop → vehicle → package → summary → searching → rider assigned → tracking → completed → order details.
- Dummy data layer (`mock_models`, `mock_data`) + Riverpod `sessionProvider` / `bookingDraftProvider`.
- Shared helpers: `GlassPageScaffold`, `IuBackButton`, `StatusChip`, `EmptyState`.
- Help & Edit Profile screens.
- End-to-end GoRouter coverage for the customer demo journey.

### Added — Milestone 2 tooling + design-system polish (2026-08-08)

- Registered official 3D asset family in `AssetPaths` (`truck`, `bike`, `auto`, `car`, `pickupTruck`, `parcel`, `parcelStack`, `rider`, `locationPin`, `invite`, `searchingRider`, `deliveryProgress`, `movingItems`).
- Declared `assets/images/3d/` (and illustration subfolders) in `pubspec.yaml`.
- Added `idhar_udhar/docs/design_system/ASSETS_3D.md` catalog for all 13 shipped 3D PNGs.

### Changed — Milestone 2

- Bumped `google_fonts` from pinned `6.1.0` to `^6.3.0` (Dart 3.12 `FontWeight` map compatibility).
- Android toolchain: Gradle **8.14**, AGP **8.7.0**, Kotlin **1.9.24**, `compileSdk` **36**, `compileOptions` / `jvmTarget` **17** (compatible with host Java 21 / Android Studio JBR).
- `TopLogo` default `showWordmark` set to `false` to prevent double wordmark over the official logo PNG.
- Aligned in-app design docs (`WIDGETS.md`, architecture notes) to canonical brand hex: orange `#FF6A00`, navy `#183B73`.
- Updated `PROJECT_STATUS.md`, `idhar_udhar/README.md`, `docs/architecture/README.md`, `UI_KIT.md` brand hex.
- Validated: `flutter analyze` (info-only), `flutter test` pass, `flutter build apk --debug` pass.

### Changed — Phase 0 audit (2026-08-08)

- Refreshed status docs to match **code reality**.
- Confirmed live first-run flow is `/splash` → `/login` → `/otp` → `/location-permission` (no onboarding route/screen in repo).

### Removed from changelog claims (not in tree)

- Prior Unreleased notes about production onboarding PNGs / onboarding screen — those files and Dart screens are **not** present; do not treat as delivered.

---

## [1.0.0+1] — Current codebase (as of 2026-08-06)

### Added — Project documentation

- Full `Project_Documentation/` specification set (`00_AI_PROJECT_CONTEXT.md` through `30_README.md`).
- `Phase_02_UI_Foundation.md` delivery catalog for the global UI foundation.
- Status docs: `PROJECT_STATUS.md`, `CHANGELOG.md`, `UI_KIT.md` (this set).

### Added — Flutter application scaffold

- Single Flutter package `idhar_udhar` (`pubspec.yaml` version `1.0.0+1`).
- `lib/main.dart` with Riverpod `ProviderScope`, portrait/landscape orientation, system UI style, `AppTheme.light`, GoRouter.
- `lib/config/` — `AppConfig`, `AppConstants`, `Environment`, Firebase placeholder stub.
- Feature folder tree under `lib/features/` (implemented + empty shells).
- Asset folder registration in `pubspec.yaml`: images, icons, logos, animations, lottie, illustrations.

### Added — Design system (core)

- Theme tokens: `AppColors`, `AppTextStyles`, `AppSpacing`, `AppRadius`, `AppShadows`, `AppGradients`, `GlassEffect`, `AppTheme`.
- Core widgets: glass surfaces, primary/secondary/animated buttons, glass text field, OTP row, page indicator, top logo, backgrounds, loading indicator, vehicle/feature/floating glass cards.
- Core animations: `AppMotion`, fade/slide/scale/hero/press/float/parallax primitives.
- `AssetPaths` constants and `Responsive` helpers.
- In-app catalog: `docs/design_system/WIDGETS.md`.

### Added — Shared UI kit

- `lib/shared/theme/` façades re-exporting core tokens + `AppDurations` / `AppAnimations`.
- `lib/shared/widgets/` kit: `GlassContainer`, gradient/glass/outline buttons, glass field wrapper, animated/vehicle/parcel/booking/rider cards, app bar, section title, bottom sheet, dialog, snack bar, loading, shimmer.
- In-app catalog: `docs/design_system/SHARED_UI_KIT.md`.
- Empty shared category directories reserved with `.gitkeep` (buttons, cards, dialogs, etc.).

### Added — First-run UI (presentation only)

- Splash screen with logo entrance, sunset gradient, loading progress → navigates to onboarding.
- Onboarding (3 pages) with painted illustrations, page indicator, skip/next/back.
- Login screen (10-digit phone, terms checkbox, continue) → OTP route with phone query param.
- OTP verification UI (6 boxes, resend timer, verify) → location permission route.
- Location permission education UI (feature cards; snackbars only — no OS permission).
- GoRouter routes and transitions for the five screens above.

### Dependencies declared (see `pubspec.yaml`)

Runtime includes (among others): `flutter_riverpod`, `go_router`, `dio`, `freezed_annotation`, `json_annotation`, `equatable`, `uuid`, `google_fonts` **6.1.0**, `flutter_svg`, `cached_network_image`, `lottie`, `flutter_animate`, `hive` / `hive_flutter`, `flutter_secure_storage`, `shared_preferences`, `connectivity_plus`, `permission_handler`, `intl`, `logger`.

Dev: `flutter_lints`, `build_runner`, `freezed`, `json_serializable`, `hive_generator`.

> Note: Many packages are declared for future use; first-run screens primarily use Flutter SDK, `go_router`, and `google_fonts` via the design system.

### Not included in this release

- Firebase / FlutterFire configuration and runtime usage.
- Real OTP send/verify, session storage, or auth state.
- OS location permission requests or maps.
- Booking, home, payments, tracking, rider, or admin features.
- Image assets referenced by `AssetPaths` (except brand logo PNG).

---

## Version history legend

| Version | Meaning |
|---------|---------|
| `1.0.0+1` | Current `pubspec` version; encompasses scaffold + UI foundation + shared kit + first-run UI |
