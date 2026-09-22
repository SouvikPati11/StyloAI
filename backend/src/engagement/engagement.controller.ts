import { Body, Controller, Delete, Get, Param, Post, Query, UseGuards } from '@nestjs/common';
import { IsNotEmpty, IsString } from 'class-validator';
import { PrismaService } from '../prisma/prisma.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { CurrentUser, AuthUser } from '../auth/current-user.decorator';

class RegisterDeviceDto {
  @IsString() @IsNotEmpty() fcm_token!: string;
}

/** FCM device registration + in-app notification inbox (§10, §19). */
@Controller()
@UseGuards(JwtAuthGuard)
export class EngagementController {
  constructor(private readonly prisma: PrismaService) {}

  @Post('devices')
  async register(@CurrentUser() user: AuthUser, @Body() dto: RegisterDeviceDto) {
    await this.prisma.device.upsert({
      where: { fcmToken: dto.fcm_token },
      update: { userId: user.userId, lastSeenAt: new Date() },
      create: { userId: user.userId, fcmToken: dto.fcm_token },
    });
    return { registered: true };
  }

  @Delete('devices/:token')
  async unregister(@CurrentUser() user: AuthUser, @Param('token') token: string) {
    await this.prisma.device
      .deleteMany({ where: { fcmToken: token, userId: user.userId } })
      .catch(() => undefined);
    return { deleted: true };
  }

  @Get('notifications')
  async list(
    @CurrentUser() user: AuthUser,
    @Query('limit') limit?: string,
    @Query('cursor') cursor?: string,
  ) {
    const take = Math.min(Math.max(parseInt(limit ?? '30', 10) || 30, 1), 50);
    const rows = await this.prisma.notification.findMany({
      where: { userId: user.userId },
      orderBy: { createdAt: 'desc' },
      take: take + 1,
      ...(cursor ? { cursor: { id: cursor }, skip: 1 } : {}),
    });
    const hasMore = rows.length > take;
    const items = hasMore ? rows.slice(0, take) : rows;
    return {
      items: items.map((n) => ({
        id: n.id,
        type: n.type,
        title: n.title,
        body: n.body,
        data: n.data,
        read: !!n.readAt,
        created_at: n.createdAt,
      })),
      next_cursor: hasMore ? items[items.length - 1].id : null,
    };
  }

  @Post('notifications/:id/read')
  async markRead(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    await this.prisma.notification
      .updateMany({ where: { id, userId: user.userId }, data: { readAt: new Date() } })
      .catch(() => undefined);
    return { read: true };
  }
}
