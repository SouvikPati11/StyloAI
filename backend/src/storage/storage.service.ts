import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { S3Client, PutObjectCommand, GetObjectCommand } from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import { randomUUID } from 'crypto';

export type UploadPurpose =
  | 'user_photo'
  | 'outfit_ref'
  | 'hair_ref'
  | 'glasses_ref'
  | 'accessory_ref'
  | 'pose_ref'
  | 'admin_content';

const PREFIX: Record<UploadPurpose, (userId: string) => string> = {
  user_photo: (u) => `originals/${u}`,
  outfit_ref: (u) => `references/${u}`,
  hair_ref: (u) => `references/${u}`,
  glasses_ref: (u) => `references/${u}`,
  accessory_ref: (u) => `references/${u}`,
  pose_ref: (u) => `references/${u}`,
  admin_content: () => `admin/trending`,
};

const ALLOWED_CONTENT_TYPES = ['image/jpeg', 'image/png', 'image/webp'];

/**
 * S3 access. Uploads use short-lived pre-signed PUT URLs so image bytes never
 * transit the API server; delivery uses short-lived signed GET URLs (buckets
 * are private). Prefixes separate originals / references / generated / admin so
 * lifecycle rules can differ. See docs/AWS_INFRASTRUCTURE.md, docs/SECURITY.md.
 */
@Injectable()
export class StorageService {
  private readonly logger = new Logger(StorageService.name);
  private readonly client: S3Client;
  private readonly bucket: string;
  private readonly uploadTtl: number;

  constructor(private readonly config: ConfigService) {
    this.bucket = this.config.get<string>('S3_BUCKET') ?? 'stylo-media';
    this.uploadTtl = Number(this.config.get<string>('S3_UPLOAD_URL_TTL') ?? '300');
    this.client = new S3Client({ region: this.config.get<string>('AWS_REGION') ?? 'us-east-1' });
  }

  isAllowedContentType(contentType: string): boolean {
    return ALLOWED_CONTENT_TYPES.includes(contentType);
  }

  private extFor(contentType: string): string {
    if (contentType === 'image/png') return 'png';
    if (contentType === 'image/webp') return 'webp';
    return 'jpg';
  }

  /** Deterministic key for an upload; the client PUTs to the returned URL. */
  buildKey(purpose: UploadPurpose, userId: string, contentType: string): string {
    const prefix = PREFIX[purpose](userId);
    return `${prefix}/${randomUUID()}.${this.extFor(contentType)}`;
  }

  /** True if a key belongs to this user's prefix (ownership check on submit). */
  ownsKey(userId: string, s3Key: string): boolean {
    return (
      s3Key.startsWith(`originals/${userId}/`) ||
      s3Key.startsWith(`references/${userId}/`) ||
      s3Key.startsWith(`generated/${userId}/`)
    );
  }

  async presignUpload(key: string, contentType: string): Promise<string> {
    const command = new PutObjectCommand({
      Bucket: this.bucket,
      Key: key,
      ContentType: contentType,
    });
    return getSignedUrl(this.client, command, { expiresIn: this.uploadTtl });
  }

  async presignDownload(key: string, ttlSeconds = 300): Promise<string> {
    const command = new GetObjectCommand({ Bucket: this.bucket, Key: key });
    return getSignedUrl(this.client, command, { expiresIn: ttlSeconds });
  }
}
