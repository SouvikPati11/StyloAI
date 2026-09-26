import { Controller, Get, Inject } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { InjectQueue } from '@nestjs/bullmq';
import { Queue } from 'bullmq';
import { IMAGE_PROVIDER, ImageGenerationProvider } from '../ai/types';
import { GENERATION_QUEUE, GenerationJobData } from './generations.constants';
import { WorkerHeartbeatService } from './worker-heartbeat.service';
import { GenerationsProcessor } from './generations.processor';

/**
 * Non-secret operational readiness probe for the AI generation pipeline. Reports
 * whether the image provider has credentials + which model, the Redis endpoint
 * (host/port/tls only — NEVER the password), whether the queue is reachable,
 * whether the WORKER is connected/consuming, and queue job counts. Public so CI
 * can verify production without an authenticated session. Bounded so it can
 * never hang the HTTP request / Nginx upstream.
 */
@Controller('gen-health')
export class GenerationHealthController {
  constructor(
    @Inject(IMAGE_PROVIDER) private readonly provider: ImageGenerationProvider,
    @InjectQueue(GENERATION_QUEUE) private readonly queue: Queue<GenerationJobData>,
    private readonly heartbeat: WorkerHeartbeatService,
    private readonly processor: GenerationsProcessor,
    private readonly config: ConfigService,
  ) {}

  /** Reliable worker liveness: is the BullMQ worker running right now? */
  private workerRunning(): boolean {
    try {
      return this.processor.worker?.isRunning() ?? false;
    } catch {
      return false;
    }
  }

  /** Redis host/port/tls with the password stripped — safe to expose. */
  private redisInfo() {
    const raw = this.config.get<string>('REDIS_URL') ?? 'redis://localhost:6379';
    try {
      const u = new URL(raw);
      const host = u.hostname;
      return {
        redis_host: host,
        redis_port: u.port || '6379',
        redis_tls: u.protocol === 'rediss:',
        redis_is_loopback: host === 'localhost' || host === '127.0.0.1',
        redis_configured: !!this.config.get<string>('REDIS_URL'),
      };
    } catch {
      return { redis_host: null, redis_port: null, redis_tls: false, redis_is_loopback: false, redis_configured: !!this.config.get<string>('REDIS_URL') };
    }
  }

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
      worker_running: this.workerRunning(),
      job_counts: counts,
      ...this.redisInfo(),
      ...this.heartbeat.snapshot(),
    };
  }
}
