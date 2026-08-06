// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tracking_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(trackingRepository)
final trackingRepositoryProvider = TrackingRepositoryProvider._();

final class TrackingRepositoryProvider
    extends
        $FunctionalProvider<
          TrackingRepository,
          TrackingRepository,
          TrackingRepository
        >
    with $Provider<TrackingRepository> {
  TrackingRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'trackingRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$trackingRepositoryHash();

  @$internal
  @override
  $ProviderElement<TrackingRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  TrackingRepository create(Ref ref) {
    return trackingRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TrackingRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TrackingRepository>(value),
    );
  }
}

String _$trackingRepositoryHash() =>
    r'9d3904cc9a94b125d3e9a7607e2c9ed7ee7a4709';

/// Polls `GET /jobs/{id}/location` every few seconds while a client is
/// looking at the tracking screen — the backend has no push/websocket
/// support, matching the chat/offers polling pattern.

@ProviderFor(technicianLocation)
final technicianLocationProvider = TechnicianLocationFamily._();

/// Polls `GET /jobs/{id}/location` every few seconds while a client is
/// looking at the tracking screen — the backend has no push/websocket
/// support, matching the chat/offers polling pattern.

final class TechnicianLocationProvider
    extends
        $FunctionalProvider<
          AsyncValue<TechnicianLocation?>,
          TechnicianLocation?,
          Stream<TechnicianLocation?>
        >
    with
        $FutureModifier<TechnicianLocation?>,
        $StreamProvider<TechnicianLocation?> {
  /// Polls `GET /jobs/{id}/location` every few seconds while a client is
  /// looking at the tracking screen — the backend has no push/websocket
  /// support, matching the chat/offers polling pattern.
  TechnicianLocationProvider._({
    required TechnicianLocationFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'technicianLocationProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$technicianLocationHash();

  @override
  String toString() {
    return r'technicianLocationProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<TechnicianLocation?> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<TechnicianLocation?> create(Ref ref) {
    final argument = this.argument as String;
    return technicianLocation(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is TechnicianLocationProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$technicianLocationHash() =>
    r'066f5a379e0dfb8ed015097716bab330bf776daf';

/// Polls `GET /jobs/{id}/location` every few seconds while a client is
/// looking at the tracking screen — the backend has no push/websocket
/// support, matching the chat/offers polling pattern.

final class TechnicianLocationFamily extends $Family
    with $FunctionalFamilyOverride<Stream<TechnicianLocation?>, String> {
  TechnicianLocationFamily._()
    : super(
        retry: null,
        name: r'technicianLocationProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Polls `GET /jobs/{id}/location` every few seconds while a client is
  /// looking at the tracking screen — the backend has no push/websocket
  /// support, matching the chat/offers polling pattern.

  TechnicianLocationProvider call(String jobId) =>
      TechnicianLocationProvider._(argument: jobId, from: this);

  @override
  String toString() => r'technicianLocationProvider';
}

/// The signed-in technician's live-location broadcast for whichever job is
/// active: periodically reads the device's GPS position and pushes it via
/// `POST /jobs/{id}/location` while sharing is on. Survives navigation
/// (e.g. to the chat screen) so sharing doesn't silently stop mid-job.

@ProviderFor(LocationSharingController)
final locationSharingControllerProvider = LocationSharingControllerProvider._();

/// The signed-in technician's live-location broadcast for whichever job is
/// active: periodically reads the device's GPS position and pushes it via
/// `POST /jobs/{id}/location` while sharing is on. Survives navigation
/// (e.g. to the chat screen) so sharing doesn't silently stop mid-job.
final class LocationSharingControllerProvider
    extends
        $NotifierProvider<LocationSharingController, LocationSharingStatus> {
  /// The signed-in technician's live-location broadcast for whichever job is
  /// active: periodically reads the device's GPS position and pushes it via
  /// `POST /jobs/{id}/location` while sharing is on. Survives navigation
  /// (e.g. to the chat screen) so sharing doesn't silently stop mid-job.
  LocationSharingControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'locationSharingControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$locationSharingControllerHash();

  @$internal
  @override
  LocationSharingController create() => LocationSharingController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LocationSharingStatus value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LocationSharingStatus>(value),
    );
  }
}

String _$locationSharingControllerHash() =>
    r'41d8065d97298f9f998289f97e7b5a7a44a9d193';

/// The signed-in technician's live-location broadcast for whichever job is
/// active: periodically reads the device's GPS position and pushes it via
/// `POST /jobs/{id}/location` while sharing is on. Survives navigation
/// (e.g. to the chat screen) so sharing doesn't silently stop mid-job.

abstract class _$LocationSharingController
    extends $Notifier<LocationSharingStatus> {
  LocationSharingStatus build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<LocationSharingStatus, LocationSharingStatus>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<LocationSharingStatus, LocationSharingStatus>,
              LocationSharingStatus,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
