# StyloAI — Your AI Personal Stylist

StyloAI is an AI-powered personal styling application. Users upload their own
photo and then explore, preview, and save different **outfits, hairstyles,
glasses, accessories, poses, and AI photo styles** — while their **facial
identity is preserved as accurately as the technology allows**.

This is not a generic AI image generator. It is a personal stylist + virtual
try-on + fashion discovery product, engineered as a real connected system with
a secure backend, a credit economy, and an admin-managed content layer.

> **Identity preservation is the #1 product requirement.** Every generation
> instructs the model to keep the user's face, structure, proportions, and
> recognizable appearance intact and change only the requested element. We
> never advertise "100% identical face" — we engineer for maximum *practical*
> identity consistency. See [`docs/GEMINI_INTEGRATION.md`](docs/GEMINI_INTEGRATION.md).

---

## Repository structure

```
StyloAI/
├── mobile/            # Flutter Android app (consumer)
├── backend/           # API + admin server (Node.js / NestJS, TypeScript)
│   ├── src/           # API modules, services, workers
│   ├── prisma/        # DB schema & migrations
│   └── admin/         # Server-rendered admin panel (or served SPA)
├── admin/             # (reserved) standalone admin SPA if split out later
├── docs/              # Architecture, schema, API, security, ops
└── .github/workflows/ # CI: analyze, test, build APK/AAB
```

The MVP ships the admin panel **inside the backend service** (same deploy) to
stay cost-conscious for a solo developer. It can be split into `/admin` later
without touching the mobile app or API contracts.

## Documentation map

| Doc | What it covers |
|-----|----------------|
| [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) | System overview, tech stack, decisions, data flow |
| [`docs/DATABASE_SCHEMA.md`](docs/DATABASE_SCHEMA.md) | PostgreSQL relational schema |
| [`docs/API_CONTRACTS.md`](docs/API_CONTRACTS.md) | REST endpoints, request/response shapes |
| [`docs/CREDITS_AND_BILLING.md`](docs/CREDITS_AND_BILLING.md) | Credit economy + Google Play Billing verification |
| [`docs/GEMINI_INTEGRATION.md`](docs/GEMINI_INTEGRATION.md) | AI service layer, identity-preservation prompt engineering |
| [`docs/AWS_INFRASTRUCTURE.md`](docs/AWS_INFRASTRUCTURE.md) | AWS services, S3, deployment topology |
| [`docs/SECURITY.md`](docs/SECURITY.md) | Threat model, secrets, auth, rate limiting, privacy |
| [`docs/FLUTTER_APP.md`](docs/FLUTTER_APP.md) | Screen map, navigation, design system |
| [`docs/ADMIN_PANEL.md`](docs/ADMIN_PANEL.md) | Admin capabilities, auth, content management |
| [`docs/CICD.md`](docs/CICD.md) | GitHub Actions build & signing strategy |
| [`docs/ENVIRONMENT.md`](docs/ENVIRONMENT.md) | Every environment variable / secret |
| [`docs/ROADMAP.md`](docs/ROADMAP.md) | Development phases & milestones |

## Tech stack (summary)

- **Mobile:** Flutter (Android first), Riverpod, go_router, Dio
- **Backend:** Node.js + NestJS (TypeScript), Prisma ORM
- **Database:** PostgreSQL (AWS RDS)
- **Object storage:** AWS S3 (+ CloudFront for delivery)
- **AI:** Google Gemini image generation/editing (server-side only)
- **Auth:** Firebase Authentication (Google Sign-In) + backend session
- **Push:** Firebase Cloud Messaging
- **Payments:** Google Play Billing + server-side purchase verification
- **Infra:** AWS (EC2/ECS, RDS, S3, CloudWatch, IAM, CloudFront)
- **CI/CD:** GitHub Actions

Full rationale in [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).

## Getting started

The MVP is being built in phases (see [`docs/ROADMAP.md`](docs/ROADMAP.md)).
Setup, environment, and deploy instructions live in each component's README as
they land:

- `mobile/README.md` — Flutter setup, running, building
- `backend/README.md` — API setup, migrations, running locally

## Security note

**No secrets are ever committed.** Gemini keys, AWS keys, DB credentials,
Firebase service accounts, and Play verification credentials live in
environment variables / secrets managers only. See
[`docs/SECURITY.md`](docs/SECURITY.md) and [`docs/ENVIRONMENT.md`](docs/ENVIRONMENT.md).
