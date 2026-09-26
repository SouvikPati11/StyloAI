import { GenerationType, GenerationMode } from '@prisma/client';

/**
 * Identity preservation — the #1 product requirement (docs/GEMINI_INTEGRATION.md §2).
 *
 * We never claim a mathematically identical face. Instead we engineer for
 * maximum PRACTICAL identity consistency: the user's own photo is the identity
 * anchor, and every prompt pins the invariants below and scopes the change to
 * exactly one region. This module is the single, tested source of that prompt
 * logic; no prompt text is authored on the client.
 */

const IDENTITY_PREAMBLE = [
  'You are editing a photo of a real person. Preserve their exact facial identity and likeness.',
  'Keep the following UNCHANGED so the person remains clearly recognizable as the same individual:',
  'face structure and proportions, eyes, nose, lips, eyebrows, jawline, cheekbones,',
  'skin tone and skin characteristics, head shape, age, gender presentation,',
  'and overall recognizable appearance.',
  'Do not beautify, slim, reshape, smooth, or otherwise alter the face.',
  'Match the lighting, camera perspective, and body proportions of the original photo.',
].join(' ');

/** What each generation type is ALLOWED to change; everything else is held. */
const TARGET_INSTRUCTION: Record<GenerationType, string> = {
  outfit:
    'Change ONLY the clothing/outfit on the body. Keep the face, hair, skin, pose, and background unchanged. Dress the same person in the described outfit so it fits naturally on their body.',
  hair: 'Change ONLY the hairstyle and hair. Keep ALL facial features, skin, and clothing unchanged. Apply the described hairstyle naturally to the same head and face.',
  glasses:
    'Change ONLY the eyewear. Add or change glasses/sunglasses to match the description. Keep the face shape, the eyes (visible through clear lenses), hairstyle, and everything else unchanged. Fit the glasses to the face perspective and proportions.',
  accessories:
    'Add ONLY the requested accessory (such as a watch, chain, ring, bracelet, cap, hat, or earrings). Keep the face, hair, and existing outfit unchanged. Place the accessory naturally and realistically.',
  pose: 'Change ONLY the body pose and framing. Preserve the exact facial identity, the outfit, and the hairstyle. Keep the same person and the same clothing in the new pose.',
  ai_edit:
    "Restyle the overall photographic look and mood as described, while keeping the person's recognizable identity and facial features intact. Do not change who the person is.",
};

/**
 * Per-preset style descriptors for explore mode (server-side catalog), keyed by
 * "<section>:<preset>" because the same preset key (e.g. `luxury`, `trending`)
 * can appear in more than one section with a different meaning.
 */
const PRESET_DESCRIPTORS: Record<string, string> = {
  // outfit
  'outfit:casual': 'a relaxed everyday casual outfit with comfortable, well-fitted pieces',
  'outfit:formal': 'an elegant formal outfit such as a tailored suit or formal dress',
  'outfit:smart_casual': 'a smart-casual outfit balancing polished and relaxed pieces',
  'outfit:streetwear':
    'a modern streetwear look: oversized silhouette, relaxed layering, urban tones',
  'outfit:party': 'a stylish party outfit with a bold, going-out aesthetic',
  'outfit:luxury': 'a luxury high-fashion outfit with premium fabrics and refined tailoring',
  'outfit:traditional': 'an elegant traditional/cultural outfit',
  'outfit:minimal': 'a minimal outfit with clean lines and a restrained neutral palette',
  'outfit:summer': 'a light summer outfit with breathable fabrics and bright, airy tones',
  'outfit:winter': 'a warm winter outfit with layered coats and cozy textures',
  'outfit:trending': 'a currently trending, on-the-moment outfit',
  // hair
  'hair:short': 'a clean short hairstyle',
  'hair:long': 'a well-styled long hairstyle',
  'hair:fade': 'a modern fade haircut with sharp, gradual tapering',
  'hair:curly': 'a natural curly hairstyle with defined curls',
  'hair:wavy': 'a relaxed wavy hairstyle',
  'hair:textured': 'a textured, tousled modern hairstyle',
  'hair:formal': 'a neat, formal hairstyle',
  'hair:modern': 'a modern, on-trend hairstyle',
  'hair:trending': 'a currently trending hairstyle',
  // glasses
  'glasses:sunglasses': 'stylish sunglasses suited to the face',
  'glasses:clear': 'clear prescription-style glasses suited to the face',
  'glasses:formal': 'refined formal glasses',
  'glasses:round': 'round-frame glasses',
  'glasses:square': 'square-frame glasses',
  'glasses:aviator': 'classic aviator-style glasses',
  'glasses:minimal': 'minimal thin-frame glasses',
  'glasses:trending': 'currently trending eyewear',
  // pose
  'pose:instagram': 'a natural, confident Instagram-style pose',
  'pose:profile_picture': 'a clean, front-facing profile-picture pose',
  'pose:fashion': 'an editorial fashion pose',
  'pose:street': 'a candid street-style pose',
  'pose:casual': 'a relaxed casual pose',
  'pose:formal': 'a composed formal pose',
  'pose:party': 'an energetic party pose',
  'pose:travel': 'a scenic travel pose',
  'pose:portrait': 'a composed portrait pose',
  // ai_edit
  'ai_edit:cinematic': 'a cinematic color grade with dramatic, filmic lighting',
  'ai_edit:luxury': 'a luxury editorial aesthetic with rich tones and premium finish',
  'ai_edit:studio_portrait': 'a professional studio portrait look with clean lighting',
  'ai_edit:street_photography': 'a candid street-photography aesthetic',
  'ai_edit:editorial_fashion': 'a high-fashion editorial magazine aesthetic',
  'ai_edit:moody_portrait': 'a moody, low-key portrait aesthetic',
  'ai_edit:clean_portrait': 'a clean, bright, natural portrait look',
};

export function describePreset(
  presetKey?: string | null,
  type?: GenerationType,
): string | undefined {
  if (!presetKey) return undefined;
  if (type && PRESET_DESCRIPTORS[`${type}:${presetKey}`]) {
    return PRESET_DESCRIPTORS[`${type}:${presetKey}`];
  }
  // fall back to any section match (keeps older callers working)
  const match = Object.entries(PRESET_DESCRIPTORS).find(([k]) => k.endsWith(`:${presetKey}`));
  return match?.[1];
}

export interface PromptContext {
  type: GenerationType;
  mode: GenerationMode;
  presetKey?: string | null;
  hasReference: boolean;
  /**
   * Explicit style description authored by an admin on the selected Trending
   * Style. When present it takes precedence over the built-in preset catalog,
   * so admin-created content actually drives the generation prompt.
   */
  styleDescriptorOverride?: string | null;
}

/**
 * Builds the full instruction: identity preamble + the type's target
 * instruction + the style source. The style source is, in priority order:
 * (1) the admin-authored description of the selected Trending Style, else
 * (2) a reference-transfer instruction (reference_upload mode), else
 * (3) a built-in preset descriptor for the section+preset.
 */
export function buildPrompt(ctx: PromptContext): { prompt: string; styleDescriptor?: string } {
  const parts: string[] = [IDENTITY_PREAMBLE, TARGET_INSTRUCTION[ctx.type]];
  let styleDescriptor: string | undefined;

  const override = ctx.styleDescriptorOverride?.trim();
  if (override) {
    styleDescriptor = override;
    parts.push(`Apply this style: ${override}.`);
  } else if (ctx.mode === 'reference_upload' && ctx.hasReference) {
    parts.push(
      'A second image is provided as a style reference. Transfer its relevant characteristics ' +
        referenceAttributes(ctx.type) +
        ' onto the person in the first image, applied naturally. The reference is only the style source; the first image is the identity source.',
    );
  } else {
    styleDescriptor = describePreset(ctx.presetKey, ctx.type);
    if (styleDescriptor) {
      parts.push(`Apply this style: ${styleDescriptor}.`);
    }
  }

  return { prompt: parts.join(' '), styleDescriptor };
}

function referenceAttributes(type: GenerationType): string {
  switch (type) {
    case 'outfit':
      return '(garment type, color, pattern, shape, style, layering, and general material appearance)';
    case 'hair':
      return '(hairstyle shape, length, texture, and parting)';
    case 'glasses':
      return '(frame shape, style, and color)';
    case 'accessories':
      return '(the accessory type, shape, and material)';
    default:
      return '';
  }
}

export const __testing = { IDENTITY_PREAMBLE, TARGET_INSTRUCTION, PRESET_DESCRIPTORS };
