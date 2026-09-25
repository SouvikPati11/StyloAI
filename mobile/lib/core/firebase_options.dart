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

  /// The Web OAuth 2.0 client ID for this Firebase project (the `client_type: 3`
  /// entry in `google-services.json`). This project initializes Firebase from
  /// [android] above rather than the `google-services` Gradle plugin, so the
  /// `default_web_client_id` Android string resource that plugin would normally
  /// generate does not exist. `google_sign_in` therefore needs this value passed
  /// explicitly as `serverClientId` so the Google ID token it returns on Android
  /// is minted with this project's web client as its audience — which is exactly
  /// what Firebase Auth requires to accept the Google credential.
  ///
  /// This is a *public* OAuth client identifier (it ships in google-services.json
  /// and in the app binary); it is not a secret. Backend secrets never live here.
  static const String webClientId =
      '165332899972-c150scdvfj0jv3qit03fdojf5j5l3j9g.apps.googleusercontent.com';

  /// Whether a real web client ID is present (vs. an unconfigured placeholder).
  static bool get hasWebClientId =>
      webClientId.isNotEmpty && !webClientId.startsWith('REPLACE_WITH_');
}
