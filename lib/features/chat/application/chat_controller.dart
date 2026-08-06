import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/network/network_providers.dart';
import '../../../core/network/polling.dart';
import '../data/chat_repository.dart';
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
