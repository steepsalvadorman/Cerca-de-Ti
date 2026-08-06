import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/network/network_providers.dart';
import '../../auth/application/auth_controller.dart';
import '../data/job_repository.dart';

part 'job_session_controller.g.dart';

@Riverpod(keepAlive: true)
JobRepository jobRepository(Ref ref) => JobRepository(ref.watch(apiClientProvider));

/// Bridges the app's single-shared-session UI flow (CercaController) into
/// the backend's job-id-keyed model: holds the id of whichever job the
/// client is currently walking through (bidding → fee → tracking →
/// rating), set once a `job_requests` row is actually created.
@Riverpod(keepAlive: true)
class JobSessionController extends _$JobSessionController {
  @override
  String? build() {
    // Being keepAlive, this survives sign-out on its own, and the next
    // account would inherit the previous one's active job.
    ref.listen(authControllerProvider, (_, next) {
      if (next.value == null) clear();
    });
    return null;
  }

  void setJobId(String jobId) => state = jobId;

  void clear() => state = null;
}
