import { Controller, Get } from '@nestjs/common';
import { SettingsService } from './settings.service';
import { PrismaService } from '../prisma/prisma.service';

/**
 * GET /v1/config — client bootstrap. The app renders credit costs, enabled
 * features, categories, and resolution options from here; it never hard-codes
 * any of them. Public (no auth) so onboarding can read it, but contains no
 * sensitive data.
 */
@Controller('config')
export class ConfigController {
  constructor(
    private readonly settings: SettingsService,
    private readonly prisma: PrismaService,
  ) {}

  @Get()
  async getConfig() {
    const [creditCosts, features, aiConfig, categories] = await Promise.all([
      this.settings.creditCosts(),
      this.settings.features(),
      this.settings.get<{ resolutions: string[] }>('ai_config', { resolutions: ['standard'] }),
      this.prisma.category.findMany({
        where: { isActive: true },
        orderBy: [{ section: 'asc' }, { sortOrder: 'asc' }],
        select: { section: true, key: true, label: true },
      }),
    ]);

    const sections: Record<string, { key: string; label: string }[]> = {};
    for (const c of categories) {
      (sections[c.section] ??= []).push({ key: c.key, label: c.label });
    }

    return {
      credit_costs: creditCosts,
      features,
      resolutions: aiConfig.resolutions ?? ['standard'],
      sections,
    };
  }
}
