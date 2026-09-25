import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../design/components.dart';
import '../../design/tokens.dart';

/// First frame shown while [AuthController.bootstrap] resolves the session.
///
/// Purely presentational — no timers, no navigation — so it can never hang; the
/// router leaves this screen the instant auth reaches a terminal phase. It puts
/// the real StyloAI logo on the brand's navy canvas with a champagne-gold glow,
/// continuous with the login screen and the native launch background.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.bgDark,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.35),
            radius: 1.05,
            colors: [Color(0x33CBA867), Color(0x0FCBA867), AppColors.bgDark],
            stops: [0.0, 0.4, 0.85],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(flex: 6, child: Center(child: _Brand())),
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

class _Brand extends StatelessWidget {
  const _Brand();
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const BrandLogo(size: 152, radius: 34),
        const SizedBox(height: AppSpace.xl),
        Text(
          'AI-POWERED PERSONAL STYLING',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              letterSpacing: 2.6,
              color: AppColors.inkSoftDark),
        ),
      ],
    );
  }
}
