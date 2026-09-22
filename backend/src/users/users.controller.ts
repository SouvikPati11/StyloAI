import { Body, Controller, Get, Patch, UseGuards } from '@nestjs/common';
import { IsBoolean, IsOptional, IsString, MaxLength } from 'class-validator';
import { PrismaService } from '../prisma/prisma.service';
import { CreditsService } from '../credits/credits.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { CurrentUser, AuthUser } from '../auth/current-user.decorator';
import { AppException } from '../common/app.exception';

class UpdateMeDto {
  @IsOptional() @IsString() @MaxLength(80) display_name?: string;
  @IsOptional() @IsBoolean() notif_generation?: boolean;
  @IsOptional() @IsBoolean() notif_trending?: boolean;
  @IsOptional() @IsBoolean() notif_marketing?: boolean;
  @IsOptional() @IsBoolean() onboarding_completed?: boolean;
}

/** GET/PATCH /v1/me — profile + wallet balance + flags. */
@Controller('me')
@UseGuards(JwtAuthGuard)
export class UsersController {
  constructor(
    private readonly prisma: PrismaService,
    private readonly credits: CreditsService,
  ) {}

  @Get()
  async me(@CurrentUser() user: AuthUser) {
    const record = await this.prisma.user.findUnique({
      where: { id: user.userId },
      include: { profile: true },
    });
    if (!record) throw AppException.notFound('User not found.');
    const balance = await this.credits.getBalance(user.userId);
    return {
      id: record.id,
      display_name: record.displayName,
      email: record.email,
      avatar_url: record.avatarUrl,
      balance,
      onboarding_completed: record.profile?.onboardingCompleted ?? false,
      notifications: {
        generation: record.profile?.notifGeneration ?? true,
        trending: record.profile?.notifTrending ?? true,
        marketing: record.profile?.notifMarketing ?? false,
      },
    };
  }

  @Patch()
  async update(@CurrentUser() user: AuthUser, @Body() dto: UpdateMeDto) {
    if (dto.display_name !== undefined) {
      await this.prisma.user.update({
        where: { id: user.userId },
        data: { displayName: dto.display_name },
      });
    }
    const profileData: Record<string, boolean> = {};
    if (dto.notif_generation !== undefined) profileData.notifGeneration = dto.notif_generation;
    if (dto.notif_trending !== undefined) profileData.notifTrending = dto.notif_trending;
    if (dto.notif_marketing !== undefined) profileData.notifMarketing = dto.notif_marketing;
    if (dto.onboarding_completed !== undefined)
      profileData.onboardingCompleted = dto.onboarding_completed;
    if (Object.keys(profileData).length > 0) {
      await this.prisma.userProfile.upsert({
        where: { userId: user.userId },
        update: profileData,
        create: { userId: user.userId, ...profileData },
      });
    }
    return this.me(user);
  }
}
