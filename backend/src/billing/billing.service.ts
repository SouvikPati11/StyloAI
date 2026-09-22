import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { GoogleAuth } from 'google-auth-library';
import { CreditTxnType, PurchaseState } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { CreditsService } from '../credits/credits.service';
import { SettingsService } from '../settings/settings.service';
import { AppException } from '../common/app.exception';
import { ErrorCode } from '../common/error-codes';

export interface StoreProduct {
  product_id: string;
  credits: number;
  title: string;
  price_hint?: string;
  bonus?: number;
}

const DEFAULT_PRODUCTS: StoreProduct[] = [
  { product_id: 'credits_50', credits: 50, title: 'Starter', price_hint: '$4.99' },
  { product_id: 'credits_120', credits: 120, title: 'Popular', price_hint: '$9.99', bonus: 10 },
  { product_id: 'credits_300', credits: 300, title: 'Pro', price_hint: '$19.99', bonus: 40 },
];

/**
 * Google Play billing. Purchases are verified SERVER-SIDE against the Play
 * Developer API before any credit is granted; the client's "success" is never
 * trusted. A purchase_token grants credits at most once (unique row). If the
 * Play service account is not configured, we DO NOT grant credits and return a
 * clearly-typed configuration error — never a fake success.
 * See docs/CREDITS_AND_BILLING.md §3.
 */
@Injectable()
export class BillingService {
  private readonly logger = new Logger(BillingService.name);
  private auth?: GoogleAuth;
  private readonly packageName?: string;

  constructor(
    private readonly prisma: PrismaService,
    private readonly credits: CreditsService,
    private readonly settings: SettingsService,
    private readonly config: ConfigService,
  ) {
    this.packageName = this.config.get<string>('PLAY_PACKAGE_NAME');
    const raw = this.config.get<string>('PLAY_SERVICE_ACCOUNT_JSON');
    if (raw && this.packageName) {
      try {
        const credentials = JSON.parse(raw);
        this.auth = new GoogleAuth({
          credentials,
          scopes: ['https://www.googleapis.com/auth/androidpublisher'],
        });
        this.logger.log('Play Developer API configured.');
      } catch (err) {
        this.logger.error('Failed to parse PLAY_SERVICE_ACCOUNT_JSON.', err as Error);
      }
    } else {
      this.logger.warn(
        'Play billing verification not configured (PLAY_SERVICE_ACCOUNT_JSON / PLAY_PACKAGE_NAME). ' +
          'Purchases will be rejected with PAYMENT_INVALID until configured.',
      );
    }
  }

  get isConfigured(): boolean {
    return !!this.auth;
  }

  async products(): Promise<StoreProduct[]> {
    return this.settings.get<StoreProduct[]>('store_products', DEFAULT_PRODUCTS);
  }

  async verifyGooglePurchase(params: {
    userId: string;
    productId: string;
    purchaseToken: string;
    orderId?: string;
  }) {
    // Idempotency: a token grants at most once.
    const existing = await this.prisma.purchase.findUnique({
      where: { purchaseToken: params.purchaseToken },
    });
    if (existing?.state === PurchaseState.granted) {
      if (existing.userId !== params.userId) {
        throw AppException.conflict(
          ErrorCode.PURCHASE_ALREADY_CLAIMED,
          'This purchase has already been claimed.',
        );
      }
      const balance = await this.credits.getBalance(params.userId);
      return { granted: true, credits_added: existing.creditsGranted, balance };
    }

    const products = await this.products();
    const product = products.find((p) => p.product_id === params.productId);
    if (!product) {
      throw AppException.validation('Unknown product.', { product_id: params.productId });
    }
    const creditsToGrant = product.credits + (product.bonus ?? 0);

    // Verify against Play. If not configured, record pending and reject clearly.
    if (!this.auth || !this.packageName) {
      await this.recordPurchase(params, PurchaseState.pending, 0, {
        note: 'Play verification not configured on server.',
      });
      throw new AppException(
        ErrorCode.PAYMENT_INVALID,
        'Purchase verification is not configured on the server yet.',
        503,
        { reason: 'play_not_configured' },
      );
    }

    const verification = await this.callPlayApi(params.productId, params.purchaseToken);
    // purchaseState: 0 = purchased, 1 = canceled, 2 = pending
    if (verification.purchaseState !== 0) {
      await this.recordPurchase(params, PurchaseState.invalid, 0, verification);
      throw new AppException(
        ErrorCode.PAYMENT_INVALID,
        'Purchase is not in a purchased state.',
        402,
        {
          purchase_state: verification.purchaseState,
        },
      );
    }

    // Grant once, atomically with the purchase row.
    const result = await this.prisma.$transaction(async (tx) => {
      const purchase = await tx.purchase.upsert({
        where: { purchaseToken: params.purchaseToken },
        update: {
          state: PurchaseState.granted,
          creditsGranted: creditsToGrant,
          verifiedAt: new Date(),
          rawVerification: verification as object,
          orderId: params.orderId ?? verification.orderId,
        },
        create: {
          userId: params.userId,
          productId: params.productId,
          purchaseToken: params.purchaseToken,
          orderId: params.orderId ?? verification.orderId,
          creditsGranted: creditsToGrant,
          state: PurchaseState.granted,
          verifiedAt: new Date(),
          rawVerification: verification as object,
        },
      });
      const txn = await this.credits.grant({
        userId: params.userId,
        amount: creditsToGrant,
        type: CreditTxnType.purchase,
        idempotencyKey: `purchase:${params.purchaseToken}`,
        purchaseId: purchase.id,
        note: `Purchase ${params.productId}`,
        tx,
      });
      return { balance: txn.balanceAfter };
    });

    // Best-effort acknowledge so Play does not auto-refund.
    this.acknowledge(params.productId, params.purchaseToken).catch((err) =>
      this.logger.warn(`Failed to acknowledge purchase: ${(err as Error).message}`),
    );

    return { granted: true, credits_added: creditsToGrant, balance: result.balance };
  }

  private async recordPurchase(
    params: { userId: string; productId: string; purchaseToken: string; orderId?: string },
    state: PurchaseState,
    creditsGranted: number,
    raw: unknown,
  ) {
    await this.prisma.purchase
      .upsert({
        where: { purchaseToken: params.purchaseToken },
        update: { state, rawVerification: raw as object },
        create: {
          userId: params.userId,
          productId: params.productId,
          purchaseToken: params.purchaseToken,
          orderId: params.orderId,
          creditsGranted,
          state,
          rawVerification: raw as object,
        },
      })
      .catch(() => undefined);
  }

  private async callPlayApi(
    productId: string,
    token: string,
  ): Promise<{ purchaseState?: number; orderId?: string; acknowledgementState?: number }> {
    const client = await this.auth!.getClient();
    const url =
      `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/` +
      `${this.packageName}/purchases/products/${productId}/tokens/${token}`;
    try {
      const res = await client.request<{
        purchaseState?: number;
        orderId?: string;
        acknowledgementState?: number;
      }>({ url });
      return res.data;
    } catch (err) {
      this.logger.warn(`Play API verification failed: ${(err as Error).message}`);
      throw new AppException(
        ErrorCode.PAYMENT_INVALID,
        'Could not verify purchase with Google Play.',
        402,
      );
    }
  }

  private async acknowledge(productId: string, token: string) {
    if (!this.auth || !this.packageName) return;
    const client = await this.auth.getClient();
    const url =
      `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/` +
      `${this.packageName}/purchases/products/${productId}/tokens/${token}:acknowledge`;
    await client.request({ url, method: 'POST', data: {} });
  }
}
