// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_conversation.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ChatConversation _$ChatConversationFromJson(Map<String, dynamic> json) =>
    _ChatConversation(
      jobRequestId: json['job_request_id'] as String,
      jobTitle: json['job_title'] as String?,
      jobStatus: json['job_status'] as String,
      counterpartRole: json['counterpart_role'] as String,
      counterpartName: json['counterpart_name'] as String,
      lastMessageText: json['last_message_text'] as String?,
      lastMessageAt: json['last_message_at'] as String?,
      lastMessageSenderId: json['last_message_sender_id'] as String?,
      unreadCount: (json['unread_count'] as num).toInt(),
      updatedAt: json['updated_at'] as String,
    );

Map<String, dynamic> _$ChatConversationToJson(_ChatConversation instance) =>
    <String, dynamic>{
      'job_request_id': instance.jobRequestId,
      'job_title': instance.jobTitle,
      'job_status': instance.jobStatus,
      'counterpart_role': instance.counterpartRole,
      'counterpart_name': instance.counterpartName,
      'last_message_text': instance.lastMessageText,
      'last_message_at': instance.lastMessageAt,
      'last_message_sender_id': instance.lastMessageSenderId,
      'unread_count': instance.unreadCount,
      'updated_at': instance.updatedAt,
    };
