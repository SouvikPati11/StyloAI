import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  Post,
  UseGuards,
} from '@nestjs/common';
import { AuthService } from './auth.service';
import { FirebaseService } from './firebase.service';
import { GoogleAuthDto, RefreshDto } from './dto';
import { JwtAuthGuard } from './jwt-auth.guard';
import { CurrentUser, AuthUser } from './current-user.decorator';
import { PrismaService } from '../prisma/prisma.service';
import { UserStatus } from '@prisma/client';

@Controller('auth')
export class AuthController {
  constructor(
    private readonly auth: AuthService,
    private readonly prisma: PrismaService,
    private readonly firebase: FirebaseService,
  ) {}

  /**
   * Non-secret readiness probe for Firebase Admin (token-verification capability).
   * Exposes only whether the Admin SDK initialized and which public project id it
   * is bound to — never any credential. Used by CI to fail the deploy if the
   * backend cannot verify Google/Firebase ID tokens.
   */
  @Get('firebase-status')
  firebaseStatus() {
    return {
      configured: this.firebase.isConfigured,
      project_id: this.firebase.projectId,
    };
  }

  /** Exchange a verified Firebase ID token for backend tokens; upserts the user. */
  @Post('google')
  @HttpCode(200)
  async google(@Body() dto: GoogleAuthDto) {
    return this.auth.loginWithGoogle(dto.firebase_id_token);
  }

  @Post('refresh')
  @HttpCode(200)
  async refresh(@Body() dto: RefreshDto) {
    return this.auth.refresh(dto.refresh_token);
  }

  @Post('logout')
  @HttpCode(204)
  @UseGuards(JwtAuthGuard)
  async logout() {
    // With stateless JWTs the client discards its tokens. When refresh-token
    // persistence lands, this revokes the stored refresh id.
    return;
  }
}

/** Account deletion (privacy, §21) lives at DELETE /v1/account. */
@Controller('account')
@UseGuards(JwtAuthGuard)
export class AccountController {
  constructor(private readonly prisma: PrismaService) {}

  @Delete()
  @HttpCode(202)
  async deleteAccount(@CurrentUser() user: AuthUser) {
    // Soft-delete now; a background job purges S3 objects and cascades records.
    await this.prisma.user.update({
      where: { id: user.userId },
      data: { status: UserStatus.deleted, deletedAt: new Date() },
    });
    return { status: 'scheduled_for_deletion' };
  }
}
