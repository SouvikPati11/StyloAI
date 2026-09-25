import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:google_sign_in/google_sign_in.dart';
import '../core/firebase_bootstrap.dart';

/// The stage of the auth flow at which a failure occurred. Used to give the
/// user an accurate, friendly message and developers a precise log.
enum AuthStage {
  config, // Firebase not configured
  cancelled, // user dismissed the Google chooser
  googleSignIn, // Google Play Services / Google Sign-In
  firebase, // Firebase credential sign-in
  tokenExchange, // Firebase returned no ID token
  backend, // backend /auth/google or profile load
  network, // no connectivity
  unknown,
}

/// A typed auth failure. [devMessage] carries the real technical detail for
/// logs (never a token or secret); [userMessage] is safe to show to the user.
class AuthFailure implements Exception {
  final AuthStage stage;
  final String code;
  final String devMessage;
  const AuthFailure(this.stage, this.code, this.devMessage);

  bool get isCancelled => stage == AuthStage.cancelled;

  String get userMessage {
    switch (stage) {
      case AuthStage.cancelled:
        return '';
      case AuthStage.config:
        return 'Google sign-in isn’t set up for this build yet. Please try again later.';
      case AuthStage.googleSignIn:
        if (code == 'DEVELOPER_ERROR') {
          return 'Google sign-in isn’t configured for this app build yet. '
              'Please try again later.';
        }
        if (code == 'NETWORK') {
          return 'No connection. Check your network and try again.';
        }
        return 'Google sign-in is temporarily unavailable. Please try again.';
      case AuthStage.firebase:
      case AuthStage.tokenExchange:
        return 'Google sign-in is temporarily unavailable. Please try again.';
      case AuthStage.network:
        return 'No connection. Check your network and try again.';
      case AuthStage.backend:
        return 'We couldn’t complete sign-in. Please try again.';
      case AuthStage.unknown:
        return 'Sign-in failed. Please try again.';
    }
  }

  /// Logs the real reason to the developer console (logcat) without secrets.
  void log() {
    debugPrint('[auth] failed at stage=${stage.name} code=$code :: $devMessage');
  }

  @override
  String toString() => 'AuthFailure(${stage.name}, $code)';
}

/// Google Sign-In via Firebase. Returns a Firebase ID token that the backend
/// verifies before issuing its own session JWTs. No backend secrets here.
class AuthService {
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  bool get isConfigured => FirebaseBootstrap.ready;

  /// Runs the Google sign-in flow and returns a Firebase ID token, or throws an
  /// [AuthFailure] describing exactly where and why it failed.
  Future<String> signInWithGoogleGetIdToken() async {
    if (!isConfigured) {
      throw const AuthFailure(
          AuthStage.config, 'FIREBASE_NOT_CONFIGURED', 'Firebase not initialized');
    }

    // Stage 1: Google Sign-In (Google Play Services).
    GoogleSignInAccount? googleUser;
    try {
      googleUser = await _googleSignIn.signIn();
    } on PlatformException catch (e) {
      throw AuthFailure(AuthStage.googleSignIn, _mapGoogleCode(e),
          'GoogleSignIn PlatformException code=${e.code} message=${e.message} details=${e.details}');
    } catch (e) {
      throw AuthFailure(AuthStage.googleSignIn, 'SIGN_IN_FAILED', 'GoogleSignIn error: $e');
    }
    if (googleUser == null) {
      throw const AuthFailure(AuthStage.cancelled, 'CANCELLED', 'User cancelled Google sign-in');
    }

    // Stage 2: obtain Google auth tokens.
    final GoogleSignInAuthentication googleAuth;
    try {
      googleAuth = await googleUser.authentication;
    } on PlatformException catch (e) {
      throw AuthFailure(AuthStage.googleSignIn, _mapGoogleCode(e),
          'GoogleSignIn.authentication PlatformException code=${e.code} message=${e.message}');
    }

    // Stage 3: Firebase credential sign-in.
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    final UserCredential userCred;
    try {
      userCred = await FirebaseAuth.instance.signInWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(AuthStage.firebase, e.code.toUpperCase(),
          'FirebaseAuthException code=${e.code} message=${e.message}');
    } catch (e) {
      throw AuthFailure(AuthStage.firebase, 'FIREBASE_ERROR', 'Firebase sign-in error: $e');
    }

    // Stage 4: obtain the Firebase ID token to hand to the backend.
    final idToken = await userCred.user?.getIdToken();
    if (idToken == null || idToken.isEmpty) {
      throw const AuthFailure(
          AuthStage.tokenExchange, 'NO_ID_TOKEN', 'Firebase returned an empty ID token');
    }
    return idToken;
  }

  /// Maps a Google Sign-In PlatformException to a stable, non-secret code.
  /// Code 10 (DEVELOPER_ERROR) means the app's SHA-1/SHA-256 isn't registered
  /// in Firebase / no Android OAuth client exists for this package+signature.
  String _mapGoogleCode(PlatformException e) {
    final blob = '${e.code}|${e.message}|${e.details}'.toUpperCase();
    if (blob.contains('DEVELOPER_ERROR') ||
        blob.contains(': 10') ||
        blob.contains('APIEXCEPTION: 10') ||
        blob.contains('STATUS{STATUSCODE=DEVELOPER_ERROR')) {
      return 'DEVELOPER_ERROR';
    }
    if (e.code == 'network_error' || blob.contains('NETWORK')) return 'NETWORK';
    if (e.code == 'sign_in_canceled' || e.code == 'canceled' || blob.contains('CANCEL')) {
      return 'CANCELLED';
    }
    return e.code.isEmpty ? 'SIGN_IN_FAILED' : e.code.toUpperCase();
  }

  Future<void> signOut() async {
    if (!isConfigured) return;
    try {
      await _googleSignIn.signOut();
      await FirebaseAuth.instance.signOut();
    } catch (_) {}
  }
}
