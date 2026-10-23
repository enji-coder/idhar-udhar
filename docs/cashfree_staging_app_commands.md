# Staging Customer / Rider build commands (do not auto-execute)

Placeholders only. Replace `<STAGING_API_HOST>` with the staging API hostname after the human operator provisions it.

These commands are documented for Checkpoint 2–4. **Do not run APK release builds as part of agent automation.** Prefer debug/profile against staging until Checkpoint 4 sign-off.

## Rules

1. Always pass `--dart-define=API_BASE_URL=https://<STAGING_API_HOST>`.
2. Never omit `API_BASE_URL` on Rider — Rider defaults to production (`https://api.idharudhar.co.in`) when unset.
3. Customer debug without dart-define uses localhost / `10.0.2.2:3000` (local API), not staging.
4. Do not use production `API_BASE_URL` while testing Sandbox payments.
5. Cashfree SDK sandbox/production follows the backend session field `cashfree_environment`, not the Flutter flavor name.

## Customer (debug → staging API)

```bash
cd idhar_udhar
flutter pub get
flutter run --flavor customer -t lib/customer/customer_main.dart --dart-define=API_BASE_URL=https://<STAGING_API_HOST>
```

Optional catalog pins (staging city UUID from staging `GET /v1/vehicle-categories`):

```bash
flutter run --flavor customer -t lib/customer/customer_main.dart ^
  --dart-define=API_BASE_URL=https://<STAGING_API_HOST> ^
  --dart-define=IU_CITY_ID=<STAGING_CITY_UUID>
```

## Rider / Partner (debug → staging API)

```bash
cd idhar_udhar
flutter pub get
flutter run --flavor rider -t lib/rider/rider_main.dart --dart-define=API_BASE_URL=https://<STAGING_API_HOST>
```

## Release APKs pointed at staging (manual only; not for store)

```bash
cd idhar_udhar
flutter build apk --release --flavor customer -t lib/customer/customer_main.dart --dart-define=API_BASE_URL=https://<STAGING_API_HOST>
flutter build apk --release --flavor rider -t lib/rider/rider_main.dart --dart-define=API_BASE_URL=https://<STAGING_API_HOST>
```

Outputs land under `build/app/outputs/flutter-apk/` (flavor-specific names). Label installs clearly as **STAGING** so they are not confused with production builds.

## Admin Panel (staging)

```bash
cd IDHAR_UDHAR_ADMIN
# copy .env.staging.example → .env with VITE_API_BASE_URL=https://<STAGING_API_HOST>
npm install
npm run dev
```

Production Netlify Admin must keep its existing production `VITE_API_BASE_URL` unchanged.
