import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../design/components.dart';
import '../../design/tokens.dart';
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
    } catch (e) {
      if (e.toString().contains('cancelled')) {
        // user cancelled — no error
      } else if (mounted) {
        showSnack(context, 'Sign-in failed. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final configured = ref.watch(authControllerProvider).firebaseConfigured;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.xl),
          child: Column(
            children: [
              const Spacer(),
              Text('StyloAI', style: t.displayLarge),
              const SizedBox(height: AppSpace.sm),
              Text('Your AI Personal Stylist',
                  style: t.bodyLarge?.copyWith(color: AppColors.inkSoft)),
              const Spacer(),
              if (!configured) ...[
                const NoticeBanner(
                  message:
                      'Sign-in needs Firebase configuration. Tap continue to see the exact setup steps.',
                ),
                const SizedBox(height: AppSpace.lg),
              ],
              PrimaryButton(
                label: configured ? 'Continue with Google' : 'Set up sign-in',
                icon: configured ? Icons.login : Icons.settings_outlined,
                loading: _loading,
                onPressed: _signIn,
              ),
              const SizedBox(height: AppSpace.lg),
              Text(
                'By continuing you agree to our Terms and Privacy Policy.',
                textAlign: TextAlign.center,
                style: t.bodySmall,
              ),
              const SizedBox(height: AppSpace.sm),
              Wrap(
                alignment: WrapAlignment.center,
                children: [
                  TextButton(
                      onPressed: () => context.push('/legal/terms'),
                      child: const Text('Terms')),
                  TextButton(
                      onPressed: () => context.push('/legal/privacy'),
                      child: const Text('Privacy Policy')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
