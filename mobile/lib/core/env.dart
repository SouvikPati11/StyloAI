/// Build-time configuration, injected with --dart-define. No secrets live here;
/// the API base URL and flavor are the only client config. See docs/FLUTTER_APP.md.
class Env {
  /// Backend base URL, e.g. https://api.stylo.app. Defaults to the Android
  /// emulator loopback for local development (10.0.2.2 -> host machine).
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:3000',
  );

  static const flavor = String.fromEnvironment('FLAVOR', defaultValue: 'dev');

  static bool get isProd => flavor == 'prod';
}
