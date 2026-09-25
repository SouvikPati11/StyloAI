import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../design/tokens.dart';

/// The first frame shown while [AuthController.bootstrap] resolves the session.
///
/// It is purely presentational — it starts no timers and drives no navigation,
/// so it can never hang: the router leaves this screen the instant auth reaches
/// a terminal phase. The composition is a dark, editorial brand lockup (deep
/// near-black canvas, a soft plum glow, an emblem fused with the wordmark) so
/// the launch reads as one premium fashion/AI product, continuous with the
/// login screen. All colors come from the existing StyloAI dark tokens.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.bgDark,
      body: DecoratedBox(
        decoration: BoxDecoration(
          // Soft plum glow rising from behind the wordmark — depth without noise.
          gradient: RadialGradient(
            center: Alignment(0, -0.35),
            radius: 1.05,
            colors: [Color(0x33C98A9B), Color(0x0FC98A9B), AppColors.bgDark],
            stops: [0.0, 0.35, 0.85],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(flex: 6, child: Center(child: _BrandLockup())),
              // Restrained, indeterminate loader — no fake progress.
              Expanded(
                flex: 3,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.accentDark),
                    ),
                    SizedBox(height: AppSpace.xxxl),
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

/// The StyloAI emblem + wordmark as a single locked-up composition, shared in
/// spirit with the login screen so the two feel like one product.
class _BrandLockup extends StatelessWidget {
  const _BrandLockup();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Emblem: a plum ring around a soft-filled disc with the brand spark.
        Container(
          width: 96,
          height: 96,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.accentSoftDark,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.accentDark, width: 1.4),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x33C98A9B), blurRadius: 40, spreadRadius: 4),
            ],
          ),
          child: const Icon(Icons.auto_awesome,
              size: 40, color: AppColors.accentDark),
        ),
        const SizedBox(height: AppSpace.xl),
        // Two-tone wordmark ties the plum accent directly into the typography.
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                  text: 'Stylo',
                  style: GoogleFonts.fraunces(
                      fontSize: 44,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.5,
                      color: AppColors.inkDark)),
              TextSpan(
                  text: 'AI',
                  style: GoogleFonts.fraunces(
                      fontSize: 44,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.5,
                      color: AppColors.accentDark)),
            ],
          ),
        ),
        const SizedBox(height: AppSpace.md),
        // Thin accent rule separates display type from the label.
        Container(width: 44, height: 2, color: AppColors.accentDark),
        const SizedBox(height: AppSpace.md),
        Text(
          'YOUR AI PERSONAL STYLIST',
          style: GoogleFonts.inter(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              letterSpacing: 3.0,
              color: AppColors.mutedDark),
        ),
      ],
    );
  }
}
