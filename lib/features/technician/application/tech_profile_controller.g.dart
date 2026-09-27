// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tech_profile_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The signed-in technician's own profile (`GET/POST /technician/profile`).
/// `null` means no profile has been saved yet.

@ProviderFor(TechProfileController)
final techProfileControllerProvider = TechProfileControllerProvider._();

/// The signed-in technician's own profile (`GET/POST /technician/profile`).
/// `null` means no profile has been saved yet.
final class TechProfileControllerProvider
    extends $AsyncNotifierProvider<TechProfileController, Technician?> {
  /// The signed-in technician's own profile (`GET/POST /technician/profile`).
  /// `null` means no profile has been saved yet.
  TechProfileControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'techProfileControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$techProfileControllerHash();

  @$internal
  @override
  TechProfileController create() => TechProfileController();
}

String _$techProfileControllerHash() =>
    r'72cbdd47a254297f600c4b20c2d9dcb52f6f016e';

/// The signed-in technician's own profile (`GET/POST /technician/profile`).
/// `null` means no profile has been saved yet.

abstract class _$TechProfileController extends $AsyncNotifier<Technician?> {
  FutureOr<Technician?> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<Technician?>, Technician?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<Technician?>, Technician?>,
              AsyncValue<Technician?>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
