import 'package:flutter_test/flutter_test.dart';
import 'package:styloai/core/api_exception.dart';

/// Locks the error contract the auth flow depends on: a transport failure is
/// classified as NETWORK ("No connection"), while an HTTP error response is a
/// coded/INTERNAL error — never "No connection". This is what lets the
/// diagnostics distinguish "backend unreachable" from "backend returned an
/// error", instead of blaming the phone's internet.
void main() {
  group('ApiException classification', () {
    test('network() is the NETWORK code used for transport failures', () {
      final e = ApiException.network();
      expect(e.code, 'NETWORK');
      expect(e.isNetwork, isTrue);
      expect(e.message.toLowerCase(), contains('connection'));
    });

    test('unknown() is INTERNAL, not NETWORK (HTTP error without envelope)', () {
      final e = ApiException.unknown();
      expect(e.code, 'INTERNAL');
      expect(e.isNetwork, isFalse);
    });

    test('a coded backend error is neither NETWORK nor auth by default', () {
      final e = ApiException('VALIDATION', 'bad', status: 400);
      expect(e.isNetwork, isFalse);
      expect(e.isAuth, isFalse);
      expect(e.status, 400);
    });

    test('auth codes are recognized for the refresh path', () {
      expect(ApiException('TOKEN_EXPIRED', 'x').isAuth, isTrue);
      expect(ApiException('UNAUTHENTICATED', 'x').isAuth, isTrue);
    });
  });
}
