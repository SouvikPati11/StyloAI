/// Typed API error mirroring the backend error envelope
/// `{ error: { code, message, details } }`. UI maps [code] to states.
class ApiException implements Exception {
  final String code;
  final String message;
  final Map<String, dynamic>? details;
  final int? status;

  /// Precise, non-secret internal classification for diagnostics/logs only
  /// (e.g. CONNECTION_TIMEOUT, DNS_FAILURE, CLEARTEXT_BLOCKED, TLS_ERROR,
  /// HTTP_401). Never shown to the user. Helps distinguish "backend unreachable"
  /// from "backend returned an error" during production debugging.
  final String? diag;

  ApiException(this.code, this.message, {this.details, this.status, this.diag});

  bool get isAuth => code == 'UNAUTHENTICATED' || code == 'TOKEN_EXPIRED';
  bool get isInsufficientCredits => code == 'INSUFFICIENT_CREDITS';
  bool get isRateLimited => code == 'RATE_LIMITED';
  bool get isPaymentInvalid => code == 'PAYMENT_INVALID';

  /// True only for a genuine transport failure (no HTTP response was received).
  /// An HTTP 401/403/404/500 is NEVER network — it has a status and its own code.
  bool get isNetwork => code == 'NETWORK';

  factory ApiException.network({String? message, String? diag}) => ApiException(
      'NETWORK',
      message ?? 'No connection. Check your network and try again.',
      diag: diag);

  factory ApiException.unknown([String? message]) => ApiException(
      'INTERNAL', message ?? 'Something went wrong. Please try again.');

  @override
  String toString() => message;
}
