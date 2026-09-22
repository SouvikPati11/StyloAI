/* eslint-disable @typescript-eslint/no-explicit-any -- in-memory Prisma fake mirrors loosely-typed query args */
import { CreditsService } from './credits.service';
import { CreditTxnStatus, CreditTxnType } from '@prisma/client';
import { AppException } from '../common/app.exception';
import { ErrorCode } from '../common/error-codes';

/**
 * Unit tests for the credit ledger's invariants using an in-memory fake of the
 * Prisma client. Verifies: grants increase balance, holds reject overspend and
 * are idempotent, and refunds reverse a pending hold exactly once.
 */
type Wallet = {
  id: string;
  userId: string;
  balance: number;
  lifetimeEarned: number;
  lifetimeSpent: number;
};
type Txn = {
  id: string;
  walletId: string;
  userId: string;
  amount: number;
  balanceAfter: number;
  type: CreditTxnType;
  status: CreditTxnStatus;
  generationId?: string | null;
  idempotencyKey?: string | null;
  note?: string | null;
};

class FakePrisma {
  wallets: Wallet[] = [];
  txns: Txn[] = [];
  private seq = 0;
  private id() {
    this.seq += 1;
    return `id_${this.seq}`;
  }

  creditWallet = {
    findUnique: async ({ where }: any) =>
      this.wallets.find((w) => (where.userId ? w.userId === where.userId : w.id === where.id)) ??
      null,
    upsert: async ({ where, create }: any) => {
      let w = this.wallets.find((x) => x.userId === where.userId);
      if (!w) {
        w = {
          id: this.id(),
          userId: create.userId,
          balance: 0,
          lifetimeEarned: 0,
          lifetimeSpent: 0,
        };
        this.wallets.push(w);
      }
      return w;
    },
    update: async ({ where, data }: any) => {
      const w = this.wallets.find((x) => x.id === where.id)!;
      if (typeof data.balance === 'number') w.balance = data.balance;
      if (data.balance?.increment) w.balance += data.balance.increment;
      if (data.lifetimeEarned?.increment) w.lifetimeEarned += data.lifetimeEarned.increment;
      if (data.lifetimeSpent?.increment) w.lifetimeSpent += data.lifetimeSpent.increment;
      if (data.lifetimeSpent?.decrement) w.lifetimeSpent -= data.lifetimeSpent.decrement;
      return w;
    },
  };

  creditTransaction = {
    findUnique: async ({ where }: any) =>
      this.txns.find((t) => t.idempotencyKey === where.idempotencyKey) ?? null,
    findFirst: async ({ where }: any) =>
      this.txns.find(
        (t) =>
          t.generationId === where.generationId &&
          t.type === where.type &&
          t.status === where.status,
      ) ?? null,
    create: async ({ data }: any) => {
      const t: Txn = { id: this.id(), ...data };
      this.txns.push(t);
      return t;
    },
    update: async ({ where, data }: any) => {
      const t = this.txns.find((x) => x.id === where.id)!;
      Object.assign(t, data);
      return t;
    },
    updateMany: async ({ where, data }: any) => {
      let count = 0;
      for (const t of this.txns) {
        if (
          t.generationId === where.generationId &&
          t.type === where.type &&
          t.status === where.status
        ) {
          Object.assign(t, data);
          count += 1;
        }
      }
      return { count };
    },
  };

  async $transaction(fn: any) {
    return fn(this);
  }
}

describe('CreditsService', () => {
  let prisma: FakePrisma;
  let credits: CreditsService;
  const userId = 'user_1';

  beforeEach(() => {
    prisma = new FakePrisma();
    credits = new CreditsService(prisma as any);
  });

  it('grants credits and increases balance', async () => {
    await credits.grant({ userId, amount: 20, type: CreditTxnType.signup_bonus });
    expect(await credits.getBalance(userId)).toBe(20);
  });

  it('is idempotent on grant idempotencyKey', async () => {
    await credits.grant({
      userId,
      amount: 20,
      type: CreditTxnType.signup_bonus,
      idempotencyKey: 'k1',
    });
    await credits.grant({
      userId,
      amount: 20,
      type: CreditTxnType.signup_bonus,
      idempotencyKey: 'k1',
    });
    expect(await credits.getBalance(userId)).toBe(20);
  });

  it('rejects a hold that exceeds balance', async () => {
    await credits.grant({ userId, amount: 3, type: CreditTxnType.signup_bonus });
    await expect(
      credits.hold({ userId, amount: 4, generationId: 'g1', idempotencyKey: 'h1' }),
    ).rejects.toMatchObject({ code: ErrorCode.INSUFFICIENT_CREDITS });
    expect(await credits.getBalance(userId)).toBe(3);
  });

  it('holds and settles, consuming credits', async () => {
    await credits.grant({ userId, amount: 10, type: CreditTxnType.signup_bonus });
    await credits.hold({ userId, amount: 4, generationId: 'g1', idempotencyKey: 'h1' });
    expect(await credits.getBalance(userId)).toBe(6);
    await credits.settle('g1');
    const hold = prisma.txns.find((t) => t.type === CreditTxnType.generation_hold);
    expect(hold?.status).toBe(CreditTxnStatus.committed);
    expect(await credits.getBalance(userId)).toBe(6);
  });

  it('is idempotent on hold idempotencyKey (no double charge)', async () => {
    await credits.grant({ userId, amount: 10, type: CreditTxnType.signup_bonus });
    await credits.hold({ userId, amount: 4, generationId: 'g1', idempotencyKey: 'h1' });
    await credits.hold({ userId, amount: 4, generationId: 'g1', idempotencyKey: 'h1' });
    expect(await credits.getBalance(userId)).toBe(6);
  });

  it('refunds a pending hold exactly once', async () => {
    await credits.grant({ userId, amount: 10, type: CreditTxnType.signup_bonus });
    await credits.hold({ userId, amount: 4, generationId: 'g1', idempotencyKey: 'h1' });
    await credits.refund({ userId, generationId: 'g1' });
    expect(await credits.getBalance(userId)).toBe(10);
    // second refund is a no-op
    const second = await credits.refund({ userId, generationId: 'g1' });
    expect(second).toBeNull();
    expect(await credits.getBalance(userId)).toBe(10);
  });

  it('throws AppException on non-positive grant', async () => {
    await expect(
      credits.grant({ userId, amount: 0, type: CreditTxnType.admin_grant }),
    ).rejects.toBeInstanceOf(AppException);
  });
});
