# StyloAI — Database Schema (PostgreSQL)

Relational schema for the StyloAI backend. **No image bytes are stored in
Postgres** — only S3 object keys, delivery metadata, and relational records.
The credit system is built on an **append-only ledger**: `credit_transactions`
is authoritative, `credit_wallets.balance` is a cached projection updated only
inside the same DB transaction that writes the ledger row.

Conventions: `id` = UUID (`gen_random_uuid()`), `snake_case`, `timestamptz`,
soft-delete via `deleted_at` where user data must be recoverable/auditable.
This is the conceptual schema; the executable source of truth is
`backend/prisma/schema.prisma` (Prisma migrations generate the SQL).

---

## Entity overview

```
users ─1:1─ user_profiles
users ─1:1─ style_profiles
users ─1:1─ credit_wallets ─1:N─ credit_transactions
users ─1:N─ purchases ─1:N─ credit_transactions
users ─1:N─ generations ─1:N─ generation_inputs
                        └─1:N─ generated_images
users ─1:N─ saved_looks ─N:1─ generated_images
users ─1:N─ devices            (FCM tokens)
users ─1:N─ notifications
trending_content ─N:1─ categories
admin_users (separate auth)
system_settings (kv: credit costs, feature flags, AI config)
```

---

## Tables

### users
Identity record, keyed to Firebase.
| column | type | notes |
|--------|------|-------|
| id | uuid PK | |
| firebase_uid | text UNIQUE NOT NULL | from verified Firebase ID token |
| email | citext UNIQUE | |
| display_name | text | |
| avatar_url | text | S3/CDN key or Google photo |
| status | text NOT NULL DEFAULT 'active' | `active` \| `suspended` \| `deleted` |
| created_at / updated_at | timestamptz | |
| deleted_at | timestamptz NULL | account deletion (privacy) |

### user_profiles
Basic profile/preferences (non-style app settings).
| id uuid PK · user_id uuid FK→users UNIQUE · locale text · notif_generation bool · notif_trending bool · notif_marketing bool DEFAULT false · onboarding_completed bool · created_at/updated_at |

### style_profiles
Personal Style Profile (§5). Distinguishes user-provided vs AI-inferred.
| id uuid PK · user_id uuid FK UNIQUE · preferred_styles text[] · favorite_colors text[] · style_interests text[] · hair_preferences text[] · glasses_preferences text[] · occasion_preferences text[] · source text (`user` \| `ai`) DEFAULT 'user' · ai_summary text NULL · created_at/updated_at |

> When AI visual analysis contributes recommendations, they are stored/labeled
> with `source='ai'` and surfaced in the app as "AI suggestion", never mixed
> silently with user-entered preferences.

### credit_wallets
Cached balance (projection of the ledger).
| id uuid PK · user_id uuid FK UNIQUE · balance integer NOT NULL DEFAULT 0 CHECK (balance >= 0) · lifetime_earned integer · lifetime_spent integer · updated_at |

### credit_transactions  *(append-only, authoritative)*
| column | type | notes |
|--------|------|-------|
| id | uuid PK | |
| wallet_id | uuid FK→credit_wallets | |
| user_id | uuid FK→users | denormalized for query speed |
| amount | integer NOT NULL | **signed**: negative = spend/hold, positive = grant/refund |
| balance_after | integer NOT NULL | wallet balance after applying this row |
| type | text NOT NULL | `signup_bonus` \| `admin_grant` \| `purchase` \| `generation_hold` \| `generation_settle` \| `generation_refund` \| `promo` |
| status | text NOT NULL | `pending` (hold) \| `committed` \| `reversed` |
| generation_id | uuid FK→generations NULL | links spend/refund to a job |
| purchase_id | uuid FK→purchases NULL | links grant to a purchase |
| idempotency_key | text UNIQUE NULL | prevents double-apply |
| note | text NULL | admin note / reason |
| created_at | timestamptz | |

> **Refund model:** a failed generation's `generation_hold` is `reversed` (or a
> compensating `generation_refund` row is inserted). Balances are never mutated
> outside a transaction that appends a ledger row.

### purchases
Google Play purchases (credit packs / future subscriptions).
| id uuid PK · user_id uuid FK · product_id text · purchase_token text UNIQUE · order_id text · platform text DEFAULT 'google_play' · credits_granted integer · amount_micros bigint NULL · currency text NULL · state text (`pending`\|`verified`\|`granted`\|`refunded`\|`invalid`) · verified_at timestamptz NULL · raw_verification jsonb · created_at/updated_at |

> `purchase_token` is UNIQUE → a token can be verified/granted **once**. Backend
> verifies against Play Developer API before setting `granted` and writing the
> `purchase` credit_transaction.

### generations
One AI generation request/job.
| column | type | notes |
|--------|------|-------|
| id | uuid PK | |
| user_id | uuid FK→users | |
| type | text NOT NULL | `outfit` \| `hair` \| `glasses` \| `accessories` \| `pose` \| `ai_edit` |
| mode | text | `explore` \| `reference_upload` |
| preset_key | text NULL | e.g. `streetwear`, `aviator` (from categories/trending) |
| status | text NOT NULL | `queued` \| `processing` \| `succeeded` \| `failed` \| `refunded` |
| credit_cost | integer NOT NULL | snapshot of cost at request time |
| provider | text | `gemini` |
| provider_job_ref | text NULL | provider-side id if any |
| idempotency_key | text UNIQUE | client-supplied per submit |
| error_code | text NULL | typed failure reason |
| params | jsonb | resolved options (style, color hints, etc.) |
| created_at / started_at / finished_at | timestamptz | |

### generation_inputs
Input images for a generation (user photo + optional reference).
| id uuid PK · generation_id uuid FK · role text (`user_photo`\|`outfit_ref`\|`hair_ref`\|`glasses_ref`\|`accessory_ref`\|`pose_ref`) · s3_key text · width int · height int · content_type text · created_at |

### generated_images
Output images.
| id uuid PK · generation_id uuid FK · user_id uuid FK · s3_key text · thumbnail_s3_key text NULL · width int · height int · content_type text · is_primary bool · created_at · deleted_at NULL |

### saved_looks
User-saved outputs ("My Looks").
| id uuid PK · user_id uuid FK · generated_image_id uuid FK · title text NULL · collection text NULL · created_at · deleted_at NULL · UNIQUE(user_id, generated_image_id) |

### categories
Taxonomy for content/presets across sections.
| id uuid PK · section text (`outfit`\|`hair`\|`glasses`\|`accessories`\|`pose`\|`ai_edit`) · key text · label text · sort_order int · is_active bool · created_at/updated_at · UNIQUE(section, key) |

### trending_content
Admin-managed discovery content (§6), fully DB-driven.
| column | type | notes |
|--------|------|-------|
| id | uuid PK | |
| section | text | `outfit`\|`hair`\|`glasses`\|`accessories`\|`pose`\|`ai_edit`\|`inspiration` |
| category_id | uuid FK→categories NULL | |
| title | text | |
| subtitle | text NULL | |
| image_s3_key | text | admin-uploaded media |
| preset_key | text NULL | links to a generation preset |
| position | int | ordering |
| is_active | bool | show/hide without app release |
| starts_at / ends_at | timestamptz NULL | scheduling |
| created_by | uuid FK→admin_users | |
| created_at / updated_at | timestamptz | |

### devices
FCM registration.
| id uuid PK · user_id uuid FK · fcm_token text UNIQUE · platform text DEFAULT 'android' · last_seen_at timestamptz · created_at |

### notifications
Sent/queued notifications record.
| id uuid PK · user_id uuid FK · type text · title text · body text · data jsonb · read_at timestamptz NULL · created_at |

### admin_users  *(separate from consumer users)*
| id uuid PK · email citext UNIQUE · password_hash text · role text (`super_admin`\|`admin`\|`content_editor`) · is_active bool · last_login_at · created_at/updated_at |

### system_settings  *(key/value config)*
| id uuid PK · key text UNIQUE · value jsonb · description text · updated_by uuid FK→admin_users NULL · updated_at |

Seeded keys include:
- `credit_costs` → `{ "outfit": 4, "hair": 4, "glasses": 2, "accessories": 2, "pose": 1, "ai_edit": 3 }` *(example values, admin-editable)*
- `signup_bonus_credits` → e.g. `20`
- `features` → `{ "hair": true, "ai_edit": true, ... }` (feature flags)
- `ai_config` → provider/model/resolution defaults
- `rate_limits` → per-endpoint limits

---

## Indexes (essential)
- `credit_transactions (user_id, created_at desc)`, `(idempotency_key)`,
  `(generation_id)`
- `generations (user_id, created_at desc)`, `(status)`, `(idempotency_key)`
- `generated_images (user_id, created_at desc)`
- `trending_content (section, is_active, position)`
- `purchases (purchase_token)`, `(user_id, created_at desc)`
- `users (firebase_uid)`, `(email)`

## Integrity rules
- Wallet balance is only ever changed inside a transaction that inserts a
  `credit_transactions` row; `balance_after` must equal the new wallet balance.
- `CHECK (balance >= 0)` prevents overspend at the DB layer as a backstop; the
  application refuses spends when `balance < credit_cost` before enqueueing.
- `purchase_token` UNIQUE guarantees a purchase grants credits at most once.
- Generation `idempotency_key` UNIQUE makes submit safe to retry.
