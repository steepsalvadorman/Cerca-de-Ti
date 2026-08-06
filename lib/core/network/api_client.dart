import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/application/auth_controller.dart';
import 'api_exception.dart';
import 'token_storage.dart';

/// Base URL of the Cerca backend. Defaults to the Android emulator's
/// alias for the host machine's localhost. Override at build/run time
/// for other targets, e.g.:
/// `flutter run --dart-define=API_BASE_URL=http://192.168.1.20:8080`
/// (physical device on the same Wi-Fi) or `http://localhost:8080` (iOS
/// simulator / desktop).
const String apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://10.0.2.2:8080',
);

/// Builds the shared [Dio] client: attaches the stored bearer token to
/// every request, maps every failure to an [ApiException] so
/// repositories only ever need to catch one error type, and drops the
/// session when the backend rejects the stored token.
///
/// [ref] is only ever used from the `onError` callback — never during
/// the owning provider's `build` — so reading `authControllerProvider`
/// here creates no dependency cycle, exactly as reading it from a
/// widget callback wouldn't.
Dio buildApiClient(Ref ref, TokenStorage tokenStorage) {
  final dio = Dio(BaseOptions(
    baseUrl: apiBaseUrl,
    // Generous on purpose: the backend's hosting plan puts the instance
    // to sleep when idle, and the first request after that has to wait
    // for a container to start. A 10s ceiling turned every such request
    // into a spurious "no se pudo conectar".
    connectTimeout: const Duration(seconds: 20),
    receiveTimeout: const Duration(seconds: 40),
  ));

  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) async {
      final token = await tokenStorage.read();
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
      handler.next(options);
    },
    onError: (error, handler) {
      final apiException = _toApiException(error);

      // Only a rejected *token* ends the session. A 401 from
      // `/auth/login` means "wrong password" (no token was sent), and a
      // 403 means the session is fine but the role isn't allowed —
      // neither should log anyone out.
      final sentToken = error.requestOptions.headers.containsKey('Authorization');
      if (apiException.isUnauthorized && sentToken) {
        try {
          ref.read(authControllerProvider.notifier).forceLogout();
        } catch (_) {
          // The one moment this read can fail is a 401 on the `/me` call
          // that `AuthController.build` itself makes at startup — the
          // controller is still building, so there is no session to drop
          // yet. `_restoreSession` already clears the stored token in
          // that case, so swallowing here loses nothing.
        }
      }

      handler.next(error.copyWith(error: apiException));
    },
  ));

  return dio;
}

ApiException _toApiException(DioException error) {
  final data = error.response?.data;
  if (data is Map && data['error'] is String) {
    return ApiException(message: data['error'] as String, statusCode: error.response?.statusCode);
  }
  switch (error.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.connectionError:
      return const ApiException(message: 'No se pudo conectar con el servidor. Verifica tu conexión.');
    default:
      return ApiException(message: error.message ?? 'Ocurrió un error inesperado.', statusCode: error.response?.statusCode);
  }
}

/// Repositories call this in every `catch (e) on DioException` block to
/// unwrap the [ApiException] attached by the interceptor above.
ApiException apiExceptionOf(DioException error) {
  final apiError = error.error;
  return apiError is ApiException ? apiError : _toApiException(error);
}
