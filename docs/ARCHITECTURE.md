# StyloAI — System Architecture

This is the master architecture document. It answers items A–N of the project
brief's "Important First Step" and records the key decisions with their
rationale. Detailed specs live in the sibling docs referenced throughout.

---

## A. Final architecture (high level)

```
┌────────────────────────────────────────────────────────────────────┐
│                        Flutter Android App                          │
│  Onboarding · Home · Create (Outfit/Hair/Glasses/Accessories/Pose/  │
│  AI Edit) · Explore/Trending · Profile/History · Credits/Store      │
└───────────────┬──────────────────────────────────┬─────────────────┘
                │ HTTPS (JWT session)               │ Firebase SDKs
                │                                    │ (Auth login, FCM)
                ▼                                    ▼
┌────────────────────────────────────┐     ┌────────────────────────┐
│      Backend API (NestJS/TS)        │     │  Firebase              │
│  api.stylo.app                      │     │  - Auth (Google)       │
│  - Auth (verify Firebase ID token,  │◄────┤  - Cloud Messaging     │
│    issue backend session JWT)       │     └────────────────────────┘
│  - Credit ledger (authoritative)    │
│  - Generation orchestration         │     ┌────────────────────────┐
│  - Play Billing verification        │────►│  Google Gemini API     │
│  - Trending/content service         │     │  (image gen/edit)      │
│  - Admin panel (protected)          │     └────────────────────────┘
└───────┬───────────────┬─────────────┘
        │               │
        ▼               ▼
┌──────────────┐  ┌──────────────────┐   ┌─────────────────────────┐
│ PostgreSQL   │  │ Async job queue  │   │ AWS S3 (private)        │
│ (RDS)        │  │ (BullMQ/Redis)   │   │ originals / refs /      │
│ ledger,      │  │ generation jobs  │   │ generated / admin media │
│ metadata     │  └──────────────────┘   │ + CloudFront (signed)   │
└──────────────┘                         └─────────────────────────┘
```

**Core principle:** the Flutter app is a *presentation and capture* layer only.
Every trust-sensitive decision — credit balance, credit cost, purchase
validity, whether a generation is allowed, what prompt is sent to Gemini —
happens **server-side**. The client is never trusted for money, credits, or AI
access.

**Request lifecycle (generation):** the app uploads images and submits a job;
the backend authenticates, validates, reserves credits, enqueues an async job;
a worker calls Gemini, stores the result in S3, writes metadata, finalizes the
credit transaction, and notifies the app (poll + FCM). Full sequence in §12 of
the brief and in [`GEMINI_INTEGRATION.md`](GEMINI_INTEGRATION.md).

---

## B. Technology stack & rationale

| Layer | Choice | Why |
|-------|--------|-----|
| Mobile | **Flutter** (Android first) | Your chosen stack; single codebase, strong UI control for a premium design system. |
| State mgmt | **Riverpod** | Compile-safe, testable, good for async generation state. |
| Routing | **go_router** | Declarative deep-linkable navigation (needed for FCM taps into a result). |
| Networking | **Dio** | Interceptors for auth token refresh, retries, multipart upload. |
| Backend | **NestJS (Node + TypeScript)** | Structured, modular (DI, guards, interceptors) — fits the "modular AI provider" and "protected admin" needs; one language across API + admin; fast for a solo dev. |
| ORM | **Prisma** | Type-safe schema + first-class migrations (satisfies "migration instructions"). |
| DB | **PostgreSQL (RDS)** | Your chosen stack; relational integrity for the credit ledger. |
| Cache/queue | **Redis + BullMQ** | Async generation jobs, idempotency locks, rate limiting. |
| Object storage | **AWS S3** + **CloudFront** | Your chosen stack; private buckets, signed delivery URLs, lifecycle rules. |
| AI | **Google Gemini** image gen/edit | Your chosen stack; wrapped behind a provider interface for future models. |
| Auth | **Firebase Auth** (Google) | Your chosen stack; backend verifies ID tokens, mints its own session JWT. |
| Push | **Firebase Cloud Messaging** | Your chosen stack. |
| Payments | **Google Play Billing** + server verification | Your chosen stack; Play Developer API verifies purchase tokens. |
| Admin panel | **Server-rendered (NestJS + a light SPA)** | Same deploy as API for MVP cost; DB-backed, real CRUD. |
| CI/CD | **GitHub Actions** | Your chosen stack; cloud builds, no local machine. |

> **Additions I recommend (not replacements):** Redis (job queue + rate limits
> + idempotency) and CloudFront (secure, cheap image delivery). Both are small,
> justified, and cost-conscious. Nothing in your preferred stack is being
> swapped out.

Alternative considered: a Python/FastAPI backend. Rejected for the MVP so the
whole server + admin is **one TypeScript codebase** a solo developer can hold in
their head; the Gemini provider layer is thin and portable if that ever changes.

---

## C. Project / repository structure

Monorepo — one source of truth, one place for CI. See root `README.md`.
`mobile/` (Flutter), `backend/` (API + admin + Prisma), `docs/`, `.github/`.

---

## D. Database schema

Full schema in [`DATABASE_SCHEMA.md`](DATABASE_SCHEMA.md). Highlights:

- **Credit integrity via an append-only ledger.** `credit_transactions` is the
  source of truth; `credit_wallets.balance` is a cached projection updated only
  inside the same DB transaction that inserts a ledger row. No image bytes ever
  live in Postgres — only S3 keys/URLs and metadata.
- **Generations are first-class**, with inputs, outputs, status, credit
  linkage, and idempotency keys for safe retries.

---

## E. API architecture

REST over HTTPS, JSON, versioned under `/v1`. Auth via `Authorization: Bearer
<backend-jwt>`. Full contracts in [`API_CONTRACTS.md`](API_CONTRACTS.md).
Principles: idempotent generation submission, async job + poll + push,
consistent error envelope with typed error codes the app maps to UI states.

---

## F. Credit / payment architecture

Server-authoritative credit ledger + Google Play purchase verification.
Full spec in [`CREDITS_AND_BILLING.md`](CREDITS_AND_BILLING.md). Costs are
configured in `system_settings` (DB), never hard-coded in Flutter. Failed
generations refund via a ledger reversal, not by mutating a balance.

---

## G. Gemini integration architecture

Backend-only gateway with a provider interface (`ImageGenerationProvider`) so a
second model can be added without touching Flutter. Identity-preservation prompt
engineering is centralized here. Full spec in
[`GEMINI_INTEGRATION.md`](GEMINI_INTEGRATION.md).

---

## H. AWS architecture

MVP: single small EC2 (or ECS Fargate) for API+admin, RDS PostgreSQL
(single-AZ to start), S3 private buckets, CloudFront, CloudWatch, IAM
least-privilege. Full spec in [`AWS_INFRASTRUCTURE.md`](AWS_INFRASTRUCTURE.md).

---

## I. Firebase architecture

- **Auth:** app does Google Sign-In → gets Firebase **ID token** → backend
  verifies it with the Firebase Admin SDK → upserts a `users` row keyed by
  `firebase_uid` → issues a **backend session JWT** used for all API calls.
- **FCM:** device registers a token (`/v1/devices`); backend stores it and sends
  generation-complete / trending / bonus notifications via Admin SDK, gated by
  admin logic. The Firebase **service account JSON is a backend secret only.**

---

## J. Admin panel architecture

Protected, DB-backed CRUD served by the backend. Manages trending content,
categories, credit costs, users, credits, and stats. Separate `admin_users`
table + role-based guards; **not** the same login as consumer app. Full spec in
[`ADMIN_PANEL.md`](ADMIN_PANEL.md). Trending content is fully DB-driven so it
updates **without an app release**.

---

## K. Flutter screen map & design system

Full spec in [`FLUTTER_APP.md`](FLUTTER_APP.md). Five bottom-nav destinations:
**Home · Explore · Create · Looks · Profile**, plus modal generation flows and a
Credits store. Coherent design system (tokens, components) — premium,
fashion-forward, restrained.

---

## L. GitHub Actions build strategy

Full spec in [`CICD.md`](CICD.md). Workflows: `analyze_test` (flutter analyze +
tests + backend lint/test on every push/PR) and `android_release` (build
signed AAB + APK on tag/manual, upload artifacts). Signing keystore + passwords
are GitHub secrets, base64-decoded at build time — never committed.

---

## M. Security strategy

Full spec in [`SECURITY.md`](SECURITY.md). Pillars: secrets never in client or
repo; server-authoritative credits & purchases; verified Firebase identity;
rate-limited AI endpoints; least-privilege IAM; private S3 + signed URLs;
protected admin; privacy-first photo handling with real deletion.

---

## N. Development phases

Full plan in [`ROADMAP.md`](ROADMAP.md). Summary:

0. **Foundations** — repo, docs, schema, CI skeleton, env contracts. *(this PR)*
1. **Backend core** — auth, users, credit ledger, S3, settings, admin auth.
2. **Generation MVP** — Outfit flow end-to-end (Gemini provider, jobs, refunds).
3. **Flutter shell** — design system, nav, onboarding, auth, home, credits UI.
4. **Create suite** — Hair, Glasses, Accessories, Pose, AI Edit + Explore.
5. **Billing** — Play Billing + server verification + store UI.
6. **Admin panel** — content, users, credits, stats dashboards.
7. **Polish & launch** — FCM, privacy/terms, error states, store assets, hardening.

---

## Key architectural decisions (log)

1. **Server-authoritative everything money-related.** The client displays
   balances and costs it *fetched*; it never computes or asserts them.
2. **Append-only credit ledger.** Balances are derived, refunds are reversals —
   auditable and race-safe under DB transactions.
3. **Async generation with idempotency keys.** Protects against duplicate
   charges on retries/network failures; enables progress UX + FCM.
4. **Provider-abstracted AI.** `ImageGenerationProvider` interface isolates
   Gemini; identity-preservation prompt logic is one central, tested module.
5. **Private storage, signed delivery.** Photos are personal data; S3 buckets
   are private, delivered via short-lived signed CloudFront/S3 URLs.
6. **Admin in-process for MVP.** One deploy, one auth stack to secure; can split
   later behind the same API contracts.
7. **DB-driven content & pricing.** Trending content and credit costs change
   from the admin panel with no app release.
