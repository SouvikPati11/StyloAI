import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../design/components.dart' show showSnack;
import '../../design/tokens.dart';
import '../../services/auth_service.dart';
import '../../state/providers.dart';

/// Premium, dark, editorial sign-in screen.
///
/// The visual language matches the splash (deep near-black canvas, plum glow,
/// two-tone wordmark) so the launch → sign-in feels like one product. Only the
/// presentation changed here; the authentication flow — typed [AuthFailure]
/// handling, the Firebase-configured guard, and router navigation — is
/// unchanged. All colors come from the existing StyloAI dark tokens.
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
      // Real reason to logcat (no tokens/secrets); friendly message to the user.
      // Cancellation stays silent.
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
    final configured = ref.watch(authControllerProvider).firebaseConfigured;

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(-0.7, -0.9),
            radius: 1.3,
            colors: [Color(0x33C98A9B), Color(0x0DC98A9B), AppColors.bgDark],
            stops: [0.0, 0.4, 0.85],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpace.xl, AppSpace.lg, AppSpace.xl, AppSpace.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _BrandRow(),

                // Editorial hero: display headline + value line + product motifs.
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _headline(),
                      const SizedBox(height: AppSpace.lg),
                      Text(
                        'Upload your photo and preview outfits, hair, glasses '
                        'and AI looks — while you stay recognizably you.',
                        style: GoogleFonts.inter(
                            fontSize: 15,
                            height: 1.55,
                            color: AppColors.inkSoftDark),
                      ),
                      const SizedBox(height: AppSpace.xl),
                      const _MotifRow(),
                    ],
                  ),
                ),

                // Bottom action area — intentional, uncluttered.
                if (!configured) ...[
                  Text(
                    'Sign-in needs Firebase configuration. Tap below for the exact setup steps.',
                    style: GoogleFonts.inter(
                        fontSize: 12.5, color: AppColors.mutedDark),
                  ),
                  const SizedBox(height: AppSpace.md),
                ],
                _GoogleButton(
                  label: configured ? 'Continue with Google' : 'Set up sign-in',
                  showGoogle: configured,
                  loading: _loading,
                  onPressed: _signIn,
                ),
                const SizedBox(height: AppSpace.md),
                _legal(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _headline() {
    TextStyle style(Color c) => GoogleFonts.fraunces(
        fontSize: 40, height: 1.05, fontWeight: FontWeight.w600, color: c);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Look the part.', style: style(AppColors.inkDark)),
        Text('Styled by AI.', style: style(AppColors.accentDark)),
      ],
    );
  }

  Widget _legal(BuildContext context) {
    final muted = GoogleFonts.inter(fontSize: 12, color: AppColors.mutedDark);
    return Center(
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text('By continuing you agree to our ', style: muted),
          _LegalLink('Terms', () => context.push('/legal/terms')),
          Text(' and ', style: muted),
          _LegalLink('Privacy Policy', () => context.push('/legal/privacy')),
          Text('.', style: muted),
        ],
      ),
    );
  }
}

/// Compact brand lockup at the top of the screen (emblem + two-tone wordmark).
class _BrandRow extends StatelessWidget {
  const _BrandRow();
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.accentSoftDark,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.accentDark, width: 1.2),
          ),
          child: const Icon(Icons.auto_awesome,
              size: 18, color: AppColors.accentDark),
        ),
        const SizedBox(width: AppSpace.md),
        Text.rich(
          TextSpan(children: [
            TextSpan(
                text: 'Stylo',
                style: GoogleFonts.fraunces(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: AppColors.inkDark)),
            TextSpan(
                text: 'AI',
                style: GoogleFonts.fraunces(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: AppColors.accentDark)),
          ]),
        ),
      ],
    );
  }
}

/// A row of product-capability chips, tying iconography to the accent.
class _MotifRow extends StatelessWidget {
  const _MotifRow();
  @override
  Widget build(BuildContext context) {
    return const Wrap(
      spacing: AppSpace.sm,
      runSpacing: AppSpace.sm,
      children: [
        _MotifChip(Icons.checkroom, 'Outfits'),
        _MotifChip(Icons.content_cut, 'Hair'),
        _MotifChip(Icons.auto_awesome, 'AI looks'),
      ],
    );
  }
}

class _MotifChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MotifChip(this.icon, this.label);
  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: AppSpace.md, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(color: AppColors.lineDark),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppColors.accentDark),
          const SizedBox(width: 7),
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.inkSoftDark)),
        ],
      ),
    );
  }
}

/// Primary CTA. A light surface makes it the clear primary action on the dark
/// canvas; the Google mark is aligned to the label.
class _GoogleButton extends StatelessWidget {
  final String label;
  final bool showGoogle;
  final bool loading;
  final VoidCallback onPressed;
  const _GoogleButton({
    required this.label,
    required this.showGoogle,
    required this.loading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppRadii.sm),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.sm),
        onTap: loading ? null : onPressed,
        child: SizedBox(
          height: 54,
          child: Center(
            child: loading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.4, color: AppColors.ink),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (showGoogle) ...[
                        const _GoogleG(),
                        const SizedBox(width: 12),
                      ] else ...[
                        const Icon(Icons.settings_outlined,
                            size: 20, color: AppColors.ink),
                        const SizedBox(width: 8),
                      ],
                      Text(label,
                          style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.ink)),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// The Google "G" sized and colored to read correctly on a white button.
class _GoogleG extends StatelessWidget {
  const _GoogleG();
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20,
      height: 20,
      child: Center(
        child: Text('G',
            style: GoogleFonts.inter(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                height: 1.0,
                color: const Color(0xFF4285F4))),
      ),
    );
  }
}

class _LegalLink extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _LegalLink(this.label, this.onTap);
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        label,
        style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.accentDark),
      ),
    );
  }
}
