import {
  Body,
  Controller,
  Delete,
  Get,
  Headers,
  HttpCode,
  Param,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import { GenerationType } from '@prisma/client';
import { GenerationsService } from './generations.service';
import { CreateGenerationDto } from './dto';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { CurrentUser, AuthUser } from '../auth/current-user.decorator';

@Controller('generations')
@UseGuards(JwtAuthGuard)
export class GenerationsController {
  constructor(private readonly generations: GenerationsService) {}

  @Post()
  @HttpCode(202)
  async create(
    @CurrentUser() user: AuthUser,
    @Body() dto: CreateGenerationDto,
    @Headers('idempotency-key') headerKey?: string,
  ) {
    const idempotencyKey =
      headerKey || dto.idempotency_key || GenerationsService.newIdempotencyKey();
    return this.generations.submit(user.userId, dto, idempotencyKey);
  }

  @Get(':id')
  async get(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.generations.get(user.userId, id);
  }

  @Get()
  async list(
    @CurrentUser() user: AuthUser,
    @Query('type') type?: GenerationType,
    @Query('limit') limit?: string,
    @Query('cursor') cursor?: string,
  ) {
    const take = Math.min(Math.max(parseInt(limit ?? '20', 10) || 20, 1), 50);
    return this.generations.list(user.userId, type, take, cursor);
  }

  @Delete(':id')
  async remove(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.generations.remove(user.userId, id);
  }
}
