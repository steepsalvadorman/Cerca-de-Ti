import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/network/polling.dart';
import '../domain/job_offer.dart';
import 'job_session_controller.dart';

part 'offers_controller.g.dart';

/// Polls `GET /jobs/{id}/offers` every few seconds while a bidding job's
/// offer list is on screen — the backend has no push/websocket support,
/// so this is the simplest way to reflect new technician bids.
@riverpod
Stream<List<JobOffer>> jobOffers(Ref ref, String jobId) {
  final repo = ref.watch(jobRepositoryProvider);
  return pollWithBackoff(() => repo.getOffers(jobId), every: const Duration(seconds: 4));
}
