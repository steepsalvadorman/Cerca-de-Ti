// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_router.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Built **once** per app run, on purpose.
///
/// Watching `authControllerProvider` here instead would rebuild the
/// provider — and with it the whole `GoRouter` — on every session
/// change, and a fresh router starts over at `initialLocation`. That is
/// how a failed login used to dump the person on the splash screen
/// rather than leaving them on the form with the error. `refreshListenable`
/// gets the redirect re-evaluated without throwing the router away.

@ProviderFor(appRouter)
final appRouterProvider = AppRouterProvider._();

/// Built **once** per app run, on purpose.
///
/// Watching `authControllerProvider` here instead would rebuild the
/// provider — and with it the whole `GoRouter` — on every session
/// change, and a fresh router starts over at `initialLocation`. That is
/// how a failed login used to dump the person on the splash screen
/// rather than leaving them on the form with the error. `refreshListenable`
/// gets the redirect re-evaluated without throwing the router away.

final class AppRouterProvider
    extends $FunctionalProvider<GoRouter, GoRouter, GoRouter>
    with $Provider<GoRouter> {
  /// Built **once** per app run, on purpose.
  ///
  /// Watching `authControllerProvider` here instead would rebuild the
  /// provider — and with it the whole `GoRouter` — on every session
  /// change, and a fresh router starts over at `initialLocation`. That is
  /// how a failed login used to dump the person on the splash screen
  /// rather than leaving them on the form with the error. `refreshListenable`
  /// gets the redirect re-evaluated without throwing the router away.
  AppRouterProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appRouterProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appRouterHash();

  @$internal
  @override
  $ProviderElement<GoRouter> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  GoRouter create(Ref ref) {
    return appRouter(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(GoRouter value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<GoRouter>(value),
    );
  }
}

String _$appRouterHash() => r'e445327cb51a0ea2a9c6d5605df7644e03933f3c';
