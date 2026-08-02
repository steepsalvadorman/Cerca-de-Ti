import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cerca/core/network/network_providers.dart';
import 'package:cerca/core/network/token_storage.dart';
import 'package:cerca/features/auth/application/auth_controller.dart';

/// Returns a canned response per path, so a test can hand out a valid
/// session first and reject the next call with a 401 the same way an
/// expired token would.
class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this.responses);

  final Map<String, ResponseBody> responses;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    final response = responses[options.path];
    if (response == null) {
      throw StateError('unexpected request to ${options.path}');
    }
    return response;
  }

  @override
  void close({bool force = false}) {}
}

class _FakeTokenStorage extends TokenStorage {
  _FakeTokenStorage(this._token);

  String? _token;
  bool cleared = false;

  @override
  Future<String?> read() async => _token;

  @override
  Future<void> save(String token) async => _token = token;

  @override
  Future<void> clear() async {
    cleared = true;
    _token = null;
  }
}

ResponseBody _json(String body, int statusCode) => ResponseBody.fromString(
      body,
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

const _meBody = '{"id":"11111111-1111-1111-1111-111111111111","email":"ana@test.local",'
    '"name":"Ana","role":"client","created_at":"2026-01-01T00:00:00Z"}';

void main() {
  test('a 401 on an authenticated request ends the session', () async {
    final storage = _FakeTokenStorage('stored-token');
    final container = ProviderContainer(
      overrides: [tokenStorageProvider.overrideWithValue(storage)],
    );
    addTearDown(container.dispose);

    container.read(apiClientProvider).httpClientAdapter = _StubAdapter({
      '/me': _json(_meBody, 200),
      '/client/addresses': _json('{"error":"invalid or expired token"}', 401),
    });

    // Session restored from the stored token, as at app startup.
    final session = await container.read(authControllerProvider.future);
    expect(session, isNotNull);

    // Any authenticated call the backend now rejects must drop it.
    await expectLater(
      container.read(apiClientProvider).get<void>('/client/addresses'),
      throwsA(isA<DioException>()),
    );
    await Future<void>.delayed(Duration.zero);

    expect(container.read(authControllerProvider).value, isNull);
    expect(storage.cleared, isTrue, reason: 'the rejected token must not survive on disk');
  });

  test('a 401 without a token attached does not end the session', () async {
    // A failed login is a 401 too, but no session exists to drop and the
    // screen needs the error to surface as a normal failure.
    final storage = _FakeTokenStorage(null);
    final container = ProviderContainer(
      overrides: [tokenStorageProvider.overrideWithValue(storage)],
    );
    addTearDown(container.dispose);

    container.read(apiClientProvider).httpClientAdapter = _StubAdapter({
      '/auth/login': _json('{"error":"invalid credentials"}', 401),
    });

    await container.read(authControllerProvider.future);

    await expectLater(
      container.read(apiClientProvider).post<void>('/auth/login', data: {'email': 'a@b.co', 'password': 'nope'}),
      throwsA(isA<DioException>()),
    );
    await Future<void>.delayed(Duration.zero);

    expect(storage.cleared, isFalse);
  });
}
