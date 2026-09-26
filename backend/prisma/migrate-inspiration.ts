/**
 * Safe, NON-DESTRUCTIVE migration for retired "inspiration" trending content.
 *
 * "Inspiration" is no longer a user-facing category. Existing rows are never
 * deleted here. By default this script only REPORTS how many inspiration rows
 * exist (dry run). To reassign them into a supported style category, set:
 *
 *   INSPIRATION_TARGET=outfit|hair|glasses|accessories|ai_edit
 *
 * and re-run. Rows are updated in place (section reassigned); nothing is dropped.
 * If you prefer to simply hide them, set INSPIRATION_HIDE=true to mark them
 * inactive instead (also non-destructive; the rows remain in the database).
 *
 * Run: `npm run migrate:inspiration`  (dry run)
 *      `INSPIRATION_TARGET=outfit npm run migrate:inspiration`  (reassign)
 *      `INSPIRATION_HIDE=true npm run migrate:inspiration`      (hide only)
 */
import { PrismaClient, ContentSection } from '@prisma/client';

const prisma = new PrismaClient();
const VALID = ['outfit', 'hair', 'glasses', 'accessories', 'ai_edit'];

async function main() {
  const rows = await prisma.trendingContent.findMany({
    where: { section: ContentSection.inspiration },
    select: { id: true, title: true, isActive: true },
  });
  console.log(`[inspiration] found ${rows.length} trending row(s) in the retired "inspiration" category.`);
  if (rows.length === 0) {
    console.log('[inspiration] nothing to migrate.');
    return;
  }

  const target = process.env.INSPIRATION_TARGET;
  const hide = process.env.INSPIRATION_HIDE === 'true';

  if (!target && !hide) {
    console.log('[inspiration] DRY RUN — no changes made.');
    console.log('[inspiration] Set INSPIRATION_TARGET=<outfit|hair|glasses|accessories|ai_edit> to reassign,');
    console.log('[inspiration] or INSPIRATION_HIDE=true to mark them inactive. Rows are never deleted.');
    for (const r of rows) console.log(`  - ${r.id} "${r.title}" (active=${r.isActive})`);
    return;
  }

  if (hide) {
    const res = await prisma.trendingContent.updateMany({
      where: { section: ContentSection.inspiration },
      data: { isActive: false },
    });
    console.log(`[inspiration] marked ${res.count} row(s) inactive (preserved, not deleted).`);
    return;
  }

  if (!VALID.includes(target as string)) {
    throw new Error(`INSPIRATION_TARGET must be one of: ${VALID.join(', ')}`);
  }
  const res = await prisma.trendingContent.updateMany({
    where: { section: ContentSection.inspiration },
    data: { section: target as ContentSection },
  });
  console.log(`[inspiration] reassigned ${res.count} row(s) to "${target}". No rows deleted.`);
}

main()
  .catch((e) => {
    console.error(e instanceof Error ? e.message : e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
