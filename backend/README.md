# StyloAI Backend

NestJS (TypeScript) API + admin + generation workers. Authoritative for auth,
credits, purchases, and all Gemini access. See the design docs in
[`../docs`](../docs) — start with [`ARCHITECTURE.md`](../docs/ARCHITECTURE.md),
[`API_CONTRACTS.md`](../docs/API_CONTRACTS.md), and
[`DATABASE_SCHEMA.md`](../docs/DATABASE_SCHEMA.md).

## Status
**Phase 1 (backend core) implemented** — see [`../docs/ROADMAP.md`](../docs/ROADMAP.md).
Working now: config/env validation + health check; Prisma schema + initial
migration + seed; Firebase-verified Google auth issuing backend JWTs; the
credit ledger (hold/settle/refund, idempotent, unit-tested); S3 upload presign;
`GET /config`; wallet endpoints; and a separate admin auth stack with stats,
settings, and secure credit grants. Generation orchestration (Gemini) is
**Phase 2**.

Verified green in CI: `npm run lint`, `npm run typecheck`, `npm test`
(credit-ledger invariants), `npm run build`.

**Phase 2 (generation pipeline) implemented** — the core feature works
end-to-end: a provider-abstracted Gemini integration, the central
identity-preservation prompt module, an async BullMQ worker, and
`POST /generations` → hold credits → Gemini → store to S3 → settle, with
automatic refund + typed `error_code` on eligible failures and bounded retries.
Requires Redis (BullMQ). Identity-preservation invariants are unit-tested.

### Implemented endpoints (v1)
```
GET  /v1/health
GET  /v1/config
POST /v1/auth/google      POST /v1/auth/refresh   POST /v1/auth/logout
DELETE /v1/account
GET  /v1/me               PATCH /v1/me
GET  /v1/wallet           GET /v1/wallet/transactions
POST /v1/uploads/presign
POST /v1/generations      GET /v1/generations[/:id]   DELETE /v1/generations/:id
POST /v1/admin/auth/login
GET  /v1/admin/stats      GET/PUT /v1/admin/settings[/:key]
POST /v1/admin/users/:id/credits
```

### Running locally (Phase 2 needs Redis)
```bash
docker run -p 5432:5432 -e POSTGRES_PASSWORD=stylo -e POSTGRES_USER=stylo -e POSTGRES_DB=stylo postgres:16
docker run -p 6379:6379 redis:7
cp .env.example .env   # set DATABASE_URL, REDIS_URL, GEMINI_API_KEY, S3/AWS
npx prisma migrate deploy && npm run seed && npm run start:dev
```

## Planned stack
- NestJS · Prisma · PostgreSQL · Redis + BullMQ · AWS S3/CloudFront
- Firebase Admin SDK (auth verify + FCM) · Google Play Developer API · Gemini

## Local setup (once scaffolded)
```bash
cp .env.example .env        # fill values (never commit .env)
npm ci
npx prisma migrate dev      # apply migrations to local Postgres
npm run seed                # seed system_settings + categories
npm run start:dev
```

## Migrations
- Author: `npx prisma migrate dev --name <change>`
- Deploy (CI/prod): `npx prisma migrate deploy`
- Schema source of truth: `prisma/schema.prisma` (mirrors `docs/DATABASE_SCHEMA.md`)

## Environment
All variables documented in [`../docs/ENVIRONMENT.md`](../docs/ENVIRONMENT.md).
Secrets come from AWS SSM in production, `.env` locally. **Never commit secrets.**
