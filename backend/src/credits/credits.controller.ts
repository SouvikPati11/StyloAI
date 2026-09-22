import { Controller, Get, Query, UseGuards } from '@nestjs/common';
import { CreditsService } from './credits.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { CurrentUser, AuthUser } from '../auth/current-user.decorator';

/**
 * GET /v1/wallet            -> balance + lifetime totals
 * GET /v1/wallet/transactions -> paginated ledger history (§7)
 */
@Controller('wallet')
@UseGuards(JwtAuthGuard)
export class CreditsController {
  constructor(private readonly credits: CreditsService) {}

  @Get()
  async wallet(@CurrentUser() user: AuthUser) {
    const balance = await this.credits.getBalance(user.userId);
    return { balance };
  }

  @Get('transactions')
  async transactions(
    @CurrentUser() user: AuthUser,
    @Query('limit') limit?: string,
    @Query('cursor') cursor?: string,
  ) {
    const take = Math.min(Math.max(parseInt(limit ?? '50', 10) || 50, 1), 100);
    return this.credits.history(user.userId, take, cursor);
  }
}
