import { Processor, WorkerHost } from '@nestjs/bullmq';
import { Inject, Logger } from '@nestjs/common';
import { Job } from 'bullmq';
import { GenerationInputRole, GenerationStatus } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { StorageService } from '../storage/storage.service';
import { CreditsService } from '../credits/credits.service';
import { IMAGE_PROVIDER, ImageGenerationProvider, ProviderError, ImageData } from '../ai/types';
import { buildPrompt } from '../ai/identity-preservation';
import { GENERATION_QUEUE, GenerationJobData } from './generations.constants';

/**
 * Async worker: runs a queued generation. Fetches inputs from S3, builds the
 * identity-preserving prompt, calls the provider, stores outputs, and settles
 * the credit hold on success — or refunds it on an eligible failure. Idempotent
 * per generation; safe to retry. See docs/GEMINI_INTEGRATION.md §4.
 */
@Processor(GENERATION_QUEUE)
export class GenerationsProcessor extends WorkerHost {
  private readonly logger = new Logger(GenerationsProcessor.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly storage: StorageService,
    private readonly credits: CreditsService,
    @Inject(IMAGE_PROVIDER) private readonly provider: ImageGenerationProvider,
  ) {
    super();
  }

  async process(job: Job<GenerationJobData>): Promise<void> {
    const { generationId } = job.data;
    const generation = await this.prisma.generation.findUnique({
      where: { id: generationId },
      include: { inputs: true },
    });
    if (!generation) {
      this.logger.warn(`Generation ${generationId} not found; dropping job.`);
      return;
    }
    // Skip if already finished (idempotent on retries).
    if (
      generation.status === GenerationStatus.succeeded ||
      generation.status === GenerationStatus.refunded
    ) {
      return;
    }

    await this.prisma.generation.update({
      where: { id: generationId },
      data: { status: GenerationStatus.processing, startedAt: new Date() },
    });

    try {
      const userPhotoInput = generation.inputs.find(
        (i) => i.role === GenerationInputRole.user_photo,
      );
      if (!userPhotoInput) throw new ProviderError('Missing user photo input.', 'provider_error');
      const referenceInput = generation.inputs.find(
        (i) => i.role !== GenerationInputRole.user_photo,
      );

      const userPhoto = await this.loadImage(userPhotoInput.s3Key);
      const reference = referenceInput ? await this.loadImage(referenceInput.s3Key) : undefined;

      const { prompt, styleDescriptor } = buildPrompt({
        type: generation.type,
        mode: generation.mode,
        presetKey: generation.presetKey,
        hasReference: !!reference,
      });

      const result = await this.provider.edit({
        type: generation.type,
        userPhoto,
        reference,
        styleDescriptor,
        prompt,
        resolution:
          (generation.params as { resolution?: 'standard' | 'high' })?.resolution ?? 'standard',
      });

      // Store outputs.
      for (let i = 0; i < result.images.length; i++) {
        const img = result.images[i];
        const key = this.storage.buildGeneratedKey(generation.userId, img.contentType);
        await this.storage.putObject(key, img.bytes, img.contentType);
        await this.prisma.generatedImage.create({
          data: {
            generationId: generation.id,
            userId: generation.userId,
            s3Key: key,
            contentType: img.contentType,
            isPrimary: i === 0,
          },
        });
      }

      await this.credits.settle(generation.id);
      await this.prisma.generation.update({
        where: { id: generation.id },
        data: {
          status: GenerationStatus.succeeded,
          finishedAt: new Date(),
          providerJobRef: this.provider.name,
        },
      });
      this.logger.log(`Generation ${generation.id} succeeded.`);
      // FCM "ready" notification is sent in Phase 7.
    } catch (err) {
      await this.handleFailure(generation.id, generation.userId, err, job);
    }
  }

  private async loadImage(key: string): Promise<ImageData> {
    const obj = await this.storage.getObjectBytes(key);
    return { bytes: obj.bytes, contentType: obj.contentType };
  }

  /**
   * Records the failure and refunds the hold when the failure is eligible
   * (provider/internal errors). BullMQ will retry per the job's `attempts`; we
   * only refund + mark refunded on the final attempt so a retry can still
   * succeed without a premature refund.
   */
  private async handleFailure(
    generationId: string,
    userId: string,
    err: unknown,
    job: Job<GenerationJobData>,
  ) {
    const isProvider = err instanceof ProviderError;
    const code = isProvider ? (err as ProviderError).code : 'provider_error';
    const refundEligible = isProvider ? (err as ProviderError).refundEligible : true;
    const attemptsLeft = job.attemptsMade + 1 < (job.opts.attempts ?? 1);

    this.logger.warn(
      `Generation ${generationId} failed (${code}); attempt ${job.attemptsMade + 1}. ` +
        (attemptsLeft ? 'Will retry.' : 'Final attempt.'),
    );

    if (attemptsLeft && code !== 'safety_blocked' && code !== 'not_configured') {
      // Let BullMQ retry; keep the hold in place.
      throw err;
    }

    await this.prisma.generation.update({
      where: { id: generationId },
      data: { status: GenerationStatus.failed, errorCode: code, finishedAt: new Date() },
    });

    if (refundEligible) {
      const refunded = await this.credits.refund({
        userId,
        generationId,
        reason: `Refund for failed generation (${code}).`,
      });
      if (refunded) {
        await this.prisma.generation.update({
          where: { id: generationId },
          data: { status: GenerationStatus.refunded },
        });
      }
    }
    // FCM "failed" notification is sent in Phase 7. Do not rethrow: the failure
    // is recorded and handled, so the job is complete.
  }
}
