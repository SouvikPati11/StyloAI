# StyloAI — CI/CD (GitHub Actions)

Cloud builds only — **no developer's local machine is required** for production
builds. GitHub is the source of truth; Actions builds the Android app and the
backend. Release signing credentials are **GitHub Actions secrets**, never
committed.

---

## Workflows

### 1. `analyze_test.yml` — on every push & PR
Fast feedback, no signing needed.
- **Mobile:** `flutter pub get` → `dart format --set-exit-if-changed` →
  `flutter analyze` → `flutter test`.
- **Backend:** `npm ci` → `npm run lint` → `npm run typecheck` →
  `npm test` (unit) → `prisma validate`.
- Paths-filtered so mobile-only changes don't run backend jobs and vice versa.

### 2. `android_release.yml` — on tag `v*` or manual `workflow_dispatch`
Produces a **signed AAB** (for Play) and an **APK** (for sideload/testing),
uploads both as artifacts.
```
steps:
  - checkout
  - setup-java (temurin 17)
  - subosito/flutter-action (pinned version)
  - flutter pub get
  - flutter analyze && flutter test
  - Decode signing keystore from secret:
      echo "$ANDROID_KEYSTORE_BASE64" | base64 -d > mobile/android/app/upload-keystore.jks
      write key.properties from secrets (storePassword/keyPassword/keyAlias/storeFile)
  - flutter build appbundle --release --dart-define=API_BASE_URL=$PROD_API_BASE_URL
  - flutter build apk --release       --dart-define=API_BASE_URL=$PROD_API_BASE_URL
  - upload-artifact: app-release.aab, app-release.apk
  # (optional later) upload to Play Console internal track via
  #   r0adkll/upload-google-play using PLAY_SERVICE_ACCOUNT_JSON
```
`key.properties` and the keystore are generated **at build time** from secrets
and never committed (`.gitignore` blocks them).

### 3. `backend_deploy.yml` — on tag / manual (added in Phase 1+)
- `npm ci && npm run build` → build Docker image → push to ECR →
  `prisma migrate deploy` → update ECS service (or deploy to EC2). Secrets pulled
  from SSM at runtime, not baked into the image.

---

## Required GitHub Actions secrets

| Secret | Used by | Purpose |
|--------|---------|---------|
| `ANDROID_KEYSTORE_BASE64` | android_release | base64 of upload keystore |
| `ANDROID_KEYSTORE_PASSWORD` | android_release | keystore password |
| `ANDROID_KEY_ALIAS` | android_release | signing key alias |
| `ANDROID_KEY_PASSWORD` | android_release | key password |
| `PROD_API_BASE_URL` | android_release | `--dart-define` API base |
| `PLAY_SERVICE_ACCOUNT_JSON` | (optional) upload step | Play Console upload |
| `AWS_*` / OIDC role | backend_deploy | ECR/ECS deploy (prefer OIDC, no static keys) |

**Never** commit keystores, `key.properties`, or service-account JSON. Generate
the upload keystore once, store it base64 as a secret, and keep an offline
backup.

---

## Reproducibility
- Pin action versions and the Flutter/Java versions. - Deterministic
  `--dart-define` build config per flavor (dev/staging/prod). - Artifacts named
  with the git tag. - Same steps locally documented in `mobile/README.md` for
  parity, but production releases come from Actions.

---

## Mobile-first developer workflow
This CI design is exactly what makes a **phone-based** workflow practical:
edit/commit on GitHub (or a mobile IDE) → Actions runs analyze/test → tag a
release → Actions builds the signed AAB → download the artifact / it lands in
the Play internal track. No PC needed for the build/release loop.
