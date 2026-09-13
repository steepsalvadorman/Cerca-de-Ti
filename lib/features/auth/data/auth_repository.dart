import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../domain/auth_session.dart';
import '../domain/auth_user.dart';

/// Talks to the `auth` feature of the backend (`/auth/register`,
/// `/auth/login`, `/auth/google`, `/me`).
class AuthRepository {
  AuthRepository(this._dio);

  final Dio _dio;

  Future<AuthSession> register({
    required String email,
    required String password,
    required String name,
    required String role,
  }) async {
    try {
      final response = await _dio.post('/auth/register', data: {
        'email': email,
        'password': password,
        'name': name,
        'role': role,
      });
      final session = AuthSession.fromJson(response.data as Map<String, dynamic>);
      if (role == 'technician') {
        await _bootstrapTechnicianProfile(session.token);
      }
      return session;
    } on DioException catch (e) {
      throw apiExceptionOf(e);
    }
  }

  Future<AuthSession> login({required String email, required String password}) async {
    try {
      final response = await _dio.post('/auth/login', data: {'email': email, 'password': password});
      return AuthSession.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw apiExceptionOf(e);
    }
  }

  /// Exchanges a Google ID token for one of our sessions. [role] is
  /// only read when the account does not exist yet; without it the
  /// backend answers 422 (`ApiException.isRoleRequired`) so the app can
  /// ask which side of Cerca this person is on and call again.
  Future<AuthSession> signInWithGoogle({required String idToken, String? role}) async {
    try {
      final response = await _dio.post('/auth/google', data: {
        'id_token': idToken,
        'role': ?role,
      });
      final session = AuthSession.fromJson(response.data as Map<String, dynamic>);
      // 201 means this call created the account, so a technician needs
      // the same empty profile row `register` bootstraps — see there.
      if (response.statusCode == 201 && session.user.role == 'technician') {
        await _bootstrapTechnicianProfile(session.token);
      }
      return session;
    } on DioException catch (e) {
      throw apiExceptionOf(e);
    }
  }

  Future<AuthUser> me() async {
    try {
      final response = await _dio.get('/me');
      return AuthUser.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw apiExceptionOf(e);
    }
  }

  /// A new technician account has no `technician_profiles` row yet, but
  /// the very next screen after registering (`tech_docs_screen`) needs
  /// one to exist — otherwise `/technician/documents` 404s. Best-effort:
  /// if this fails, `tech_profile_screen`'s own save creates it later.
  Future<void> _bootstrapTechnicianProfile(String token) async {
    try {
      await _dio.post(
        '/technician/profile',
        data: {'oficio': '', 'coverage_km': 5, 'available_days': <String>[], 'categories': <String>[]},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
    } catch (_) {
      // Best-effort bootstrap; ignore failures here.
    }
  }
}
