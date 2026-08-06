// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cerca_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Single shared session controller for the whole Cerca flow, mirroring the
/// prototype's single `Component.state` object: every screen reads and
/// mutates the same state, so it must stay alive across navigation instead
/// of being auto-disposed when a screen unmounts.

@ProviderFor(CercaController)
final cercaControllerProvider = CercaControllerProvider._();

/// Single shared session controller for the whole Cerca flow, mirroring the
/// prototype's single `Component.state` object: every screen reads and
/// mutates the same state, so it must stay alive across navigation instead
/// of being auto-disposed when a screen unmounts.
final class CercaControllerProvider
    extends $NotifierProvider<CercaController, CercaState> {
  /// Single shared session controller for the whole Cerca flow, mirroring the
  /// prototype's single `Component.state` object: every screen reads and
  /// mutates the same state, so it must stay alive across navigation instead
  /// of being auto-disposed when a screen unmounts.
  CercaControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'cercaControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$cercaControllerHash();

  @$internal
  @override
  CercaController create() => CercaController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CercaState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CercaState>(value),
    );
  }
}

String _$cercaControllerHash() => r'd4d22f537cf8851508414e21cfb4f35cc3e28dfc';

/// Single shared session controller for the whole Cerca flow, mirroring the
/// prototype's single `Component.state` object: every screen reads and
/// mutates the same state, so it must stay alive across navigation instead
/// of being auto-disposed when a screen unmounts.

abstract class _$CercaController extends $Notifier<CercaState> {
  CercaState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<CercaState, CercaState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<CercaState, CercaState>,
              CercaState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
