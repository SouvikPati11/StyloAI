import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import * as admin from 'firebase-admin';
import { AppException } from '../common/app.exception';

export interface FirebaseIdentity {
  uid: string;
  email?: string;
  name?: string;
  picture?: string;
}

/**
 * Verifies Firebase ID tokens with the Admin SDK. The service-account
 * credentials are a backend secret (FIREBASE_SERVICE_ACCOUNT_JSON) and never
 * reach the client. Also the entry point for sending FCM later.
 */
@Injectable()
export class FirebaseService implements OnModuleInit {
  private readonly logger = new Logger(FirebaseService.name);
  private app?: admin.app.App;
  private _projectId: string | null = null;

  constructor(private readonly config: ConfigService) {}

  onModuleInit() {
    // In production the Admin SDK MUST initialize — Google Sign-In cannot work
    // without it. A missing/invalid service account is a hard boot failure so a
    // misconfigured backend can never appear healthy (it crash-loops and the
    // deployment fails). In non-production it degrades to a warning for local dev.
    const isProd = this.config.get<string>('NODE_ENV') === 'production';
    const fail = (msg: string, err?: unknown): never | void => {
      if (isProd) throw new Error(msg);
      this.logger.warn(err ? `${msg} :: ${String(err)}` : msg);
    };

    const raw = this.config.get<string>('FIREBASE_SERVICE_ACCOUNT_JSON');
    if (!raw) {
      // Keep the historical phrase for log-based tooling, plus a hard failure.
      return void fail(
        'FIREBASE_SERVICE_ACCOUNT_JSON not set — Firebase auth verification disabled.',
      );
    }

    let serviceAccount: Record<string, unknown>;
    try {
      serviceAccount = JSON.parse(raw) as Record<string, unknown>;
    } catch (err) {
      return void fail('FIREBASE_SERVICE_ACCOUNT_JSON is not valid JSON.', err);
    }

    try {
      this.app =
        admin.apps.length > 0
          ? admin.app()
          : admin.initializeApp({
              credential: admin.credential.cert(
                serviceAccount as admin.ServiceAccount,
              ),
            });
      this._projectId =
        this.app.options.projectId ??
        (serviceAccount['project_id'] as string | undefined) ??
        null;
      this.logger.log(
        `Firebase Admin initialized (project ${this._projectId ?? 'unknown'}).`,
      );
    } catch (err) {
      return void fail('Failed to initialize Firebase Admin.', err);
    }
  }

  get isConfigured(): boolean {
    return !!this.app;
  }

  /** Public (non-secret) Firebase project id the Admin SDK is bound to. */
  get projectId(): string | null {
    return this._projectId;
  }

  async verifyIdToken(idToken: string): Promise<FirebaseIdentity> {
    if (!this.app) {
      throw AppException.unauthenticated('Authentication is not configured on the server.');
    }
    try {
      const decoded = await this.app.auth().verifyIdToken(idToken);
      return {
        uid: decoded.uid,
        email: decoded.email,
        name: decoded.name as string | undefined,
        picture: decoded.picture,
      };
    } catch {
      throw AppException.unauthenticated('Invalid Firebase ID token.');
    }
  }

  /** Send an FCM push to a single device token. No-op when not configured. */
  async sendPush(
    token: string,
    title: string,
    body: string,
    data?: Record<string, string>,
  ): Promise<void> {
    if (!this.app) return;
    await this.app.messaging().send({
      token,
      notification: { title, body },
      data,
      android: { priority: 'high' },
    });
  }
}
