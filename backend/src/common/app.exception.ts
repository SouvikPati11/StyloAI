import { HttpException, HttpStatus } from '@nestjs/common';
import { ErrorCode } from './error-codes';

/**
 * Application error carrying a typed ErrorCode. The HttpExceptionFilter renders
 * it into the standard { error: { code, message, details } } envelope.
 */
export class AppException extends HttpException {
  constructor(
    public readonly code: ErrorCode,
    message: string,
    status: HttpStatus,
    public readonly details?: Record<string, unknown>,
  ) {
    super({ code, message, details }, status);
  }

  static unauthenticated(message = 'Authentication required.') {
    return new AppException(ErrorCode.UNAUTHENTICATED, message, HttpStatus.UNAUTHORIZED);
  }

  static forbidden(message = 'Not allowed.') {
    return new AppException(ErrorCode.FORBIDDEN, message, HttpStatus.FORBIDDEN);
  }

  static notFound(message = 'Not found.') {
    return new AppException(ErrorCode.NOT_FOUND, message, HttpStatus.NOT_FOUND);
  }

  static validation(message: string, details?: Record<string, unknown>) {
    return new AppException(ErrorCode.VALIDATION_ERROR, message, HttpStatus.BAD_REQUEST, details);
  }

  static insufficientCredits(required: number, balance: number) {
    return new AppException(
      ErrorCode.INSUFFICIENT_CREDITS,
      `You need ${required} credits but have ${balance}.`,
      HttpStatus.PAYMENT_REQUIRED,
      { required, balance },
    );
  }

  static featureDisabled(feature: string) {
    return new AppException(
      ErrorCode.FEATURE_DISABLED,
      `The ${feature} feature is currently unavailable.`,
      HttpStatus.FORBIDDEN,
      { feature },
    );
  }

  static conflict(code: ErrorCode, message: string, details?: Record<string, unknown>) {
    return new AppException(code, message, HttpStatus.CONFLICT, details);
  }
}
