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
  // Per-CATEGORY default price for Pose. An admin can raise it here or per-pose;
  // 0 = free by default. Pose fully participates in the credit system.
  pose: 0,
  ai_edit: 3,
};

/**
 * Default ORDER of the Home category sliders (admin-overridable via the
 * `home_sections` system setting). Backend-driven so the app can reorder the
 * five style sliders without a release — the client never hard-codes this.
 * Only the five style sections appear as Home category sliders; Pose has its
 * own Explore surface and is never a Home category slider.
 */
export const DEFAULT_HOME_SECTIONS = ['outfit', 'hair', 'glasses', 'accessories', 'ai_edit'];
const VALID_HOME_SECTIONS = new Set(DEFAULT_HOME_SECTIONS);

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

  /**
   * Admin-controlled ORDER of the Home category sliders. Sanitized so a bad or
   * partial admin value can never break the Home layout: only valid style
   * sections are kept, duplicates are dropped, and any sections the admin
   * omitted are appended in the default order (so all five always render).
   */
  async homeSections(): Promise<string[]> {
    const raw = await this.get<unknown>('home_sections', DEFAULT_HOME_SECTIONS);
    const list = Array.isArray(raw) ? raw : DEFAULT_HOME_SECTIONS;
    const seen = new Set<string>();
    const ordered: string[] = [];
    for (const s of list) {
      if (typeof s === 'string' && VALID_HOME_SECTIONS.has(s) && !seen.has(s)) {
        seen.add(s);
        ordered.push(s);
      }
    }
    for (const s of DEFAULT_HOME_SECTIONS) if (!seen.has(s)) ordered.push(s);
    return ordered;
  }
}
