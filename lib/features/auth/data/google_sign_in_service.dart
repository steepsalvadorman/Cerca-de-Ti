import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/network/api_exception.dart';

/// The **Web** OAuth client id of the Google Cloud project, supplied at
/// build time:
/// `flutter run --dart-define=GOOGLE_SERVER_CLIENT_ID=<id>.apps.googleusercontent.com`
///
/// Counter-intuitively it is the *web* client id that Android needs: it
/// is what makes Google mint an ID token addressed to our backend, and
/// it is the value that shows up in the token's `aud` claim — the same
/// one the backend lists in `GOOGLE_CLIENT_IDS`. The Android client id
/// still has to exist in the same project (Google matches it by package
/// name and signing certificate) but is never named here.
const String googleServerClientId = String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');

/// The iOS OAuth client id, needed only by the iOS build.
const String googleIosClientId = String.fromEnvironment('GOOGLE_IOS_CLIENT_ID');

/// Thrown when the person dismisses Google's account sheet. Not a
/// failure: the UI returns to where it was without an error message.
class GoogleSignInCancelled implements Exception {
  const GoogleSignInCancelled();
}

/// Wraps the Google Sign-In SDK down to the one thing the backend wants:
/// an ID token. Everything Google-specific stops here — the repository
/// and the controller only ever see a `String` or an exception.
class GoogleSignInService {
  const GoogleSignInService();

  /// `initialize` must run once before `authenticate`, and running it
  /// twice is harmless, but re-doing the platform round trip on every
  /// tap is not free — so it is remembered here.
  static Future<void>? _initialization;

  Future<String> idToken() async {
    if (googleServerClientId.isEmpty) {
      throw const ApiException(
        message: 'Ingresar con Google no está configurado en esta versión de la app.',
      );
    }

    final signIn = GoogleSignIn.instance;

    if (!signIn.supportsAuthenticate()) {
      // Web is the platform that says no here: it hands sign-in through
      // its own button widget instead of a method call. Cerca ships to
      // Android and iOS, so this is a guard, not a supported path.
      throw const ApiException(
        message: 'Ingresar con Google no está disponible en esta plataforma.',
      );
    }

    try {
      _initialization ??= signIn.initialize(
        serverClientId: googleServerClientId,
        clientId: googleIosClientId.isEmpty ? null : googleIosClientId,
      );
      await _initialization;
    } catch (_) {
      // A failed initialize must not be remembered as done, or every
      // later attempt in this session would await a broken future.
      _initialization = null;
      rethrow;
    }

    final GoogleSignInAccount account;
    try {
      account = await signIn.authenticate();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        throw const GoogleSignInCancelled();
      }
      throw ApiException(message: _messageFor(e));
    }

    final idToken = account.authentication.idToken;
    if (idToken == null) {
      // Google authenticated the person but minted no ID token, which
      // in practice means `serverClientId` does not match a real web
      // client in the project — a build configuration problem.
      throw const ApiException(
        message: 'Google no entregó un token de identidad. Revisa la configuración de la app.',
      );
    }
    return idToken;
  }

  /// Forgets the Google account on the device so the next sign-in asks
  /// again, instead of silently reusing the last one.
  Future<void> signOut() async {
    if (googleServerClientId.isEmpty) return;
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {
      // Nothing the user can act on: our own session is already gone.
    }
  }

  String _messageFor(GoogleSignInException e) {
    switch (e.code) {
      case GoogleSignInExceptionCode.canceled:
      case GoogleSignInExceptionCode.interrupted:
        return 'No se completó el ingreso con Google.';
      case GoogleSignInExceptionCode.clientConfigurationError:
        return 'La configuración de Google de esta app no es válida.';
      case GoogleSignInExceptionCode.providerConfigurationError:
        return 'Google Play Services no está disponible en este dispositivo.';
      case GoogleSignInExceptionCode.uiUnavailable:
        return 'No se pudo mostrar la ventana de Google.';
      case GoogleSignInExceptionCode.userMismatch:
      case GoogleSignInExceptionCode.unknownError:
        return 'No se pudo ingresar con Google. Inténtalo de nuevo.';
    }
  }
}
