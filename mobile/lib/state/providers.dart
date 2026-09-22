import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';
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

  Future<void> bootstrap() async {
    final tokens = ref.read(tokenStoreProvider);
    await tokens.load();
    final configured = ref.read(authServiceProvider).isConfigured;
    if (tokens.hasSession) {
      try {
        final me = await ref.read(userRepoProvider).me();
        state = AuthState(
            phase: AuthPhase.signedIn, me: me, firebaseConfigured: configured);
        _postSignIn();
        return;
      } catch (_) {
        await tokens.clear();
      }
    }
    state =
        AuthState(phase: AuthPhase.signedOut, firebaseConfigured: configured);
  }

  /// Full sign-in: Firebase Google → backend exchange → load profile.
  Future<void> signInWithGoogle() async {
    final idToken =
        await ref.read(authServiceProvider).signInWithGoogleGetIdToken();
    final res = await ref.read(authRepoProvider).loginWithGoogle(idToken);
    await ref.read(tokenStoreProvider).save(
          res['access_token'] as String,
          res['refresh_token'] as String,
        );
    final me = await ref.read(userRepoProvider).me();
    state = state.copyWith(phase: AuthPhase.signedIn, me: me);
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
