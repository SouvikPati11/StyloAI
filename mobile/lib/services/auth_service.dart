import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../core/firebase_bootstrap.dart';

/// Google Sign-In via Firebase. Returns a Firebase ID token that the backend
/// verifies before issuing its own session JWTs. No backend secrets here.
class AuthService {
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  bool get isConfigured => FirebaseBootstrap.ready;

  /// Runs the Google sign-in flow and returns a Firebase ID token, or throws.
  Future<String> signInWithGoogleGetIdToken() async {
    if (!isConfigured) {
      throw StateError('Firebase is not configured. See docs/ENVIRONMENT.md.');
    }
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) {
      throw StateError('cancelled');
    }
    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    final userCred =
        await FirebaseAuth.instance.signInWithCredential(credential);
    final idToken = await userCred.user?.getIdToken();
    if (idToken == null) {
      throw StateError('Could not obtain an ID token.');
    }
    return idToken;
  }

  Future<void> signOut() async {
    if (!isConfigured) return;
    try {
      await _googleSignIn.signOut();
      await FirebaseAuth.instance.signOut();
    } catch (_) {}
  }
}
