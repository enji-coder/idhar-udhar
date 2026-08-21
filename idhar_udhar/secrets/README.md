# Local secrets (IDHAR UDHAR)

This folder is **LOCAL ONLY**.

- Never commit real credentials to GitHub.
- Never share real API keys, tokens, passwords, or private keys publicly.
- Never paste production secrets into chat, tickets, or screenshots.

The GitHub repository contains **source code** and **placeholder examples only**.

The Customer and Rider apps currently run on dummy/local data. These files are a layout for **future** credentials.

## Layout

```
secrets/
├── README.md                 (this file — safe to track)
├── customer/
│   └── .env.example          (placeholders only)
├── rider/
│   └── .env.example          (placeholders only)
├── backend/
│   └── .env.example          (placeholders only)
└── firebase/
    └── .env.example          (placeholders only)
```

Copy each `.env.example` to `.env` (or the real filename listed below) **on this computer only**, then fill in values locally.

## Where to put future credentials

| Credential | Place locally | Commit to GitHub? |
|------------|---------------|-------------------|
| Customer API URL / keys | `secrets/customer/.env` | No |
| Rider API URL / keys | `secrets/rider/.env` | No |
| Backend API / DB / JWT | `secrets/backend/.env` | No |
| Firebase **service account** JSON (private) | `secrets/firebase/` | No |
| Android upload keystore (`.jks` / `.keystore`) | `secrets/` or a password manager | No |
| `key.properties` (store passwords) | project `android/` locally (already gitignored) | No |

### Firebase — public vs private

Do **not** treat all Firebase files the same.

| File | Type | GitHub |
|------|------|--------|
| `google-services.json` (Android client) | Public client configuration | Usually OK for a client app when Firebase is added; currently gitignored until that decision is made |
| `GoogleService-Info.plist` (iOS client) | Public client configuration | Same as above |
| `lib/firebase_options.dart` | Generated client options | Currently gitignored |
| Firebase **service account** JSON | **Private** credential | **Never** |
| Any file with `BEGIN PRIVATE KEY` | **Private** key | **Never** |

Do not move or delete client Firebase files blindly. Only private credentials belong in `secrets/firebase/`.

## Required variables (future)

None are required today (dummy data). When a backend is connected, start with:

**Customer / Rider / root `.env`**

- `APP_ENV`
- `API_BASE_URL`
- `API_KEY`
- `SECRET_KEY` (if the backend requires a client secret — prefer not to ship true secrets in the mobile app)

**Backend**

- `API_BASE_URL`
- `API_KEY`
- `SECRET_KEY`
- plus database/JWT values only on the server, never in the mobile repo

**Firebase (when configured)**

- Follow official FlutterFire setup
- Keep service-account JSON in `secrets/firebase/` only

## New computer setup

Computer A (this machine):

1. Keep real values in `secrets/**/.env` and keystores locally.
2. Push **source** to GitHub (examples only).

Computer B:

```bash
git clone https://github.com/enji-coder/idhar-udhar-mobile.git
cd idhar-udhar-mobile
```

Create the local secrets layout:

```bash
mkdir secrets/customer secrets/rider secrets/backend secrets/firebase
```

Copy templates (from this repo) and fill in **your** values — do not invent fake production keys:

```bash
copy secrets\customer\.env.example secrets\customer\.env
copy secrets\rider\.env.example secrets\rider\.env
copy secrets\backend\.env.example secrets\backend\.env
copy secrets\firebase\.env.example secrets\firebase\.env
copy .env.example .env
```

Then:

```bash
flutter pub get
flutter run --flavor customer -t lib/main.dart
flutter run --flavor rider -t lib/rider/rider_main.dart
```

If Android release signing is used, copy `key.properties` and the `.jks` file locally; they must stay gitignored.

## Rules

1. Real `.env` files stay local.
2. Example files contain placeholders such as `YOUR_API_KEY` only.
3. If you are unsure whether a file is secret, do not commit it.
