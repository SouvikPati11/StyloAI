import 'package:flutter/material.dart';
import '../../design/tokens.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('StyloAI', style: t.displayMedium),
            const SizedBox(height: AppSpace.sm),
            Text('Your AI Personal Stylist', style: t.bodySmall),
            const SizedBox(height: AppSpace.xxl),
            const SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(strokeWidth: 2.4)),
          ],
        ),
      ),
    );
  }
}
