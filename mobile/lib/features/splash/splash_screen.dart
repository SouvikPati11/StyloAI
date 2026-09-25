import 'package:flutter/material.dart';
import '../../design/tokens.dart';

/// The first frame the app shows while [AuthController.bootstrap] resolves the
/// session. It is purely presentational — it starts no timers and drives no
/// navigation, so it can never hang: the router leaves this screen the moment
/// auth reaches a terminal phase. Branding here matches the sign-in screen so
/// the launch feels like one continuous, premium experience.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Brand sits just above centre for a balanced, editorial composition.
            Expanded(
              flex: 5,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    width: 84,
                    height: 84,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.10),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.auto_awesome,
                        size: 38, color: scheme.primary),
                  ),
                  const SizedBox(height: AppSpace.xl),
                  Text('StyloAI', style: t.displayLarge),
                  const SizedBox(height: AppSpace.xs),
                  Text('Your AI Personal Stylist',
                      style: t.bodyLarge?.copyWith(color: AppColors.inkSoft)),
                ],
              ),
            ),
            // A restrained accent loader anchored to the lower area.
            Expanded(
              flex: 4,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.2, color: scheme.primary),
                  ),
                  const SizedBox(height: AppSpace.xxxl),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
