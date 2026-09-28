import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import {
  EditRequest,
  EditResult,
  ImageData,
  ImageGenerationProvider,
  ProviderError,
} from './types';

/**
 * OpenAI image-editing provider (the ACTIVE image generation provider).
 *
 * Reached ONLY from the backend worker — the API key (OPENAI_API_KEY) is a
 * server secret and never leaves the server (never shipped to, or called from,
 * the mobile app). It edits the user's own photo (the identity anchor) with an
 * optional style reference and the identity-preserving instruction, and returns
 * the generated image bytes.
 *
 * Uses the Images Edits endpoint (`POST /v1/images/edits`) with a current image
 * model (gpt-image-1 by default) so the person's face is the base of the edit —
 * exactly what identity preservation requires. Every failure is surfaced as a
 * typed ProviderError with a NON-SECRET code so orchestration can move the
 * generation to a terminal state and refund eligible failures. The API key,
 * request/response bodies, and any provider internals are never returned to the
 * client. See docs/OPENAI_INTEGRATION.md.
 */
@Injectable()
export class OpenAiProvider implements ImageGenerationProvider {
  readonly name = 'openai';
  private readonly logger = new Logger(OpenAiProvider.name);
  private readonly apiKey?: string;
  readonly model: string;
  private readonly timeoutMs: number;
  private readonly baseUrl: string;

  constructor(private readonly config: ConfigService) {
    this.apiKey = this.config.get<string>('OPENAI_API_KEY');
    // Current GA image model. Overridable via OPENAI_IMAGE_MODEL without a code
    // change. gpt-image-1 supports /v1/images/edits with input image(s), which
    // is what identity preservation (editing the user's own photo) requires.
    this.model = this.config.get<string>('OPENAI_IMAGE_MODEL') || 'gpt-image-1';
    this.timeoutMs = Number(this.config.get<string>('OPENAI_TIMEOUT_MS') ?? '120000');
    this.baseUrl = (
      this.config.get<string>('OPENAI_BASE_URL') || 'https://api.openai.com/v1'
    ).replace(/\/+$/, '');
  }

  get isConfigured(): boolean {
    return !!this.apiKey;
  }

  async edit(input: EditRequest): Promise<EditResult> {
    if (!this.apiKey) {
      throw new ProviderError('OpenAI is not configured.', 'not_configured', true);
    }

    const form = new FormData();
    form.append('model', this.model);
    form.append('prompt', input.prompt);
    form.append('n', '1');
    form.append('size', this.sizeFor(input.resolution));
    // The user's own photo is the identity anchor / base of the edit. When a
    // style reference is provided (upload mode), it is passed as an additional
    // input image; the prompt already tells the model the first image is the
    // identity source and the second is the style source only.
    form.append('image[]', this.blob(input.userPhoto), this.filename(input.userPhoto, 'user'));
    if (input.reference) {
      form.append(
        'image[]',
        this.blob(input.reference),
        this.filename(input.reference, 'reference'),
      );
    }

    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), this.timeoutMs);
    let res: Response;
    try {
      res = await fetch(`${this.baseUrl}/images/edits`, {
        method: 'POST',
        headers: { Authorization: `Bearer ${this.apiKey}` },
        body: form,
        signal: controller.signal,
      });
    } catch (err) {
      const aborted = err instanceof Error && err.name === 'AbortError';
      throw new ProviderError(
        aborted ? 'OpenAI request timed out.' : 'OpenAI request failed.',
        aborted ? 'provider_timeout' : 'provider_error',
        true,
      );
    } finally {
      clearTimeout(timeout);
    }

    if (!res.ok) {
      const text = await res.text().catch(() => '');
      // Log the status + a short, non-secret snippet (never the key, which is
      // only sent in the Authorization header and never echoed).
      this.logger.warn(`OpenAI ${res.status}: ${text.slice(0, 300)}`);
      throw this.mapHttpError(res.status, text);
    }

    const json = (await res.json()) as OpenAiImageResponse;
    return this.parseResult(json);
  }

  /**
   * Maps an OpenAI HTTP error to a typed, non-secret ProviderError code:
   * 401/403 → not_configured (bad/blocked key; not retryable),
   * 429 → quota_exceeded (rate limit or exhausted quota/billing; not retried),
   * 400 with a moderation/safety/content-policy signal → safety_blocked,
   * other 4xx → provider_error (not retryable), 5xx → provider_error (retryable).
   */
  private mapHttpError(status: number, body: string): ProviderError {
    const lower = body.toLowerCase();
    if (status === 401 || status === 403) {
      return new ProviderError(
        'OpenAI rejected the API key (auth). Check OPENAI_API_KEY.',
        'not_configured',
        true,
      );
    }
    if (status === 429) {
      return new ProviderError(
        'OpenAI quota / rate limit exceeded — check plan and billing on the OPENAI_API_KEY.',
        'quota_exceeded',
        true,
      );
    }
    if (status === 400 && /moderation|safety|content[_ ]?policy|not allowed|rejected/.test(lower)) {
      return new ProviderError('Content was blocked for safety.', 'safety_blocked', true);
    }
    // Non-2xx below 500 is a request problem (won't fix on retry). 5xx may be
    // transient — the processor's retry policy handles the difference.
    return new ProviderError(`OpenAI returned ${status}.`, 'provider_error', true);
  }

  private parseResult(json: OpenAiImageResponse): EditResult {
    const images: ImageData[] = [];
    for (const item of json.data ?? []) {
      if (item.b64_json) {
        images.push({
          bytes: Buffer.from(item.b64_json, 'base64'),
          contentType: 'image/png',
        });
      }
    }
    if (images.length === 0) {
      throw new ProviderError('OpenAI returned no image.', 'no_image_returned', true);
    }
    return { images, safety: { blocked: false, reasons: [] } };
  }

  /** gpt-image-1 supported sizes. Portrait for "high" suits full-body looks. */
  private sizeFor(resolution: 'standard' | 'high'): string {
    return resolution === 'high' ? '1024x1536' : '1024x1024';
  }

  private blob(image: ImageData): Blob {
    // Buffer -> Uint8Array view keeps the exact bytes; Blob carries the mime so
    // OpenAI accepts it as a real png/jpg/webp upload part.
    return new Blob([new Uint8Array(image.bytes)], { type: image.contentType });
  }

  private filename(image: ImageData, base: string): string {
    const ext = image.contentType.includes('png')
      ? 'png'
      : image.contentType.includes('webp')
        ? 'webp'
        : 'jpg';
    return `${base}.${ext}`;
  }
}

// Minimal shape of the OpenAI images response we consume.
interface OpenAiImageResponse {
  data?: { b64_json?: string; url?: string }[];
}
