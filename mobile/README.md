# StyloAI Mobile (Flutter, Android)

The consumer app — a premium AI personal stylist. Presentation/capture layer
only: no secrets, no money logic. Wired to the StyloAI backend
([`../docs/API_CONTRACTS.md`](../docs/API_CONTRACTS.md)); design system and screen
map in [`../docs/FLUTTER_APP.md`](../docs/FLUTTER_APP.md).

## Status
**Implemented** — one coherent design system and the full screen set: splash,
onboarding, Google sign-in, home, explore/trending, the Create hub with all six
flows (Outfit, Hair, Glasses, Accessories, Pose, AI Edit) including user-photo +
reference-image upload, generation progress, before/after result, save look,
history, personal style profile, credits store (Google Play Billing), profile,
settings, notifications, and Privacy/Terms — all wired to the real backend.
`flutter analyze` is clean and unit tests pass.

## Stack
Flutter · Riverpod · go_router · Dio · firebase_auth · firebase_messaging ·
google_sign_in · in_app_purchase · image_picker · cached_network_image ·
google_fonts.

## Configuration you must provide

### 1. Backend URL (build-time, not a secret)
Passed with `--dart-define`. Defaults to the Android-emulator loopback
`http://10.0.2.2:3000` for local dev.

### 2. Firebase (required for sign-in + push) — CONFIGURATION POINT
Google Sign-In uses Firebase Auth. Until you configure it, the app runs in a
clearly-marked "sign-in setup required" state (it never fakes auth):
```bash
dart pub global activate flutterfire_cli
flutterfire configure --project=<your-firebase-project>
```
This overwrites `lib/core/firebase_options.dart` with your real options and adds
`android/app/google-services.json` (both gitignored). Then enable Google
Sign-In under Firebase Authentication and rebuild.

### 3. Google Play Billing (required for purchases)
Create the credit-pack products in Google Play Console with IDs matching the
backend `store_products` setting (`credits_50`, `credits_120`, `credits_300`).
Purchases are verified server-side before credits are granted.

## Run locally
```bash
flutter pub get
flutter run \
  --dart-define=API_BASE_URL=http://10.0.2.2:3000 \
  --dart-define=FLAVOR=dev
```

## Verify
```bash
flutter analyze     # static analysis (clean)
flutter test        # unit tests
```

## Build (production comes from CI)
```bash
flutter build apk --release  --dart-define=API_BASE_URL=$PROD_API_BASE_URL
flutter build appbundle --release --dart-define=API_BASE_URL=$PROD_API_BASE_URL
```
Signed release builds (AAB + APK) are produced by GitHub Actions from secrets —
see [`../docs/CICD.md`](../docs/CICD.md). Release signing reads
`android/key.properties` (never committed); without it, builds fall back to
debug keys so the project still compiles.
