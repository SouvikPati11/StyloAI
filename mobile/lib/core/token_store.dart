import 'package:shared_preferences/shared_preferences.dart';

/// Persists the backend access/refresh tokens on-device. These are session
/// tokens issued by our backend — no third-party secrets.
class TokenStore {
  static const _access = 'stylo_access';
  static const _refresh = 'stylo_refresh';

  String? accessToken;
  String? refreshToken;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    accessToken = prefs.getString(_access);
    refreshToken = prefs.getString(_refresh);
  }

  Future<void> save(String access, String refresh) async {
    accessToken = access;
    refreshToken = refresh;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_access, access);
    await prefs.setString(_refresh, refresh);
  }

  Future<void> clear() async {
    accessToken = null;
    refreshToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_access);
    await prefs.remove(_refresh);
  }

  bool get hasSession => accessToken != null;
}
