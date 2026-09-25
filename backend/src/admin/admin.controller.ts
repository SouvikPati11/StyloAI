import { Body, Controller, Get, HttpCode, Param, Post, Put, Query, UseGuards } from '@nestjs/common';
import { IsEmail, IsInt, IsNotEmpty, IsOptional, IsString, Min } from 'class-validator';
import { AdminRole, CreditTxnType } from '@prisma/client';
import { AdminService } from './admin.service';
import { AdminAuthGuard, Roles, CurrentAdmin, AdminPrincipal } from './admin-auth.guard';
import { PrismaService } from '../prisma/prisma.service';
import { SettingsService } from '../settings/settings.service';
import { CreditsService } from '../credits/credits.service';
import { AppException } from '../common/app.exception';

class AdminLoginDto {
  @IsEmail() email!: string;
  @IsString() @IsNotEmpty() password!: string;
}

class UpdateSettingDto {
  // value is arbitrary JSON validated per-key by the admin UI
  value!: unknown;
}

class GrantCreditsDto {
  @IsInt() @Min(1) amount!: number;
  @IsOptional() @IsString() note?: string;
}

@Controller('admin')
export class AdminController {
  constructor(
    private readonly admin: AdminService,
    private readonly prisma: PrismaService,
    private readonly settings: SettingsService,
    private readonly credits: CreditsService,
  ) {}

  @Post('auth/login')
  @HttpCode(200)
  login(@Body() dto: AdminLoginDto) {
    return this.admin.login(dto.email, dto.password);
  }

  @Get('stats')
  @UseGuards(AdminAuthGuard)
  stats() {
    return this.admin.stats();
  }

  /** Read-only global generation activity (filter by status/type). */
  @Get('generations')
  @UseGuards(AdminAuthGuard)
  listGenerations(
    @Query('status') status?: string,
    @Query('type') type?: string,
    @Query('limit') limit?: string,
    @Query('offset') offset?: string,
  ) {
    return this.admin.listGenerations({ status, type, limit, offset });
  }

  /** Read-only global credit-ledger feed (filter by type). */
  @Get('transactions')
  @UseGuards(AdminAuthGuard)
  listTransactions(
    @Query('type') type?: string,
    @Query('limit') limit?: string,
    @Query('offset') offset?: string,
  ) {
    return this.admin.listTransactions({ type, limit, offset });
  }

  @Get('settings')
  @UseGuards(AdminAuthGuard)
  async listSettings() {
    return this.prisma.systemSetting.findMany({ orderBy: { key: 'asc' } });
  }

  @Put('settings/:key')
  @UseGuards(AdminAuthGuard)
  @Roles(AdminRole.super_admin, AdminRole.admin)
  async updateSetting(
    @Param('key') key: string,
    @Body() dto: UpdateSettingDto,
    @CurrentAdmin() admin: AdminPrincipal,
  ) {
    const row = await this.prisma.systemSetting.upsert({
      where: { key },
      update: { value: dto.value as object, updatedBy: admin.adminId },
      create: { key, value: dto.value as object, updatedBy: admin.adminId },
    });
    this.settings.invalidate(key);
    return row;
  }

  /** Securely add credits via a ledger grant (never a raw balance edit). */
  @Post('users/:id/credits')
  @UseGuards(AdminAuthGuard)
  @Roles(AdminRole.super_admin, AdminRole.admin)
  async grantCredits(
    @Param('id') userId: string,
    @Body() dto: GrantCreditsDto,
    @CurrentAdmin() admin: AdminPrincipal,
  ) {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) throw AppException.notFound('User not found.');
    const txn = await this.credits.grant({
      userId,
      amount: dto.amount,
      type: CreditTxnType.admin_grant,
      note: `${dto.note ?? 'Admin grant'} (by ${admin.adminId})`,
    });
    return { granted: dto.amount, balance: txn.balanceAfter };
  }
}
