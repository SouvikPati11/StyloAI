import 'package:firebase_core/firebase_core.dart';

/// Firebase configuration for StyloAI (Android).
///
/// These values are derived from `android/app/google-services.json` (the
/// standard FlutterFire client configuration). They are Firebase client
/// identifiers, not backend secrets — the same values ship in google-services.json
/// and are safe on the client. Backend secrets (Gemini/AWS/DB/Play) never live
/// here. To regenerate after a Firebase project change, run
/// `flutterfire configure`.
///
/// The bootstrap ([FirebaseBootstrap]) initializes Firebase only when
/// [isConfigured] is true; otherwise the app shows a "sign-in setup required"
/// state and never fakes authentication.
class DefaultFirebaseOptions {
  static const String _placeholderApiKey = 'REPLACE_WITH_FLUTTERFIRE_CONFIGURE';

  /// True once real Firebase options have been set into this file.
  static bool get isConfigured => android.apiKey != _placeholderApiKey;

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyA6--MwKQfi10M0QWLUscgKS95rIpZirz0',
    appId: '1:165332899972:android:86e21d78597248e8414ad1',
    messagingSenderId: '165332899972',
    projectId: 'lifereset-556c7',
    storageBucket: 'lifereset-556c7.firebasestorage.app',
  );

  static FirebaseOptions get currentPlatform => android;
}
