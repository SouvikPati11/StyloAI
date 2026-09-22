import { Body, Controller, Delete, Get, Param, Post, Query, UseGuards } from '@nestjs/common';
import { IsOptional, IsString, IsUUID, MaxLength } from 'class-validator';
import { PrismaService } from '../prisma/prisma.service';
import { StorageService } from '../storage/storage.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { CurrentUser, AuthUser } from '../auth/current-user.decorator';
import { AppException } from '../common/app.exception';

class SaveLookDto {
  @IsUUID() generated_image_id!: string;
  @IsOptional() @IsString() @MaxLength(80) title?: string;
}

/** Saved Looks (§19). */
@Controller('looks')
@UseGuards(JwtAuthGuard)
export class LooksController {
  constructor(
    private readonly prisma: PrismaService,
    private readonly storage: StorageService,
  ) {}

  @Post()
  async save(@CurrentUser() user: AuthUser, @Body() dto: SaveLookDto) {
    const image = await this.prisma.generatedImage.findFirst({
      where: { id: dto.generated_image_id, userId: user.userId, deletedAt: null },
    });
    if (!image) throw AppException.notFound('Image not found.');
    const look = await this.prisma.savedLook.upsert({
      where: {
        userId_generatedImageId: {
          userId: user.userId,
          generatedImageId: dto.generated_image_id,
        },
      },
      update: { title: dto.title, deletedAt: null },
      create: { userId: user.userId, generatedImageId: dto.generated_image_id, title: dto.title },
    });
    return { id: look.id, saved: true };
  }

  @Get()
  async list(
    @CurrentUser() user: AuthUser,
    @Query('limit') limit?: string,
    @Query('cursor') cursor?: string,
  ) {
    const take = Math.min(Math.max(parseInt(limit ?? '30', 10) || 30, 1), 50);
    const rows = await this.prisma.savedLook.findMany({
      where: { userId: user.userId, deletedAt: null },
      orderBy: { createdAt: 'desc' },
      take: take + 1,
      ...(cursor ? { cursor: { id: cursor }, skip: 1 } : {}),
      include: { image: true },
    });
    const hasMore = rows.length > take;
    const items = hasMore ? rows.slice(0, take) : rows;
    const mapped = await Promise.all(
      items.map(async (l) => ({
        id: l.id,
        title: l.title,
        image_url: await this.storage.presignDownload(l.image.s3Key),
        created_at: l.createdAt,
      })),
    );
    return { items: mapped, next_cursor: hasMore ? items[items.length - 1].id : null };
  }

  @Delete(':id')
  async remove(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    const look = await this.prisma.savedLook.findFirst({ where: { id, userId: user.userId } });
    if (!look) throw AppException.notFound('Saved look not found.');
    await this.prisma.savedLook.update({ where: { id }, data: { deletedAt: new Date() } });
    return { deleted: true };
  }
}
