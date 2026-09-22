/// Typed API error mirroring the backend error envelope
/// `{ error: { code, message, details } }`. UI maps [code] to states.
class ApiException implements Exception {
  final String code;
  final String message;
  final Map<String, dynamic>? details;
  final int? status;

  ApiException(this.code, this.message, {this.details, this.status});

  bool get isAuth => code == 'UNAUTHENTICATED' || code == 'TOKEN_EXPIRED';
  bool get isInsufficientCredits => code == 'INSUFFICIENT_CREDITS';
  bool get isRateLimited => code == 'RATE_LIMITED';
  bool get isPaymentInvalid => code == 'PAYMENT_INVALID';
  bool get isNetwork => code == 'NETWORK';

  factory ApiException.network([String? message]) => ApiException(
      'NETWORK', message ?? 'No connection. Check your network and try again.');

  factory ApiException.unknown([String? message]) => ApiException(
      'INTERNAL', message ?? 'Something went wrong. Please try again.');

  @override
  String toString() => message;
}
