# StyloAI Backend

NestJS (TypeScript) API + admin + generation workers. Authoritative for auth,
credits, purchases, and all Gemini access. See the design docs in
[`../docs`](../docs) — start with [`ARCHITECTURE.md`](../docs/ARCHITECTURE.md),
[`API_CONTRACTS.md`](../docs/API_CONTRACTS.md), and
[`DATABASE_SCHEMA.md`](../docs/DATABASE_SCHEMA.md).

## Status
Scaffolding. Implementation begins in **Phase 1** (see
[`../docs/ROADMAP.md`](../docs/ROADMAP.md)).

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
