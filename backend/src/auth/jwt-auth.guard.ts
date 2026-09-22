import { CanActivate, ExecutionContext, Injectable } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import { Request } from 'express';
import { AppException } from '../common/app.exception';
import { ErrorCode } from '../common/error-codes';
import { AuthUser } from './current-user.decorator';

/**
 * Verifies the backend access JWT on the Authorization header and attaches the
 * AuthUser to the request. Distinguishes an expired token (TOKEN_EXPIRED, so the
 * app can refresh) from an otherwise invalid one (UNAUTHENTICATED).
 */
@Injectable()
export class JwtAuthGuard implements CanActivate {
  constructor(
    private readonly jwt: JwtService,
    private readonly config: ConfigService,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const req = context.switchToHttp().getRequest<Request>();
    const header = req.headers['authorization'];
    if (!header || !header.startsWith('Bearer ')) {
      throw AppException.unauthenticated('Missing bearer token.');
    }
    const token = header.slice('Bearer '.length);
    try {
      const payload = await this.jwt.verifyAsync<{
        sub: string;
        fuid: string;
        type: string;
      }>(token, { secret: this.config.get<string>('JWT_ACCESS_SECRET') });
      if (payload.type !== 'access') {
        throw AppException.unauthenticated('Wrong token type.');
      }
      const user: AuthUser = { userId: payload.sub, firebaseUid: payload.fuid };
      (req as Request & { user: AuthUser }).user = user;
      return true;
    } catch (err) {
      if (err instanceof AppException) throw err;
      const expired = err instanceof Error && err.name === 'TokenExpiredError';
      throw new AppException(
        expired ? ErrorCode.TOKEN_EXPIRED : ErrorCode.UNAUTHENTICATED,
        expired ? 'Access token expired.' : 'Invalid access token.',
        401,
      );
    }
  }
}
