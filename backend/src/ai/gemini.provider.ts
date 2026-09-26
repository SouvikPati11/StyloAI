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
 * Gemini image-editing provider. Reached ONLY from the backend — the API key
 * (GEMINI_API_KEY) is a server secret and never leaves the server.
 *
 * Sends the user photo (identity anchor) plus an optional reference image and
 * the identity-preserving instruction to a Gemini image-capable model, and
 * returns the generated image bytes. Failures are surfaced as typed
 * ProviderError so orchestration can refund eligible failures.
 */
@Injectable()
export class GeminiProvider implements ImageGenerationProvider {
  readonly name = 'gemini';
  private readonly logger = new Logger(GeminiProvider.name);
  private readonly apiKey?: string;
  readonly model: string;
  private readonly timeoutMs: number;

  constructor(private readonly config: ConfigService) {
    this.apiKey = this.config.get<string>('GEMINI_API_KEY');
    this.model =
      this.config.get<string>('GEMINI_MODEL') || 'gemini-2.0-flash-preview-image-generation';
    this.timeoutMs = Number(this.config.get<string>('GEMINI_TIMEOUT_MS') ?? '60000');
  }

  get isConfigured(): boolean {
    return !!this.apiKey;
  }

  async edit(input: EditRequest): Promise<EditResult> {
    if (!this.apiKey) {
      throw new ProviderError('Gemini is not configured.', 'not_configured', true);
    }

    const parts: unknown[] = [{ text: input.prompt }];
    parts.push(this.inlineImage(input.userPhoto));
    if (input.reference) parts.push(this.inlineImage(input.reference));

    const body = {
      contents: [{ role: 'user', parts }],
      generationConfig: { responseModalities: ['IMAGE', 'TEXT'] },
    };

    const url =
      `https://generativelanguage.googleapis.com/v1beta/models/${this.model}:generateContent` +
      `?key=${this.apiKey}`;

    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), this.timeoutMs);
    let res: Response;
    try {
      res = await fetch(url, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(body),
        signal: controller.signal,
      });
    } catch (err) {
      const aborted = err instanceof Error && err.name === 'AbortError';
      throw new ProviderError(
        aborted ? 'Gemini request timed out.' : 'Gemini request failed.',
        aborted ? 'provider_timeout' : 'provider_error',
        true,
      );
    } finally {
      clearTimeout(timeout);
    }

    if (!res.ok) {
      const text = await res.text().catch(() => '');
      this.logger.warn(`Gemini ${res.status}: ${text.slice(0, 300)}`);
      throw new ProviderError(`Gemini returned ${res.status}.`, 'provider_error', true);
    }

    const json = (await res.json()) as GeminiResponse;
    return this.parseResult(json);
  }

  private inlineImage(image: ImageData) {
    return {
      inline_data: { mime_type: image.contentType, data: image.bytes.toString('base64') },
    };
  }

  private parseResult(json: GeminiResponse): EditResult {
    const candidate = json.candidates?.[0];
    if (candidate?.finishReason === 'SAFETY' || json.promptFeedback?.blockReason) {
      throw new ProviderError('Content was blocked for safety.', 'safety_blocked', true);
    }
    const images: ImageData[] = [];
    for (const part of candidate?.content?.parts ?? []) {
      const inline = part.inlineData ?? part.inline_data;
      if (inline?.data) {
        images.push({
          bytes: Buffer.from(inline.data, 'base64'),
          contentType: inline.mimeType ?? inline.mime_type ?? 'image/png',
        });
      }
    }
    if (images.length === 0) {
      throw new ProviderError('Gemini returned no image.', 'no_image_returned', true);
    }
    return { images, safety: { blocked: false, reasons: [] } };
  }
}

// Minimal shape of the Gemini generateContent response we consume.
interface GeminiInlineData {
  data?: string;
  mimeType?: string;
  mime_type?: string;
}
interface GeminiPart {
  text?: string;
  inlineData?: GeminiInlineData;
  inline_data?: GeminiInlineData;
}
interface GeminiResponse {
  candidates?: { content?: { parts?: GeminiPart[] }; finishReason?: string }[];
  promptFeedback?: { blockReason?: string };
}
