# Firebase Setup (Placeholder)

Firebase is **not** configured in Phase 2.

## When ready

1. Create Firebase projects for `dev`, `stg`, and `prod`.
2. Install FlutterFire CLI: `dart pub global activate flutterfire_cli`
3. From the app root:

```bash
flutterfire configure --project=<project-id>
```

4. Enable Authentication, Firestore, Storage, FCM, and Crashlytics in the console.
5. Add platform config files via CI or a secure local path (they are gitignored).
6. Prefer region `asia-south1` when creating Firestore / Functions.

## Generated artifacts (do not invent manually)

- `lib/firebase_options.dart`
- `android/app/google-services.json`
- `ios/Runner/GoogleService-Info.plist`

See `Project_Documentation/12_Firebase_Architecture.md` for the full plan.
