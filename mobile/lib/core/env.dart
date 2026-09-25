/// Build-time configuration, injected with --dart-define. No secrets live here;
/// the API base URL and flavor are the only client config. See docs/FLUTTER_APP.md.
class Env {
  /// Backend base URL. The permanent production API is the HTTPS domain and is
  /// also the default, so a build always targets production unless a developer
  /// explicitly overrides it for local work with
  /// `--dart-define=API_BASE_URL=...`. There is deliberately no IP, emulator, or
  /// cleartext fallback — the app only ever speaks HTTPS to api.souvikpati.in.
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.souvikpati.in',
  );

  static const flavor = String.fromEnvironment('FLAVOR', defaultValue: 'dev');

  static bool get isProd => flavor == 'prod';
}
