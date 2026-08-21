# 10 — Folder Structure

## 10.1 Recommended Monorepo Layout

```
idhar_udhar/
├── README.md
├── melos.yaml                          # optional workspace tooling
├── analysis_options.yaml               # root lint baseline
├── Project_Documentation/              # this documentation set
│   ├── 01_Project_Overview.md
│   └── ...
├── apps/
│   ├── customer_app/
│   │   ├── android/
│   │   ├── ios/
│   │   ├── lib/
│   │   │   ├── main.dart
│   │   │   ├── main_dev.dart
│   │   │   ├── main_stg.dart
│   │   │   ├── main_prod.dart
│   │   │   ├── app.dart
│   │   │   ├── bootstrap.dart
│   │   │   ├── firebase_options_*.dart
│   │   │   ├── core/
│   │   │   │   ├── config/
│   │   │   │   ├── di/
│   │   │   │   ├── error/
│   │   │   │   ├── network/
│   │   │   │   ├── routing/
│   │   │   │   └── utils/
│   │   │   └── features/
│   │   │       ├── splash/
│   │   │       ├── onboarding/
│   │   │       ├── auth/
│   │   │       ├── location_permission/
│   │   │       ├── home/
│   │   │       ├── booking/
│   │   │       ├── tracking/
│   │   │       ├── payments/
│   │   │       ├── history/
│   │   │       ├── ratings/
│   │   │       ├── profile/
│   │   │       ├── settings/
│   │   │       ├── notifications/
│   │   │       └── support/
│   │   ├── test/
│   │   ├── assets/
│   │   │   ├── images/
│   │   │   ├── lottie/
│   │   │   ├── icons/
│   │   │   └── fonts/                # if self-hosted; prefer google_fonts
│   │   └── pubspec.yaml
│   └── rider_app/
│       ├── android/
│       ├── ios/
│       ├── lib/
│       │   ├── main*.dart
│       │   ├── app.dart
│       │   ├── bootstrap.dart
│       │   ├── core/
│       │   └── features/
│       │       ├── splash/
│       │       ├── auth/
│       │       ├── kyc/
│       │       ├── vehicle/
│       │       ├── home/
│       │       ├── availability/
│       │       ├── requests/
│       │       ├── trip/
│       │       ├── navigation/
│       │       ├── earnings/
│       │       ├── wallet/
│       │       ├── history/
│       │       ├── ratings/
│       │       ├── notifications/
│       │       ├── profile/
│       │       └── support/
│       ├── test/
│       ├── assets/
│       └── pubspec.yaml
├── packages/
│   ├── iu_core/
│   │   ├── lib/
│   │   │   ├── iu_core.dart
│   │   │   ├── constants/
│   │   │   ├── extensions/
│   │   │   ├── logging/
│   │   │   ├── result/
│   │   │   └── storage/
│   │   └── pubspec.yaml
│   ├── iu_design_system/
│   │   ├── lib/
│   │   │   ├── iu_design_system.dart
│   │   │   ├── theme/
│   │   │   │   ├── colors.dart
│   │   │   │   ├── typography.dart
│   │   │   │   ├── radii.dart
│   │   │   │   ├── shadows.dart
│   │   │   │   ├── gradients.dart
│   │   │   │   └── theme_data.dart
│   │   │   ├── components/
│   │   │   │   ├── buttons/
│   │   │   │   ├── cards/
│   │   │   │   ├── inputs/
│   │   │   │   ├── glass/
│   │   │   │   └── feedback/
│   │   │   └── tokens/
│   │   └── pubspec.yaml
│   ├── iu_domain/
│   │   ├── lib/
│   │   │   ├── entities/
│   │   │   ├── enums/
│   │   │   ├── failures/
│   │   │   └── value_objects/
│   │   └── pubspec.yaml
│   └── iu_firebase/
│       ├── lib/
│       │   ├── auth/
│       │   ├── firestore/
│       │   ├── storage/
│       │   ├── messaging/
│       │   └── crashlytics/
│       └── pubspec.yaml
├── backend/
│   └── functions/                      # Firebase Cloud Functions
│       ├── src/
│       │   ├── booking/
│       │   ├── matching/
│       │   ├── fare/
│       │   ├── payments/
│       │   ├── notifications/
│       │   ├── kyc/
│       │   └── index.ts
│       ├── package.json
│       └── tsconfig.json
├── tool/
│   ├── scripts/
│   └── ci/
└── docs/                               # optional generated API docs later
```

## 10.2 Feature Module Internal Pattern

Each feature folder:

```
features/<feature>/
├── data/
│   ├── datasources/
│   ├── dto/
│   ├── mappers/
│   └── repositories/
├── domain/
│   ├── entities/          # or use iu_domain
│   ├── repositories/      # abstracts
│   └── usecases/
├── presentation/
│   ├── providers/
│   ├── screens/
│   ├── widgets/
│   └── controllers/
└── <feature>.dart         # barrel (optional)
```

## 10.3 Assets Convention

```
assets/
  brand/
    logo_full.png
    logo_mark.png
  backgrounds/
    auth_sunset.webp
  illustrations/
    onboarding_1.webp
  icons/
  lottie/
    loading_truck.json
```

Use WebP where possible; keep PNG for logo transparency.

## 10.4 Test Layout Mirror

```
test/
  features/
    auth/
      login_notifier_test.dart
  golden/
```

## 10.5 Naming Rules

- Folders: `snake_case`
- Dart files: `snake_case.dart`
- Classes: `PascalCase`
- Providers: `camelCaseProvider` / `camelCaseNotifierProvider`
- Routes: path strings centralized in `routing/routes.dart`

## 10.6 What Not to Do

- No giant `widgets/` dumping ground at app root
- No business logic in `build()` methods
- No Firebase imports inside presentation widgets (use repositories)
- No duplicated color hexes outside design system package
