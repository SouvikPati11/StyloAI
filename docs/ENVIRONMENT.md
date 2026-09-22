# StyloAI — Environment & Secrets Reference

Every configuration value and secret used by StyloAI. **Secrets are never
committed** — they live in backend env / AWS SSM / GitHub Actions secrets. This
doc is the checklist; `.env.example` files (committed, no real values) mirror it.

---

## Backend (`backend/.env` — from SSM in prod)

| Variable | Secret? | Description |
|----------|:------:|-------------|
| `NODE_ENV` | no | `development` / `production` |
| `PORT` | no | API port |
| `API_BASE_URL` | no | public base, e.g. `https://api.stylo.app` |
| `ADMIN_BASE_URL` | no | `https://admin.stylo.app` |
| `DATABASE_URL` | **yes** | Postgres connection string (RDS) |
| `REDIS_URL` | **yes** | Redis/ElastiCache connection |
| `JWT_ACCESS_SECRET` | **yes** | signs backend access tokens |
| `JWT_REFRESH_SECRET` | **yes** | signs refresh tokens |
| `JWT_ACCESS_TTL` / `JWT_REFRESH_TTL` | no | token lifetimes |
| `FIREBASE_PROJECT_ID` | no | Firebase project |
| `FIREBASE_SERVICE_ACCOUNT_JSON` | **yes** | Admin SDK (verify ID tokens + send FCM) — JSON or path via SSM |
| `GEMINI_API_KEY` | **yes** | Google Gemini image API key |
| `GEMINI_MODEL` | no | model id / default |
| `AWS_REGION` | no | e.g. `ap-south-1` |
| `S3_BUCKET` | no | media bucket name |
| `S3_UPLOAD_URL_TTL` | no | presign expiry seconds |
| `CLOUDFRONT_DOMAIN` | no | CDN domain for signed delivery |
| `CLOUDFRONT_KEY_PAIR_ID` | **yes** | signed-URL key pair id |
| `CLOUDFRONT_PRIVATE_KEY` | **yes** | signed-URL private key |
| `PLAY_PACKAGE_NAME` | no | Android package name |
| `PLAY_SERVICE_ACCOUNT_JSON` | **yes** | Play Developer API (purchase verification) |
| `CORS_ALLOWED_ORIGINS` | no | admin origin(s) |
| `RATE_LIMIT_*` | no | per-endpoint overrides (defaults also in DB settings) |

> In production prefer an **IAM instance/task role** over static `AWS_ACCESS_KEY_ID`/
> `AWS_SECRET_ACCESS_KEY`. If static keys are unavoidable, they are secrets.

## Admin bootstrap
| `ADMIN_BOOTSTRAP_EMAIL` / `ADMIN_BOOTSTRAP_PASSWORD` | **yes** | seed the first `super_admin` (one-time, then rotate) |

---

## Mobile (`--dart-define` at build, not a `.env`)

| Define | Secret? | Description |
|--------|:------:|-------------|
| `API_BASE_URL` | no | backend base URL per flavor |
| `FLAVOR` | no | `dev` / `staging` / `prod` |

Firebase client config ships as `google-services.json` (gitignored by
convention; it is a client config, not a secret). **No Gemini/AWS/DB/Play
secrets ever exist in the app.**

---

## GitHub Actions secrets
See [`CICD.md`](CICD.md) — `ANDROID_KEYSTORE_BASE64`,
`ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`,
`PROD_API_BASE_URL`, optional `PLAY_SERVICE_ACCOUNT_JSON`, AWS OIDC role.

---

## `.env.example` policy
Each component commits a `.env.example` with **keys only / placeholder values**.
Real values are injected via SSM (backend) or Actions secrets (CI). CI/secret
scanning should fail the build if a real secret is detected in a commit.
