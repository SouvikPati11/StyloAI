import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';
import '../core/api_exception.dart';
import '../core/token_store.dart';
import '../data/models.dart';
import '../data/repositories.dart';
import '../services/auth_service.dart';
import '../services/fcm_service.dart';

/// Dependency wiring for the app (Riverpod). Singletons for the token store,
/// API client, and repositories; controllers for auth/session and config.

final tokenStoreProvider = Provider<TokenStore>((ref) => TokenStore());

final apiClientProvider = Provider<ApiClient>((ref) {
  final client = ApiClient(ref.read(tokenStoreProvider));
  client.onSessionExpired = () async {
    await ref.read(authControllerProvider.notifier).forceSignOut();
  };
  return client;
});

final authRepoProvider =
    Provider((ref) => AuthRepository(ref.read(apiClientProvider)));
final userRepoProvider =
    Provider((ref) => UserRepository(ref.read(apiClientProvider)));
final uploadRepoProvider =
    Provider((ref) => UploadRepository(ref.read(apiClientProvider)));
final generationRepoProvider =
    Provider((ref) => GenerationRepository(ref.read(apiClientProvider)));
final contentRepoProvider =
    Provider((ref) => ContentRepository(ref.read(apiClientProvider)));
final creditsRepoProvider =
    Provider((ref) => CreditsRepository(ref.read(apiClientProvider)));
final billingRepoProvider =
    Provider((ref) => BillingRepository(ref.read(apiClientProvider)));
final looksRepoProvider =
    Provider((ref) => LooksRepository(ref.read(apiClientProvider)));
final styleProfileRepoProvider =
    Provider((ref) => StyleProfileRepository(ref.read(apiClientProvider)));
final notificationsRepoProvider =
    Provider((ref) => NotificationsRepository(ref.read(apiClientProvider)));

final authServiceProvider = Provider((ref) => AuthService());
final fcmServiceProvider =
    Provider((ref) => FcmService(ref.read(userRepoProvider)));

/// Auth/session state.
enum AuthPhase { loading, signedOut, signedIn }

class AuthState {
  final AuthPhase phase;
  final Me? me;
  final bool firebaseConfigured;
  const AuthState(
      {required this.phase, this.me, required this.firebaseConfigured});

  AuthState copyWith({AuthPhase? phase, Me? me, bool? firebaseConfigured}) =>
      AuthState(
        phase: phase ?? this.phase,
        me: me ?? this.me,
        firebaseConfigured: firebaseConfigured ?? this.firebaseConfigured,
      );
}

class AuthController extends StateNotifier<AuthState> {
  final Ref ref;
  AuthController(this.ref)
      : super(const AuthState(
            phase: AuthPhase.loading, firebaseConfigured: false));

  /// Restores a session on startup. Always resolves to a terminal phase
  /// (signedIn or signedOut) — it never leaves the app in [AuthPhase.loading],
  /// so the splash can never hang. A stored session that can't be validated
  /// (expired, invalid, offline, or timed out) falls back to a recoverable
  /// signed-out state so the user can sign in again.
  Future<void> bootstrap() async {
    final configured = _firebaseConfigured();
    try {
      final tokens = ref.read(tokenStoreProvider);
      await tokens.load();
      if (tokens.hasSession) {
        try {
          final me = await ref
              .read(userRepoProvider)
              .me()
              .timeout(const Duration(seconds: 10));
          state = AuthState(
              phase: AuthPhase.signedIn, me: me, firebaseConfigured: configured);
          _postSignIn();
          return;
        } catch (_) {
          // Session restoration failed — clear it and continue signed out.
          await tokens.clear();
        }
      }
    } catch (_) {
      // Any unexpected bootstrap error still resolves to a usable state.
    }
    state =
        AuthState(phase: AuthPhase.signedOut, firebaseConfigured: configured);
  }

  bool _firebaseConfigured() {
    try {
      return ref.read(authServiceProvider).isConfigured;
    } catch (_) {
      return false;
    }
  }

  /// Full sign-in: Firebase Google → backend exchange → load profile.
  /// Throws a typed [AuthFailure] identifying the exact stage that failed.
  Future<void> signInWithGoogle() async {
    // Stage 1–4: Google + Firebase → Firebase ID token (throws AuthFailure).
    final idToken =
        await ref.read(authServiceProvider).signInWithGoogleGetIdToken();

    // Stage 5: exchange the Firebase token for a backend session.
    final Map<String, dynamic> res;
    try {
      res = await ref.read(authRepoProvider).loginWithGoogle(idToken);
    } on ApiException catch (e) {
      throw AuthFailure(
          e.isNetwork ? AuthStage.network : AuthStage.backend,
          e.code,
          'POST /auth/google failed: code=${e.code} status=${e.status} diag=${e.diag} :: ${e.message}');
    }
    await ref.read(tokenStoreProvider).save(
          res['access_token'] as String,
          res['refresh_token'] as String,
        );

    // Stage 6: load the profile so the shell has data immediately.
    try {
      final me = await ref.read(userRepoProvider).me();
      state = state.copyWith(phase: AuthPhase.signedIn, me: me);
    } on ApiException catch (e) {
      throw AuthFailure(
          e.isNetwork ? AuthStage.network : AuthStage.backend,
          e.code,
          'GET /me after sign-in failed: code=${e.code} status=${e.status} diag=${e.diag} :: ${e.message}');
    }
    _postSignIn();
  }

  void _postSignIn() {
    // Register for push (no-op until Firebase configured).
    ref.read(fcmServiceProvider).register();
  }

  Future<void> refreshMe() async {
    try {
      final me = await ref.read(userRepoProvider).me();
      state = state.copyWith(me: me);
    } catch (_) {}
  }

  Future<void> signOut() async {
    await ref.read(authServiceProvider).signOut();
    try {
      await ref.read(authRepoProvider).logout();
    } catch (_) {}
    await ref.read(tokenStoreProvider).clear();
    state = state.copyWith(phase: AuthPhase.signedOut, me: null);
  }

  Future<void> forceSignOut() async {
    await ref.read(tokenStoreProvider).clear();
    state = state.copyWith(phase: AuthPhase.signedOut, me: null);
  }

  Future<void> deleteAccount() async {
    await ref.read(authRepoProvider).deleteAccount();
    await signOut();
  }
}

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>(
    (ref) => AuthController(ref));

/// Server-driven config (credit costs, features, categories).
final appConfigProvider = FutureProvider<AppConfig>((ref) async {
  return ref.read(userRepoProvider).config();
});

/// Wallet balance (server-authoritative). Refreshable after generations/purchases.
final walletBalanceProvider = FutureProvider<int>((ref) async {
  return ref.read(creditsRepoProvider).balance();
});
