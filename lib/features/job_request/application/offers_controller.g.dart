// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'offers_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Polls `GET /jobs/{id}/offers` every few seconds while a bidding job's
/// offer list is on screen — the backend has no push/websocket support,
/// so this is the simplest way to reflect new technician bids.

@ProviderFor(jobOffers)
final jobOffersProvider = JobOffersFamily._();

/// Polls `GET /jobs/{id}/offers` every few seconds while a bidding job's
/// offer list is on screen — the backend has no push/websocket support,
/// so this is the simplest way to reflect new technician bids.

final class JobOffersProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<JobOffer>>,
          List<JobOffer>,
          Stream<List<JobOffer>>
        >
    with $FutureModifier<List<JobOffer>>, $StreamProvider<List<JobOffer>> {
  /// Polls `GET /jobs/{id}/offers` every few seconds while a bidding job's
  /// offer list is on screen — the backend has no push/websocket support,
  /// so this is the simplest way to reflect new technician bids.
  JobOffersProvider._({
    required JobOffersFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'jobOffersProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$jobOffersHash();

  @override
  String toString() {
    return r'jobOffersProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<JobOffer>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<JobOffer>> create(Ref ref) {
    final argument = this.argument as String;
    return jobOffers(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is JobOffersProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$jobOffersHash() => r'bdfb0c5fcb7762f5cf57d8225254e2ba4ece10b7';

/// Polls `GET /jobs/{id}/offers` every few seconds while a bidding job's
/// offer list is on screen — the backend has no push/websocket support,
/// so this is the simplest way to reflect new technician bids.

final class JobOffersFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<JobOffer>>, String> {
  JobOffersFamily._()
    : super(
        retry: null,
        name: r'jobOffersProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Polls `GET /jobs/{id}/offers` every few seconds while a bidding job's
  /// offer list is on screen — the backend has no push/websocket support,
  /// so this is the simplest way to reflect new technician bids.

  JobOffersProvider call(String jobId) =>
      JobOffersProvider._(argument: jobId, from: this);

  @override
  String toString() => r'jobOffersProvider';
}
