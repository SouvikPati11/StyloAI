import { Controller, Get, Inject } from '@nestjs/common';
import { InjectQueue } from '@nestjs/bullmq';
import { Queue } from 'bullmq';
import { IMAGE_PROVIDER, ImageGenerationProvider } from '../ai/types';
import { GENERATION_QUEUE, GenerationJobData } from './generations.constants';

/**
 * Non-secret readiness probe for the AI generation pipeline. Reports whether the
 * image provider has credentials, which model is configured, and whether the
 * job queue (Redis) is reachable — the two things whose absence silently breaks
 * generation. NEVER exposes the API key or any secret. Public so CI can verify
 * production without an authenticated session.
 */
@Controller('gen-health')
export class GenerationHealthController {
  constructor(
    @Inject(IMAGE_PROVIDER) private readonly provider: ImageGenerationProvider,
    @InjectQueue(GENERATION_QUEUE) private readonly queue: Queue<GenerationJobData>,
  ) {}

  @Get()
  async status() {
    let queueReachable = false;
    let counts: Record<string, number> | null = null;
    try {
      // getJobCounts round-trips to Redis; success means the queue is reachable.
      counts = (await this.queue.getJobCounts(
        'waiting',
        'active',
        'delayed',
        'failed',
      )) as unknown as Record<string, number>;
      queueReachable = true;
    } catch {
      queueReachable = false;
    }

    return {
      provider: this.provider.name,
      // Configured = the provider has an API key. Never the key itself.
      provider_configured: this.provider.isConfigured ?? false,
      model: this.provider.model ?? null,
      queue_reachable: queueReachable,
      job_counts: counts,
    };
  }
}
