import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cerca/core/network/network_providers.dart';
import 'package:cerca/core/network/token_storage.dart';
import 'package:cerca/features/chat/application/chat_controller.dart';
import 'package:cerca/features/chat/domain/chat_conversation.dart';
import 'package:cerca/features/chat/presentation/screens/chats_screen.dart';

class _FakeTokenStorage extends TokenStorage {
  const _FakeTokenStorage();

  @override
  Future<String?> read() async => null;

  @override
  Future<void> save(String token) async {}

  @override
  Future<void> clear() async {}
}

ChatConversation _conversation({
  String status = 'active',
  String name = 'Marcelo Reyes',
  String? lastText = 'Llego en 10',
  int unread = 0,
}) {
  return ChatConversation.fromJson({
    'job_request_id': 'job-1',
    'job_title': 'Gasfitería: fuga en la cocina',
    'job_status': status,
    'counterpart_role': 'technician',
    'counterpart_name': name,
    'last_message_text': lastText,
    'last_message_at': lastText == null ? null : '2026-09-27T15:04:00Z',
    'last_message_sender_id': lastText == null ? null : 'tech-user',
    'unread_count': unread,
    'updated_at': '2026-09-27T15:04:00Z',
  });
}

Future<void> _pumpInbox(WidgetTester tester, List<ChatConversation> conversations) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [
      tokenStorageProvider.overrideWithValue(const _FakeTokenStorage()),
      chatConversationsProvider.overrideWith((ref) => Stream.value(conversations)),
    ],
    child: const MaterialApp(home: ChatsScreen()),
  ));
  await tester.pump();
  await tester.pump();
}

void main() {
  group('ChatConversation', () {
    test('parses the backend payload', () {
      final c = _conversation(unread: 2);
      expect(c.jobRequestId, 'job-1');
      expect(c.counterpartName, 'Marcelo Reyes');
      expect(c.unreadCount, 2);
    });

    test('is writable only while pending or active', () {
      expect(_conversation(status: 'pending').isWritable, isTrue);
      expect(_conversation(status: 'active').isWritable, isTrue);
      expect(_conversation(status: 'completed').isWritable, isFalse);
    });

    test('builds initials from the counterpart name', () {
      expect(_conversation(name: 'Marcelo Reyes').counterpartMono, 'MR');
      expect(_conversation(name: 'sofía').counterpartMono, 'S');
      expect(_conversation(name: '  ').counterpartMono, '?');
    });
  });

  group('ChatsScreen', () {
    testWidgets('lists conversations with preview and unread badge', (tester) async {
      await _pumpInbox(tester, [_conversation(unread: 3)]);

      expect(find.text('Marcelo Reyes'), findsOneWidget);
      expect(find.text('Gasfitería: fuga en la cocina'), findsOneWidget);
      expect(find.text('Llego en 10'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('shows a placeholder for an empty thread', (tester) async {
      await _pumpInbox(tester, [_conversation(lastText: null)]);

      expect(find.text('Sin mensajes todavía'), findsOneWidget);
    });

    testWidgets('explains the empty inbox', (tester) async {
      await _pumpInbox(tester, const []);

      expect(find.textContaining('Aún no tienes conversaciones'), findsOneWidget);
    });
  });
}
