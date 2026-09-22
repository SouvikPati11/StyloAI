# StyloAI — Admin Panel

A real, functional, DB-backed admin panel — not a fake dashboard. Served by the
backend at `admin.stylo.app`, protected by a separate auth stack from the
consumer app.

---

## Auth & roles
- Separate `admin_users` table (email + password hash), separate login
  (`POST /admin/auth/login`), separate JWT audience. **Not** Firebase/consumer
  login.
- Roles: `super_admin` (all), `admin` (content + users + credits + settings),
  `content_editor` (content only). Role-based route guards.
- Optional IP allowlist + strong password policy + audit of admin actions
  (`created_by`/`updated_by`/`updated_at` on records).

---

## Capabilities

### Dashboard (stats)
`GET /admin/stats` aggregates: total users, active users, total/successful/failed
generations, generation volume by type, credit usage (spent/granted), purchases
& revenue-adjacent records, AI usage trends, and basic system health. Charts +
tables, DB-sourced (no mock numbers).

### Content management (drives Explore/Trending without an app release, §6)
CRUD over `trending_content` and `categories`:
- Add/edit/remove trending outfits, hairstyles, glasses, accessories, poses,
  AI-edit styles.
- Upload content media (to S3 `admin/` prefix via presign).
- Manage categories/presets per section; `is_active`, `position`, scheduling
  (`starts_at`/`ends_at`).
- Because the app reads this live from the API, changes appear immediately — no
  Play release needed.

### User management
- Search users, view a user (profile, status, style profile).
- View credit balance, full credit-transaction history, generation history.
- Set account `status` (`active`/`suspended`); handle deletion requests.

### Credit management
- Add bonus credits / adjust credits **securely** → writes an
  `admin_grant`/`promo` **ledger** row (never a raw balance edit), with a
  required reason `note` and `updated_by`.
- View a user's transaction history and purchases.

### System settings
- Edit `credit_costs` per generation type (live pricing).
- Feature flags (`features`) to enable/disable sections.
- AI config defaults (model/resolution) where appropriate.
- Notification/content configuration.
All settings persist in `system_settings` and take effect via `GET /config`.

### Notifications
- Compose/trigger admin notifications (new trending, bonuses, account notices)
  through FCM, gated by admin logic. No spam: throttling + user opt-outs
  respected (`notif_*` prefs).

---

## Admin API surface (examples)
```
POST   /admin/auth/login
GET    /admin/stats
GET    /admin/trending            POST /admin/trending
PUT    /admin/trending/:id        DELETE /admin/trending/:id
GET    /admin/categories          POST/PUT/DELETE ...
GET    /admin/users?q=            GET /admin/users/:id
POST   /admin/users/:id/credits   { amount, type, note }
PATCH  /admin/users/:id/status    { status }
GET    /admin/settings            PUT /admin/settings/:key
POST   /admin/media/presign       (S3 upload for content)
POST   /admin/notifications       (compose/send)
```
All admin routes require an admin JWT + role guard; all mutations are audited.

---

## Implementation note (MVP)
Served in-process by the backend (same NestJS app, `/admin` module) with a
lightweight admin SPA or server-rendered views — one deploy, one auth stack to
secure, cost-conscious. Clean seam to split into a standalone `/admin` SPA later
against the same `/admin` API. See [`ARCHITECTURE.md`](ARCHITECTURE.md) §J.
