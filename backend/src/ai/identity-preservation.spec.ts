import { buildPrompt, describePreset } from './identity-preservation';
import { GenerationType, GenerationMode } from '@prisma/client';

/**
 * The identity-preservation prompt is the #1 product requirement, so its
 * invariants are asserted here: every prompt pins facial identity, scopes the
 * change to the requested element, and never promises an "identical" face.
 */
describe('identity-preservation prompt', () => {
  const IDENTITY_SIGNALS = ['facial identity', 'unchanged', 'recognizable'];

  const types = Object.values(GenerationType);

  it.each(types)('always pins facial identity for type "%s"', (type) => {
    const { prompt } = buildPrompt({
      type,
      mode: GenerationMode.explore,
      presetKey: 'trending',
      hasReference: false,
    });
    const lower = prompt.toLowerCase();
    expect(IDENTITY_SIGNALS.some((s) => lower.includes(s))).toBe(true);
    // Never over-promise a mathematically identical face.
    expect(lower).not.toContain('100%');
    expect(lower).not.toContain('identical face');
  });

  it('scopes an outfit change to clothing only', () => {
    const { prompt } = buildPrompt({
      type: GenerationType.outfit,
      mode: GenerationMode.explore,
      presetKey: 'streetwear',
      hasReference: false,
    });
    expect(prompt.toLowerCase()).toContain('clothing');
    expect(prompt.toLowerCase()).toContain('keep the face');
  });

  it('scopes a hair change while holding facial features', () => {
    const { prompt } = buildPrompt({
      type: GenerationType.hair,
      mode: GenerationMode.explore,
      presetKey: 'fade',
      hasReference: false,
    });
    const lower = prompt.toLowerCase();
    expect(lower).toContain('hairstyle');
    expect(lower).toContain('facial features');
  });

  it('adds a reference-transfer instruction in upload mode', () => {
    const { prompt, styleDescriptor } = buildPrompt({
      type: GenerationType.outfit,
      mode: GenerationMode.reference_upload,
      presetKey: null,
      hasReference: true,
    });
    expect(prompt.toLowerCase()).toContain('reference');
    expect(prompt.toLowerCase()).toContain('identity source');
    // no preset descriptor is applied in reference mode
    expect(styleDescriptor).toBeUndefined();
  });

  it('applies a preset descriptor in explore mode', () => {
    const { prompt, styleDescriptor } = buildPrompt({
      type: GenerationType.outfit,
      mode: GenerationMode.explore,
      presetKey: 'streetwear',
      hasReference: false,
    });
    expect(styleDescriptor).toBe(describePreset('streetwear'));
    expect(prompt).toContain('streetwear');
  });

  it("uses an admin style's description (override) over the preset catalog", () => {
    const override = 'Modern oversized black streetwear outfit';
    const { prompt, styleDescriptor } = buildPrompt({
      type: GenerationType.outfit,
      mode: GenerationMode.explore,
      presetKey: 'streetwear',
      hasReference: false,
      styleDescriptorOverride: override,
    });
    expect(styleDescriptor).toBe(override);
    expect(prompt).toContain(override);
    // The generic catalog descriptor is NOT used when an override is present.
    expect(prompt).not.toContain('urban tones');
  });

  it('override wins even in reference_upload mode (admin content is authoritative)', () => {
    const override = 'Modern low fade hairstyle';
    const { prompt, styleDescriptor } = buildPrompt({
      type: GenerationType.hair,
      mode: GenerationMode.reference_upload,
      presetKey: null,
      hasReference: true,
      styleDescriptorOverride: override,
    });
    expect(styleDescriptor).toBe(override);
    expect(prompt).toContain(override);
    // Still pins identity.
    expect(prompt.toLowerCase()).toContain('facial features');
  });
});
