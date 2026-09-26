import { Processor, WorkerHost } from '@nestjs/bullmq';
import { Inject, Logger, OnModuleInit } from '@nestjs/common';
import { Job } from 'bullmq';
import { GenerationInputRole, GenerationStatus } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { StorageService } from '../storage/storage.service';
import { CreditsService } from '../credits/credits.service';
import { IMAGE_PROVIDER, ImageGenerationProvider, ProviderError, ImageData } from '../ai/types';
import { buildPrompt } from '../ai/identity-preservation';
import { NotificationsService } from '../engagement/notifications.service';
import { GENERATION_QUEUE, GenerationJobData } from './generations.constants';
import { WorkerHeartbeatService } from './worker-heartbeat.service';

/**
 * Async worker: runs a queued generation. Fetches inputs from S3, builds the
 * identity-preserving prompt, calls the provider, stores outputs, and settles
 * the credit hold on success — or refunds it on an eligible failure. Idempotent
 * per generation; safe to retry. See docs/GEMINI_INTEGRATION.md §4.
 */
@Processor(GENERATION_QUEUE)
export class GenerationsProcessor extends WorkerHost implements OnModuleInit {
  private readonly logger = new Logger(GenerationsProcessor.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly storage: StorageService,
    private readonly credits: CreditsService,
    private readonly notifications: NotificationsService,
    private readonly heartbeat: WorkerHeartbeatService,
    @Inject(IMAGE_PROVIDER) private readonly provider: ImageGenerationProvider,
  ) {
    super();
  }

  /**
   * Track the worker's Redis connection so gen-health reports real worker
   * readiness (not just that the process booted). Errors are surfaced (their
   * short code) rather than silently swallowed.
   */
  onModuleInit() {
    const w = this.worker;
    if (!w) return;
    w.on('ready', () => {
      this.heartbeat.setReady();
      this.logger.log('[generation] worker connected to Redis and ready.');
    });
    w.on('error', (err: Error) => {
      this.heartbeat.setError(err?.message ?? 'worker error');
      this.logger.error(`[generation] worker Redis error: ${err?.message ?? err}`);
    });
    w.on('closing', () => this.heartbeat.setClosed());
    w.on('ioredis:close', () => this.heartbeat.setClosed());
  }

  async process(job: Job<GenerationJobData>): Promise<void> {
    this.heartbeat.markJob();
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

    // Non-secret stage diagnostics — identify exactly where a generation breaks
    // without leaking any image bytes, keys, tokens, or provider credentials.
    const stage = (s: string, extra = '') =>
      this.logger.log(`[generation] id=${generationId} type=${generation.type} stage=${s}${extra}`);
    stage('request_received');

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
      stage('content_loaded', ` inputs=${generation.inputs.length}`);

      const userPhoto = await this.loadImage(userPhotoInput.s3Key);
      const reference = referenceInput ? await this.loadImage(referenceInput.s3Key) : undefined;
      stage('input_image_validated', ` bytes=${userPhoto.bytes.length} mime=${userPhoto.contentType}`);

      const params = generation.params as {
        resolution?: 'standard' | 'high';
        style_descriptor?: string;
      } | null;

      const { prompt, styleDescriptor } = buildPrompt({
        type: generation.type,
        mode: generation.mode,
        presetKey: generation.presetKey,
        hasReference: !!reference,
        styleDescriptorOverride: params?.style_descriptor,
      });
      stage('provider_request', ` provider=${this.provider.name} prompt_len=${prompt.length}`);

      const result = await this.provider.edit({
        type: generation.type,
        userPhoto,
        reference,
        styleDescriptor,
        prompt,
        resolution: params?.resolution ?? 'standard',
      });
      stage('provider_response', ` images=${result.images.length}`);

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

      stage('result_stored');
      await this.credits.settle(generation.id);
      await this.prisma.generation.update({
        where: { id: generation.id },
        data: {
          status: GenerationStatus.succeeded,
          finishedAt: new Date(),
          providerJobRef: this.provider.name,
        },
      });
      stage('completed');
      this.heartbeat.markSuccess();
      await this.notifications.notify({
        userId: generation.userId,
        type: 'generation_completed',
        title: 'Your new look is ready',
        body: `Your ${generation.type} look has been generated. Tap to view.`,
        data: { generation_id: generation.id, type: generation.type },
        respectPref: 'notifGeneration',
      });
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
    // Record the non-secret failure stage/code so /v1/gen-health surfaces the
    // real reason (e.g. provider_error from a deprecated model) without logs.
    this.heartbeat.markFailure(isProvider ? 'provider' : 'worker', code);

    this.logger.warn(
      `[generation] id=${generationId} stage=failed code=${code} attempt=${job.attemptsMade + 1} ` +
        (attemptsLeft ? 'will_retry' : 'final'),
    );

    if (
      attemptsLeft &&
      code !== 'safety_blocked' &&
      code !== 'not_configured' &&
      code !== 'quota_exceeded'
    ) {
      // Let BullMQ retry; keep the hold in place. Quota/safety/config errors are
      // not transient, so we don't retry them (avoids a second wasted call).
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

    await this.notifications.notify({
      userId,
      type: 'generation_failed',
      title: "Your look couldn't be created",
      body: refundEligible
        ? 'We hit a problem generating your look and refunded your credits. Please try again.'
        : 'We couldn’t create that look. Please try a different photo.',
      data: { generation_id: generationId, error_code: code },
      respectPref: 'notifGeneration',
    });
    // Do not rethrow: the failure is recorded and handled, so the job is complete.
  }
}
