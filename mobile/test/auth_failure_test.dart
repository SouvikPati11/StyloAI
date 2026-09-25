import 'package:flutter_test/flutter_test.dart';
import 'package:styloai/services/auth_service.dart';

/// Verifies the auth error contract: every failure stage yields a friendly,
/// non-technical user message, cancellation is silent, and the real technical
/// detail is preserved for logs (but never surfaced to the user). This is what
/// stops the generic "Sign-in failed. Please try again." from hiding the real
/// reason (e.g. a DEVELOPER_ERROR from a missing SHA-1 in Firebase).
void main() {
  group('AuthFailure.userMessage', () {
    test('cancellation is silent and flagged', () {
      const f = AuthFailure(AuthStage.cancelled, 'CANCELLED', 'user dismissed');
      expect(f.isCancelled, isTrue);
      expect(f.userMessage, isEmpty);
    });

    test('DEVELOPER_ERROR (missing SHA / OAuth client) is user-friendly', () {
      const f = AuthFailure(
          AuthStage.googleSignIn, 'DEVELOPER_ERROR', 'ApiException: 10');
      expect(f.isCancelled, isFalse);
      // Friendly, no jargon, and never leaks the raw code to the user.
      expect(f.userMessage, isNotEmpty);
      expect(f.userMessage.toLowerCase(), isNot(contains('developer_error')));
      expect(f.userMessage.toLowerCase(), contains('configured'));
    });

    test('missing Google ID token maps to a friendly, non-cancelled message', () {
      // Raised when google_sign_in returns no ID token (serverClientId / web
      // OAuth client not configured) — before the Firebase credential is built.
      const f = AuthFailure(AuthStage.tokenExchange, 'NO_GOOGLE_ID_TOKEN',
          'Google returned no ID token');
      expect(f.isCancelled, isFalse);
      expect(f.userMessage, isNotEmpty);
      expect(f.userMessage.toLowerCase(), isNot(contains('id token')));
    });

    test('network stage tells the user to check their connection', () {
      const f = AuthFailure(AuthStage.network, 'NETWORK', 'no connectivity');
      expect(f.userMessage.toLowerCase(), contains('connection'));
    });

    test('backend stage stays generic but actionable', () {
      const f = AuthFailure(
          AuthStage.backend, 'INTERNAL', 'Backend /auth/google failed: 500');
      expect(f.userMessage, isNotEmpty);
      expect(f.userMessage.toLowerCase(), isNot(contains('500')));
    });

    test('config stage (Firebase not initialised) is handled', () {
      const f = AuthFailure(
          AuthStage.config, 'FIREBASE_NOT_CONFIGURED', 'not initialized');
      expect(f.userMessage, isNotEmpty);
    });

    test('every stage produces a non-null message and never throws', () {
      for (final stage in AuthStage.values) {
        final f = AuthFailure(stage, 'CODE', 'dev detail');
        expect(() => f.userMessage, returnsNormally);
        expect(() => f.log(), returnsNormally);
      }
    });

    test('devMessage carries technical detail for logs, not for users', () {
      const f = AuthFailure(
          AuthStage.firebase, 'INVALID_CREDENTIAL', 'FirebaseAuthException x');
      expect(f.devMessage, contains('FirebaseAuthException'));
      // The user-facing string does not echo the raw technical detail.
      expect(f.userMessage, isNot(contains('FirebaseAuthException')));
    });
  });
}
