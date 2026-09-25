import 'package:flutter_test/flutter_test.dart';
import 'package:styloai/core/firebase_options.dart';

void main() {
  group('DefaultFirebaseOptions', () {
    test('isConfigured is true for Android once real options are set', () {
      expect(DefaultFirebaseOptions.isConfigured, isTrue);
    });

    test('Android options carry the real project identifiers', () {
      const android = DefaultFirebaseOptions.android;
      expect(android.projectId, 'lifereset-556c7');
      expect(android.messagingSenderId, '165332899972');
      expect(android.appId, contains(':android:'));
      expect(android.apiKey, isNotEmpty);
    });

    test('web client ID is present and used as the Google Sign-In audience', () {
      // Required on Android as serverClientId so google_sign_in returns an ID
      // token Firebase will accept (this project has no default_web_client_id
      // resource because the google-services Gradle plugin is not applied).
      expect(DefaultFirebaseOptions.hasWebClientId, isTrue);
      expect(DefaultFirebaseOptions.webClientId,
          endsWith('.apps.googleusercontent.com'));
      // The web client belongs to the same Firebase project (same number).
      expect(DefaultFirebaseOptions.webClientId,
          startsWith('${DefaultFirebaseOptions.android.messagingSenderId}-'));
    });
  });
}
