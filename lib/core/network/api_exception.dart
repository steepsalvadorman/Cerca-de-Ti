/// Uniform error shape for every backend call, built from the `{"error":
/// "..."}` body the Rust API returns on non-2xx responses (see
/// `backend/src/shared/error.rs`).
class ApiException implements Exception {
  const ApiException({required this.message, this.statusCode});

  final String message;
  final int? statusCode;

  bool get isUnauthorized => statusCode == 401;
  bool get isNotFound => statusCode == 404;

  /// `/auth/google` answering "I need to know whether this person is a
  /// client or a technician before I can create the account". The app
  /// asks and retries rather than showing this as a failure.
  bool get isRoleRequired => statusCode == 422;

  @override
  String toString() => message;
}
