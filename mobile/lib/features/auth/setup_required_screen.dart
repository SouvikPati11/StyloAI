import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/env.dart';
import '../../design/tokens.dart';

/// Shown when Firebase is not yet configured. This is a clearly-marked
/// configuration state — the app never fakes authentication. It tells the
/// developer exactly what to do.
class SetupRequiredScreen extends StatelessWidget {
  const SetupRequiredScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    const steps = [
      'Create a Firebase project and add an Android app with package name app.stylo.styloai.',
      'Install the FlutterFire CLI:\n  dart pub global activate flutterfire_cli',
      'Run:  flutterfire configure\n  (generates lib/core/firebase_options.dart + android/app/google-services.json)',
      'Enable Google Sign-In in Firebase Authentication.',
      'Rebuild the app — sign-in and push notifications activate automatically.',
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Sign-in setup')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpace.gutter),
        children: [
          Text('Configure Google Sign-In', style: t.headlineMedium),
          const SizedBox(height: AppSpace.sm),
          Text(
            'StyloAI uses Firebase Authentication for Google sign-in. It isn’t configured in this build yet, so we won’t pretend to sign you in.',
            style: t.bodyMedium?.copyWith(color: AppColors.inkSoft),
          ),
          const SizedBox(height: AppSpace.xl),
          ...steps.asMap().entries.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpace.lg),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      child: Text('${e.key + 1}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 13)),
                    ),
                    const SizedBox(width: AppSpace.md),
                    Expanded(child: Text(e.value, style: t.bodyMedium)),
                  ],
                ),
              )),
          const SizedBox(height: AppSpace.lg),
          Container(
            padding: const EdgeInsets.all(AppSpace.md),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(AppRadii.sm),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: Text('Backend API: ${Env.apiBaseUrl}\nFlavor: ${Env.flavor}',
                style: t.bodySmall),
          ),
          const SizedBox(height: AppSpace.xl),
          OutlinedButton(
              onPressed: () => context.pop(), child: const Text('Back')),
        ],
      ),
    );
  }
}
