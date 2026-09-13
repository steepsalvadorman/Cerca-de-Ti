import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/network_providers.dart';
import '../data/auth_repository.dart';
import '../data/google_sign_in_service.dart';
import '../domain/auth_session.dart';

part 'auth_controller.g.dart';

@Riverpod(keepAlive: true)
AuthRepository authRepository(Ref ref) => AuthRepository(ref.watch(apiClientProvider));

@Riverpod(keepAlive: true)
GoogleSignInService googleSignInService(Ref ref) => const GoogleSignInService();

/// Session state for the whole app: `null` means signed out. Restores
/// the session from the stored JWT on first read (app startup), and
/// drives every login/register/logout action.
@Riverpod(keepAlive: true)
class AuthController extends _$AuthController {
  @override
  Future<AuthSession?> build() => _restoreSession();

  Future<AuthSession?> _restoreSession() async {
    final storage = ref.read(tokenStorageProvider);
    final String? token;
    try {
      token = await storage.read();
    } catch (_) {
      // Secure storage can fail to even open (corrupted keychain/keystore,
      // no platform channel in a test host, etc). Treat that the same as
      // "no session" instead of leaving the app stuck restoring forever.
      return null;
    }
    if (token == null) return null;

    // The backend runs on a plan whose instance sleeps when idle and can
    // take the better part of a minute to wake. Retrying spans that wake
    // window, so the first launch of the day restores the session instead
    // of bouncing the user to the login screen.
    const attemptDelays = [Duration(seconds: 2), Duration(seconds: 5), Duration(seconds: 10)];

    for (var attempt = 0; ; attempt++) {
      try {
        final user = await ref.read(authRepositoryProvider).me();
        return AuthSession(token: token, user: user);
      } on ApiException catch (e) {
        // Only the server saying "this token is no good" ends the
        // session. Treating every failure as a bad token used to log
        // people out whenever the backend was merely unreachable.
        if (e.isUnauthorized) {
          await storage.clear();
          return null;
        }
        if (attempt >= attemptDelays.length) rethrow;
        await Future<void>.delayed(attemptDelays[attempt]);
      }
    }
  }

  Future<void> login({required String email, required String password}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final session = await ref.read(authRepositoryProvider).login(email: email, password: password);
      await ref.read(tokenStorageProvider).save(session.token);
      return session;
    });
  }

  Future<void> register({
    required String email,
    required String password,
    required String name,
    required String role,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final session = await ref.read(authRepositoryProvider).register(
            email: email,
            password: password,
            name: name,
            role: role,
          );
      await ref.read(tokenStorageProvider).save(session.token);
      return session;
    });
  }

  /// Signs in through Google. [role] is only consulted when the account
  /// is new; an existing one keeps the role it has. Called without a
  /// role (from the login screen) a first-time account comes back as
  /// `ApiException.isRoleRequired`, which the caller turns into a
  /// client/technician prompt and one more attempt.
  Future<void> signInWithGoogle({String? role}) async {
    final previous = state.value;
    state = const AsyncLoading();

    try {
      final idToken = await ref.read(googleSignInServiceProvider).idToken();
      final session = await ref
          .read(authRepositoryProvider)
          .signInWithGoogle(idToken: idToken, role: role);
      await ref.read(tokenStorageProvider).save(session.token);
      state = AsyncData(session);
    } on GoogleSignInCancelled {
      // Backing out of Google's account sheet is a decision, not a
      // failure: no error banner, just the screen as it was.
      state = AsyncData(previous);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }

  Future<void> logout() async {
    // Google remembers the chosen account across sign-ins; without this
    // the next "Continuar con Google" would silently re-enter the very
    // account the person just left.
    await ref.read(googleSignInServiceProvider).signOut();
    try {
      await ref.read(tokenStorageProvider).clear();
    } catch (_) {
      // Even if clearing the stored token fails, the in-memory session
      // must still drop — the user tapped "log out" and expects it to work.
    }
    state = const AsyncData(null);
  }

  /// Ends the session because the backend rejected the stored token
  /// (expired or invalid), not because the user asked to. Called from
  /// the Dio interceptor on a 401; the router's redirect then takes the
  /// app back to `/login` on its own.
  ///
  /// Idempotent on purpose: several in-flight requests can each get a
  /// 401 at the same time, and only the first one should do the work.
  Future<void> forceLogout() async {
    if (state.value == null) return;
    await logout();
  }
}
