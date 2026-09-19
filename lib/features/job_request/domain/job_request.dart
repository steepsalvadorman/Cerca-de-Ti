import 'package:freezed_annotation/freezed_annotation.dart';

part 'job_request.freezed.dart';
part 'job_request.g.dart';

/// Mirrors the backend's `JobRequestResponse`.
@freezed
abstract class JobRequest with _$JobRequest {
  const factory JobRequest({
    required String id,
    required String clientId,
    int? technicianProfileId,
    int? techTeamId,
    required String jobKind,
    required String status,
    required int timelineStep,
    required String feeType,
    required int feeAmount,
    required bool feePaid,
    String? paymentMethod,
    required bool paymentDone,
    required bool mobilityIncluded,
    int? agreedPrice,
    int? rating,
    String? title,
    String? address,
    String? comment,
    required String createdAt,
  }) = _JobRequest;

  factory JobRequest.fromJson(Map<String, dynamic> json) => _$JobRequestFromJson(json);
}

extension JobRequestX on JobRequest {
  bool get isPending => status == 'pending';
  bool get isActive => status == 'active';
  bool get isCompleted => status == 'completed';
  bool get isCancelled => status == 'cancelled';

  /// Backend allows sending messages only while the job is pending or active.
  bool get isChatWritable => isPending || isActive;
}
