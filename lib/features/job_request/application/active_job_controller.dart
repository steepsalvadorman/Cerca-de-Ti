import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/job_repository.dart';
import '../domain/job_request.dart';
import 'job_session_controller.dart';

part 'active_job_controller.g.dart';

/// The job the client is currently walking through, resolved from
/// [JobSessionController]'s id. `null` while no job has been created yet.
@riverpod
class ActiveJobController extends _$ActiveJobController {
  @override
  Future<JobRequest?> build() async {
    final jobId = ref.watch(jobSessionControllerProvider);
    if (jobId == null) return null;
    return ref.read(jobRepositoryProvider).getJob(jobId);
  }

  Future<void> _refresh() async {
    final jobId = ref.read(jobSessionControllerProvider);
    if (jobId == null) return;
    state = await AsyncValue.guard(() => ref.read(jobRepositoryProvider).getJob(jobId));
  }

  Future<PayFeeResult?> payFee(String paymentMethod) async {
    final jobId = ref.read(jobSessionControllerProvider);
    if (jobId == null) return null;
    state = const AsyncLoading();
    final result = await ref.read(jobRepositoryProvider).payFee(jobId, paymentMethod);
    await _refresh();
    return result;
  }

  Future<void> advance() async {
    final jobId = ref.read(jobSessionControllerProvider);
    if (jobId == null) return;
    await ref.read(jobRepositoryProvider).advance(jobId);
    await _refresh();
  }

  Future<void> rate(int rating, {String? comment}) async {
    final jobId = ref.read(jobSessionControllerProvider);
    if (jobId == null) return;
    state = const AsyncLoading();
    await ref.read(jobRepositoryProvider).rate(jobId, rating, comment: comment);
    await _refresh();
  }

  Future<void> chooseOffer(int offerId) async {
    final jobId = ref.read(jobSessionControllerProvider);
    if (jobId == null) return;
    state = const AsyncLoading();
    await ref.read(jobRepositoryProvider).chooseOffer(jobId, offerId);
    await _refresh();
  }
}
