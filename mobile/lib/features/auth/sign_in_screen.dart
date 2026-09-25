import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../design/components.dart';
import '../../design/tokens.dart';
import '../../services/auth_service.dart';
import '../../state/providers.dart';

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});
  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  bool _loading = false;

  Future<void> _signIn() async {
    final auth = ref.read(authControllerProvider);
    if (!auth.firebaseConfigured) {
      context.push('/setup-required');
      return;
    }
    setState(() => _loading = true);
    try {
      await ref.read(authControllerProvider.notifier).signInWithGoogle();
      if (mounted) context.go('/home');
    } on AuthFailure catch (f) {
      // Developers get the exact code + stage in logcat; users get a friendly
      // message. Cancellation is silent. No tokens are ever logged.
      f.log();
      if (!f.isCancelled && mounted) showSnack(context, f.userMessage);
    } catch (e) {
      debugPrint('[auth] unexpected sign-in error: $e');
      if (mounted) showSnack(context, 'Sign-in failed. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final configured = ref.watch(authControllerProvider).firebaseConfigured;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.xl, vertical: AppSpace.lg),
          child: Column(
            children: [
              // Hero — brand + value proposition, vertically balanced.
              Expanded(
                flex: 5,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _BrandMark(),
                      const SizedBox(height: AppSpace.xl),
                      Text('StyloAI', style: t.displayLarge),
                      const SizedBox(height: AppSpace.xs),
                      Text('Your AI Personal Stylist',
                          style:
                              t.bodyLarge?.copyWith(color: AppColors.inkSoft)),
                      const SizedBox(height: AppSpace.xl),
                      Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: AppSpace.md),
                        child: Text(
                          'Upload your photo and preview outfits, hair, glasses '
                          'and AI looks — while you stay recognizably you.',
                          textAlign: TextAlign.center,
                          style: t.bodyMedium?.copyWith(
                              color: AppColors.muted, height: 1.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Actions — pinned to the lower third.
              Expanded(
                flex: 3,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (!configured) ...[
                      const NoticeBanner(
                        message:
                            'Sign-in needs Firebase configuration. Tap to see the exact setup steps.',
                      ),
                      const SizedBox(height: AppSpace.lg),
                    ],
                    PrimaryButton(
                      label:
                          configured ? 'Continue with Google' : 'Set up sign-in',
                      leading: configured ? const GoogleGlyph() : null,
                      icon: configured ? null : Icons.settings_outlined,
                      loading: _loading,
                      onPressed: _signIn,
                    ),
                    const SizedBox(height: AppSpace.md),
                    Text(
                      'By continuing you agree to our Terms and Privacy Policy.',
                      textAlign: TextAlign.center,
                      style: t.bodySmall?.copyWith(color: AppColors.muted),
                    ),
                    const SizedBox(height: AppSpace.xs),
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        TextButton(
                          onPressed: () => context.push('/legal/terms'),
                          style: TextButton.styleFrom(
                              foregroundColor: scheme.primary),
                          child: const Text('Terms'),
                        ),
                        const Text('·',
                            style: TextStyle(color: AppColors.muted)),
                        TextButton(
                          onPressed: () => context.push('/legal/privacy'),
                          style: TextButton.styleFrom(
                              foregroundColor: scheme.primary),
                          child: const Text('Privacy Policy'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The StyloAI brand mark: a soft accent-tinted disc with a monogram, echoing
/// the accent used across the app.
class _BrandMark extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 92,
      height: 92,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.10),
        shape: BoxShape.circle,
      ),
      child: Icon(Icons.auto_awesome, size: 40, color: scheme.primary),
    );
  }
}
