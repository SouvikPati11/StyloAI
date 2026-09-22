import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import '../core/firebase_bootstrap.dart';
import '../data/repositories.dart';

/// Registers the device's FCM token with the backend so the server can push
/// generation-complete / trending / bonus notifications. No-op until Firebase
/// is configured. Backend gates sending by user preference (never spam).
class FcmService {
  final UserRepository users;
  FcmService(this.users);

  Future<void> register() async {
    if (!FirebaseBootstrap.ready) return;
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission();
      final token = await messaging.getToken();
      if (token != null) {
        await users.registerDevice(token);
      }
      messaging.onTokenRefresh.listen((t) {
        users.registerDevice(t).catchError((_) {});
      });
    } catch (e) {
      debugPrint('FCM registration skipped: $e');
    }
  }
}
