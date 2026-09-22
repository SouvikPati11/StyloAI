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
      await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform);
      ready = true;
    } catch (e) {
      debugPrint('Firebase init failed: $e');
      ready = false;
    }
  }
}
