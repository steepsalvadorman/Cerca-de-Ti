// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'providers_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(technicianRepository)
final technicianRepositoryProvider = TechnicianRepositoryProvider._();

final class TechnicianRepositoryProvider
    extends
        $FunctionalProvider<
          TechnicianRepository,
          TechnicianRepository,
          TechnicianRepository
        >
    with $Provider<TechnicianRepository> {
  TechnicianRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'technicianRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$technicianRepositoryHash();

  @$internal
  @override
  $ProviderElement<TechnicianRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  TechnicianRepository create(Ref ref) {
    return technicianRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TechnicianRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TechnicianRepository>(value),
    );
  }
}

String _$technicianRepositoryHash() =>
    r'891b0ef8668d2836c6dc4135d8388246e17b01c2';

/// Which trade the home screen is filtered to, or `null` for all of
/// them. Its id matches `technician_profiles.categories` in the backend
/// (`gasfiteria`, `electricidad`, …).

@ProviderFor(SelectedCategory)
final selectedCategoryProvider = SelectedCategoryProvider._();

/// Which trade the home screen is filtered to, or `null` for all of
/// them. Its id matches `technician_profiles.categories` in the backend
/// (`gasfiteria`, `electricidad`, …).
final class SelectedCategoryProvider
    extends $NotifierProvider<SelectedCategory, String?> {
  /// Which trade the home screen is filtered to, or `null` for all of
  /// them. Its id matches `technician_profiles.categories` in the backend
  /// (`gasfiteria`, `electricidad`, …).
  SelectedCategoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'selectedCategoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$selectedCategoryHash();

  @$internal
  @override
  SelectedCategory create() => SelectedCategory();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String?>(value),
    );
  }
}

String _$selectedCategoryHash() => r'1c51a2bcf030a3b9b132e770f1c17a8c9c8e4aa8';

/// Which trade the home screen is filtered to, or `null` for all of
/// them. Its id matches `technician_profiles.categories` in the backend
/// (`gasfiteria`, `electricidad`, …).

abstract class _$SelectedCategory extends $Notifier<String?> {
  String? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<String?, String?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<String?, String?>,
              String?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Home screen's technician/team listing (`GET /providers`).

@ProviderFor(ProvidersController)
final providersControllerProvider = ProvidersControllerProvider._();

/// Home screen's technician/team listing (`GET /providers`).
final class ProvidersControllerProvider
    extends $AsyncNotifierProvider<ProvidersController, ProvidersPage> {
  /// Home screen's technician/team listing (`GET /providers`).
  ProvidersControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'providersControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$providersControllerHash();

  @$internal
  @override
  ProvidersController create() => ProvidersController();
}

String _$providersControllerHash() =>
    r'993c6c879aa5737b3718c6d09e46b253e135e30c';

/// Home screen's technician/team listing (`GET /providers`).

abstract class _$ProvidersController extends $AsyncNotifier<ProvidersPage> {
  FutureOr<ProvidersPage> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<ProvidersPage>, ProvidersPage>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<ProvidersPage>, ProvidersPage>,
              AsyncValue<ProvidersPage>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
