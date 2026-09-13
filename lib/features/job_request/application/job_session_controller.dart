import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/network/network_providers.dart';
import '../../auth/application/auth_controller.dart';
import '../data/job_repository.dart';

part 'job_session_controller.g.dart';

class ServiceRequestDraft {
  const ServiceRequestDraft({this.categoryId, this.categoryLabel, this.description = ''});

  final String? categoryId;
  final String? categoryLabel;
  final String description;

  bool get isComplete => categoryId != null && description.trim().isNotEmpty;
  String get title => '${categoryLabel ?? 'Servicio'}: ${description.trim()}';
}

class ServiceRequestDraftController extends Notifier<ServiceRequestDraft> {
  @override
  ServiceRequestDraft build() => const ServiceRequestDraft();

  void save({required String categoryId, required String categoryLabel, required String description}) {
    state = ServiceRequestDraft(
      categoryId: categoryId,
      categoryLabel: categoryLabel,
      description: description.trim(),
    );
  }

  void clear() => state = const ServiceRequestDraft();
}

final serviceRequestDraftProvider =
    NotifierProvider<ServiceRequestDraftController, ServiceRequestDraft>(ServiceRequestDraftController.new);

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
