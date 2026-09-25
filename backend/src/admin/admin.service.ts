import { Injectable } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import * as bcrypt from 'bcryptjs';
import {
  CreditTxnType,
  GenerationStatus,
  GenerationType,
  Prisma,
} from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { AppException } from '../common/app.exception';

const GENERATION_STATUSES = Object.values(GenerationStatus);
const GENERATION_TYPES = Object.values(GenerationType);
const CREDIT_TXN_TYPES = Object.values(CreditTxnType);

function clamp(value: number, min: number, max: number): number {
  return Math.min(Math.max(value, min), max);
}

@Injectable()
export class AdminService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly jwt: JwtService,
    private readonly config: ConfigService,
  ) {}

  async login(email: string, password: string) {
    const admin = await this.prisma.adminUser.findUnique({ where: { email } });
    if (!admin || !admin.isActive || !(await bcrypt.compare(password, admin.passwordHash))) {
      throw AppException.unauthenticated('Invalid admin credentials.');
    }
    await this.prisma.adminUser.update({
      where: { id: admin.id },
      data: { lastLoginAt: new Date() },
    });
    const access_token = await this.jwt.signAsync(
      { sub: admin.id, role: admin.role, type: 'admin' },
      { secret: this.config.get<string>('JWT_ACCESS_SECRET'), expiresIn: 60 * 60 * 8 },
    );
    return { access_token, admin: { id: admin.id, email: admin.email, role: admin.role } };
  }

  /** Dashboard aggregates — real DB counts, no mock data (docs/ADMIN_PANEL.md). */
  async stats() {
    const now = Date.now();
    const since30 = new Date(now - 30 * 24 * 60 * 60 * 1000);
    const since7 = new Date(now - 7 * 24 * 60 * 60 * 1000);

    const [users, generations, succeeded, failed, inProgress, purchases] =
      await Promise.all([
        this.prisma.user.count({ where: { status: { not: 'deleted' } } }),
        this.prisma.generation.count(),
        this.prisma.generation.count({
          where: { status: GenerationStatus.succeeded },
        }),
        this.prisma.generation.count({
          where: { status: GenerationStatus.failed },
        }),
        this.prisma.generation.count({
          where: {
            status: {
              in: [GenerationStatus.queued, GenerationStatus.processing],
            },
          },
        }),
        this.prisma.purchase.count({ where: { state: 'granted' } }),
      ]);

    const byType = await this.prisma.generation.groupBy({
      by: ['type'],
      _count: { _all: true },
    });

    // Active users = distinct users who created a generation in the last 30d.
    const activeGroups = await this.prisma.generation.groupBy({
      by: ['userId'],
      where: { createdAt: { gte: since30 } },
    });

    const [recentSignups, creditsAgg, recentUsers] = await Promise.all([
      this.prisma.user.count({
        where: { status: { not: 'deleted' }, createdAt: { gte: since7 } },
      }),
      this.prisma.creditWallet.aggregate({
        _sum: { lifetimeSpent: true, lifetimeEarned: true },
      }),
      this.prisma.user.findMany({
        where: { status: { not: 'deleted' } },
        orderBy: { createdAt: 'desc' },
        take: 8,
        include: { wallet: true },
      }),
    ]);

    return {
      users,
      active_users: activeGroups.length,
      recent_signups: recentSignups,
      generations: {
        total: generations,
        succeeded,
        failed,
        in_progress: inProgress,
      },
      generations_by_type: byType.map((g) => ({
        type: g.type,
        count: g._count._all,
      })),
      purchases_granted: purchases,
      credits_used: creditsAgg._sum.lifetimeSpent ?? 0,
      credits_earned: creditsAgg._sum.lifetimeEarned ?? 0,
      recent_users: recentUsers.map((u) => ({
        id: u.id,
        email: u.email,
        display_name: u.displayName,
        status: u.status,
        balance: u.wallet?.balance ?? 0,
        created_at: u.createdAt,
      })),
    };
  }

  /** Read-only global generation activity feed for the admin console. */
  async listGenerations(opts: {
    status?: string;
    type?: string;
    limit?: string;
    offset?: string;
  }) {
    const take = clamp(parseInt(opts.limit ?? '25', 10) || 25, 1, 100);
    const skip = Math.max(parseInt(opts.offset ?? '0', 10) || 0, 0);
    const where: Prisma.GenerationWhereInput = {};
    if (opts.status && GENERATION_STATUSES.includes(opts.status as GenerationStatus)) {
      where.status = opts.status as GenerationStatus;
    }
    if (opts.type && GENERATION_TYPES.includes(opts.type as GenerationType)) {
      where.type = opts.type as GenerationType;
    }
    const [total, rows] = await Promise.all([
      this.prisma.generation.count({ where }),
      this.prisma.generation.findMany({
        where,
        orderBy: { createdAt: 'desc' },
        take,
        skip,
        include: { user: { select: { email: true, displayName: true } } },
      }),
    ]);
    return {
      total,
      limit: take,
      offset: skip,
      items: rows.map((g) => ({
        id: g.id,
        type: g.type,
        mode: g.mode,
        status: g.status,
        credit_cost: g.creditCost,
        provider: g.provider,
        error_code: g.errorCode,
        created_at: g.createdAt,
        started_at: g.startedAt,
        finished_at: g.finishedAt,
        user_email: g.user?.email ?? null,
        user_name: g.user?.displayName ?? null,
      })),
    };
  }

  /** Read-only global credit-ledger feed for the admin console. */
  async listTransactions(opts: {
    type?: string;
    limit?: string;
    offset?: string;
  }) {
    const take = clamp(parseInt(opts.limit ?? '25', 10) || 25, 1, 100);
    const skip = Math.max(parseInt(opts.offset ?? '0', 10) || 0, 0);
    const where: Prisma.CreditTransactionWhereInput = {};
    if (opts.type && CREDIT_TXN_TYPES.includes(opts.type as CreditTxnType)) {
      where.type = opts.type as CreditTxnType;
    }
    const [total, rows] = await Promise.all([
      this.prisma.creditTransaction.count({ where }),
      this.prisma.creditTransaction.findMany({
        where,
        orderBy: { createdAt: 'desc' },
        take,
        skip,
        include: { user: { select: { email: true, displayName: true } } },
      }),
    ]);
    return {
      total,
      limit: take,
      offset: skip,
      items: rows.map((t) => ({
        id: t.id,
        amount: t.amount,
        balance_after: t.balanceAfter,
        type: t.type,
        status: t.status,
        note: t.note,
        created_at: t.createdAt,
        user_email: t.user?.email ?? null,
        user_name: t.user?.displayName ?? null,
      })),
    };
  }
}
