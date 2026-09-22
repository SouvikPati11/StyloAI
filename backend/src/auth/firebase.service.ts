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

  constructor(private readonly config: ConfigService) {}

  onModuleInit() {
    const raw = this.config.get<string>('FIREBASE_SERVICE_ACCOUNT_JSON');
    if (!raw) {
      this.logger.warn(
        'FIREBASE_SERVICE_ACCOUNT_JSON not set — Firebase auth verification disabled.',
      );
      return;
    }
    try {
      const serviceAccount = JSON.parse(raw) as admin.ServiceAccount;
      this.app =
        admin.apps.length > 0
          ? admin.app()
          : admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
      this.logger.log('Firebase Admin initialized.');
    } catch (err) {
      this.logger.error('Failed to initialize Firebase Admin.', err as Error);
    }
  }

  get isConfigured(): boolean {
    return !!this.app;
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
}
