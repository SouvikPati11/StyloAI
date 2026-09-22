import { Controller, Get, Query, UseGuards } from '@nestjs/common';
import { ContentSection } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { StorageService } from '../storage/storage.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { CurrentUser, AuthUser } from '../auth/current-user.decorator';

/**
 * Explore / Trending (§6) — DB-driven content managed from the admin panel, so
 * it changes without an app release. Images are delivered via signed URLs.
 */
@Controller()
@UseGuards(JwtAuthGuard)
export class ContentController {
  constructor(
    private readonly prisma: PrismaService,
    private readonly storage: StorageService,
  ) {}

  @Get('trending')
  async trending(@Query('section') section?: ContentSection) {
    const now = new Date();
    const rows = await this.prisma.trendingContent.findMany({
      where: {
        isActive: true,
        ...(section ? { section } : {}),
        AND: [
          { OR: [{ startsAt: null }, { startsAt: { lte: now } }] },
          { OR: [{ endsAt: null }, { endsAt: { gte: now } }] },
        ],
      },
      orderBy: [{ section: 'asc' }, { position: 'asc' }],
      take: 100,
    });
    const items = await Promise.all(
      rows.map(async (r) => ({
        id: r.id,
        section: r.section,
        title: r.title,
        subtitle: r.subtitle,
        preset_key: r.presetKey,
        image_url: await this.storage.presignDownload(r.imageS3Key, 3600),
      })),
    );
    return { items };
  }

  @Get('categories')
  async categories(@Query('section') section?: ContentSection) {
    const rows = await this.prisma.category.findMany({
      where: { isActive: true, ...(section ? { section } : {}) },
      orderBy: [{ section: 'asc' }, { sortOrder: 'asc' }],
    });
    return {
      items: rows.map((c) => ({ section: c.section, key: c.key, label: c.label })),
    };
  }

  /**
   * Personalized recommendations from the user's style profile, falling back to
   * active trending content. Kept simple for the MVP; the seam supports richer
   * ranking later.
   */
  @Get('recommendations')
  async recommendations(@CurrentUser() user: AuthUser) {
    const profile = await this.prisma.styleProfile.findUnique({ where: { userId: user.userId } });
    const preferred = profile?.preferredStyles ?? [];
    const rows = await this.prisma.trendingContent.findMany({
      where: { isActive: true },
      orderBy: { position: 'asc' },
      take: 40,
    });
    const ranked = rows
      .map((r) => ({
        row: r,
        score: preferred.includes(r.presetKey ?? '') ? 1 : 0,
      }))
      .sort((a, b) => b.score - a.score)
      .slice(0, 12);
    const items = await Promise.all(
      ranked.map(async ({ row }) => ({
        id: row.id,
        section: row.section,
        title: row.title,
        subtitle: row.subtitle,
        preset_key: row.presetKey,
        image_url: await this.storage.presignDownload(row.imageS3Key, 3600),
      })),
    );
    return { items, personalized: preferred.length > 0 };
  }
}
