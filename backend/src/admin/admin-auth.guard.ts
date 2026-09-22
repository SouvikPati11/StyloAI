import { CanActivate, ExecutionContext, Injectable, SetMetadata } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import { Request } from 'express';
import { AdminRole } from '@prisma/client';
import { AppException } from '../common/app.exception';

export interface AdminPrincipal {
  adminId: string;
  role: AdminRole;
}

export const ROLES_KEY = 'admin_roles';
/** Restrict a route to specific admin roles. */
export const Roles = (...roles: AdminRole[]) => SetMetadata(ROLES_KEY, roles);

/**
 * Guards admin routes with a SEPARATE token type ('admin') from the consumer
 * app, and enforces role-based access. Admin auth is intentionally distinct
 * from Firebase/consumer auth (docs/ADMIN_PANEL.md, docs/SECURITY.md §3).
 */
@Injectable()
export class AdminAuthGuard implements CanActivate {
  constructor(
    private readonly jwt: JwtService,
    private readonly config: ConfigService,
    private readonly reflector: Reflector,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const req = context.switchToHttp().getRequest<Request>();
    const header = req.headers['authorization'];
    if (!header || !header.startsWith('Bearer ')) {
      throw AppException.unauthenticated('Missing admin token.');
    }
    let principal: AdminPrincipal;
    try {
      const payload = await this.jwt.verifyAsync<{ sub: string; role: AdminRole; type: string }>(
        header.slice('Bearer '.length),
        { secret: this.config.get<string>('JWT_ACCESS_SECRET') },
      );
      if (payload.type !== 'admin') throw AppException.forbidden('Not an admin token.');
      principal = { adminId: payload.sub, role: payload.role };
    } catch (err) {
      if (err instanceof AppException) throw err;
      throw AppException.unauthenticated('Invalid admin token.');
    }

    const required = this.reflector.getAllAndOverride<AdminRole[]>(ROLES_KEY, [
      context.getHandler(),
      context.getClass(),
    ]);
    if (required && required.length > 0 && !required.includes(principal.role)) {
      throw AppException.forbidden('Insufficient admin role.');
    }
    (req as Request & { admin: AdminPrincipal }).admin = principal;
    return true;
  }
}

import { createParamDecorator } from '@nestjs/common';
export const CurrentAdmin = createParamDecorator(
  (_data: unknown, ctx: ExecutionContext): AdminPrincipal => {
    return ctx.switchToHttp().getRequest().admin as AdminPrincipal;
  },
);
