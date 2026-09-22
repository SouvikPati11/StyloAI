import { Body, Controller, Post, UseGuards } from '@nestjs/common';
import { IsIn, IsString } from 'class-validator';
import { StorageService, UploadPurpose } from './storage.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { CurrentUser, AuthUser } from '../auth/current-user.decorator';
import { AppException } from '../common/app.exception';

const PURPOSES: UploadPurpose[] = [
  'user_photo',
  'outfit_ref',
  'hair_ref',
  'glasses_ref',
  'accessory_ref',
  'pose_ref',
];

class PresignDto {
  @IsIn(PURPOSES) purpose!: UploadPurpose;
  @IsString() content_type!: string;
}

/**
 * POST /v1/uploads/presign — returns a short-lived S3 PUT URL. The client uploads
 * bytes directly to S3, then references the returned s3_key in a generation
 * request. The backend validates ownership + content-type on submit.
 */
@Controller('uploads')
@UseGuards(JwtAuthGuard)
export class UploadsController {
  constructor(private readonly storage: StorageService) {}

  @Post('presign')
  async presign(@CurrentUser() user: AuthUser, @Body() dto: PresignDto) {
    if (!this.storage.isAllowedContentType(dto.content_type)) {
      throw AppException.validation('Unsupported image type.', {
        allowed: ['image/jpeg', 'image/png', 'image/webp'],
      });
    }
    const s3_key = this.storage.buildKey(dto.purpose, user.userId, dto.content_type);
    const upload_url = await this.storage.presignUpload(s3_key, dto.content_type);
    return { upload_url, s3_key, expires_in: 300 };
  }
}
