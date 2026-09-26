import { Injectable, Logger } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import { CreditTxnType } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { CreditsService } from '../credits/credits.service';
import { SettingsService } from '../settings/settings.service';
import { FirebaseService } from './firebase.service';
import { AppException } from '../common/app.exception';
import { ErrorCode } from '../common/error-codes';

export interface TokenPair {
  access_token: string;
  refresh_token: string;
  expires_in: number;
}

/** A friendly display name from an email local-part (e.g. jane.doe -> Jane Doe). */
function deriveNameFromEmail(email?: string): string | undefined {
  if (!email) return undefined;
  const local = email.split('@')[0]?.replace(/[._-]+/g, ' ').trim();
  if (!local) return undefined;
  return local
    .split(' ')
    .filter(Boolean)
    .map((w) => w.charAt(0).toUpperCase() + w.slice(1))
    .join(' ');
}

/**
 * Auth flow: the app signs in with Firebase Google Sign-In and sends the
 * resulting ID token. We verify it, upsert the user by firebase_uid, grant the
 * signup bonus once, and issue our OWN short-lived access + rotating refresh
 * JWT. All subsequent API calls use the backend access token.
 */
@Injectable()
export class AuthService {
  private readonly logger = new Logger(AuthService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly firebase: FirebaseService,
    private readonly credits: CreditsService,
    private readonly settings: SettingsService,
    private readonly jwt: JwtService,
    private readonly config: ConfigService,
  ) {}

  async loginWithGoogle(idToken: string) {
    const identity = await this.firebase.verifyIdToken(idToken);

    const isNew = !(await this.prisma.user.findUnique({
      where: { firebaseUid: identity.uid },
    }));

    // Prefer the Google display name; fall back to a friendly name derived from
    // the email local-part so the app always has something to greet the user by.
    const fallbackName = deriveNameFromEmail(identity.email);
    const user = await this.prisma.user.upsert({
      where: { firebaseUid: identity.uid },
      update: {
        email: identity.email,
        // Only overwrite when Google actually provides a name, so a user's saved
        // name is never wiped by a token that happens to omit the claim.
        ...(identity.name ? { displayName: identity.name } : {}),
        avatarUrl: identity.picture,
      },
      create: {
        firebaseUid: identity.uid,
        email: identity.email,
        displayName: identity.name ?? fallbackName,
        avatarUrl: identity.picture,
        profile: { create: {} },
        wallet: { create: {} },
      },
    });

    if (isNew) {
      const bonus = await this.settings.signupBonusCredits();
      if (bonus > 0) {
        await this.credits.grant({
          userId: user.id,
          amount: bonus,
          type: CreditTxnType.signup_bonus,
          idempotencyKey: `signup_bonus:${user.id}`,
          note: 'Welcome bonus.',
        });
      }
    }

    const tokens = await this.issueTokens(user.id, user.firebaseUid);
    return {
      ...tokens,
      user: {
        id: user.id,
        display_name: user.displayName,
        avatar_url: user.avatarUrl,
        onboarding_completed: false,
      },
    };
  }

  async refresh(refreshToken: string): Promise<TokenPair> {
    try {
      const payload = await this.jwt.verifyAsync<{ sub: string; fuid: string; type: string }>(
        refreshToken,
        { secret: this.config.get<string>('JWT_REFRESH_SECRET') },
      );
      if (payload.type !== 'refresh') {
        throw AppException.unauthenticated('Wrong token type.');
      }
      // Rotation: a full implementation persists a refresh-token id and revokes
      // the old one here. The signing structure supports that without changing
      // the client contract.
      return this.issueTokens(payload.sub, payload.fuid);
    } catch (err) {
      if (err instanceof AppException) throw err;
      throw new AppException(ErrorCode.UNAUTHENTICATED, 'Invalid refresh token.', 401);
    }
  }

  private async issueTokens(userId: string, firebaseUid: string): Promise<TokenPair> {
    const accessTtl = this.config.get<string>('JWT_ACCESS_TTL') ?? '3600';
    const refreshTtl = this.config.get<string>('JWT_REFRESH_TTL') ?? '2592000';
    const access_token = await this.jwt.signAsync(
      { sub: userId, fuid: firebaseUid, type: 'access' },
      { secret: this.config.get<string>('JWT_ACCESS_SECRET'), expiresIn: Number(accessTtl) },
    );
    const refresh_token = await this.jwt.signAsync(
      { sub: userId, fuid: firebaseUid, type: 'refresh' },
      { secret: this.config.get<string>('JWT_REFRESH_SECRET'), expiresIn: Number(refreshTtl) },
    );
    return { access_token, refresh_token, expires_in: Number(accessTtl) };
  }
}
