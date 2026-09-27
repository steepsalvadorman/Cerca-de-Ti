// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'chat_conversation.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ChatConversation {

 String get jobRequestId; String? get jobTitle; String get jobStatus; String get counterpartRole; String get counterpartName; String? get lastMessageText; String? get lastMessageAt; String? get lastMessageSenderId; int get unreadCount; String get updatedAt;
/// Create a copy of ChatConversation
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ChatConversationCopyWith<ChatConversation> get copyWith => _$ChatConversationCopyWithImpl<ChatConversation>(this as ChatConversation, _$identity);

  /// Serializes this ChatConversation to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ChatConversation&&(identical(other.jobRequestId, jobRequestId) || other.jobRequestId == jobRequestId)&&(identical(other.jobTitle, jobTitle) || other.jobTitle == jobTitle)&&(identical(other.jobStatus, jobStatus) || other.jobStatus == jobStatus)&&(identical(other.counterpartRole, counterpartRole) || other.counterpartRole == counterpartRole)&&(identical(other.counterpartName, counterpartName) || other.counterpartName == counterpartName)&&(identical(other.lastMessageText, lastMessageText) || other.lastMessageText == lastMessageText)&&(identical(other.lastMessageAt, lastMessageAt) || other.lastMessageAt == lastMessageAt)&&(identical(other.lastMessageSenderId, lastMessageSenderId) || other.lastMessageSenderId == lastMessageSenderId)&&(identical(other.unreadCount, unreadCount) || other.unreadCount == unreadCount)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,jobRequestId,jobTitle,jobStatus,counterpartRole,counterpartName,lastMessageText,lastMessageAt,lastMessageSenderId,unreadCount,updatedAt);

@override
String toString() {
  return 'ChatConversation(jobRequestId: $jobRequestId, jobTitle: $jobTitle, jobStatus: $jobStatus, counterpartRole: $counterpartRole, counterpartName: $counterpartName, lastMessageText: $lastMessageText, lastMessageAt: $lastMessageAt, lastMessageSenderId: $lastMessageSenderId, unreadCount: $unreadCount, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class $ChatConversationCopyWith<$Res>  {
  factory $ChatConversationCopyWith(ChatConversation value, $Res Function(ChatConversation) _then) = _$ChatConversationCopyWithImpl;
@useResult
$Res call({
 String jobRequestId, String? jobTitle, String jobStatus, String counterpartRole, String counterpartName, String? lastMessageText, String? lastMessageAt, String? lastMessageSenderId, int unreadCount, String updatedAt
});




}
/// @nodoc
class _$ChatConversationCopyWithImpl<$Res>
    implements $ChatConversationCopyWith<$Res> {
  _$ChatConversationCopyWithImpl(this._self, this._then);

  final ChatConversation _self;
  final $Res Function(ChatConversation) _then;

/// Create a copy of ChatConversation
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? jobRequestId = null,Object? jobTitle = freezed,Object? jobStatus = null,Object? counterpartRole = null,Object? counterpartName = null,Object? lastMessageText = freezed,Object? lastMessageAt = freezed,Object? lastMessageSenderId = freezed,Object? unreadCount = null,Object? updatedAt = null,}) {
  return _then(_self.copyWith(
jobRequestId: null == jobRequestId ? _self.jobRequestId : jobRequestId // ignore: cast_nullable_to_non_nullable
as String,jobTitle: freezed == jobTitle ? _self.jobTitle : jobTitle // ignore: cast_nullable_to_non_nullable
as String?,jobStatus: null == jobStatus ? _self.jobStatus : jobStatus // ignore: cast_nullable_to_non_nullable
as String,counterpartRole: null == counterpartRole ? _self.counterpartRole : counterpartRole // ignore: cast_nullable_to_non_nullable
as String,counterpartName: null == counterpartName ? _self.counterpartName : counterpartName // ignore: cast_nullable_to_non_nullable
as String,lastMessageText: freezed == lastMessageText ? _self.lastMessageText : lastMessageText // ignore: cast_nullable_to_non_nullable
as String?,lastMessageAt: freezed == lastMessageAt ? _self.lastMessageAt : lastMessageAt // ignore: cast_nullable_to_non_nullable
as String?,lastMessageSenderId: freezed == lastMessageSenderId ? _self.lastMessageSenderId : lastMessageSenderId // ignore: cast_nullable_to_non_nullable
as String?,unreadCount: null == unreadCount ? _self.unreadCount : unreadCount // ignore: cast_nullable_to_non_nullable
as int,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [ChatConversation].
extension ChatConversationPatterns on ChatConversation {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ChatConversation value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ChatConversation() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ChatConversation value)  $default,){
final _that = this;
switch (_that) {
case _ChatConversation():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ChatConversation value)?  $default,){
final _that = this;
switch (_that) {
case _ChatConversation() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String jobRequestId,  String? jobTitle,  String jobStatus,  String counterpartRole,  String counterpartName,  String? lastMessageText,  String? lastMessageAt,  String? lastMessageSenderId,  int unreadCount,  String updatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ChatConversation() when $default != null:
return $default(_that.jobRequestId,_that.jobTitle,_that.jobStatus,_that.counterpartRole,_that.counterpartName,_that.lastMessageText,_that.lastMessageAt,_that.lastMessageSenderId,_that.unreadCount,_that.updatedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String jobRequestId,  String? jobTitle,  String jobStatus,  String counterpartRole,  String counterpartName,  String? lastMessageText,  String? lastMessageAt,  String? lastMessageSenderId,  int unreadCount,  String updatedAt)  $default,) {final _that = this;
switch (_that) {
case _ChatConversation():
return $default(_that.jobRequestId,_that.jobTitle,_that.jobStatus,_that.counterpartRole,_that.counterpartName,_that.lastMessageText,_that.lastMessageAt,_that.lastMessageSenderId,_that.unreadCount,_that.updatedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String jobRequestId,  String? jobTitle,  String jobStatus,  String counterpartRole,  String counterpartName,  String? lastMessageText,  String? lastMessageAt,  String? lastMessageSenderId,  int unreadCount,  String updatedAt)?  $default,) {final _that = this;
switch (_that) {
case _ChatConversation() when $default != null:
return $default(_that.jobRequestId,_that.jobTitle,_that.jobStatus,_that.counterpartRole,_that.counterpartName,_that.lastMessageText,_that.lastMessageAt,_that.lastMessageSenderId,_that.unreadCount,_that.updatedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ChatConversation implements ChatConversation {
  const _ChatConversation({required this.jobRequestId, this.jobTitle, required this.jobStatus, required this.counterpartRole, required this.counterpartName, this.lastMessageText, this.lastMessageAt, this.lastMessageSenderId, required this.unreadCount, required this.updatedAt});
  factory _ChatConversation.fromJson(Map<String, dynamic> json) => _$ChatConversationFromJson(json);

@override final  String jobRequestId;
@override final  String? jobTitle;
@override final  String jobStatus;
@override final  String counterpartRole;
@override final  String counterpartName;
@override final  String? lastMessageText;
@override final  String? lastMessageAt;
@override final  String? lastMessageSenderId;
@override final  int unreadCount;
@override final  String updatedAt;

/// Create a copy of ChatConversation
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ChatConversationCopyWith<_ChatConversation> get copyWith => __$ChatConversationCopyWithImpl<_ChatConversation>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ChatConversationToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ChatConversation&&(identical(other.jobRequestId, jobRequestId) || other.jobRequestId == jobRequestId)&&(identical(other.jobTitle, jobTitle) || other.jobTitle == jobTitle)&&(identical(other.jobStatus, jobStatus) || other.jobStatus == jobStatus)&&(identical(other.counterpartRole, counterpartRole) || other.counterpartRole == counterpartRole)&&(identical(other.counterpartName, counterpartName) || other.counterpartName == counterpartName)&&(identical(other.lastMessageText, lastMessageText) || other.lastMessageText == lastMessageText)&&(identical(other.lastMessageAt, lastMessageAt) || other.lastMessageAt == lastMessageAt)&&(identical(other.lastMessageSenderId, lastMessageSenderId) || other.lastMessageSenderId == lastMessageSenderId)&&(identical(other.unreadCount, unreadCount) || other.unreadCount == unreadCount)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,jobRequestId,jobTitle,jobStatus,counterpartRole,counterpartName,lastMessageText,lastMessageAt,lastMessageSenderId,unreadCount,updatedAt);

@override
String toString() {
  return 'ChatConversation(jobRequestId: $jobRequestId, jobTitle: $jobTitle, jobStatus: $jobStatus, counterpartRole: $counterpartRole, counterpartName: $counterpartName, lastMessageText: $lastMessageText, lastMessageAt: $lastMessageAt, lastMessageSenderId: $lastMessageSenderId, unreadCount: $unreadCount, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$ChatConversationCopyWith<$Res> implements $ChatConversationCopyWith<$Res> {
  factory _$ChatConversationCopyWith(_ChatConversation value, $Res Function(_ChatConversation) _then) = __$ChatConversationCopyWithImpl;
@override @useResult
$Res call({
 String jobRequestId, String? jobTitle, String jobStatus, String counterpartRole, String counterpartName, String? lastMessageText, String? lastMessageAt, String? lastMessageSenderId, int unreadCount, String updatedAt
});




}
/// @nodoc
class __$ChatConversationCopyWithImpl<$Res>
    implements _$ChatConversationCopyWith<$Res> {
  __$ChatConversationCopyWithImpl(this._self, this._then);

  final _ChatConversation _self;
  final $Res Function(_ChatConversation) _then;

/// Create a copy of ChatConversation
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? jobRequestId = null,Object? jobTitle = freezed,Object? jobStatus = null,Object? counterpartRole = null,Object? counterpartName = null,Object? lastMessageText = freezed,Object? lastMessageAt = freezed,Object? lastMessageSenderId = freezed,Object? unreadCount = null,Object? updatedAt = null,}) {
  return _then(_ChatConversation(
jobRequestId: null == jobRequestId ? _self.jobRequestId : jobRequestId // ignore: cast_nullable_to_non_nullable
as String,jobTitle: freezed == jobTitle ? _self.jobTitle : jobTitle // ignore: cast_nullable_to_non_nullable
as String?,jobStatus: null == jobStatus ? _self.jobStatus : jobStatus // ignore: cast_nullable_to_non_nullable
as String,counterpartRole: null == counterpartRole ? _self.counterpartRole : counterpartRole // ignore: cast_nullable_to_non_nullable
as String,counterpartName: null == counterpartName ? _self.counterpartName : counterpartName // ignore: cast_nullable_to_non_nullable
as String,lastMessageText: freezed == lastMessageText ? _self.lastMessageText : lastMessageText // ignore: cast_nullable_to_non_nullable
as String?,lastMessageAt: freezed == lastMessageAt ? _self.lastMessageAt : lastMessageAt // ignore: cast_nullable_to_non_nullable
as String?,lastMessageSenderId: freezed == lastMessageSenderId ? _self.lastMessageSenderId : lastMessageSenderId // ignore: cast_nullable_to_non_nullable
as String?,unreadCount: null == unreadCount ? _self.unreadCount : unreadCount // ignore: cast_nullable_to_non_nullable
as int,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
