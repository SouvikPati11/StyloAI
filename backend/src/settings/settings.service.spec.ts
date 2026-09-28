import { SettingsService } from './settings.service';
import { PrismaService } from '../prisma/prisma.service';

/**
 * Locks the admin-controlled settings that were failing in production:
 * per-category credit costs (Issue 5) and the Home slider order (Issue 4).
 * Both are sanitized so a bad stored value can never break pricing or layout.
 */
function serviceWith(settings: Record<string, unknown>): SettingsService {
  const prisma = {
    systemSetting: {
      findUnique: async ({ where: { key } }: { where: { key: string } }) =>
        key in settings ? { key, value: settings[key] } : null,
    },
  } as unknown as PrismaService;
  return new SettingsService(prisma);
}

describe('SettingsService.creditCosts', () => {
  it('returns all six categories with the built-in defaults (Pose is NOT free)', async () => {
    const costs = await serviceWith({}).creditCosts();
    expect(costs).toEqual({
      outfit: 4,
      hair: 4,
      glasses: 2,
      accessories: 2,
      pose: 2,
      ai_edit: 3,
    });
    expect(costs.pose).toBeGreaterThan(0);
  });

  it('applies admin overrides for every category, including Pose', async () => {
    const costs = await serviceWith({
      credit_costs: { outfit: 5, hair: 6, glasses: 3, accessories: 3, ai_edit: 4, pose: 8 },
    }).creditCosts();
    expect(costs.pose).toBe(8);
    expect(costs.outfit).toBe(5);
  });

  it('treats 0 as a valid free price', async () => {
    const costs = await serviceWith({ credit_costs: { pose: 0 } }).creditCosts();
    expect(costs.pose).toBe(0);
  });

  it('clamps negatives to 0, floors decimals, and ignores non-numbers', async () => {
    const costs = await serviceWith({
      credit_costs: { outfit: -5, hair: 4.9, glasses: 'free' },
    }).creditCosts();
    expect(costs.outfit).toBe(0); // negative clamped
    expect(costs.hair).toBe(4); // decimal floored
    expect(costs.glasses).toBe(2); // non-number -> default
  });
});

describe('SettingsService.homeSections', () => {
  it('defaults to the canonical style order', async () => {
    expect(await serviceWith({}).homeSections()).toEqual([
      'outfit',
      'hair',
      'glasses',
      'accessories',
      'ai_edit',
    ]);
  });

  it('honours an admin-set order verbatim', async () => {
    const order = await serviceWith({
      home_sections: ['ai_edit', 'outfit', 'accessories', 'hair', 'glasses'],
    }).homeSections();
    expect(order).toEqual(['ai_edit', 'outfit', 'accessories', 'hair', 'glasses']);
  });

  it('drops unknown/duplicate sections and appends any missing ones (safe fallback)', async () => {
    const order = await serviceWith({
      home_sections: ['ai_edit', 'pose', 'ai_edit', 'bogus', 'hair'],
    }).homeSections();
    // pose + bogus are not style sliders; duplicates removed; the rest appended.
    expect(order).toEqual(['ai_edit', 'hair', 'outfit', 'glasses', 'accessories']);
    expect(order).toHaveLength(5);
  });
});
