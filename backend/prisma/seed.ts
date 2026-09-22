/**
 * Seeds baseline configuration: system settings (credit costs, signup bonus,
 * feature flags, AI + rate-limit defaults), a starter category taxonomy, and
 * the first admin from ADMIN_BOOTSTRAP_* env (one-time; rotate after).
 *
 * Idempotent: safe to run repeatedly (upserts by unique key).
 */
import { PrismaClient, ContentSection, AdminRole } from '@prisma/client';
import * as bcrypt from 'bcryptjs';

const prisma = new PrismaClient();

const SETTINGS: { key: string; value: unknown; description: string }[] = [
  {
    key: 'credit_costs',
    value: { outfit: 4, hair: 4, glasses: 2, accessories: 2, pose: 1, ai_edit: 3 },
    description: 'Credit cost per generation type. Editable from the admin panel.',
  },
  {
    key: 'signup_bonus_credits',
    value: 20,
    description: 'Credits granted to a new user on first sign-in.',
  },
  {
    key: 'features',
    value: {
      outfit: true,
      hair: true,
      glasses: true,
      accessories: true,
      pose: true,
      ai_edit: true,
      billing: true,
    },
    description: 'Feature flags per section; false disables the feature app-wide.',
  },
  {
    key: 'ai_config',
    value: { provider: 'gemini', model: 'default', resolutions: ['standard', 'high'] },
    description: 'Default AI provider/model and offered resolution options.',
  },
  {
    key: 'rate_limits',
    value: {
      generations: { perMinute: 5, perDay: 100 },
      presign: { perMinute: 20 },
      billing_verify: { perMinute: 10 },
    },
    description: 'Per-user rate limits for expensive endpoints.',
  },
  {
    key: 'store_products',
    value: [
      { product_id: 'credits_50', credits: 50, title: 'Starter', price_hint: '$4.99' },
      { product_id: 'credits_120', credits: 120, title: 'Popular', price_hint: '$9.99', bonus: 10 },
      { product_id: 'credits_300', credits: 300, title: 'Pro', price_hint: '$19.99', bonus: 40 },
    ],
    description: 'Credit packs shown in the store. Must match Google Play Console product IDs.',
  },
];

// section -> [ [key, label], ... ]
const CATEGORIES: Record<string, [string, string][]> = {
  outfit: [
    ['casual', 'Casual'],
    ['formal', 'Formal'],
    ['smart_casual', 'Smart Casual'],
    ['streetwear', 'Streetwear'],
    ['party', 'Party'],
    ['luxury', 'Luxury'],
    ['traditional', 'Traditional'],
    ['minimal', 'Minimal'],
    ['summer', 'Summer'],
    ['winter', 'Winter'],
    ['trending', 'Trending'],
  ],
  hair: [
    ['short', 'Short'],
    ['long', 'Long'],
    ['fade', 'Fade'],
    ['curly', 'Curly'],
    ['wavy', 'Wavy'],
    ['textured', 'Textured'],
    ['formal', 'Formal'],
    ['modern', 'Modern'],
    ['trending', 'Trending'],
  ],
  glasses: [
    ['sunglasses', 'Sunglasses'],
    ['clear', 'Clear Glasses'],
    ['formal', 'Formal'],
    ['round', 'Round'],
    ['square', 'Square'],
    ['aviator', 'Aviator'],
    ['minimal', 'Minimal'],
    ['trending', 'Trending'],
  ],
  accessories: [
    ['watches', 'Watches'],
    ['chains', 'Chains'],
    ['rings', 'Rings'],
    ['bracelets', 'Bracelets'],
    ['caps', 'Caps'],
    ['hats', 'Hats'],
    ['earrings', 'Earrings'],
  ],
  pose: [
    ['instagram', 'Instagram'],
    ['profile_picture', 'Profile Picture'],
    ['fashion', 'Fashion'],
    ['street', 'Street'],
    ['casual', 'Casual'],
    ['formal', 'Formal'],
    ['party', 'Party'],
    ['travel', 'Travel'],
    ['portrait', 'Portrait'],
  ],
  ai_edit: [
    ['cinematic', 'Cinematic'],
    ['luxury', 'Luxury'],
    ['studio_portrait', 'Studio Portrait'],
    ['street_photography', 'Street Photography'],
    ['editorial_fashion', 'Editorial Fashion'],
    ['moody_portrait', 'Moody Portrait'],
    ['clean_portrait', 'Clean Portrait'],
  ],
};

async function main() {
  for (const s of SETTINGS) {
    await prisma.systemSetting.upsert({
      where: { key: s.key },
      update: { value: s.value as object, description: s.description },
      create: { key: s.key, value: s.value as object, description: s.description },
    });
  }
  console.log(`Seeded ${SETTINGS.length} system settings.`);

  let catCount = 0;
  for (const [section, entries] of Object.entries(CATEGORIES)) {
    let order = 0;
    for (const [key, label] of entries) {
      await prisma.category.upsert({
        where: { section_key: { section: section as ContentSection, key } },
        update: { label, sortOrder: order },
        create: { section: section as ContentSection, key, label, sortOrder: order },
      });
      order += 1;
      catCount += 1;
    }
  }
  console.log(`Seeded ${catCount} categories.`);

  const email = process.env.ADMIN_BOOTSTRAP_EMAIL;
  const password = process.env.ADMIN_BOOTSTRAP_PASSWORD;
  if (email && password) {
    const passwordHash = await bcrypt.hash(password, 12);
    await prisma.adminUser.upsert({
      where: { email },
      update: {},
      create: { email, passwordHash, role: AdminRole.super_admin },
    });
    console.log(`Ensured bootstrap admin: ${email}`);
  } else {
    console.log('ADMIN_BOOTSTRAP_EMAIL/PASSWORD not set — skipping admin seed.');
  }
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
