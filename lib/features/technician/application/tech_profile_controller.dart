import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/technician.dart';
import 'providers_controller.dart';

part 'tech_profile_controller.g.dart';

/// The signed-in technician's own profile (`GET/POST /technician/profile`).
/// `null` means no profile has been saved yet.
@riverpod
class TechProfileController extends _$TechProfileController {
  @override
  Future<Technician?> build() => ref.read(technicianRepositoryProvider).getMyProfile();

  Future<void> save({
    required String oficio,
    required String priceLabel,
    required int coverageKm,
    required List<String> availableDays,
    required List<String> categories,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(technicianRepositoryProvider).saveProfile(
            oficio: oficio,
            priceLabel: priceLabel,
            coverageKm: coverageKm,
            availableDays: availableDays,
            categories: categories,
          );
      return ref.read(technicianRepositoryProvider).getMyProfile();
    });
  }
}
