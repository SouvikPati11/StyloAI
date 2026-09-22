import { Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

export interface CreditCosts {
  outfit: number;
  hair: number;
  glasses: number;
  accessories: number;
  pose: number;
  ai_edit: number;
}

const DEFAULT_CREDIT_COSTS: CreditCosts = {
  outfit: 4,
  hair: 4,
  glasses: 2,
  accessories: 2,
  pose: 1,
  ai_edit: 3,
};

/**
 * Reads admin-managed configuration from system_settings with a short in-memory
 * cache. Credit costs and feature flags are DB-driven so they can change from
 * the admin panel without an app release. The client never hard-codes these.
 */
@Injectable()
export class SettingsService {
  private readonly logger = new Logger(SettingsService.name);
  private cache = new Map<string, { value: unknown; expires: number }>();
  private readonly ttlMs = 30_000;

  constructor(private readonly prisma: PrismaService) {}

  async get<T>(key: string, fallback: T): Promise<T> {
    const cached = this.cache.get(key);
    if (cached && cached.expires > Date.now()) {
      return cached.value as T;
    }
    const row = await this.prisma.systemSetting.findUnique({ where: { key } });
    const value = (row?.value as T) ?? fallback;
    this.cache.set(key, { value, expires: Date.now() + this.ttlMs });
    return value;
  }

  invalidate(key?: string) {
    if (key) this.cache.delete(key);
    else this.cache.clear();
  }

  async creditCosts(): Promise<CreditCosts> {
    return this.get<CreditCosts>('credit_costs', DEFAULT_CREDIT_COSTS);
  }

  async costFor(type: keyof CreditCosts): Promise<number> {
    const costs = await this.creditCosts();
    return costs[type] ?? DEFAULT_CREDIT_COSTS[type];
  }

  async features(): Promise<Record<string, boolean>> {
    return this.get<Record<string, boolean>>('features', {});
  }

  async isFeatureEnabled(feature: string): Promise<boolean> {
    const features = await this.features();
    // default enabled unless explicitly turned off
    return features[feature] !== false;
  }

  async signupBonusCredits(): Promise<number> {
    return this.get<number>('signup_bonus_credits', 0);
  }
}
