import { Injectable } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import * as bcrypt from 'bcryptjs';
import { GenerationStatus } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { AppException } from '../common/app.exception';

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
    const [users, generations, succeeded, failed, purchases] = await Promise.all([
      this.prisma.user.count({ where: { status: { not: 'deleted' } } }),
      this.prisma.generation.count(),
      this.prisma.generation.count({ where: { status: GenerationStatus.succeeded } }),
      this.prisma.generation.count({ where: { status: GenerationStatus.failed } }),
      this.prisma.purchase.count({ where: { state: 'granted' } }),
    ]);
    const byType = await this.prisma.generation.groupBy({
      by: ['type'],
      _count: { _all: true },
    });
    return {
      users,
      generations: { total: generations, succeeded, failed },
      generations_by_type: byType.map((g) => ({ type: g.type, count: g._count._all })),
      purchases_granted: purchases,
    };
  }
}
