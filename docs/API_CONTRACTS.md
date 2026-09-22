# StyloAI — API Contracts (v1)

REST over HTTPS, JSON. Base: `https://api.stylo.app/v1`. All app→backend calls
(except auth exchange) require `Authorization: Bearer <backend-jwt>`.

## Conventions

- **Auth:** client obtains a Firebase ID token, exchanges it for a backend
  session JWT (access + refresh). Access token ~1h; refresh rotates.
- **Idempotency:** mutating generation/purchase calls take an
  `Idempotency-Key` (also echoed in body). Safe to retry on network failure.
- **Error envelope** (every non-2xx):
  ```json
  { "error": { "code": "INSUFFICIENT_CREDITS", "message": "You need 4 credits.",
               "details": { "required": 4, "balance": 1 } } }
  ```
  Typed `code`s map directly to Flutter UI states (§26 of brief):
  `UNAUTHENTICATED`, `TOKEN_EXPIRED`, `INSUFFICIENT_CREDITS`, `RATE_LIMITED`,
  `VALIDATION_ERROR`, `GENERATION_FAILED`, `PAYMENT_INVALID`,
  `PURCHASE_ALREADY_CLAIMED`, `NOT_FOUND`, `FEATURE_DISABLED`, `INTERNAL`.
- **Pagination:** cursor-based `?limit=&cursor=`; responses include `next_cursor`.

---

## Auth

### POST /auth/google
Exchange a verified Firebase ID token for backend tokens; upserts the user.
```
req:  { "firebase_id_token": "..." }
res:  { "access_token": "...", "refresh_token": "...", "expires_in": 3600,
        "user": { "id", "display_name", "avatar_url", "onboarding_completed" } }
```
### POST /auth/refresh  → new access/refresh pair
### POST /auth/logout    → revokes refresh token
### DELETE /account      → schedules account + data deletion (privacy, §21)

---

## Profile & style

- `GET /me` → user + wallet balance + flags
- `PATCH /me` → display_name, avatar, notification prefs
- `GET /me/style-profile` · `PUT /me/style-profile` (user-provided prefs)
- `POST /me/style-profile/analyze` → optional AI analysis of a photo; returns
  `source:"ai"` suggestions the user can accept (costs credits if configured)

---

## Media upload

Uploads use **pre-signed S3 PUT** so bytes never transit the API server.
### POST /uploads/presign
```
req:  { "purpose": "user_photo" | "outfit_ref" | ...,
        "content_type": "image/jpeg" }
res:  { "upload_url": "<s3 signed PUT>", "s3_key": "...", "expires_in": 300 }
```
Client PUTs the image to `upload_url`, then references `s3_key` in a generation
request. Backend validates ownership + content-type + size on submit.

---

## Generation

### GET /config
Client bootstrap: credit costs, enabled features, categories, resolution
options — all from `system_settings`/DB. **The app renders costs from here; it
never hard-codes them.**
```
res: { "credit_costs": {...}, "features": {...}, "resolutions": [...],
       "sections": {...} }
```

### POST /generations
Submit a job (async). One endpoint, `type` discriminates.
```
headers: Idempotency-Key: <uuid>
req: {
  "type": "outfit",
  "mode": "reference_upload",            // or "explore"
  "preset_key": "streetwear",            // when mode=explore
  "user_photo_key": "s3://.../user.jpg",
  "reference_key": "s3://.../outfit.jpg",// when mode=reference_upload
  "options": { "resolution": "standard" }
}
res 202: { "generation_id": "...", "status": "queued", "credit_cost": 4,
           "balance_after_hold": 16 }
```
Backend flow: authenticate → validate inputs/ownership → load cost from settings
→ check balance → **insert `generation_hold` (pending) + create generation** in
one transaction → enqueue worker job → return 202. Duplicate `Idempotency-Key`
returns the original generation (no second charge).

### GET /generations/:id  → status + outputs when done
```
res: { "id", "type", "status": "succeeded",
       "images": [ { "id", "url": "<signed>", "thumbnail_url", "width","height" } ],
       "credit_cost": 4, "created_at", "finished_at" }
```
On `failed`: `error_code` set, hold reversed → `status:"refunded"` where policy
applies; balance restored.

### GET /generations?type=&cursor=  → history (§19)
### POST /looks  {generated_image_id, title?} → save (§19)
### GET /looks  · DELETE /looks/:id
### DELETE /generations/:id  → user deletes a generation + its images (privacy)

---

## Explore / Trending (§6)

- `GET /trending?section=outfit` → active `trending_content`, ordered
- `GET /categories?section=hair` → presets for "Explore Styles"
- `GET /recommendations` → personalized from style_profile + trending

All content is DB-driven and admin-managed → changes without an app release.

---

## Credits & billing

- `GET /wallet` → balance, lifetime earned/spent
- `GET /wallet/transactions?cursor=` → ledger history (§7)
- `GET /store/products` → credit packs (from Play + settings)
- `POST /billing/google/verify`
  ```
  req: { "product_id": "credits_100", "purchase_token": "...", "order_id": "..." }
  res: { "granted": true, "credits_added": 100, "balance": 116 }
  ```
  Backend verifies the token against the Play Developer API, acknowledges the
  purchase, and grants credits **once** (token UNIQUE). Never trusts a client
  "success" flag. Full flow in [`CREDITS_AND_BILLING.md`](CREDITS_AND_BILLING.md).

---

## Devices & notifications

- `POST /devices` {fcm_token} · `DELETE /devices/:token`
- `GET /notifications?cursor=` · `POST /notifications/:id/read`

---

## Admin API (separate auth, `/admin` prefix, admin JWT)
See [`ADMIN_PANEL.md`](ADMIN_PANEL.md). Examples: `POST /admin/auth/login`,
`GET /admin/stats`, CRUD `/admin/trending`, `/admin/categories`,
`/admin/users`, `POST /admin/users/:id/credits`, `PUT /admin/settings/:key`.

---

## Rate limiting
Expensive endpoints (`POST /generations`, `POST /billing/google/verify`,
`POST /uploads/presign`) are rate-limited per user + per IP via Redis.
Exceeding returns `RATE_LIMITED` with `Retry-After`.
