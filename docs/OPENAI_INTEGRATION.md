# StyloAI — OpenAI Image Integration (active provider)

OpenAI is the **active** image-generation provider. Gemini remains in the tree
as an inactive alternative implementation of the same interface, so a provider
swap is a one-line change in `ai.module.ts` and nothing else.

The OpenAI API is reached **only** from the backend worker. The API key never
touches the Flutter app, is never logged, and is never returned to the client.

---

## 1. Provider abstraction

All AI access goes through `ImageGenerationProvider` (`src/ai/types.ts`), so the
worker, the credit orchestration, the `/v1/gen-health` probe, and the mobile app
are all provider-agnostic:

```ts
interface ImageGenerationProvider {
  readonly name: string;          // "openai"
  readonly isConfigured?: boolean; // has OPENAI_API_KEY (non-secret boolean)
  readonly model?: string;        // e.g. "gpt-image-1" (non-secret)
  edit(input: EditRequest): Promise<EditResult>;
}
```

`OpenAiProvider` (`src/ai/openai.provider.ts`) is bound to the `IMAGE_PROVIDER`
token in `src/ai/ai.module.ts`.

## 2. How a generation runs

1. The worker (`GenerationsProcessor`) fetches the user photo (identity anchor)
   and any style reference from S3.
2. `buildPrompt()` (`src/ai/identity-preservation.ts`) builds the identity-
   preserving instruction — unchanged by the provider switch.
3. `OpenAiProvider.edit()` calls `POST /v1/images/edits` with `model=gpt-image-1`,
   the user photo as the base input image (`image[]`), the optional reference as a
   second `image[]`, the prompt, `n=1`, and a size derived from the resolution.
   The user's own photo is the base of the edit — the identity-preservation
   requirement.
4. The returned `data[0].b64_json` is decoded to PNG bytes, stored in S3, and the
   credit hold is settled.

## 3. Error handling → terminal state + refund

Every failure is a typed `ProviderError` with a **non-secret** code; the worker
moves the generation to a terminal state and refunds eligible failures. OpenAI
HTTP errors are mapped as:

| OpenAI response | code | retried? | refund |
| --- | --- | --- | --- |
| 401 / 403 (bad/blocked key) | `not_configured` | no | yes |
| 429 (rate limit / quota / billing) | `quota_exceeded` | no | yes |
| 400 with moderation/safety/content-policy | `safety_blocked` | no | yes |
| other 4xx (bad request) | `provider_error` | no* | yes |
| 5xx | `provider_error` | yes (once) | yes on final |
| network timeout | `provider_timeout` | yes (once) | yes on final |
| empty result | `no_image_returned` | yes (once) | yes on final |

\* BullMQ `attempts: 2`; `quota_exceeded` / `safety_blocked` / `not_configured`
skip the retry (they will not fix themselves).

The mobile app only ever receives the non-secret `error_code`; the API key,
request/response bodies, and provider internals are never exposed.

## 4. Configuration (server-side only)

| Env var | Purpose | Default |
| --- | --- | --- |
| `OPENAI_API_KEY` | **Required** to enable generation. Server secret. | — |
| `OPENAI_IMAGE_MODEL` | Image model id | `gpt-image-1` |
| `OPENAI_TIMEOUT_MS` | Per-request timeout | `120000` |
| `OPENAI_BASE_URL` | API base (override for a proxy) | `https://api.openai.com/v1` |

The deploy publishes `OPENAI_API_KEY` / `OPENAI_IMAGE_MODEL` from GitHub Actions
secrets into SSM Parameter Store (SecureString) and writes them to the on-instance
`.env` (chmod 600). When `OPENAI_API_KEY` is not set, `/v1/gen-health` reports
`provider_configured:false` and the deploy gate emits a **warning** (it does not
block unrelated deploys); generation stays disabled until the key is added.

## 5. Verifying the real path (no paid call per deploy)

`/v1/gen-health` is a free readiness probe — it never calls the paid image API.
To actually verify end-to-end generation, run the **manual** `gen_selftest`
GitHub Actions workflow (`workflow_dispatch`), which runs
`backend/scripts/gen-selftest.mjs` on the instance against an isolated test user
and prints a non-secret JSON summary. This is the only path that makes a real
(paid) OpenAI image call, and it only runs when triggered by hand.
