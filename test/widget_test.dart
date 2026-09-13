import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cerca/core/network/network_providers.dart';
import 'package:cerca/core/network/token_storage.dart';
import 'package:cerca/main.dart';

/// `TokenStorage`'s real implementation goes through a platform channel
/// (`flutter_secure_storage`) that `flutter_test` never wires up — the
/// call just hangs forever instead of resolving or throwing, which used
/// to leave the splash screen stuck and this test permanently failing.
class _FakeTokenStorage extends TokenStorage {
  const _FakeTokenStorage();

  @override
  Future<String?> read() async => null;

  @override
  Future<void> save(String token) async {}

  @override
  Future<void> clear() async {}
}

void main() {
  testWidgets('App boots into the animated splash and advances to Login', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [tokenStorageProvider.overrideWithValue(const _FakeTokenStorage())],
      child: const CercaApp(),
    ));
    await tester.pump();

    expect(find.text('Técnicos verificados, cerca de ti'), findsOneWidget);

    // It must remain visible for the configured minimum presentation time.
    await tester.pump(const Duration(milliseconds: 2100));
    expect(find.text('Cerca'), findsOneWidget);
    expect(find.text('¿Eres nuevo? Crea tu cuenta'), findsNothing);

    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('¿Eres nuevo? Crea tu cuenta'), findsOneWidget);
  });
}
