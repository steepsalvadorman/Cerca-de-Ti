// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'cerca_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$CercaState {

 String get loginName; bool get loginRemembered; bool get loginAnimating; JobKind get jobKind; Map<String, DocStatus> get docs; bool get docsSubmitted; Set<String> get techCategories; int get coverageKm; Set<String> get availableDays; bool get techProfileSaved; bool get clientProfileSaved; FeeType get feeType; bool get feePaid; bool get viewingTeam; int get selectedTeamId; bool get mobilityIncluded; SortBy get sortBy; PaymentMethodKind get payment; int get rating; int get jobStep; int get selectedTechId; bool get paymentDone;
/// Create a copy of CercaState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CercaStateCopyWith<CercaState> get copyWith => _$CercaStateCopyWithImpl<CercaState>(this as CercaState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CercaState&&(identical(other.loginName, loginName) || other.loginName == loginName)&&(identical(other.loginRemembered, loginRemembered) || other.loginRemembered == loginRemembered)&&(identical(other.loginAnimating, loginAnimating) || other.loginAnimating == loginAnimating)&&(identical(other.jobKind, jobKind) || other.jobKind == jobKind)&&const DeepCollectionEquality().equals(other.docs, docs)&&(identical(other.docsSubmitted, docsSubmitted) || other.docsSubmitted == docsSubmitted)&&const DeepCollectionEquality().equals(other.techCategories, techCategories)&&(identical(other.coverageKm, coverageKm) || other.coverageKm == coverageKm)&&const DeepCollectionEquality().equals(other.availableDays, availableDays)&&(identical(other.techProfileSaved, techProfileSaved) || other.techProfileSaved == techProfileSaved)&&(identical(other.clientProfileSaved, clientProfileSaved) || other.clientProfileSaved == clientProfileSaved)&&(identical(other.feeType, feeType) || other.feeType == feeType)&&(identical(other.feePaid, feePaid) || other.feePaid == feePaid)&&(identical(other.viewingTeam, viewingTeam) || other.viewingTeam == viewingTeam)&&(identical(other.selectedTeamId, selectedTeamId) || other.selectedTeamId == selectedTeamId)&&(identical(other.mobilityIncluded, mobilityIncluded) || other.mobilityIncluded == mobilityIncluded)&&(identical(other.sortBy, sortBy) || other.sortBy == sortBy)&&(identical(other.payment, payment) || other.payment == payment)&&(identical(other.rating, rating) || other.rating == rating)&&(identical(other.jobStep, jobStep) || other.jobStep == jobStep)&&(identical(other.selectedTechId, selectedTechId) || other.selectedTechId == selectedTechId)&&(identical(other.paymentDone, paymentDone) || other.paymentDone == paymentDone));
}


@override
int get hashCode => Object.hashAll([runtimeType,loginName,loginRemembered,loginAnimating,jobKind,const DeepCollectionEquality().hash(docs),docsSubmitted,const DeepCollectionEquality().hash(techCategories),coverageKm,const DeepCollectionEquality().hash(availableDays),techProfileSaved,clientProfileSaved,feeType,feePaid,viewingTeam,selectedTeamId,mobilityIncluded,sortBy,payment,rating,jobStep,selectedTechId,paymentDone]);

@override
String toString() {
  return 'CercaState(loginName: $loginName, loginRemembered: $loginRemembered, loginAnimating: $loginAnimating, jobKind: $jobKind, docs: $docs, docsSubmitted: $docsSubmitted, techCategories: $techCategories, coverageKm: $coverageKm, availableDays: $availableDays, techProfileSaved: $techProfileSaved, clientProfileSaved: $clientProfileSaved, feeType: $feeType, feePaid: $feePaid, viewingTeam: $viewingTeam, selectedTeamId: $selectedTeamId, mobilityIncluded: $mobilityIncluded, sortBy: $sortBy, payment: $payment, rating: $rating, jobStep: $jobStep, selectedTechId: $selectedTechId, paymentDone: $paymentDone)';
}


}

/// @nodoc
abstract mixin class $CercaStateCopyWith<$Res>  {
  factory $CercaStateCopyWith(CercaState value, $Res Function(CercaState) _then) = _$CercaStateCopyWithImpl;
@useResult
$Res call({
 String loginName, bool loginRemembered, bool loginAnimating, JobKind jobKind, Map<String, DocStatus> docs, bool docsSubmitted, Set<String> techCategories, int coverageKm, Set<String> availableDays, bool techProfileSaved, bool clientProfileSaved, FeeType feeType, bool feePaid, bool viewingTeam, int selectedTeamId, bool mobilityIncluded, SortBy sortBy, PaymentMethodKind payment, int rating, int jobStep, int selectedTechId, bool paymentDone
});




}
/// @nodoc
class _$CercaStateCopyWithImpl<$Res>
    implements $CercaStateCopyWith<$Res> {
  _$CercaStateCopyWithImpl(this._self, this._then);

  final CercaState _self;
  final $Res Function(CercaState) _then;

/// Create a copy of CercaState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? loginName = null,Object? loginRemembered = null,Object? loginAnimating = null,Object? jobKind = null,Object? docs = null,Object? docsSubmitted = null,Object? techCategories = null,Object? coverageKm = null,Object? availableDays = null,Object? techProfileSaved = null,Object? clientProfileSaved = null,Object? feeType = null,Object? feePaid = null,Object? viewingTeam = null,Object? selectedTeamId = null,Object? mobilityIncluded = null,Object? sortBy = null,Object? payment = null,Object? rating = null,Object? jobStep = null,Object? selectedTechId = null,Object? paymentDone = null,}) {
  return _then(_self.copyWith(
loginName: null == loginName ? _self.loginName : loginName // ignore: cast_nullable_to_non_nullable
as String,loginRemembered: null == loginRemembered ? _self.loginRemembered : loginRemembered // ignore: cast_nullable_to_non_nullable
as bool,loginAnimating: null == loginAnimating ? _self.loginAnimating : loginAnimating // ignore: cast_nullable_to_non_nullable
as bool,jobKind: null == jobKind ? _self.jobKind : jobKind // ignore: cast_nullable_to_non_nullable
as JobKind,docs: null == docs ? _self.docs : docs // ignore: cast_nullable_to_non_nullable
as Map<String, DocStatus>,docsSubmitted: null == docsSubmitted ? _self.docsSubmitted : docsSubmitted // ignore: cast_nullable_to_non_nullable
as bool,techCategories: null == techCategories ? _self.techCategories : techCategories // ignore: cast_nullable_to_non_nullable
as Set<String>,coverageKm: null == coverageKm ? _self.coverageKm : coverageKm // ignore: cast_nullable_to_non_nullable
as int,availableDays: null == availableDays ? _self.availableDays : availableDays // ignore: cast_nullable_to_non_nullable
as Set<String>,techProfileSaved: null == techProfileSaved ? _self.techProfileSaved : techProfileSaved // ignore: cast_nullable_to_non_nullable
as bool,clientProfileSaved: null == clientProfileSaved ? _self.clientProfileSaved : clientProfileSaved // ignore: cast_nullable_to_non_nullable
as bool,feeType: null == feeType ? _self.feeType : feeType // ignore: cast_nullable_to_non_nullable
as FeeType,feePaid: null == feePaid ? _self.feePaid : feePaid // ignore: cast_nullable_to_non_nullable
as bool,viewingTeam: null == viewingTeam ? _self.viewingTeam : viewingTeam // ignore: cast_nullable_to_non_nullable
as bool,selectedTeamId: null == selectedTeamId ? _self.selectedTeamId : selectedTeamId // ignore: cast_nullable_to_non_nullable
as int,mobilityIncluded: null == mobilityIncluded ? _self.mobilityIncluded : mobilityIncluded // ignore: cast_nullable_to_non_nullable
as bool,sortBy: null == sortBy ? _self.sortBy : sortBy // ignore: cast_nullable_to_non_nullable
as SortBy,payment: null == payment ? _self.payment : payment // ignore: cast_nullable_to_non_nullable
as PaymentMethodKind,rating: null == rating ? _self.rating : rating // ignore: cast_nullable_to_non_nullable
as int,jobStep: null == jobStep ? _self.jobStep : jobStep // ignore: cast_nullable_to_non_nullable
as int,selectedTechId: null == selectedTechId ? _self.selectedTechId : selectedTechId // ignore: cast_nullable_to_non_nullable
as int,paymentDone: null == paymentDone ? _self.paymentDone : paymentDone // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [CercaState].
extension CercaStatePatterns on CercaState {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CercaState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CercaState() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CercaState value)  $default,){
final _that = this;
switch (_that) {
case _CercaState():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CercaState value)?  $default,){
final _that = this;
switch (_that) {
case _CercaState() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String loginName,  bool loginRemembered,  bool loginAnimating,  JobKind jobKind,  Map<String, DocStatus> docs,  bool docsSubmitted,  Set<String> techCategories,  int coverageKm,  Set<String> availableDays,  bool techProfileSaved,  bool clientProfileSaved,  FeeType feeType,  bool feePaid,  bool viewingTeam,  int selectedTeamId,  bool mobilityIncluded,  SortBy sortBy,  PaymentMethodKind payment,  int rating,  int jobStep,  int selectedTechId,  bool paymentDone)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CercaState() when $default != null:
return $default(_that.loginName,_that.loginRemembered,_that.loginAnimating,_that.jobKind,_that.docs,_that.docsSubmitted,_that.techCategories,_that.coverageKm,_that.availableDays,_that.techProfileSaved,_that.clientProfileSaved,_that.feeType,_that.feePaid,_that.viewingTeam,_that.selectedTeamId,_that.mobilityIncluded,_that.sortBy,_that.payment,_that.rating,_that.jobStep,_that.selectedTechId,_that.paymentDone);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String loginName,  bool loginRemembered,  bool loginAnimating,  JobKind jobKind,  Map<String, DocStatus> docs,  bool docsSubmitted,  Set<String> techCategories,  int coverageKm,  Set<String> availableDays,  bool techProfileSaved,  bool clientProfileSaved,  FeeType feeType,  bool feePaid,  bool viewingTeam,  int selectedTeamId,  bool mobilityIncluded,  SortBy sortBy,  PaymentMethodKind payment,  int rating,  int jobStep,  int selectedTechId,  bool paymentDone)  $default,) {final _that = this;
switch (_that) {
case _CercaState():
return $default(_that.loginName,_that.loginRemembered,_that.loginAnimating,_that.jobKind,_that.docs,_that.docsSubmitted,_that.techCategories,_that.coverageKm,_that.availableDays,_that.techProfileSaved,_that.clientProfileSaved,_that.feeType,_that.feePaid,_that.viewingTeam,_that.selectedTeamId,_that.mobilityIncluded,_that.sortBy,_that.payment,_that.rating,_that.jobStep,_that.selectedTechId,_that.paymentDone);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String loginName,  bool loginRemembered,  bool loginAnimating,  JobKind jobKind,  Map<String, DocStatus> docs,  bool docsSubmitted,  Set<String> techCategories,  int coverageKm,  Set<String> availableDays,  bool techProfileSaved,  bool clientProfileSaved,  FeeType feeType,  bool feePaid,  bool viewingTeam,  int selectedTeamId,  bool mobilityIncluded,  SortBy sortBy,  PaymentMethodKind payment,  int rating,  int jobStep,  int selectedTechId,  bool paymentDone)?  $default,) {final _that = this;
switch (_that) {
case _CercaState() when $default != null:
return $default(_that.loginName,_that.loginRemembered,_that.loginAnimating,_that.jobKind,_that.docs,_that.docsSubmitted,_that.techCategories,_that.coverageKm,_that.availableDays,_that.techProfileSaved,_that.clientProfileSaved,_that.feeType,_that.feePaid,_that.viewingTeam,_that.selectedTeamId,_that.mobilityIncluded,_that.sortBy,_that.payment,_that.rating,_that.jobStep,_that.selectedTechId,_that.paymentDone);case _:
  return null;

}
}

}

/// @nodoc


class _CercaState implements CercaState {
  const _CercaState({this.loginName = 'Sofía Herrera', this.loginRemembered = true, this.loginAnimating = false, this.jobKind = JobKind.puntual, final  Map<String, DocStatus> docs = const {'cedula' : DocStatus.uploaded, 'antecedentes' : DocStatus.uploaded, 'especialidad' : DocStatus.pending, 'seguro' : DocStatus.pending}, this.docsSubmitted = false, final  Set<String> techCategories = const {'gasfiteria', 'electrodomesticos'}, this.coverageKm = 8, final  Set<String> availableDays = const {'lun', 'mar', 'mie', 'jue', 'vie'}, this.techProfileSaved = false, this.clientProfileSaved = false, this.feeType = FeeType.direct, this.feePaid = false, this.viewingTeam = false, this.selectedTeamId = 1, this.mobilityIncluded = true, this.sortBy = SortBy.price, this.payment = PaymentMethodKind.card, this.rating = 0, this.jobStep = 0, this.selectedTechId = 1, this.paymentDone = false}): _docs = docs,_techCategories = techCategories,_availableDays = availableDays;
  

@override@JsonKey() final  String loginName;
@override@JsonKey() final  bool loginRemembered;
@override@JsonKey() final  bool loginAnimating;
@override@JsonKey() final  JobKind jobKind;
 final  Map<String, DocStatus> _docs;
@override@JsonKey() Map<String, DocStatus> get docs {
  if (_docs is EqualUnmodifiableMapView) return _docs;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_docs);
}

@override@JsonKey() final  bool docsSubmitted;
 final  Set<String> _techCategories;
@override@JsonKey() Set<String> get techCategories {
  if (_techCategories is EqualUnmodifiableSetView) return _techCategories;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableSetView(_techCategories);
}

@override@JsonKey() final  int coverageKm;
 final  Set<String> _availableDays;
@override@JsonKey() Set<String> get availableDays {
  if (_availableDays is EqualUnmodifiableSetView) return _availableDays;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableSetView(_availableDays);
}

@override@JsonKey() final  bool techProfileSaved;
@override@JsonKey() final  bool clientProfileSaved;
@override@JsonKey() final  FeeType feeType;
@override@JsonKey() final  bool feePaid;
@override@JsonKey() final  bool viewingTeam;
@override@JsonKey() final  int selectedTeamId;
@override@JsonKey() final  bool mobilityIncluded;
@override@JsonKey() final  SortBy sortBy;
@override@JsonKey() final  PaymentMethodKind payment;
@override@JsonKey() final  int rating;
@override@JsonKey() final  int jobStep;
@override@JsonKey() final  int selectedTechId;
@override@JsonKey() final  bool paymentDone;

/// Create a copy of CercaState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CercaStateCopyWith<_CercaState> get copyWith => __$CercaStateCopyWithImpl<_CercaState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CercaState&&(identical(other.loginName, loginName) || other.loginName == loginName)&&(identical(other.loginRemembered, loginRemembered) || other.loginRemembered == loginRemembered)&&(identical(other.loginAnimating, loginAnimating) || other.loginAnimating == loginAnimating)&&(identical(other.jobKind, jobKind) || other.jobKind == jobKind)&&const DeepCollectionEquality().equals(other._docs, _docs)&&(identical(other.docsSubmitted, docsSubmitted) || other.docsSubmitted == docsSubmitted)&&const DeepCollectionEquality().equals(other._techCategories, _techCategories)&&(identical(other.coverageKm, coverageKm) || other.coverageKm == coverageKm)&&const DeepCollectionEquality().equals(other._availableDays, _availableDays)&&(identical(other.techProfileSaved, techProfileSaved) || other.techProfileSaved == techProfileSaved)&&(identical(other.clientProfileSaved, clientProfileSaved) || other.clientProfileSaved == clientProfileSaved)&&(identical(other.feeType, feeType) || other.feeType == feeType)&&(identical(other.feePaid, feePaid) || other.feePaid == feePaid)&&(identical(other.viewingTeam, viewingTeam) || other.viewingTeam == viewingTeam)&&(identical(other.selectedTeamId, selectedTeamId) || other.selectedTeamId == selectedTeamId)&&(identical(other.mobilityIncluded, mobilityIncluded) || other.mobilityIncluded == mobilityIncluded)&&(identical(other.sortBy, sortBy) || other.sortBy == sortBy)&&(identical(other.payment, payment) || other.payment == payment)&&(identical(other.rating, rating) || other.rating == rating)&&(identical(other.jobStep, jobStep) || other.jobStep == jobStep)&&(identical(other.selectedTechId, selectedTechId) || other.selectedTechId == selectedTechId)&&(identical(other.paymentDone, paymentDone) || other.paymentDone == paymentDone));
}


@override
int get hashCode => Object.hashAll([runtimeType,loginName,loginRemembered,loginAnimating,jobKind,const DeepCollectionEquality().hash(_docs),docsSubmitted,const DeepCollectionEquality().hash(_techCategories),coverageKm,const DeepCollectionEquality().hash(_availableDays),techProfileSaved,clientProfileSaved,feeType,feePaid,viewingTeam,selectedTeamId,mobilityIncluded,sortBy,payment,rating,jobStep,selectedTechId,paymentDone]);

@override
String toString() {
  return 'CercaState(loginName: $loginName, loginRemembered: $loginRemembered, loginAnimating: $loginAnimating, jobKind: $jobKind, docs: $docs, docsSubmitted: $docsSubmitted, techCategories: $techCategories, coverageKm: $coverageKm, availableDays: $availableDays, techProfileSaved: $techProfileSaved, clientProfileSaved: $clientProfileSaved, feeType: $feeType, feePaid: $feePaid, viewingTeam: $viewingTeam, selectedTeamId: $selectedTeamId, mobilityIncluded: $mobilityIncluded, sortBy: $sortBy, payment: $payment, rating: $rating, jobStep: $jobStep, selectedTechId: $selectedTechId, paymentDone: $paymentDone)';
}


}

/// @nodoc
abstract mixin class _$CercaStateCopyWith<$Res> implements $CercaStateCopyWith<$Res> {
  factory _$CercaStateCopyWith(_CercaState value, $Res Function(_CercaState) _then) = __$CercaStateCopyWithImpl;
@override @useResult
$Res call({
 String loginName, bool loginRemembered, bool loginAnimating, JobKind jobKind, Map<String, DocStatus> docs, bool docsSubmitted, Set<String> techCategories, int coverageKm, Set<String> availableDays, bool techProfileSaved, bool clientProfileSaved, FeeType feeType, bool feePaid, bool viewingTeam, int selectedTeamId, bool mobilityIncluded, SortBy sortBy, PaymentMethodKind payment, int rating, int jobStep, int selectedTechId, bool paymentDone
});




}
/// @nodoc
class __$CercaStateCopyWithImpl<$Res>
    implements _$CercaStateCopyWith<$Res> {
  __$CercaStateCopyWithImpl(this._self, this._then);

  final _CercaState _self;
  final $Res Function(_CercaState) _then;

/// Create a copy of CercaState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? loginName = null,Object? loginRemembered = null,Object? loginAnimating = null,Object? jobKind = null,Object? docs = null,Object? docsSubmitted = null,Object? techCategories = null,Object? coverageKm = null,Object? availableDays = null,Object? techProfileSaved = null,Object? clientProfileSaved = null,Object? feeType = null,Object? feePaid = null,Object? viewingTeam = null,Object? selectedTeamId = null,Object? mobilityIncluded = null,Object? sortBy = null,Object? payment = null,Object? rating = null,Object? jobStep = null,Object? selectedTechId = null,Object? paymentDone = null,}) {
  return _then(_CercaState(
loginName: null == loginName ? _self.loginName : loginName // ignore: cast_nullable_to_non_nullable
as String,loginRemembered: null == loginRemembered ? _self.loginRemembered : loginRemembered // ignore: cast_nullable_to_non_nullable
as bool,loginAnimating: null == loginAnimating ? _self.loginAnimating : loginAnimating // ignore: cast_nullable_to_non_nullable
as bool,jobKind: null == jobKind ? _self.jobKind : jobKind // ignore: cast_nullable_to_non_nullable
as JobKind,docs: null == docs ? _self._docs : docs // ignore: cast_nullable_to_non_nullable
as Map<String, DocStatus>,docsSubmitted: null == docsSubmitted ? _self.docsSubmitted : docsSubmitted // ignore: cast_nullable_to_non_nullable
as bool,techCategories: null == techCategories ? _self._techCategories : techCategories // ignore: cast_nullable_to_non_nullable
as Set<String>,coverageKm: null == coverageKm ? _self.coverageKm : coverageKm // ignore: cast_nullable_to_non_nullable
as int,availableDays: null == availableDays ? _self._availableDays : availableDays // ignore: cast_nullable_to_non_nullable
as Set<String>,techProfileSaved: null == techProfileSaved ? _self.techProfileSaved : techProfileSaved // ignore: cast_nullable_to_non_nullable
as bool,clientProfileSaved: null == clientProfileSaved ? _self.clientProfileSaved : clientProfileSaved // ignore: cast_nullable_to_non_nullable
as bool,feeType: null == feeType ? _self.feeType : feeType // ignore: cast_nullable_to_non_nullable
as FeeType,feePaid: null == feePaid ? _self.feePaid : feePaid // ignore: cast_nullable_to_non_nullable
as bool,viewingTeam: null == viewingTeam ? _self.viewingTeam : viewingTeam // ignore: cast_nullable_to_non_nullable
as bool,selectedTeamId: null == selectedTeamId ? _self.selectedTeamId : selectedTeamId // ignore: cast_nullable_to_non_nullable
as int,mobilityIncluded: null == mobilityIncluded ? _self.mobilityIncluded : mobilityIncluded // ignore: cast_nullable_to_non_nullable
as bool,sortBy: null == sortBy ? _self.sortBy : sortBy // ignore: cast_nullable_to_non_nullable
as SortBy,payment: null == payment ? _self.payment : payment // ignore: cast_nullable_to_non_nullable
as PaymentMethodKind,rating: null == rating ? _self.rating : rating // ignore: cast_nullable_to_non_nullable
as int,jobStep: null == jobStep ? _self.jobStep : jobStep // ignore: cast_nullable_to_non_nullable
as int,selectedTechId: null == selectedTechId ? _self.selectedTechId : selectedTechId // ignore: cast_nullable_to_non_nullable
as int,paymentDone: null == paymentDone ? _self.paymentDone : paymentDone // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
