# StyloAI — AI Integration & Identity Preservation

This document covers the AI service layer and the **#1 product requirement:
preserving the user's identity** while changing only the requested element. The
Gemini API is reached **only** from the backend; the API key never touches the
Flutter app.

---

## 1. Provider abstraction (future-proofing)

All AI access goes through a single interface so a second model/provider can be
added later without rewriting the app or the orchestration layer:

```ts
interface ImageGenerationProvider {
  readonly name: string;               // "gemini"
  edit(input: EditRequest): Promise<EditResult>;
}

interface EditRequest {
  type: GenerationType;                // outfit | hair | glasses | accessories | pose | ai_edit
  userPhoto: ImageRef;                 // the person — identity anchor
  reference?: ImageRef;                // outfit/hair/glasses reference (upload mode)
  preset?: PresetSpec;                 // explore mode (style descriptor)
  resolution: 'standard' | 'high';
}

interface EditResult { images: GeneratedImage[]; safety: SafetyReport; raw: unknown; }
```

`GeminiProvider implements ImageGenerationProvider`. Orchestration (credits,
storage, retries) is provider-agnostic; only prompt construction and the API
call are provider-specific.

---

## 2. Identity preservation — the core engineering

Generative models cannot mathematically guarantee an identical face, so we
**never claim "100% identical."** Instead we maximize *practical* identity
consistency through layered techniques:

### 2.1 Image-conditioned editing, not text-to-image
We always pass the **user's actual photo as the primary conditioning image** and
instruct an **edit/inpaint-style transformation**, not a fresh generation. The
user photo is the identity anchor; only the targeted region changes.

### 2.2 A strong, explicit identity-preservation instruction
Every request prepends a centralized system instruction (one tested module,
`identityPreservationPreamble`) that pins the invariants:

> Preserve the person's exact facial identity and likeness. Keep unchanged:
> face structure and proportions, eyes, nose, lips, eyebrows, jawline, cheekbones,
> skin tone and skin characteristics, facial hair (unless the request targets it),
> head shape, age, gender presentation, and overall recognizable appearance.
> Do not beautify, slim, reshape, or alter the face. Maintain the same person so
> they remain clearly recognizable. Change **only** {TARGET}. Match lighting,
> perspective, and body proportions of the original photo.

`{TARGET}` is filled per type:

| type | TARGET (only this may change) | Explicitly hold constant |
|------|-------------------------------|--------------------------|
| outfit | clothing / garments on the body | face, hair, skin, pose, background as feasible |
| hair | hairstyle / hair only | **all facial features**, skin, outfit |
| glasses | eyewear only | face shape, eyes behind lenses, hairstyle |
| accessories | requested accessory only (watch, chain, cap…) | face, hair, outfit unless it's the accessory |
| pose | body pose / framing | **facial identity**, outfit, hair |
| ai_edit | overall photographic style/mood | recognizable identity, facial features |

### 2.3 Reference-image analysis (upload mode)
When the user uploads a reference (outfit/hair/glasses), we pass **both** images
and instruct the model to transfer the reference's characteristics onto the
user while preserving identity. For outfits we call out the attributes to carry:
garment type, color, pattern, shape, style, layering, general material look —
applied naturally to the user's body. The reference is the *style* source; the
user photo is the *identity* source.

### 2.4 Region-targeted change
Instructions scope the edit to a region (e.g. "modify only the hair region above
and around the head; leave the face untouched"). Where the provider supports
masks/inpainting, we supply a region hint to further constrain drift.

### 2.5 Never overwrite the original
The user's original upload is stored immutably in S3 and **never altered**.
Every generation is a new `generated_images` record; the source photo is
preserved for re-use and for the user's control/deletion.

### 2.6 Post-generation guardrails (roadmap-aware)
- **Safety report** from the provider is stored; unsafe outputs are rejected and
  refunded.
- Optional **identity similarity check** (future): compare a face embedding of
  the output vs the input and flag low-similarity results for auto-retry or
  refund. Designed for via `SafetyReport`/metadata; not required for MVP but the
  seam exists.

---

## 3. Prompt construction (per type)

Prompts are assembled server-side from three parts, in order:
1. `identityPreservationPreamble` (constant invariants above).
2. **Target instruction** — what to change, filled from type + preset/reference.
3. **Style descriptor** — for `explore` mode, a curated descriptor per
   `preset_key` (e.g. `streetwear` → "modern streetwear: oversized silhouette,
   relaxed layering, urban tones"); for `reference_upload`, the reference image
   + "transfer these garment characteristics."

Descriptors live in a versioned server-side catalog (tied to `categories`), so
they can be tuned without an app release. Preset text is **never** authored on
the client.

---

## 4. Generation orchestration (server)

```
POST /generations
  → authenticate (backend JWT)
  → validate inputs (ownership of S3 keys, content-type, dimensions, safety pre-checks)
  → load credit_cost from settings; check balance
  → TXN: insert generation (queued) + generation_hold (pending)
  → enqueue BullMQ job {generation_id}
  → 202 {generation_id}

worker(generation_id):
  → mark processing, started_at
  → build prompt (identity preamble + target + descriptor/reference)
  → provider.edit(...) with timeout + limited retries (idempotent)
  → on success: store output(s) to S3, thumbnails, insert generated_images,
                settle hold (committed), status=succeeded, FCM "ready"
  → on failure: status=failed, error_code, refund hold if eligible,
                status=refunded, FCM "failed"
```

**Robustness:** idempotency keys on submit + hold + refund; bounded retries with
backoff; a single provider timeout budget; duplicate submits return the original
generation. No credits are consumed for provider/internal failures.

---

## 5. Cost control (§27)
- Credit gate before any API call. - Resolution options (`standard` cheaper than
  `high`). - Rate limiting per user/IP. - Duplicate-request prevention via
  idempotency. - Temporary/reference images get S3 lifecycle expiry. - Admin
  dashboards surface generation volume & success/failure to watch AI spend.

---

## 6. Security recap
- `GEMINI_API_KEY` is a **backend secret** (env / secrets manager), never in the
  app or repo. - The app can only *request* a generation through the
  authenticated, rate-limited API; it can never reach Gemini directly. - All
  prompt logic (including identity preservation) is server-side and versioned.
