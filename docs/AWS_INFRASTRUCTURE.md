# StyloAI — AWS Infrastructure

Cost-conscious for a solo developer, scalable when needed. Start small; the
architecture leaves clean upgrade paths (no rewrites).

---

## MVP topology

```
                        Route 53 (stylo.app)
                    ┌──────────┴───────────┐
              api.stylo.app          admin.stylo.app
                    │                       │
                    ▼                       ▼
        ┌───────────────────────────────────────────┐
        │  Backend service (NestJS)                  │
        │  MVP: 1× EC2 t3.small  (or ECS Fargate)    │
        │  behind ALB (TLS via ACM)                  │
        │  - API + admin + BullMQ worker(s)          │
        └───────┬──────────────┬───────────┬─────────┘
                │              │           │
                ▼              ▼           ▼
        ┌────────────┐  ┌────────────┐  ┌──────────────┐
        │ RDS        │  │ ElastiCache│  │ S3 (private) │
        │ PostgreSQL │  │ Redis      │  │ 1 bucket,    │
        │ single-AZ  │  │ (t4g.micro)│  │ prefixed     │
        │ t4g.micro  │  └────────────┘  └──────┬───────┘
        └────────────┘                         │
                                               ▼
                                        CloudFront (signed URLs)
        CloudWatch (logs/metrics/alarms) · IAM (least privilege)
```

## Services & rationale

| Service | MVP choice | Purpose | Scale path |
|---------|-----------|---------|------------|
| **Compute** | 1× EC2 `t3.small` (or ECS Fargate 0.5vCPU) | API + admin + worker | ECS service + autoscaling; split worker onto its own task |
| **Load balancer / TLS** | ALB + ACM cert | HTTPS, subdomain routing | add WAF |
| **Database** | RDS PostgreSQL `t4g.micro`, single-AZ | ledger + metadata | Multi-AZ, read replica |
| **Cache/queue** | ElastiCache Redis `t4g.micro` (or in-EC2 Redis to start) | BullMQ jobs, rate limits, idempotency | dedicated cluster |
| **Object storage** | S3, one private bucket, prefixed | images | lifecycle + Intelligent-Tiering |
| **CDN** | CloudFront + signed URLs | fast, secure image delivery | + edge caching |
| **DNS** | Route 53 | `api.` / `admin.` subdomains | — |
| **Secrets** | SSM Parameter Store (SecureString) | env/secrets | Secrets Manager + rotation |
| **Monitoring** | CloudWatch logs/metrics/alarms | ops visibility | + dashboards, X-Ray |
| **Identity** | IAM roles (instance/task role) | no static AWS keys in app | scoped policies |

> **Even cheaper day-1 option:** run Postgres + Redis co-located on the single
> EC2 box (Docker Compose) to defer RDS/ElastiCache cost, and move to managed
> services when traffic justifies it. The code doesn't change — only
> `DATABASE_URL`/`REDIS_URL`. RDS is recommended once real users exist (backups,
> failover, less ops).

## S3 layout
```
stylo-media/            (private, Block Public Access ON)
  originals/{userId}/…        # user uploads (kept while account active)
  references/{userId}/…       # outfit/hair/glasses refs (lifecycle-expire)
  generated/{userId}/…        # AI outputs (kept until user deletes)
  admin/trending/…            # admin-uploaded content media
```
Lifecycle: expire `references/` after N days; optional Intelligent-Tiering on
`generated/`. All access via pre-signed URLs (PUT for upload, GET for delivery).

## Deployment
- **MVP:** Dockerized backend; deploy via a GitHub Actions job that builds the
  image, pushes to ECR, and updates the ECS service (or `ssh` + `docker compose
  up` on EC2). - Migrations run as a release step (`prisma migrate deploy`). -
  Zero secrets in the image — injected from SSM at runtime.
- **Domains/TLS:** ACM cert for `stylo.app`, `api.stylo.app`, `admin.stylo.app`;
  HTTPS enforced.

## Cost posture
Single small compute + micro RDS/Redis + S3/CloudFront keeps monthly infra
low while the AI (Gemini) usage — the real cost driver — is gated behind
credits, rate limits, and admin-visible usage metrics (§27).

## Don't over-engineer (§13/§28)
No Kubernetes, no multi-region, no microservices for the MVP. One service, one
DB, one bucket, clear seams to grow later.
