import { ConfigService } from '@nestjs/config';
import { OpenAiProvider } from './openai.provider';
import { ProviderError } from './types';

/**
 * Locks the OpenAI provider contract that orchestration relies on: it reports
 * configuration truthfully (no secret leak), uses a current image model, and
 * fails as a typed ProviderError so the worker can move to a terminal state and
 * refund. HTTP-error classification (auth/quota/safety/other) is verified via
 * the exposed mapper without any network call.
 */
function makeConfig(values: Record<string, string | undefined>): ConfigService {
  return { get: (k: string) => values[k] } as unknown as ConfigService;
}

describe('OpenAiProvider', () => {
  it('is not configured without an API key, and reports the model + name', () => {
    const p = new OpenAiProvider(makeConfig({}));
    expect(p.name).toBe('openai');
    expect(p.isConfigured).toBe(false);
    expect(p.model).toBe('gpt-image-1');
  });

  it('honours OPENAI_IMAGE_MODEL override and marks configured when a key is set', () => {
    const p = new OpenAiProvider(
      makeConfig({ OPENAI_API_KEY: 'sk-test', OPENAI_IMAGE_MODEL: 'gpt-image-1-mini' }),
    );
    expect(p.isConfigured).toBe(true);
    expect(p.model).toBe('gpt-image-1-mini');
  });

  it('throws not_configured (refund-eligible) when edit() is called without a key', async () => {
    const p = new OpenAiProvider(makeConfig({}));
    await expect(
      p.edit({
        type: 'ai_edit' as never,
        userPhoto: { bytes: Buffer.from('x'), contentType: 'image/png' },
        prompt: 'test',
        resolution: 'standard',
      }),
    ).rejects.toMatchObject({ code: 'not_configured', refundEligible: true });
  });

  describe('HTTP error classification', () => {
    const p = new OpenAiProvider(makeConfig({ OPENAI_API_KEY: 'sk-test' }));
    const map = (status: number, body = '') =>
      (p as unknown as { mapHttpError(s: number, b: string): ProviderError }).mapHttpError(
        status,
        body,
      );

    it('maps 401/403 to not_configured (auth)', () => {
      expect(map(401).code).toBe('not_configured');
      expect(map(403).code).toBe('not_configured');
    });
    it('maps 429 to quota_exceeded', () => {
      expect(map(429, 'You exceeded your current quota').code).toBe('quota_exceeded');
    });
    it('maps a 400 moderation/safety refusal to safety_blocked', () => {
      expect(
        map(400, '{"error":{"message":"request was rejected by our safety system"}}').code,
      ).toBe('safety_blocked');
      expect(map(400, '{"error":{"code":"moderation_blocked"}}').code).toBe('safety_blocked');
    });
    it('maps other 4xx/5xx to provider_error', () => {
      expect(map(400, '{"error":{"message":"invalid size"}}').code).toBe('provider_error');
      expect(map(500).code).toBe('provider_error');
    });
  });
});
