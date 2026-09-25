import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'firebase_options.dart';

/// Initializes Firebase only when real options have been configured. When the
/// developer has not yet run `flutterfire configure`, [ready] stays false and
/// the app shows a "sign-in setup required" screen instead of crashing.
class FirebaseBootstrap {
  static bool ready = false;

  static Future<void> init() async {
    if (!DefaultFirebaseOptions.isConfigured) {
      debugPrint('Firebase not configured — run `flutterfire configure`. '
          'Google Sign-In and push notifications are disabled until then.');
      ready = false;
      return;
    }
    try {
      // Bounded so a hung native init can never trap the app before first frame.
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      ).timeout(const Duration(seconds: 12));
      ready = true;
    } catch (e) {
      // Non-fatal: the app still starts and falls back to the signed-out /
      // setup-required flow instead of hanging.
      debugPrint('Firebase init failed or timed out: $e');
      ready = false;
    }
  }
}
