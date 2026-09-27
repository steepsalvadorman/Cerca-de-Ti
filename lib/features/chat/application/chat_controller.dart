import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/network/network_providers.dart';
import '../../../core/network/polling.dart';
import '../data/chat_repository.dart';
import '../domain/chat_conversation.dart';
import '../domain/chat_message.dart';

part 'chat_controller.g.dart';

@Riverpod(keepAlive: true)
ChatRepository chatRepository(Ref ref) => ChatRepository(ref.watch(apiClientProvider));

/// Polls `GET /jobs/{id}/messages` every few seconds while a chat is on
/// screen — the backend has no push/websocket support.
@riverpod
Stream<List<ChatMessage>> chatMessages(Ref ref, String jobId) {
  final repo = ref.watch(chatRepositoryProvider);
  return pollWithBackoff(() => repo.getMessages(jobId), every: const Duration(seconds: 3));
}

/// The inbox, refreshed on a slower beat than an open thread: it only
/// drives previews and unread badges. Watched by the tab bar, so it keeps
/// polling on every tab, not just while the inbox is on screen.
@riverpod
Stream<List<ChatConversation>> chatConversations(Ref ref) {
  final repo = ref.watch(chatRepositoryProvider);
  return pollWithBackoff(repo.getConversations, every: const Duration(seconds: 10));
}

/// Total unread messages across every conversation, for the tab badge.
@riverpod
int chatUnreadTotal(Ref ref) {
  final conversations = ref.watch(chatConversationsProvider).value ?? const [];
  return conversations.fold(0, (sum, c) => sum + c.unreadCount);
}
