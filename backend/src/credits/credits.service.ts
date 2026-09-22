import { Injectable, Logger } from '@nestjs/common';
import { CreditTxnStatus, CreditTxnType, Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { AppException } from '../common/app.exception';

/**
 * Authoritative credit ledger. `credit_transactions` is append-only and is the
 * source of truth; `credit_wallets.balance` is a cached projection that is
 * updated ONLY inside the same DB transaction that appends a ledger row.
 *
 * Spend lifecycle: hold (pending, -cost) -> settle (committed) | refund
 * (reverse hold + compensating +cost row). Idempotency keys make every mutation
 * safe to retry. See docs/CREDITS_AND_BILLING.md.
 */
@Injectable()
export class CreditsService {
  private readonly logger = new Logger(CreditsService.name);

  constructor(private readonly prisma: PrismaService) {}

  /** Ensure a wallet exists for a user (called on signup). */
  async ensureWallet(userId: string, tx?: Prisma.TransactionClient) {
    const client = tx ?? this.prisma;
    return client.creditWallet.upsert({
      where: { userId },
      update: {},
      create: { userId },
    });
  }

  async getBalance(userId: string): Promise<number> {
    const wallet = await this.prisma.creditWallet.findUnique({ where: { userId } });
    return wallet?.balance ?? 0;
  }

  /**
   * Grant credits (signup bonus, admin grant, promo, purchase). Positive amount.
   * If an idempotencyKey is provided and already used, the existing grant is
   * returned without double-applying.
   */
  async grant(params: {
    userId: string;
    amount: number;
    type: CreditTxnType;
    idempotencyKey?: string;
    purchaseId?: string;
    note?: string;
    tx?: Prisma.TransactionClient;
  }) {
    if (params.amount <= 0) {
      throw AppException.validation('Grant amount must be positive.');
    }
    const run = async (client: Prisma.TransactionClient) => {
      if (params.idempotencyKey) {
        const existing = await client.creditTransaction.findUnique({
          where: { idempotencyKey: params.idempotencyKey },
        });
        if (existing) return existing;
      }
      const wallet = await client.creditWallet.upsert({
        where: { userId: params.userId },
        update: {},
        create: { userId: params.userId },
      });
      const newBalance = wallet.balance + params.amount;
      await client.creditWallet.update({
        where: { id: wallet.id },
        data: { balance: newBalance, lifetimeEarned: { increment: params.amount } },
      });
      return client.creditTransaction.create({
        data: {
          walletId: wallet.id,
          userId: params.userId,
          amount: params.amount,
          balanceAfter: newBalance,
          type: params.type,
          status: CreditTxnStatus.committed,
          idempotencyKey: params.idempotencyKey,
          purchaseId: params.purchaseId,
          note: params.note,
        },
      });
    };
    return params.tx ? run(params.tx) : this.prisma.$transaction(run);
  }

  /**
   * Place a hold for a generation: appends a pending `generation_hold` row of
   * -cost and decrements the wallet, atomically. Rejects when balance < cost.
   * Idempotent on idempotencyKey (a retried submit returns the original hold).
   */
  async hold(params: {
    userId: string;
    amount: number; // positive cost
    generationId: string;
    idempotencyKey: string;
  }) {
    if (params.amount < 0) throw AppException.validation('Hold amount must be non-negative.');
    return this.prisma.$transaction(async (client) => {
      const existing = await client.creditTransaction.findUnique({
        where: { idempotencyKey: params.idempotencyKey },
      });
      if (existing) return existing;

      const wallet = await client.creditWallet.findUnique({ where: { userId: params.userId } });
      if (!wallet || wallet.balance < params.amount) {
        throw AppException.insufficientCredits(params.amount, wallet?.balance ?? 0);
      }
      const newBalance = wallet.balance - params.amount;
      await client.creditWallet.update({
        where: { id: wallet.id },
        data: { balance: newBalance, lifetimeSpent: { increment: params.amount } },
      });
      return client.creditTransaction.create({
        data: {
          walletId: wallet.id,
          userId: params.userId,
          amount: -params.amount,
          balanceAfter: newBalance,
          type: CreditTxnType.generation_hold,
          status: CreditTxnStatus.pending,
          generationId: params.generationId,
          idempotencyKey: params.idempotencyKey,
        },
      });
    });
  }

  /** Settle a successful generation: the pending hold becomes committed. */
  async settle(generationId: string) {
    return this.prisma.creditTransaction.updateMany({
      where: {
        generationId,
        type: CreditTxnType.generation_hold,
        status: CreditTxnStatus.pending,
      },
      data: { status: CreditTxnStatus.committed },
    });
  }

  /**
   * Refund an eligible failed generation: reverse the pending hold and append a
   * compensating `generation_refund` (+cost), restoring the wallet. Idempotent:
   * if the hold is not pending, nothing happens.
   */
  async refund(params: { userId: string; generationId: string; reason?: string }) {
    return this.prisma.$transaction(async (client) => {
      const hold = await client.creditTransaction.findFirst({
        where: {
          generationId: params.generationId,
          type: CreditTxnType.generation_hold,
          status: CreditTxnStatus.pending,
        },
      });
      if (!hold) return null; // already settled/refunded — idempotent no-op

      await client.creditTransaction.update({
        where: { id: hold.id },
        data: { status: CreditTxnStatus.reversed },
      });

      const amount = Math.abs(hold.amount);
      const wallet = await client.creditWallet.update({
        where: { id: hold.walletId },
        data: { balance: { increment: amount }, lifetimeSpent: { decrement: amount } },
      });

      return client.creditTransaction.create({
        data: {
          walletId: hold.walletId,
          userId: params.userId,
          amount,
          balanceAfter: wallet.balance,
          type: CreditTxnType.generation_refund,
          status: CreditTxnStatus.committed,
          generationId: params.generationId,
          note: params.reason ?? 'Automatic refund for failed generation.',
        },
      });
    });
  }

  async history(userId: string, limit = 50, cursor?: string) {
    const rows = await this.prisma.creditTransaction.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
      take: limit + 1,
      ...(cursor ? { cursor: { id: cursor }, skip: 1 } : {}),
    });
    const hasMore = rows.length > limit;
    const items = hasMore ? rows.slice(0, limit) : rows;
    return { items, next_cursor: hasMore ? items[items.length - 1].id : null };
  }
}
