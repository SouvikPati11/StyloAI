import { Body, Controller, Get, Put, UseGuards } from '@nestjs/common';
import { IsArray, IsOptional, IsString } from 'class-validator';
import { StyleProfileSource } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { CurrentUser, AuthUser } from '../auth/current-user.decorator';

class StyleProfileDto {
  @IsOptional() @IsArray() @IsString({ each: true }) preferred_styles?: string[];
  @IsOptional() @IsArray() @IsString({ each: true }) favorite_colors?: string[];
  @IsOptional() @IsArray() @IsString({ each: true }) style_interests?: string[];
  @IsOptional() @IsArray() @IsString({ each: true }) hair_preferences?: string[];
  @IsOptional() @IsArray() @IsString({ each: true }) glasses_preferences?: string[];
  @IsOptional() @IsArray() @IsString({ each: true }) occasion_preferences?: string[];
}

/**
 * Personal Style Profile (§5). User-provided preferences (source='user').
 * AI-derived suggestions are stored separately with source='ai' and surfaced as
 * suggestions, never silently mixed with user input.
 */
@Controller('me/style-profile')
@UseGuards(JwtAuthGuard)
export class StyleProfileController {
  constructor(private readonly prisma: PrismaService) {}

  @Get()
  async get(@CurrentUser() user: AuthUser) {
    const p = await this.prisma.styleProfile.findUnique({ where: { userId: user.userId } });
    return {
      preferred_styles: p?.preferredStyles ?? [],
      favorite_colors: p?.favoriteColors ?? [],
      style_interests: p?.styleInterests ?? [],
      hair_preferences: p?.hairPreferences ?? [],
      glasses_preferences: p?.glassesPreferences ?? [],
      occasion_preferences: p?.occasionPreferences ?? [],
      source: p?.source ?? StyleProfileSource.user,
      ai_summary: p?.aiSummary ?? null,
    };
  }

  @Put()
  async put(@CurrentUser() user: AuthUser, @Body() dto: StyleProfileDto) {
    const data = {
      preferredStyles: dto.preferred_styles ?? [],
      favoriteColors: dto.favorite_colors ?? [],
      styleInterests: dto.style_interests ?? [],
      hairPreferences: dto.hair_preferences ?? [],
      glassesPreferences: dto.glasses_preferences ?? [],
      occasionPreferences: dto.occasion_preferences ?? [],
      source: StyleProfileSource.user,
    };
    await this.prisma.styleProfile.upsert({
      where: { userId: user.userId },
      update: data,
      create: { userId: user.userId, ...data },
    });
    return this.get(user);
  }
}
