import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/network/network_providers.dart';
import '../data/technician_repository.dart';

part 'providers_controller.g.dart';

@riverpod
TechnicianRepository technicianRepository(Ref ref) => TechnicianRepository(ref.watch(apiClientProvider));

/// Which trade the home screen is filtered to, or `null` for all of
/// them. Its id matches `technician_profiles.categories` in the backend
/// (`gasfiteria`, `electricidad`, …).
@riverpod
class SelectedCategory extends _$SelectedCategory {
  @override
  String? build() => null;

  /// Tapping the active chip clears the filter, which is the only way
  /// back to the full listing.
  void toggle(String categoryId) => state = state == categoryId ? null : categoryId;

  void select(String categoryId) => state = categoryId;

  void clear() => state = null;
}

/// Home screen's technician/team listing (`GET /providers`).
@riverpod
class ProvidersController extends _$ProvidersController {
  @override
  Future<ProvidersPage> build() {
    // `watch`, so picking a category refetches on its own.
    final category = ref.watch(selectedCategoryProvider);
    return ref.read(technicianRepositoryProvider).getProviders(category: category);
  }
}
