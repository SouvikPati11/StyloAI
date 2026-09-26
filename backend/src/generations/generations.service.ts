import { Injectable, Logger } from '@nestjs/common';
import { InjectQueue } from '@nestjs/bullmq';
import { Queue } from 'bullmq';
import {
  GenerationInputRole,
  GenerationMode,
  GenerationStatus,
  GenerationType,
} from '@prisma/client';
import { randomUUID } from 'crypto';
import { PrismaService } from '../prisma/prisma.service';
import { SettingsService, CreditCosts } from '../settings/settings.service';
import { CreditsService } from '../credits/credits.service';
import { StorageService } from '../storage/storage.service';
import { AppException } from '../common/app.exception';
import { GENERATION_QUEUE, GenerationJobData } from './generations.constants';
import { CreateGenerationDto } from './dto';

const REFERENCE_ROLE: Record<GenerationType, GenerationInputRole | null> = {
  outfit: GenerationInputRole.outfit_ref,
  hair: GenerationInputRole.hair_ref,
  glasses: GenerationInputRole.glasses_ref,
  accessories: GenerationInputRole.accessory_ref,
  pose: GenerationInputRole.pose_ref,
  ai_edit: null,
};

@Injectable()
export class GenerationsService {
  private readonly logger = new Logger(GenerationsService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly settings: SettingsService,
    private readonly credits: CreditsService,
    private readonly storage: StorageService,
    @InjectQueue(GENERATION_QUEUE) private readonly queue: Queue<GenerationJobData>,
  ) {}

  /**
   * Submit a generation (async). Validates inputs/ownership/feature, snapshots
   * the credit cost, holds credits, creates the generation + inputs, and
   * enqueues a worker job — returning 202-style state. Idempotent on the
   * idempotency key: a retried submit returns the original generation and never
   * double-charges. See docs/GEMINI_INTEGRATION.md §4.
   */
  async submit(userId: string, dto: CreateGenerationDto, idempotencyKey: string) {
    // Idempotency: return the original generation if this key was already used.
    const existing = await this.prisma.generation.findUnique({
      where: { idempotencyKey },
      include: { images: true },
    });
    if (existing) return this.presentSubmit(existing.id, userId);

    // Resolve the AUTHORITATIVE style from the database when an admin-created
    // Trending Style is referenced. Its section (=type), preset, description and
    // per-item price come from the DB record — never reconstructed on the client.
    let type: GenerationType = dto.type;
    let presetKey = dto.preset_key;
    let styleDescriptor: string | undefined;
    let priceOverride: number | null = null;
    if (dto.trending_content_id) {
      const style = await this.prisma.trendingContent.findFirst({
        where: { id: dto.trending_content_id, isActive: true },
      });
      if (!style) throw AppException.notFound('Selected style is unavailable.');
      type = style.section as unknown as GenerationType;
      presetKey = style.presetKey ?? presetKey;
      styleDescriptor = style.description ?? undefined;
      priceOverride = style.creditPrice;
    }

    if (!(await this.settings.isFeatureEnabled(type))) {
      throw AppException.featureDisabled(type);
    }

    // Validate inputs.
    if (!this.storage.ownsKey(userId, dto.user_photo_key)) {
      throw AppException.validation('user_photo_key does not belong to you.');
    }
    if (dto.mode === GenerationMode.reference_upload) {
      if (!dto.reference_key) {
        throw AppException.validation('reference_key is required in reference_upload mode.');
      }
      if (!this.storage.ownsKey(userId, dto.reference_key)) {
        throw AppException.validation('reference_key does not belong to you.');
      }
    }
    if (dto.mode === GenerationMode.explore && !presetKey && !dto.trending_content_id) {
      throw AppException.validation('preset_key is required in explore mode.');
    }

    // Backend is the single source of truth for price:
    //  - Pose is always free.
    //  - A referenced Trending Style uses its configured price when set.
    //  - Otherwise the per-type credit cost from system settings applies.
    const cost =
      type === GenerationType.pose
        ? 0
        : priceOverride ?? (await this.settings.costFor(type as keyof CreditCosts));

    // Fast-fail on balance before creating anything (skipped for free content).
    const balance = await this.credits.getBalance(userId);
    if (cost > 0 && balance < cost) throw AppException.insufficientCredits(cost, balance);

    // Create the generation + inputs, then hold credits (idempotent).
    const generation = await this.prisma.generation.create({
      data: {
        userId,
        type,
        mode: dto.mode,
        presetKey,
        status: GenerationStatus.queued,
        creditCost: cost,
        idempotencyKey,
        params: {
          resolution: dto.options?.resolution ?? 'standard',
          ...(styleDescriptor ? { style_descriptor: styleDescriptor } : {}),
          ...(dto.trending_content_id ? { trending_content_id: dto.trending_content_id } : {}),
        },
        inputs: {
          create: this.buildInputs(dto, type),
        },
      },
    });

    // Only hold credits for paid generations; free content never touches the ledger.
    if (cost > 0) {
      try {
        await this.credits.hold({
          userId,
          amount: cost,
          generationId: generation.id,
          idempotencyKey: `hold:${generation.id}`,
        });
      } catch (err) {
        // Roll back the generation shell so a failed hold leaves no orphan.
        await this.prisma.generation
          .delete({ where: { id: generation.id } })
          .catch(() => undefined);
        throw err;
      }
    }

    await this.queue.add(
      'generate',
      { generationId: generation.id },
      {
        jobId: generation.id,
        attempts: 2,
        backoff: { type: 'exponential', delay: 3000 },
        removeOnComplete: true,
        removeOnFail: 500,
      },
    );

    return {
      generation_id: generation.id,
      status: GenerationStatus.queued,
      credit_cost: cost,
      balance_after_hold: balance - cost,
    };
  }

  private buildInputs(dto: CreateGenerationDto, type: GenerationType) {
    const inputs: { role: GenerationInputRole; s3Key: string }[] = [
      { role: GenerationInputRole.user_photo, s3Key: dto.user_photo_key },
    ];
    const refRole = REFERENCE_ROLE[type];
    if (dto.mode === GenerationMode.reference_upload && dto.reference_key && refRole) {
      inputs.push({ role: refRole, s3Key: dto.reference_key });
    }
    return inputs;
  }

  private async presentSubmit(generationId: string, userId: string) {
    const g = await this.prisma.generation.findFirst({
      where: { id: generationId, userId },
    });
    if (!g) throw AppException.notFound('Generation not found.');
    return {
      generation_id: g.id,
      status: g.status,
      credit_cost: g.creditCost,
    };
  }

  /** Full generation view with signed image URLs when finished. */
  async get(userId: string, generationId: string) {
    const g = await this.prisma.generation.findFirst({
      where: { id: generationId, userId },
      include: { images: { where: { deletedAt: null } } },
    });
    if (!g) throw AppException.notFound('Generation not found.');

    const images = await Promise.all(
      g.images.map(async (img) => ({
        id: img.id,
        url: await this.storage.presignDownload(img.s3Key),
        thumbnail_url: img.thumbnailS3Key
          ? await this.storage.presignDownload(img.thumbnailS3Key)
          : null,
        width: img.width,
        height: img.height,
      })),
    );

    return {
      id: g.id,
      type: g.type,
      mode: g.mode,
      status: g.status,
      credit_cost: g.creditCost,
      error_code: g.errorCode,
      images,
      created_at: g.createdAt,
      finished_at: g.finishedAt,
    };
  }

  async list(userId: string, type?: GenerationType, limit = 20, cursor?: string) {
    const rows = await this.prisma.generation.findMany({
      where: { userId, ...(type ? { type } : {}) },
      orderBy: { createdAt: 'desc' },
      take: limit + 1,
      ...(cursor ? { cursor: { id: cursor }, skip: 1 } : {}),
      include: { images: { where: { deletedAt: null }, take: 1 } },
    });
    const hasMore = rows.length > limit;
    const items = hasMore ? rows.slice(0, limit) : rows;
    const mapped = await Promise.all(
      items.map(async (g) => ({
        id: g.id,
        type: g.type,
        status: g.status,
        thumbnail_url: g.images[0]
          ? await this.storage.presignDownload(g.images[0].thumbnailS3Key ?? g.images[0].s3Key)
          : null,
        created_at: g.createdAt,
      })),
    );
    return { items: mapped, next_cursor: hasMore ? items[items.length - 1].id : null };
  }

  /** User deletes a generation and its images (privacy, §21). */
  async remove(userId: string, generationId: string) {
    const g = await this.prisma.generation.findFirst({
      where: { id: generationId, userId },
      include: { images: true },
    });
    if (!g) throw AppException.notFound('Generation not found.');
    for (const img of g.images) {
      await this.storage.deleteObject(img.s3Key).catch(() => undefined);
      if (img.thumbnailS3Key)
        await this.storage.deleteObject(img.thumbnailS3Key).catch(() => undefined);
    }
    await this.prisma.generation.delete({ where: { id: g.id } });
    return { deleted: true };
  }

  static newIdempotencyKey(): string {
    return randomUUID();
  }
}
