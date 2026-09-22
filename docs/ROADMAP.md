# StyloAI — Development Roadmap

Build a real, connected system in dependency order — backend and data first,
then the app against real contracts. **No fake UI with backend "later."** Each
phase is shippable/testable on its own.

---

## Phase 0 — Foundations  *(this PR)*
- Monorepo scaffold, `.gitignore`, README.
- Full architecture, schema, API, security, AWS, credits, Gemini, Flutter,
  admin, CI/CD, environment docs.
- Roadmap + decisions log.
**Exit:** the whole system is designed and agreed; anyone can start any component.

## Phase 1 — Backend core & data
- NestJS skeleton, config/secrets loading, health check.
- Prisma schema (from `DATABASE_SCHEMA.md`) + first migration + seed
  (`system_settings`: credit costs, signup bonus, features; base categories).
- Firebase ID-token verification → `POST /auth/google` → user upsert + backend
  JWT (access/refresh).
- Credit ledger service (hold/settle/refund) + wallet projection, fully tested.
- S3 presign (`/uploads/presign`) + ownership validation.
- Admin auth + `system_settings` read/write; `GET /config`.
**Exit:** auth, credits, uploads, settings work end-to-end (API + tests).

## Phase 2 — Generation MVP (Outfit, end-to-end)
- `ImageGenerationProvider` interface + `GeminiProvider`.
- Identity-preservation prompt module (central, tested).
- BullMQ worker; `POST /generations` (hold) → worker → S3 store → settle/refund
  → `GET /generations/:id`.
- Idempotency, retries, refund policy, rate limiting.
**Exit:** an authenticated request with a user photo + outfit reference returns a
stored, identity-preserving result and charges credits correctly (refunds on
failure).

## Phase 3 — Flutter shell
- Design system (tokens + core components), theming (light/dark).
- go_router nav, Dio client w/ auth interceptor, error→state mapping.
- Onboarding, Google Sign-In, Home, Credits/ledger view, Profile.
- Outfit Create flow wired to the real Phase-2 API (all states).
**Exit:** installable app: sign in, set photo, run an Outfit generation, see
before/after, see credits move — against the real backend.

## Phase 4 — Full Create suite + Explore
- Hair, Glasses, Accessories, Pose, AI Edit flows (explore + reference modes).
- Per-type prompt targets + preset descriptor catalog.
- Explore/Trending screens reading DB-driven content; Recommendations from
  Style Profile; Looks/History; Style Profile screens.
**Exit:** all six Create sections + discovery live.

## Phase 5 — Billing
- Play Billing in app (`in_app_purchase`) + Store UI (packs from server).
- `POST /billing/google/verify` with Play Developer API verification, one-time
  grant, acknowledge; ledger `purchase` rows.
**Exit:** users buy credits; grants are server-verified and idempotent.

## Phase 6 — Admin panel
- Stats dashboard (real aggregates).
- Content CRUD (trending/categories) + media upload → live in app.
- User management, secure credit adjustments (ledger), settings/feature flags,
  admin notifications.
**Exit:** you can run the product's content, pricing, and users without a
release.

## Phase 7 — Polish, privacy & launch readiness
- FCM (generation done/failed, trending, bonus) gated by admin logic + opt-outs.
- Privacy Policy + Terms; account/data deletion; S3 lifecycle rules.
- Every error/empty/loading state; honest progress UX.
- CloudWatch alarms; load/cost review; Play listing assets; hardening pass;
  `android_release` signed AAB → Play internal track.
**Exit:** a store-ready MVP.

---

## Explicitly deferred (designed-for, not built — §28)
Shopping links, product recommendations, wardrobe/closet, style score, AI
stylist chat, subscriptions, additional AI providers, social sharing. The
ledger, provider abstraction, and content model already leave room for these.

---

## Missing-but-required items surfaced during planning
These aren't in the original stack list but are needed for a real MVP; all are
small and cost-conscious (details in the linked docs):
1. **Redis** — job queue, idempotency, rate limiting. (`AWS_INFRASTRUCTURE.md`)
2. **CloudFront + signed URLs** — secure, cheap private-image delivery.
3. **Play Developer API service account** — server-side purchase verification.
4. **A registered domain + ACM TLS** — `api.` / `admin.` subdomains, HTTPS.
5. **Privacy Policy & Terms** — required by Google Play for a photo app.
6. **An async job model** — generations must be async (worker), not request-
   blocking, for reliability and cost control.
