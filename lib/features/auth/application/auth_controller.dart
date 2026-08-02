import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/network/network_providers.dart';
import '../data/auth_repository.dart';
import '../domain/auth_session.dart';

part 'auth_controller.g.dart';

@Riverpod(keepAlive: true)
AuthRepository authRepository(Ref ref) => AuthRepository(ref.watch(apiClientProvider));

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

    try {
      final user = await ref.read(authRepositoryProvider).me();
      return AuthSession(token: token, user: user);
    } catch (_) {
      await storage.clear();
      return null;
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

  Future<void> logout() async {
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
