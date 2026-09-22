import 'package:flutter/material.dart';
import '../../design/tokens.dart';

/// In-app Privacy Policy and Terms. This is baseline product copy for launch
/// readiness; have it reviewed for your jurisdiction before publishing.
class LegalScreen extends StatelessWidget {
  final String doc; // 'privacy' | 'terms'
  const LegalScreen({super.key, required this.doc});

  @override
  Widget build(BuildContext context) {
    final isPrivacy = doc == 'privacy';
    return Scaffold(
      appBar: AppBar(
          title: Text(isPrivacy ? 'Privacy Policy' : 'Terms of Service')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpace.gutter),
        children: [
          Text(isPrivacy ? _privacy : _terms,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(height: 1.6)),
          const SizedBox(height: AppSpace.xl),
        ],
      ),
    );
  }
}

const _privacy = '''StyloAI Privacy Policy

Last updated: 2026

StyloAI ("we") helps you explore personal styles using AI. This policy explains what we collect and how we use it.

Photos you upload
• Your photos are uploaded securely and used only to generate the looks you request.
• We aim to preserve your identity and only change the attribute you choose. We do not claim a mathematically identical result.
• Original photos and generated images are stored privately in encrypted object storage and served to you over short-lived, signed links.

What we store
• Your account (via Google Sign-In), your credit balance and transactions, your generations and saved looks, and your style preferences.
• We do not sell your personal data.

Your control
• You can delete individual generated looks and saved looks at any time.
• You can delete your account and associated data from Settings → Delete account. This removes your photos, generated images, saved looks, and profile.
• Temporary reference images are automatically expired from storage.

AI processing
• Generations are processed by our secure backend, which sends the necessary images and instructions to the AI provider. Provider API keys are never stored in this app.

Contact
• For privacy requests, contact support at the address on our store listing.

This document is provided as a starting point and should be reviewed by legal counsel for your jurisdiction before production launch.''';

const _terms = '''StyloAI Terms of Service

Last updated: 2026

Welcome to StyloAI. By using the app you agree to these terms.

Your account
• You must sign in with Google and be old enough to use the app in your country.
• You are responsible for the photos you upload and must have the right to use them.

Credits and purchases
• AI generations consume credits. Credit costs and balances are managed by our servers.
• Credits can be purchased through Google Play. Purchases are verified by our servers before credits are granted.
• Credits have no cash value and are non-transferable. Failed generations may be refunded in credits per our refund logic.

Acceptable use
• Do not upload photos of other people without their consent, or content that is illegal, harmful, or infringing.
• Do not attempt to misuse, reverse engineer, or disrupt the service.

AI-generated content
• Generated images are created by AI and may not be perfectly accurate. We engineer for strong identity consistency but cannot guarantee an identical likeness.

Availability
• The service is provided "as is." Features may change, and generation availability may vary.

This document is provided as a starting point and should be reviewed by legal counsel for your jurisdiction before production launch.''';
