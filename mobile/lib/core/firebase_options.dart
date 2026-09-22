import 'package:firebase_core/firebase_core.dart';

/// ⚠️ CONFIGURATION POINT — replace this file with your real Firebase config.
///
/// Generate it with the FlutterFire CLI (recommended):
///   dart pub global activate flutterfire_cli
///   flutterfire configure --project=<your-firebase-project>
///
/// That command overwrites this file with your project's real options AND adds
/// `android/app/google-services.json`. Until then the app runs in a clearly
/// marked "sign-in setup required" state — it never fakes authentication.
///
/// The placeholder values below are NOT secrets and NOT functional.
class DefaultFirebaseOptions {
  static const String _placeholderApiKey = 'REPLACE_WITH_FLUTTERFIRE_CONFIGURE';

  /// True once real Firebase options have been generated into this file.
  static bool get isConfigured => android.apiKey != _placeholderApiKey;

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: _placeholderApiKey,
    appId: '1:000000000000:android:0000000000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'styloai-placeholder',
    storageBucket: 'styloai-placeholder.appspot.com',
  );

  static FirebaseOptions get currentPlatform => android;
}
