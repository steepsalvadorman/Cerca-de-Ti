import 'package:freezed_annotation/freezed_annotation.dart';

part 'chat_conversation.freezed.dart';
part 'chat_conversation.g.dart';

/// One row of the chat inbox. Mirrors the backend's `ConversationResponse`.
@freezed
abstract class ChatConversation with _$ChatConversation {
  const factory ChatConversation({
    required String jobRequestId,
    String? jobTitle,
    required String jobStatus,
    required String counterpartRole, // "client" | "technician"
    required String counterpartName,
    String? lastMessageText,
    String? lastMessageAt,
    String? lastMessageSenderId,
    required int unreadCount,
    required String updatedAt,
  }) = _ChatConversation;

  factory ChatConversation.fromJson(Map<String, dynamic> json) => _$ChatConversationFromJson(json);
}

extension ChatConversationX on ChatConversation {
  /// Same rule as the backend: messages only while pending or active.
  bool get isWritable => jobStatus == 'pending' || jobStatus == 'active';

  String get counterpartMono {
    final parts = counterpartName.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    final letters = parts.length == 1 ? parts.first.substring(0, 1) : '${parts.first[0]}${parts[1][0]}';
    return letters.toUpperCase();
  }
}
