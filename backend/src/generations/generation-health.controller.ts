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
    // The Redis round-trip is bounded HARD: if the queue is unreachable the call
    // must return fast and NEVER hang the request (a hang would time out the
    // Nginx upstream and briefly 502 the whole backend). A hung probe here is
    // itself the signal that Redis is down.
    let queueReachable = false;
    let counts: Record<string, number> | null = null;
    // Issue the Redis round-trip and IMMEDIATELY attach a catch so a later
    // rejection (e.g. Redis unreachable → MaxRetriesPerRequestError) can never
    // surface as an unhandled rejection and crash the process. Then race it
    // against a short timeout so the HTTP response is always fast.
    const countsPromise = this.queue
      .getJobCounts('waiting', 'active', 'delayed', 'failed')
      .then((c) => c as unknown as Record<string, number>)
      .catch(() => null);
    const timeout = new Promise<null>((resolve) =>
      setTimeout(() => resolve(null), 2500),
    );
    const result = await Promise.race([countsPromise, timeout]);
    if (result) {
      counts = result;
      queueReachable = true;
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
