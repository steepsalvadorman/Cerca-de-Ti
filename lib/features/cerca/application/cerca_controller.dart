import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../auth/application/auth_controller.dart';
import '../domain/entities/doc_requirement.dart';
import '../domain/entities/fee_type.dart';
import '../domain/entities/job_offer.dart';
import '../domain/entities/service_provider.dart';
import 'cerca_seed_data.dart';
import 'cerca_state.dart';

part 'cerca_controller.g.dart';

/// Single shared session controller for the whole Cerca flow, mirroring the
/// prototype's single `Component.state` object: every screen reads and
/// mutates the same state, so it must stay alive across navigation instead
/// of being auto-disposed when a screen unmounts.
@Riverpod(keepAlive: true)
class CercaController extends _$CercaController {
  @override
  CercaState build() {
    // This object is deliberately kept alive across navigation, which
    // also means it survives sign-out: without this, the next account
    // inherits the previous one's trade categories, coverage radius,
    // chosen payment method and rating.
    ref.listen(authControllerProvider, (_, next) {
      if (next.value == null) state = const CercaState();
    });
    return const CercaState();
  }

  void setLoginName(String name) => state = state.copyWith(loginName: name);

  void startLoginAnimation() => state = state.copyWith(loginAnimating: true);

  void finishLoginAnimation() => state = state.copyWith(loginAnimating: false);

  void selectTech(int id) =>
      state = state.copyWith(selectedTechId: id, viewingTeam: false);

  void selectTeam(int id) =>
      state = state.copyWith(selectedTeamId: id, viewingTeam: true);

  void setJobKind(JobKind kind) => state = state.copyWith(jobKind: kind);

  void toggleMobility() =>
      state = state.copyWith(mobilityIncluded: !state.mobilityIncluded);

  void toggleDoc(String key) {
    final current = state.docs[key] ?? DocStatus.pending;
    final next = current == DocStatus.uploaded
        ? DocStatus.pending
        : DocStatus.uploaded;
    state = state.copyWith(docs: {...state.docs, key: next});
  }

  void submitDocs() => state = state.copyWith(docsSubmitted: true);

  void setSort(SortBy sort) => state = state.copyWith(sortBy: sort);

  void chooseOffer() =>
      state = state.copyWith(feeType: FeeType.bidding, feePaid: false);

  void acceptDirect() =>
      state = state.copyWith(feeType: FeeType.direct, feePaid: false);

  void requestProjectVisit() =>
      state = state.copyWith(feeType: FeeType.project, feePaid: false);

  void payFee() => state = state.copyWith(feePaid: true, jobStep: 0);

  void advanceJob() =>
      state = state.copyWith(jobStep: (state.jobStep + 1).clamp(0, 3));

  void setPayment(PaymentMethodKind method) =>
      state = state.copyWith(payment: method);

  void setRating(int n) => state = state.copyWith(rating: n);

  void confirmPayment() => state = state.copyWith(paymentDone: true);

  void toggleTechCategory(String id) {
    final next = {...state.techCategories};
    if (!next.remove(id)) next.add(id);
    state = state.copyWith(techCategories: next);
  }

  void setCoverageKm(int km) => state = state.copyWith(coverageKm: km);

  void toggleDay(String day) {
    final next = {...state.availableDays};
    if (!next.remove(day)) next.add(day);
    state = state.copyWith(availableDays: next);
  }

  void saveTechProfile() => state = state.copyWith(techProfileSaved: true);

  void saveClientProfile() =>
      state = state.copyWith(clientProfileSaved: true);

  // --- Computed view data, recomputed from current state on every read
  // (equivalent to the prototype's `renderVals()`). ---

  ServiceProvider get selectedProvider {
    if (state.viewingTeam) {
      return CercaSeedData.teams.firstWhere(
        (t) => t.id == state.selectedTeamId,
        orElse: () => CercaSeedData.teams.first,
      );
    }
    return CercaSeedData.technicians.firstWhere(
      (t) => t.id == state.selectedTechId,
      orElse: () => CercaSeedData.technicians.first,
    );
  }

  int get uploadedDocsCount =>
      state.docs.values.where((v) => v == DocStatus.uploaded).length;

  bool get allDocsUploaded =>
      uploadedDocsCount == CercaSeedData.docRequirements.length;

  double get docsProgress =>
      uploadedDocsCount / CercaSeedData.docRequirements.length;

  FeeConfig get currentFeeConfig => CercaSeedData.feeConfig[state.feeType]!;

  List<JobOffer> get sortedOffers {
    final list = [...CercaSeedData.offers];
    if (state.sortBy == SortBy.price) {
      list.sort((a, b) => a.price.compareTo(b.price));
    } else {
      list.sort((a, b) => b.rating.compareTo(a.rating));
    }
    return list;
  }

  int get projectMobilityCost {
    final provider = selectedProvider;
    if (provider is! TechTeam) return 0;
    return state.mobilityIncluded ? provider.mobilityCost : 0;
  }

  int get projectTotal {
    final provider = selectedProvider;
    if (provider is! TechTeam) return 0;
    return provider.laborCost + provider.materialsCost + projectMobilityCost;
  }

  String get loginInitial =>
      state.loginName.trim().isEmpty ? '?' : state.loginName.trim()[0].toUpperCase();

  String get loginButtonLabel {
    if (state.loginAnimating) return '';
    if (state.loginRemembered) {
      final firstName = state.loginName.trim().split(' ').first;
      return 'Continuar como $firstName';
    }
    return 'Ingresar';
  }
}
