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

  /** The user's own photo (S3 key from /uploads/presign). Identity anchor. */
  @IsString() @IsNotEmpty() user_photo_key!: string;

  /** Required in reference_upload mode: the reference image S3 key. */
  @IsOptional() @IsString() reference_key?: string;

  @IsOptional() @ValidateNested() @Type(() => GenerationOptions) options?: GenerationOptions;

  /** Idempotency key (also accepted via the Idempotency-Key header). */
  @IsOptional() @IsString() idempotency_key?: string;
}
