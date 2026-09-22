import { Controller, Get, Param, Query, UseGuards } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { CreditsService } from '../credits/credits.service';
import { AdminAuthGuard } from './admin-auth.guard';
import { AppException } from '../common/app.exception';

/** Admin user management — search, view, credits, generations, transactions. */
@Controller('admin/users')
@UseGuards(AdminAuthGuard)
export class AdminUsersController {
  constructor(
    private readonly prisma: PrismaService,
    private readonly credits: CreditsService,
  ) {}

  @Get()
  async search(@Query('q') q?: string, @Query('limit') limit?: string) {
    const take = Math.min(Math.max(parseInt(limit ?? '25', 10) || 25, 1), 100);
    const rows = await this.prisma.user.findMany({
      where: q
        ? {
            OR: [
              { email: { contains: q, mode: 'insensitive' } },
              { displayName: { contains: q, mode: 'insensitive' } },
            ],
          }
        : {},
      orderBy: { createdAt: 'desc' },
      take,
      include: { wallet: true },
    });
    return rows.map((u) => ({
      id: u.id,
      email: u.email,
      display_name: u.displayName,
      status: u.status,
      balance: u.wallet?.balance ?? 0,
      created_at: u.createdAt,
    }));
  }

  @Get(':id')
  async detail(@Param('id') id: string) {
    const user = await this.prisma.user.findUnique({
      where: { id },
      include: { wallet: true, profile: true, styleProfile: true },
    });
    if (!user) throw AppException.notFound('User not found.');
    const [generations, transactions] = await Promise.all([
      this.prisma.generation.findMany({
        where: { userId: id },
        orderBy: { createdAt: 'desc' },
        take: 20,
      }),
      this.prisma.creditTransaction.findMany({
        where: { userId: id },
        orderBy: { createdAt: 'desc' },
        take: 30,
      }),
    ]);
    return {
      id: user.id,
      email: user.email,
      display_name: user.displayName,
      status: user.status,
      balance: user.wallet?.balance ?? 0,
      lifetime_earned: user.wallet?.lifetimeEarned ?? 0,
      lifetime_spent: user.wallet?.lifetimeSpent ?? 0,
      created_at: user.createdAt,
      generations: generations.map((g) => ({
        id: g.id,
        type: g.type,
        status: g.status,
        credit_cost: g.creditCost,
        created_at: g.createdAt,
      })),
      transactions: transactions.map((t) => ({
        id: t.id,
        amount: t.amount,
        balance_after: t.balanceAfter,
        type: t.type,
        status: t.status,
        note: t.note,
        created_at: t.createdAt,
      })),
    };
  }
}
