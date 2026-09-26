import { Body, Controller, Delete, Get, Param, Post, Put, Query, UseGuards } from '@nestjs/common';
import {
  IsArray,
  IsBoolean,
  IsIn,
  IsInt,
  IsOptional,
  IsString,
  IsNotEmpty,
  Min,
} from 'class-validator';
import { ContentSection, AdminRole } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { StorageService } from '../storage/storage.service';
import { AdminAuthGuard, Roles, CurrentAdmin, AdminPrincipal } from './admin-auth.guard';
import { AppException } from '../common/app.exception';

// The five user-facing STYLE categories. `pose` is a separate, free content
// type (managed under Poses) and `inspiration` is retired — neither is a valid
// trending-style section any more.
const STYLE_SECTIONS: ContentSection[] = [
  ContentSection.outfit,
  ContentSection.hair,
  ContentSection.glasses,
  ContentSection.accessories,
  ContentSection.ai_edit,
];

class TrendingDto {
  @IsIn(STYLE_SECTIONS) section!: ContentSection;
  @IsString() @IsNotEmpty() title!: string;
  @IsOptional() @IsString() subtitle?: string;
  @IsOptional() @IsString() description?: string;
  @IsOptional() @IsArray() @IsString({ each: true }) tags?: string[];
  @IsString() @IsNotEmpty() image_s3_key!: string;
  @IsOptional() @IsString() preset_key?: string;
  @IsOptional() @IsString() category_id?: string;
  // Authoritative per-item credit price. 0 = free (where allowed). Never trusted
  // from the client at generation time — only set here by an admin.
  @IsOptional() @IsInt() @Min(0) credit_price?: number;
  @IsOptional() @IsInt() position?: number;
  @IsOptional() @IsBoolean() is_active?: boolean;
}

class PoseDto {
  @IsString() @IsNotEmpty() title!: string;
  @IsOptional() @IsString() description?: string;
  @IsString() @IsNotEmpty() image_s3_key!: string;
  @IsOptional() @IsString() pose_type?: string;
  @IsOptional() @IsArray() @IsString({ each: true }) tags?: string[];
  @IsOptional() @IsInt() position?: number;
  @IsOptional() @IsBoolean() is_active?: boolean;
}

class CategoryDto {
  @IsIn(STYLE_SECTIONS) section!: ContentSection;
  @IsString() @IsNotEmpty() key!: string;
  @IsString() @IsNotEmpty() label!: string;
  @IsOptional() @IsInt() sort_order?: number;
  @IsOptional() @IsBoolean() is_active?: boolean;
}

class MediaPresignDto {
  @IsString() content_type!: string;
}

/** Admin content management — drives Explore/Trending without an app release. */
@Controller('admin')
@UseGuards(AdminAuthGuard)
export class AdminContentController {
  constructor(
    private readonly prisma: PrismaService,
    private readonly storage: StorageService,
  ) {}

  // ---- Trending ----
  @Get('trending')
  async listTrending(@Query('section') section?: ContentSection) {
    const rows = await this.prisma.trendingContent.findMany({
      where: section ? { section } : {},
      orderBy: [{ section: 'asc' }, { position: 'asc' }],
    });
    return Promise.all(
      rows.map(async (r) => ({
        ...r,
        image_url: await this.storage.presignDownload(r.imageS3Key, 3600),
      })),
    );
  }

  @Post('trending')
  @Roles(AdminRole.super_admin, AdminRole.admin, AdminRole.content_editor)
  async createTrending(@Body() dto: TrendingDto, @CurrentAdmin() admin: AdminPrincipal) {
    return this.prisma.trendingContent.create({
      data: {
        section: dto.section,
        title: dto.title,
        subtitle: dto.subtitle,
        description: dto.description,
        tags: dto.tags ?? [],
        imageS3Key: dto.image_s3_key,
        presetKey: dto.preset_key,
        categoryId: dto.category_id,
        creditPrice: dto.credit_price ?? null,
        position: dto.position ?? 0,
        isActive: dto.is_active ?? true,
        createdBy: admin.adminId,
      },
    });
  }

  @Put('trending/:id')
  @Roles(AdminRole.super_admin, AdminRole.admin, AdminRole.content_editor)
  async updateTrending(@Param('id') id: string, @Body() dto: Partial<TrendingDto>) {
    await this.ensureTrending(id);
    return this.prisma.trendingContent.update({
      where: { id },
      data: {
        ...(dto.section ? { section: dto.section } : {}),
        ...(dto.title !== undefined ? { title: dto.title } : {}),
        ...(dto.subtitle !== undefined ? { subtitle: dto.subtitle } : {}),
        ...(dto.description !== undefined ? { description: dto.description } : {}),
        ...(dto.tags !== undefined ? { tags: dto.tags } : {}),
        ...(dto.image_s3_key ? { imageS3Key: dto.image_s3_key } : {}),
        ...(dto.preset_key !== undefined ? { presetKey: dto.preset_key } : {}),
        ...(dto.credit_price !== undefined ? { creditPrice: dto.credit_price } : {}),
        ...(dto.position !== undefined ? { position: dto.position } : {}),
        ...(dto.is_active !== undefined ? { isActive: dto.is_active } : {}),
      },
    });
  }

  @Delete('trending/:id')
  @Roles(AdminRole.super_admin, AdminRole.admin, AdminRole.content_editor)
  async deleteTrending(@Param('id') id: string) {
    await this.ensureTrending(id);
    await this.prisma.trendingContent.delete({ where: { id } });
    return { deleted: true };
  }

  private async ensureTrending(id: string) {
    const row = await this.prisma.trendingContent.findUnique({ where: { id } });
    if (!row) throw AppException.notFound('Trending item not found.');
  }

  // ---- Categories ----
  @Get('categories')
  async listCategories(@Query('section') section?: ContentSection) {
    return this.prisma.category.findMany({
      where: section ? { section } : {},
      orderBy: [{ section: 'asc' }, { sortOrder: 'asc' }],
    });
  }

  @Post('categories')
  @Roles(AdminRole.super_admin, AdminRole.admin, AdminRole.content_editor)
  async createCategory(@Body() dto: CategoryDto) {
    return this.prisma.category.upsert({
      where: { section_key: { section: dto.section, key: dto.key } },
      update: { label: dto.label, sortOrder: dto.sort_order ?? 0, isActive: dto.is_active ?? true },
      create: {
        section: dto.section,
        key: dto.key,
        label: dto.label,
        sortOrder: dto.sort_order ?? 0,
        isActive: dto.is_active ?? true,
      },
    });
  }

  @Delete('categories/:id')
  @Roles(AdminRole.super_admin, AdminRole.admin)
  async deleteCategory(@Param('id') id: string) {
    await this.prisma.category.delete({ where: { id } }).catch(() => {
      throw AppException.notFound('Category not found.');
    });
    return { deleted: true };
  }

  // ---- Poses (separate, free reference content) ----
  @Get('poses')
  async listPoses() {
    const rows = await this.prisma.pose.findMany({
      orderBy: [{ position: 'asc' }, { createdAt: 'desc' }],
    });
    return Promise.all(
      rows.map(async (r) => ({
        ...r,
        image_url: await this.storage.presignDownload(r.imageS3Key, 3600),
      })),
    );
  }

  @Post('poses')
  @Roles(AdminRole.super_admin, AdminRole.admin, AdminRole.content_editor)
  async createPose(@Body() dto: PoseDto, @CurrentAdmin() admin: AdminPrincipal) {
    return this.prisma.pose.create({
      data: {
        title: dto.title,
        description: dto.description,
        imageS3Key: dto.image_s3_key,
        poseType: dto.pose_type,
        tags: dto.tags ?? [],
        position: dto.position ?? 0,
        isActive: dto.is_active ?? true,
        createdBy: admin.adminId,
      },
    });
  }

  @Put('poses/:id')
  @Roles(AdminRole.super_admin, AdminRole.admin, AdminRole.content_editor)
  async updatePose(@Param('id') id: string, @Body() dto: Partial<PoseDto>) {
    await this.ensurePose(id);
    return this.prisma.pose.update({
      where: { id },
      data: {
        ...(dto.title !== undefined ? { title: dto.title } : {}),
        ...(dto.description !== undefined ? { description: dto.description } : {}),
        ...(dto.image_s3_key ? { imageS3Key: dto.image_s3_key } : {}),
        ...(dto.pose_type !== undefined ? { poseType: dto.pose_type } : {}),
        ...(dto.tags !== undefined ? { tags: dto.tags } : {}),
        ...(dto.position !== undefined ? { position: dto.position } : {}),
        ...(dto.is_active !== undefined ? { isActive: dto.is_active } : {}),
      },
    });
  }

  @Delete('poses/:id')
  @Roles(AdminRole.super_admin, AdminRole.admin, AdminRole.content_editor)
  async deletePose(@Param('id') id: string) {
    await this.ensurePose(id);
    await this.prisma.pose.delete({ where: { id } });
    return { deleted: true };
  }

  private async ensurePose(id: string) {
    const row = await this.prisma.pose.findUnique({ where: { id } });
    if (!row) throw AppException.notFound('Pose not found.');
  }

  // ---- Media upload (admin content images) ----
  @Post('media/presign')
  @Roles(AdminRole.super_admin, AdminRole.admin, AdminRole.content_editor)
  async presign(@Body() dto: MediaPresignDto) {
    if (!this.storage.isAllowedContentType(dto.content_type)) {
      throw AppException.validation('Unsupported image type.');
    }
    const s3_key = this.storage.buildKey('admin_content', 'admin', dto.content_type);
    const upload_url = await this.storage.presignUpload(s3_key, dto.content_type);
    return { upload_url, s3_key, expires_in: 300 };
  }
}
