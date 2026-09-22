import { Body, Controller, Get, HttpCode, Post, UseGuards } from '@nestjs/common';
import { IsNotEmpty, IsOptional, IsString } from 'class-validator';
import { BillingService } from './billing.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { CurrentUser, AuthUser } from '../auth/current-user.decorator';

class VerifyPurchaseDto {
  @IsString() @IsNotEmpty() product_id!: string;
  @IsString() @IsNotEmpty() purchase_token!: string;
  @IsOptional() @IsString() order_id?: string;
}

@Controller()
@UseGuards(JwtAuthGuard)
export class BillingController {
  constructor(private readonly billing: BillingService) {}

  /** GET /v1/store/products — credit packs (server-driven). */
  @Get('store/products')
  async products() {
    return { products: await this.billing.products() };
  }

  /** POST /v1/billing/google/verify — server-side Play verification + grant. */
  @Post('billing/google/verify')
  @HttpCode(200)
  async verify(@CurrentUser() user: AuthUser, @Body() dto: VerifyPurchaseDto) {
    return this.billing.verifyGooglePurchase({
      userId: user.userId,
      productId: dto.product_id,
      purchaseToken: dto.purchase_token,
      orderId: dto.order_id,
    });
  }
}
