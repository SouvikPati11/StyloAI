import { IsEnum, IsIn, IsOptional, IsString, ValidateNested, IsNotEmpty } from 'class-validator';
import { Type } from 'class-transformer';
import { GenerationType, GenerationMode } from '@prisma/client';

class GenerationOptions {
  @IsOptional() @IsIn(['standard', 'high']) resolution?: 'standard' | 'high';
}

export class CreateGenerationDto {
  @IsEnum(GenerationType) type!: GenerationType;
  @IsEnum(GenerationMode) mode!: GenerationMode;

  /** Required in explore mode: which preset/category to apply. */
  @IsOptional() @IsString() preset_key?: string;

  /**
   * Optional authoritative reference to an admin-created Trending Style. When
   * present, the backend loads that style and derives the type, preset, style
   * description, and credit PRICE from the database record — the client is never
   * trusted for the price. See GenerationsService.submit.
   */
  @IsOptional() @IsString() trending_content_id?: string;

  /**
   * Optional reference to an admin-created Pose. When present the backend forces
   * type=pose, uses the pose's description in the prompt, and prices it from the
   * pose's own credit price (or the category default) — client never sets it.
   */
  @IsOptional() @IsString() pose_id?: string;

  /** The user's own photo (S3 key from /uploads/presign). Identity anchor. */
  @IsString() @IsNotEmpty() user_photo_key!: string;

  /** Required in reference_upload mode: the reference image S3 key. */
  @IsOptional() @IsString() reference_key?: string;

  @IsOptional() @ValidateNested() @Type(() => GenerationOptions) options?: GenerationOptions;

  /** Idempotency key (also accepted via the Idempotency-Key header). */
  @IsOptional() @IsString() idempotency_key?: string;
}
