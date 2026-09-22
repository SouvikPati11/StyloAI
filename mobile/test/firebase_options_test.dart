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
  });
}
