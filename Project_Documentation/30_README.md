# 30 — README

# IDHAR UDHAR

**Delivering Trust, Every Time.**

IDHAR UDHAR is a production-oriented, Porter-like logistics platform connecting customers with verified delivery riders for on-demand parcel and goods transportation across Indian cities.

This repository (and documentation package) defines the architecture, design system, and delivery plan for:

- **Customer App** (Flutter)
- **Rider App** (Flutter)
- **Admin Panel** (future)
- **Firebase-backed** platform services

> **Current status:** Documentation phase complete. Application source code is intentionally not started until documentation sign-off.

---

## Features

### Customer App (MVP)

- Splash, onboarding, authentication (login, register, OTP, forgot password)
- Location permission with privacy rationale
- Pickup & drop via Google Maps + Places
- Parcel type, weight, vehicle selection
- Fare estimation & coupons
- Booking, live tracking, cash payments
- Order history, ratings, profile, help & support
- Push notifications

### Rider App (MVP)

- Authentication & document KYC
- Vehicle registration
- Online/Offline availability
- Booking requests with accept/reject
- Navigation to pickup/drop
- Pickup & delivery confirmation
- Earnings, wallet, trip history, ratings
- Notifications

### Admin Panel (Future)

Customer, rider, vehicle, booking, payments, offers, notifications, analytics, reports, settings—architecture is designed for later integration without schema rewrites.

---

## Tech Stack

| Area | Technology |
|------|------------|
| Framework | Flutter (latest stable), Dart |
| UI | Material Design 3 + custom glass design system |
| State | Riverpod |
| Routing | GoRouter |
| Backend | Firebase Auth, Firestore, Storage, FCM, Crashlytics, Cloud Functions |
| Maps | Google Maps, Places, Directions |
| HTTP | Dio |
| Models | Freezed, Json Serializable |
| Local | Hive, Flutter Secure Storage, Shared Preferences |
| Media | Cached Network Image, Lottie, Google Fonts |
| Layout | Responsive Framework |

---

## Architecture

High-level:

```
Customer App ─┐
Rider App    ─┼─ Firebase Auth / Firestore / Storage / FCM
Admin (later)─┘         │
                 Cloud Functions (matching, fare, payments, push)
                         │
                 Google Maps Platform
```

- Feature-first Flutter modules
- Shared packages: `iu_core`, `iu_design_system`, `iu_domain`, `iu_firebase`
- Server-enforced booking state machine and fare truth
- Multi-environment flavors: `dev`, `stg`, `prod`

See: `09_System_Architecture.md`, `11_Database_Architecture.md`, `12_Firebase_Architecture.md`.

---

## Folder Structure

```
idhar_udhar/
├── Project_Documentation/     # You are here (spec package)
├── apps/
│   ├── customer_app/
│   └── rider_app/
├── packages/
│   ├── iu_core/
│   ├── iu_design_system/
│   ├── iu_domain/
│   └── iu_firebase/
└── backend/
    └── functions/
```

Full tree: `10_Folder_Structure.md`.

---

## Documentation Index

| # | Document |
|---|----------|
| 01 | Project Overview |
| 02 | Product Vision |
| 03 | User Personas |
| 04 | Feature List |
| 05 | Project Scope |
| 06 | Functional Requirements |
| 07 | Non-Functional Requirements |
| 08 | User Flows |
| 09 | System Architecture |
| 10 | Folder Structure |
| 11 | Database Architecture |
| 12 | Firebase Architecture |
| 13 | API Strategy |
| 14 | State Management |
| 15 | UI/UX Guidelines |
| 16 | Design System |
| 17 | Animation Guidelines |
| 18 | Navigation Architecture |
| 19 | Security Strategy |
| 20 | Error Handling |
| 21 | Offline Strategy |
| 22 | Performance Strategy |
| 23 | Testing Strategy |
| 24 | Git Workflow |
| 25 | Coding Standards |
| 26 | Project Roadmap |
| 27 | Development Phases |
| 28 | Risk Assessment |
| 29 | Future Enhancements |
| 30 | README (this file) |

---

## Installation Guide (When Code Exists)

> Placeholder for post–Phase 1. Expected flow:

```bash
# Prerequisites: Flutter stable, Git, Firebase CLI, Node 20+
git clone <repo-url>
cd idhar_udhar

# Optional Melos
dart pub global activate melos
melos bootstrap

# Or per app
cd apps/customer_app && flutter pub get
cd ../rider_app && flutter pub get
```

---

## Dependencies (Planned)

Core (non-exhaustive):

- `flutter_riverpod` / `riverpod_annotation`
- `go_router`
- `firebase_core`, `firebase_auth`, `cloud_firestore`, `firebase_storage`, `firebase_messaging`, `firebase_crashlytics`
- `dio`
- `freezed_annotation`, `json_annotation`
- `hive` / `hive_flutter`
- `flutter_secure_storage`
- `shared_preferences`
- `geolocator`, `permission_handler`
- `google_maps_flutter`
- `cached_network_image`
- `lottie`
- `google_fonts`
- `responsive_framework`

Exact versions pinned at implementation time.

---

## Environment Setup

1. Install Flutter (stable channel) and run `flutter doctor`
2. Install Android Studio / Xcode as needed
3. Install Firebase CLI and log in
4. Create projects: `idhar-udhar-dev`, `-stg`, `-prod`
5. Configure flavors and entrypoints (`main_dev.dart`, etc.)
6. Store secrets in CI / local unscanned files—never commit production keys

---

## Firebase Setup

1. Enable Authentication (Phone / Email)
2. Create Firestore in `asia-south1` (confirm availability)
3. Enable Storage, FCM, Crashlytics
4. Deploy security rules (deny-by-default)
5. Initialize Cloud Functions TypeScript project
6. Configure App Check before public launch
7. Use Emulator Suite for local development

Details: `12_Firebase_Architecture.md`.

---

## Build Commands (Planned)

```bash
# Customer
flutter run --flavor dev -t lib/main_dev.dart
flutter build apk --flavor prod -t lib/main_prod.dart
flutter build ipa --flavor prod -t lib/main_prod.dart

# Rider
cd apps/rider_app
flutter run --flavor dev -t lib/main_dev.dart
```

---

## Git Workflow

- Protected `main`
- Branches: `feature/*`, `fix/*`, `chore/*`
- Conventional Commits
- PR + review required

See `24_Git_Workflow.md`.

---

## Development Rules

1. No business logic in widgets
2. No Firebase imports in presentation layer
3. Design tokens only from `iu_design_system`
4. Server validates fare, matching, coupons
5. All user strings via l10n
6. Follow `25_Coding_Standards.md`

---

## Contribution Guide

1. Read `05_Project_Scope.md` and `27_Development_Phases.md`
2. Pick a task aligned to the current phase
3. Create a feature branch
4. Implement with tests
5. Open PR with screenshots for UI
6. Ensure analyze + tests pass

---

## Design Language (Quick Reference)

| Token | Value |
|-------|-------|
| Orange | `#FF6624` |
| Navy | `#2E4072` |
| CTA | Orange horizontal gradient, pill button |
| Cards | Glassmorphism, radius 32–40 |
| Font | Poppins via Google Fonts |

Full tokens: `16_Design_System.md`.

---

## License

Copyright © IDHAR UDHAR. All rights reserved.

License type (MIT / proprietary) — **TBD by stakeholders**. This placeholder must be replaced before open distribution.

---

## Contact

Product / engineering contacts — TBD.

For architecture questions, start with `01_Project_Overview.md` and `09_System_Architecture.md`.
