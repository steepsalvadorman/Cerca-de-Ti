// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tech_docs_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The signed-in technician's document checklist
/// (`GET /technician/documents`, plus the upload-url/confirm pair).

@ProviderFor(TechDocsController)
final techDocsControllerProvider = TechDocsControllerProvider._();

/// The signed-in technician's document checklist
/// (`GET /technician/documents`, plus the upload-url/confirm pair).
final class TechDocsControllerProvider
    extends
        $AsyncNotifierProvider<
          TechDocsController,
          List<TechnicianDocumentStatus>
        > {
  /// The signed-in technician's document checklist
  /// (`GET /technician/documents`, plus the upload-url/confirm pair).
  TechDocsControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'techDocsControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$techDocsControllerHash();

  @$internal
  @override
  TechDocsController create() => TechDocsController();
}

String _$techDocsControllerHash() =>
    r'4edd6a7253f0d1c43c71dd4ad67ad716325ab454';

/// The signed-in technician's document checklist
/// (`GET /technician/documents`, plus the upload-url/confirm pair).

abstract class _$TechDocsController
    extends $AsyncNotifier<List<TechnicianDocumentStatus>> {
  FutureOr<List<TechnicianDocumentStatus>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<
              AsyncValue<List<TechnicianDocumentStatus>>,
              List<TechnicianDocumentStatus>
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<List<TechnicianDocumentStatus>>,
                List<TechnicianDocumentStatus>
              >,
              AsyncValue<List<TechnicianDocumentStatus>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
