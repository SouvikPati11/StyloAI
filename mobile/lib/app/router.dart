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

/// App navigation (go_router). Redirects based on auth phase. Deep links into a
/// generation result are supported so an FCM tap can open it.
GoRouter buildRouter(WidgetRef ref) {
  return GoRouter(
    initialLocation: '/',
    refreshListenable: _AuthListenable(ref),
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final loc = state.matchedLocation;
      if (auth.phase == AuthPhase.loading) return loc == '/' ? null : '/';
      final signedIn = auth.phase == AuthPhase.signedIn;
      final atAuth = loc == '/onboarding' || loc == '/sign-in' || loc == '/';
      if (!signedIn && !atAuth) return '/onboarding';
      if (signedIn && atAuth) return '/home';
      return null;
    },
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
