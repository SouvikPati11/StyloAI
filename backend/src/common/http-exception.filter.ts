import {
  ArgumentsHost,
  Catch,
  ExceptionFilter,
  HttpException,
  HttpStatus,
  Logger,
} from '@nestjs/common';
import { Response } from 'express';
import { ErrorCode } from './error-codes';

/**
 * Renders every error as the standard envelope:
 *   { "error": { "code": ErrorCode, "message": string, "details"?: object } }
 * so the Flutter client can map codes to UI states deterministically.
 */
@Catch()
export class HttpExceptionFilter implements ExceptionFilter {
  private readonly logger = new Logger(HttpExceptionFilter.name);

  catch(exception: unknown, host: ArgumentsHost) {
    const ctx = host.switchToHttp();
    const res = ctx.getResponse<Response>();

    let status = HttpStatus.INTERNAL_SERVER_ERROR;
    let code: string = ErrorCode.INTERNAL;
    let message = 'Something went wrong.';
    let details: Record<string, unknown> | undefined;

    if (exception instanceof HttpException) {
      status = exception.getStatus();
      const body = exception.getResponse();
      if (typeof body === 'object' && body !== null) {
        const b = body as Record<string, unknown>;
        code = (b.code as string) ?? this.codeForStatus(status);
        message = (b.message as string) ?? exception.message;
        details = b.details as Record<string, unknown> | undefined;
        // class-validator returns message as string[]
        if (Array.isArray(b.message)) {
          code = ErrorCode.VALIDATION_ERROR;
          message = 'Validation failed.';
          details = { errors: b.message };
        }
      } else {
        message = String(body);
        code = this.codeForStatus(status);
      }
    } else {
      this.logger.error(exception instanceof Error ? exception.stack : String(exception));
    }

    res.status(status).json({ error: { code, message, ...(details ? { details } : {}) } });
  }

  private codeForStatus(status: number): string {
    switch (status) {
      case HttpStatus.UNAUTHORIZED:
        return ErrorCode.UNAUTHENTICATED;
      case HttpStatus.FORBIDDEN:
        return ErrorCode.FORBIDDEN;
      case HttpStatus.NOT_FOUND:
        return ErrorCode.NOT_FOUND;
      case HttpStatus.BAD_REQUEST:
        return ErrorCode.VALIDATION_ERROR;
      case HttpStatus.TOO_MANY_REQUESTS:
        return ErrorCode.RATE_LIMITED;
      case HttpStatus.CONFLICT:
        return ErrorCode.CONFLICT;
      default:
        return ErrorCode.INTERNAL;
    }
  }
}
