# StyloAI — Security & Privacy

Security is production functionality, not an afterthought. StyloAI handles
personal photos and real money (credits), so the design assumes the client is
untrusted.

---

## 1. Secrets — never in the client or repo
The following live **only** in backend environment variables / a secrets manager
(AWS SSM Parameter Store or Secrets Manager), and are enumerated in
[`ENVIRONMENT.md`](ENVIRONMENT.md):

- `GEMINI_API_KEY`
- AWS access credentials (prefer **IAM instance role**, not static keys)
- `DATABASE_URL` (RDS credentials)
- Firebase Admin **service account JSON** (Auth verify + FCM send)
- Google **Play Developer API** service account (purchase verification)
- Backend JWT signing secret(s)

`.gitignore` blocks `.env`, keystores, `google-services.json`, service-account
JSON, `key.properties`. CI uses GitHub Actions secrets. A pre-commit / secret
scan is recommended.

## 2. Authentication & sessions
- App signs in with **Firebase Google Sign-In** → receives a Firebase **ID
  token**. - Backend verifies it with the **Firebase Admin SDK**, upserts the
  user by `firebase_uid`, and issues its **own** short-lived access JWT +
  rotating refresh token. - The Firebase ID token is only used at
  `/auth/google`; all other calls use the backend JWT. - Logout revokes the
  refresh token; account deletion tears down sessions + data.

## 3. Authorization
- Every resource is scoped to the authenticated `user_id`; the API never lets a
  user read/mutate another user's photos, looks, generations, wallet, or
  transactions. - S3 object ownership is validated on generation submit (the
  `s3_key` must belong to the caller's prefix). - **Admin** uses a separate
  `admin_users` table, separate login, separate JWT audience, and role-based
  guards (`super_admin` / `admin` / `content_editor`). Admin routes are network-
  and auth-gated.

## 4. Money & credits (never trust the client)
- Balances and costs are server-authoritative (ledger). - Purchases are granted
  only after **server-side Play verification**; `purchase_token` UNIQUE prevents
  replay. - Spends use hold→settle/refund with idempotency keys. See
  [`CREDITS_AND_BILLING.md`](CREDITS_AND_BILLING.md).

## 5. Rate limiting & abuse control
- Redis-backed limits on expensive endpoints: `POST /generations`,
  `POST /billing/google/verify`, `POST /uploads/presign`, `/auth/*`. - Per-user
  **and** per-IP. - `RATE_LIMITED` with `Retry-After`. - Upload presign
  constrains content-type and enforces max object size; generation validates
  dimensions.

## 6. Object storage
- S3 buckets are **private** (no public ACLs, Block Public Access on). - Uploads
  via short-lived pre-signed PUT URLs. - Delivery via short-lived signed
  CloudFront/S3 GET URLs — images are never permanently public. - Separate
  prefixes: `originals/`, `references/`, `generated/`, `admin/`. - Lifecycle
  rules expire temporary/reference objects (§ cost + privacy).

## 7. Transport & network
- HTTPS everywhere (TLS), HSTS. - `api.stylo.app` and `admin.stylo.app`
  subdomains. - Admin panel additionally restricted (auth + optional IP
  allowlist). - Security headers, CORS locked to known origins.

## 8. Input validation
- All request bodies validated (DTO schema validation in NestJS). - Image
  content-type/size/dimension checks. - No user-supplied text is interpolated
  into prompts unsanitized; preset descriptors come from the server catalog.

## 9. Privacy (personal photos, §21)
- **Data minimization:** store only what's needed (S3 keys + metadata; no raw
  images in Postgres). - **User control:** delete individual generations/looks;
  delete account → cascade delete of photos (S3), generations, looks, profile;
  purge FCM tokens. - **Retention:** temporary/reference images expire via S3
  lifecycle; originals kept only while the account/feature needs them. -
  **Transparency:** in-app Privacy Policy + Terms before production launch;
  clear description of how photos are used for generation. - **No unnecessary
  PII**; marketing notifications default **off**.

## 10. Logging & monitoring
- CloudWatch logs/metrics/alarms. - Never log secrets, tokens, or full image
  data. - Audit trail: credit ledger + admin actions (`updated_by`,
  `created_by`) are traceable. - Alarms on error rates, generation failure
  spikes, and unusual purchase-verification failures.

## 11. Least privilege
- IAM roles scoped narrowly (S3 prefix-scoped, RDS access from app SG only). -
  DB user has only needed grants. - Admin roles gate destructive actions.

## 12. Deletion & incident readiness
- Documented account-deletion path (privacy + Play policy). - Backups of RDS
  (automated snapshots). - Secret rotation is possible without code changes
  (env-driven).
