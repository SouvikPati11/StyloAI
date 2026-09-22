import { Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { FirebaseService } from '../auth/firebase.service';

/**
 * Sends notifications: persists an in-app record and, when FCM is configured and
 * the user hasn't opted out, delivers a push to their devices. Gated by user
 * preferences so we never spam (§10).
 */
@Injectable()
export class NotificationsService {
  private readonly logger = new Logger(NotificationsService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly firebase: FirebaseService,
  ) {}

  async notify(params: {
    userId: string;
    type: string;
    title: string;
    body: string;
    data?: Record<string, string>;
    respectPref?: 'notifGeneration' | 'notifTrending' | 'notifMarketing';
  }) {
    // Respect the user's notification preferences.
    if (params.respectPref) {
      const profile = await this.prisma.userProfile.findUnique({
        where: { userId: params.userId },
      });
      if (profile && profile[params.respectPref] === false) {
        // Still store the in-app record, but skip push.
        await this.persist(params);
        return;
      }
    }
    await this.persist(params);
    await this.push(params);
  }

  private async persist(params: {
    userId: string;
    type: string;
    title: string;
    body: string;
    data?: Record<string, string>;
  }) {
    await this.prisma.notification
      .create({
        data: {
          userId: params.userId,
          type: params.type,
          title: params.title,
          body: params.body,
          data: params.data,
        },
      })
      .catch((err) => this.logger.warn(`Failed to persist notification: ${err.message}`));
  }

  private async push(params: {
    userId: string;
    title: string;
    body: string;
    data?: Record<string, string>;
  }) {
    if (!this.firebase.isConfigured) return;
    const devices = await this.prisma.device.findMany({ where: { userId: params.userId } });
    for (const device of devices) {
      await this.firebase
        .sendPush(device.fcmToken, params.title, params.body, params.data)
        .catch((err) => this.logger.warn(`Push failed: ${err.message}`));
    }
  }
}
