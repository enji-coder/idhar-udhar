# IDHAR UDHAR Mobile App

Customer + Rider Flutter applications.

One repository, two Android flavors, two entry points.

| App | Flavor | Entry point | Application ID |
|-----|--------|-------------|----------------|
| Customer | `customer` | `lib/main.dart` | `com.idharudhar.idhar_udhar` |
| Rider (Partner) | `rider` | `lib/rider/rider_main.dart` | `com.idharudhar.rider` |

## Prerequisites

- Flutter stable (project verified on Flutter 3.44.x / Dart 3.12.x)
- Dart SDK matching `pubspec.yaml` (`>=3.2.6 <4.0.0`)
- Android toolchain for device / APK builds

```bash
cd idhar_udhar
flutter pub get
```

## Customer

Run:

```bash
flutter run --flavor customer -t lib/main.dart
```

## Rider

Run:

```bash
flutter run --flavor rider -t lib/rider/rider_main.dart
```

## Build Customer APK

```bash
flutter build apk --flavor customer -t lib/main.dart
```

## Build Rider APK

```bash
flutter build apk --flavor rider -t lib/rider/rider_main.dart
```

## Project structure

```
lib/
  main.dart                 # Customer entry (re-exports customer app)
  customer/                 # Customer app (UI, routing, dummy data)
  rider/                    # Rider / Partner app
    rider_main.dart         # Rider entry
android/
  app/build.gradle          # productFlavors: customer, rider
  app/src/main/             # Shared Android resources
  app/src/customer/         # Customer flavor resources
  app/src/rider/            # Rider flavor resources (icon, name, overlay permission)
assets/
  customer/                 # Customer logos, illustrations, 3D images
  rider/                    # Rider logos and images
```

## Notes

- Both apps currently use **dummy / local data**. Firebase and backend are not wired.
- Do not commit secrets (`.env`, keystores, `key.properties`, service-account JSON).
- Copy `.env.example` to `.env` locally if you add environment values later.
- Local credentials belong in `secrets/` (see `secrets/README.md`). That folder is gitignored except README and `*.example` templates.

## License

Copyright © IDHAR UDHAR. All rights reserved.
