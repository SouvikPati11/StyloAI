import { Injectable } from '@nestjs/common';

/**
 * Tracks real BullMQ worker health from the worker's own Redis connection
 * events, so /v1/gen-health can report whether the worker is actually connected
 * and consuming — not merely that the process started. All values are non-secret.
 */
@Injectable()
export class WorkerHeartbeatService {
  private _ready = false;
  private _lastReadyAt: Date | null = null;
  private _lastError: string | null = null;
  private _lastJobAt: Date | null = null;
  private _processed = 0;
  private _lastFailure: { stage: string; code: string; at: Date } | null = null;
  private _lastSuccessAt: Date | null = null;

  setReady() {
    this._ready = true;
    this._lastReadyAt = new Date();
    this._lastError = null;
  }

  setClosed() {
    this._ready = false;
  }

  setError(message: string) {
    this._ready = false;
    // Keep only a short, non-secret error label (e.g. the ioredis error code).
    this._lastError = message.slice(0, 120);
  }

  markJob() {
    this._lastJobAt = new Date();
    this._processed += 1;
  }

  /** Record the exact non-secret failure stage + code of the last generation. */
  markFailure(stage: string, code: string) {
    this._lastFailure = { stage, code: code.slice(0, 60), at: new Date() };
  }

  markSuccess() {
    this._lastSuccessAt = new Date();
  }

  snapshot() {
    return {
      worker_ready: this._ready,
      worker_last_ready_at: this._lastReadyAt,
      worker_last_job_at: this._lastJobAt,
      worker_jobs_processed: this._processed,
      worker_last_error: this._lastError,
      worker_last_success_at: this._lastSuccessAt,
      // Non-secret: which stage failed + the typed error code (e.g. provider_error).
      last_generation_failure: this._lastFailure,
    };
  }
}
