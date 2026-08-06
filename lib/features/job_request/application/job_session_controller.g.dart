// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'job_session_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(jobRepository)
final jobRepositoryProvider = JobRepositoryProvider._();

final class JobRepositoryProvider
    extends $FunctionalProvider<JobRepository, JobRepository, JobRepository>
    with $Provider<JobRepository> {
  JobRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'jobRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$jobRepositoryHash();

  @$internal
  @override
  $ProviderElement<JobRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  JobRepository create(Ref ref) {
    return jobRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(JobRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<JobRepository>(value),
    );
  }
}

String _$jobRepositoryHash() => r'5dd3f944b0a7eac496ee92a99e7afc02c6f14e17';

/// Bridges the app's single-shared-session UI flow (CercaController) into
/// the backend's job-id-keyed model: holds the id of whichever job the
/// client is currently walking through (bidding → fee → tracking →
/// rating), set once a `job_requests` row is actually created.

@ProviderFor(JobSessionController)
final jobSessionControllerProvider = JobSessionControllerProvider._();

/// Bridges the app's single-shared-session UI flow (CercaController) into
/// the backend's job-id-keyed model: holds the id of whichever job the
/// client is currently walking through (bidding → fee → tracking →
/// rating), set once a `job_requests` row is actually created.
final class JobSessionControllerProvider
    extends $NotifierProvider<JobSessionController, String?> {
  /// Bridges the app's single-shared-session UI flow (CercaController) into
  /// the backend's job-id-keyed model: holds the id of whichever job the
  /// client is currently walking through (bidding → fee → tracking →
  /// rating), set once a `job_requests` row is actually created.
  JobSessionControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'jobSessionControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$jobSessionControllerHash();

  @$internal
  @override
  JobSessionController create() => JobSessionController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String?>(value),
    );
  }
}

String _$jobSessionControllerHash() =>
    r'8e2e447c34b2b2b9b62d6b728f90ba67582d559a';

/// Bridges the app's single-shared-session UI flow (CercaController) into
/// the backend's job-id-keyed model: holds the id of whichever job the
/// client is currently walking through (bidding → fee → tracking →
/// rating), set once a `job_requests` row is actually created.

abstract class _$JobSessionController extends $Notifier<String?> {
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
