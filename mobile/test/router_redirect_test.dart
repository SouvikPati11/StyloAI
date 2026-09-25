import 'package:flutter_test/flutter_test.dart';
import 'package:styloai/app/router.dart';
import 'package:styloai/state/providers.dart';

/// Guards the startup routing so the app can NEVER hang on the splash: a
/// signed-out user at '/' must always be routed to onboarding.
void main() {
  group('resolveRedirect', () {
    test('loading: stays on splash, bounces others to splash', () {
      expect(resolveRedirect(AuthPhase.loading, '/'), isNull);
      expect(resolveRedirect(AuthPhase.loading, '/home'), '/');
    });

    test('signed out at splash routes to onboarding (splash-hang regression)', () {
      expect(resolveRedirect(AuthPhase.signedOut, '/'), '/onboarding');
    });

    test('signed out: auth flow, setup and legal are allowed to rest', () {
      expect(resolveRedirect(AuthPhase.signedOut, '/onboarding'), isNull);
      expect(resolveRedirect(AuthPhase.signedOut, '/sign-in'), isNull);
      expect(resolveRedirect(AuthPhase.signedOut, '/setup-required'), isNull);
      expect(resolveRedirect(AuthPhase.signedOut, '/legal/privacy'), isNull);
    });

    test('signed out: protected routes go to onboarding', () {
      expect(resolveRedirect(AuthPhase.signedOut, '/home'), '/onboarding');
      expect(resolveRedirect(AuthPhase.signedOut, '/credits'), '/onboarding');
      expect(resolveRedirect(AuthPhase.signedOut, '/create/outfit'), '/onboarding');
    });

    test('signed in: splash and auth screens go to home', () {
      expect(resolveRedirect(AuthPhase.signedIn, '/'), '/home');
      expect(resolveRedirect(AuthPhase.signedIn, '/onboarding'), '/home');
      expect(resolveRedirect(AuthPhase.signedIn, '/sign-in'), '/home');
    });

    test('signed in: in-app routes are left alone', () {
      expect(resolveRedirect(AuthPhase.signedIn, '/home'), isNull);
      expect(resolveRedirect(AuthPhase.signedIn, '/credits'), isNull);
      expect(resolveRedirect(AuthPhase.signedIn, '/result/abc'), isNull);
    });
  });
}
