import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../state/providers.dart';
import '../features/splash/splash_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/auth/sign_in_screen.dart';
import '../features/auth/setup_required_screen.dart';
import '../features/shell/home_shell.dart';
import '../features/create/create_flow_screen.dart';
import '../features/result/result_screen.dart';
import '../features/credits/credits_screen.dart';
import '../features/profile/style_profile_screen.dart';
import '../features/profile/settings_screen.dart';
import '../features/profile/notifications_screen.dart';
import '../features/legal/legal_screen.dart';

/// Pure redirect decision (extracted so it can be unit-tested). Returns the
/// path to redirect to, or null to stay. Guarantees a signed-out user is never
/// left on the splash '/' — they always route to onboarding — so the app can
/// never hang on the splash once bootstrap resolves.
String? resolveRedirect(AuthPhase phase, String loc) {
  // While session restoration is in progress, hold on the splash ('/');
  // bounce any other location to the splash until bootstrap resolves.
  if (phase == AuthPhase.loading) {
    return loc == '/' ? null : '/';
  }

  final signedIn = phase == AuthPhase.signedIn;

  if (!signedIn) {
    // Signed-out users may sit on the auth flow, the Firebase setup notice, or
    // the legal pages. Everywhere else — INCLUDING the splash '/' — routes to
    // onboarding so the app can never get stuck on the splash.
    final allowedSignedOut = loc == '/onboarding' ||
        loc == '/sign-in' ||
        loc == '/setup-required' ||
        loc.startsWith('/legal');
    return allowedSignedOut ? null : '/onboarding';
  }

  // Signed in: leave the splash and auth screens for the app shell.
  if (loc == '/' || loc == '/onboarding' || loc == '/sign-in') {
    return '/home';
  }
  return null;
}

/// App navigation (go_router). Redirects based on auth phase. Deep links into a
/// generation result are supported so an FCM tap can open it.
GoRouter buildRouter(WidgetRef ref) {
  return GoRouter(
    initialLocation: '/',
    refreshListenable: _AuthListenable(ref),
    redirect: (context, state) =>
        resolveRedirect(ref.read(authControllerProvider).phase, state.matchedLocation),
    routes: [
      GoRoute(path: '/', builder: (_, __) => const SplashScreen()),
      GoRoute(
          path: '/onboarding', builder: (_, __) => const OnboardingScreen()),
      GoRoute(path: '/sign-in', builder: (_, __) => const SignInScreen()),
      GoRoute(
          path: '/setup-required',
          builder: (_, __) => const SetupRequiredScreen()),
      GoRoute(
        path: '/home',
        builder: (_, __) => const HomeShell(),
      ),
      GoRoute(
        path: '/create/:type',
        builder: (_, s) => CreateFlowScreen(type: s.pathParameters['type']!),
      ),
      GoRoute(
        path: '/result/:id',
        builder: (_, s) => ResultScreen(generationId: s.pathParameters['id']!),
      ),
      GoRoute(path: '/credits', builder: (_, __) => const CreditsScreen()),
      GoRoute(
          path: '/style-profile',
          builder: (_, __) => const StyleProfileScreen()),
      GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
      GoRoute(
          path: '/notifications',
          builder: (_, __) => const NotificationsScreen()),
      GoRoute(
        path: '/legal/:doc',
        builder: (_, s) => LegalScreen(doc: s.pathParameters['doc']!),
      ),
    ],
  );
}

/// Bridges the auth StateNotifier to go_router's refreshListenable.
class _AuthListenable extends ChangeNotifier {
  _AuthListenable(WidgetRef ref) {
    ref.listen(authControllerProvider, (_, __) => notifyListeners());
  }
}
