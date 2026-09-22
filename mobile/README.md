# StyloAI Mobile (Flutter, Android)

The consumer app. Presentation/capture layer only — no secrets, no money logic.
See [`../docs/FLUTTER_APP.md`](../docs/FLUTTER_APP.md) for the screen map and
design system, and [`../docs/API_CONTRACTS.md`](../docs/API_CONTRACTS.md) for the
backend it talks to.

## Status
Scaffolding. Implementation begins in **Phase 3** (see
[`../docs/ROADMAP.md`](../docs/ROADMAP.md)).

## Planned stack
Flutter · Riverpod · go_router · Dio · firebase_auth · firebase_messaging ·
in_app_purchase · image_picker.

## Local setup (once scaffolded)
```bash
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000 --dart-define=FLAVOR=dev
```
Add `google-services.json` under `android/app/` (gitignored). It is Firebase
client config — not a secret, but not committed by convention.

## Build (production comes from CI, not a local machine)
```bash
flutter build appbundle --release --dart-define=API_BASE_URL=$PROD_API_BASE_URL
```
Signed release builds are produced by GitHub Actions — see
[`../docs/CICD.md`](../docs/CICD.md). Never commit keystores or `key.properties`.

## Config
- `API_BASE_URL`, `FLAVOR` via `--dart-define`.
- Credit costs, features, categories are fetched at runtime from `GET /config`
  (never hard-coded).
