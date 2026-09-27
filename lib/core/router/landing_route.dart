import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/domain/auth_user.dart';
import '../../features/technician/application/tech_profile_controller.dart';
import 'route_paths.dart';

/// Where a signed-in person lands when the app opens or after logging in:
/// straight into their hub instead of the one-button Welcome screen.
///
/// Welcome is kept for fresh registrations and for a technician whose
/// professional profile is still incomplete, since there it explains the
/// next step. If the profile can't be checked quickly, Welcome is the safe
/// default — it shows the right call to action once the profile loads.
Future<String> landingRouteFor(WidgetRef ref, AuthUser user) async {
  if (!user.isTechnician) return RoutePaths.home;

  try {
    final profile = await ref.read(techProfileControllerProvider.future).timeout(const Duration(seconds: 3));
    final complete = profile != null && profile.oficio.trim().isNotEmpty && profile.categories.isNotEmpty;
    return complete ? RoutePaths.technicianJobs : RoutePaths.welcome;
  } catch (_) {
    return RoutePaths.welcome;
  }
}
