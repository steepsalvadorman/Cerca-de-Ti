import 'package:freezed_annotation/freezed_annotation.dart';

import '../domain/entities/doc_requirement.dart';
import '../domain/entities/fee_type.dart';

part 'cerca_state.freezed.dart';

enum JobKind { puntual, proyecto }

enum SortBy { price, rating }

enum PaymentMethodKind { card, cash, transfer }

@freezed
abstract class CercaState with _$CercaState {
  const factory CercaState({
    @Default('Sofía Herrera') String loginName,
    @Default(true) bool loginRemembered,
    @Default(false) bool loginAnimating,
    @Default(JobKind.puntual) JobKind jobKind,
    @Default({
      'cedula': DocStatus.uploaded,
      'antecedentes': DocStatus.uploaded,
      'especialidad': DocStatus.pending,
      'seguro': DocStatus.pending,
    })
    Map<String, DocStatus> docs,
    @Default(false) bool docsSubmitted,
    @Default({'gasfiteria', 'electrodomesticos'}) Set<String> techCategories,
    @Default(8) int coverageKm,
    @Default({'lun', 'mar', 'mie', 'jue', 'vie'}) Set<String> availableDays,
    @Default(false) bool techProfileSaved,
    @Default(false) bool clientProfileSaved,
    @Default(FeeType.direct) FeeType feeType,
    @Default(false) bool feePaid,
    @Default(false) bool viewingTeam,
    @Default(1) int selectedTeamId,
    @Default(true) bool mobilityIncluded,
    @Default(SortBy.price) SortBy sortBy,
    @Default(PaymentMethodKind.card) PaymentMethodKind payment,
    @Default(0) int rating,
    @Default(0) int jobStep,
    @Default(1) int selectedTechId,
    @Default(false) bool paymentDone,
  }) = _CercaState;
}
