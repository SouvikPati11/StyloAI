import { GenerationType } from '@prisma/client';

/** A binary image handed to / returned from a provider. */
export interface ImageData {
  bytes: Buffer;
  contentType: string;
}

/** Resolved request the provider executes. Identity anchor = userPhoto. */
export interface EditRequest {
  type: GenerationType;
  /** The person. The identity is preserved from this image. */
  userPhoto: ImageData;
  /** Optional style/appearance reference (upload mode). */
  reference?: ImageData;
  /** Curated style descriptor text (explore mode) or extra hints. */
  styleDescriptor?: string;
  /** The fully-built instruction (identity preamble + target + descriptor). */
  prompt: string;
  resolution: 'standard' | 'high';
}

export interface SafetyReport {
  blocked: boolean;
  reasons: string[];
}

export interface EditResult {
  images: ImageData[];
  safety: SafetyReport;
  /** Raw provider payload for auditing/debugging (no secrets). */
  raw?: unknown;
}

/** Thrown by providers to signal a typed, refund-eligible failure. */
export class ProviderError extends Error {
  constructor(
    message: string,
    public readonly code:
      | 'provider_timeout'
      | 'provider_error'
      | 'safety_blocked'
      | 'no_image_returned'
      | 'not_configured',
    public readonly refundEligible: boolean = true,
  ) {
    super(message);
    this.name = 'ProviderError';
  }
}

/**
 * Provider abstraction. Every AI model is reached through this interface so a
 * second provider can be added without touching orchestration or the app.
 * See docs/GEMINI_INTEGRATION.md §1.
 */
export interface ImageGenerationProvider {
  readonly name: string;
  /** Whether the provider has the credentials it needs (non-secret boolean). */
  readonly isConfigured?: boolean;
  /** The model identifier in use (non-secret). */
  readonly model?: string;
  edit(input: EditRequest): Promise<EditResult>;
}

export const IMAGE_PROVIDER = Symbol('IMAGE_PROVIDER');
