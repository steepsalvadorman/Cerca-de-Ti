import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/router/route_paths.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/application/auth_controller.dart';
import '../../../cerca/application/cerca_format.dart';
import '../../../cerca/presentation/widgets/cerca_text_styles.dart';
import '../../../cerca/presentation/widgets/monogram_avatar.dart';
import '../../application/chat_controller.dart';
import '../../domain/chat_conversation.dart';

/// The "Mensajes" tab: every job the person can chat on, newest activity
/// first, with a preview of the last message and an unread count. Shared
/// by the client and technician shells.
class ChatsScreen extends ConsumerWidget {
  const ChatsScreen({super.key});

  Future<void> _open(BuildContext context, WidgetRef ref, ChatConversation conversation) async {
    await context.push(RoutePaths.chatFor(conversation.jobRequestId));
    // Opening the thread marked it read server-side; reflect that now
    // instead of on the next poll.
    ref.invalidate(chatConversationsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversationsAsync = ref.watch(chatConversationsProvider);
    final conversations = conversationsAsync.value;
    final currentUserId = ref.watch(authControllerProvider).value?.user.id;

    return Scaffold(
      backgroundColor: AppColors.cercaBackground,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              child: Text('Mensajes', style: CercaText.lora(fontSize: 20)),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => ref.refresh(chatConversationsProvider.future),
                child: switch ((conversations, conversationsAsync.error)) {
                  (null, final Object error) => _Message(
                      text: error is ApiException ? error.message : 'No se pudieron cargar tus conversaciones.',
                      actionLabel: 'Reintentar',
                      onAction: () => ref.invalidate(chatConversationsProvider),
                    ),
                  (null, _) => const Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.cercaPrimary),
                      ),
                    ),
                  (final List<ChatConversation> list, _) when list.isEmpty => const _Message(
                      text: 'Aún no tienes conversaciones.\nCuando un trabajo tenga técnico asignado, podrás chatear aquí.',
                    ),
                  (final List<ChatConversation> list, _) => ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
                      itemCount: list.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) => _ConversationTile(
                        conversation: list[index],
                        currentUserId: currentUserId,
                        onTap: () => _open(context, ref, list[index]),
                      ),
                    ),
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({required this.conversation, required this.currentUserId, required this.onTap});

  final ChatConversation conversation;
  final String? currentUserId;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final unread = conversation.unreadCount;
    final lastText = conversation.lastMessageText;
    final fromMe = conversation.lastMessageSenderId != null && conversation.lastMessageSenderId == currentUserId;
    final preview = lastText == null ? 'Sin mensajes todavía' : (fromMe ? 'Tú: $lastText' : lastText);
    final title = conversation.jobTitle?.trim();

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.cercaBorder),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              MonogramAvatar(text: conversation.counterpartMono, size: 42, borderRadius: 12, fontSize: 14),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            conversation.counterpartName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: CercaText.sora(fontSize: 13.5, fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          formatChatTime(conversation.updatedAt),
                          style: CercaText.sora(
                            fontSize: 10.5,
                            color: unread > 0 ? AppColors.cercaPrimary : AppColors.cercaTextMuted,
                            fontWeight: unread > 0 ? FontWeight.w700 : FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                    if (title != null && title.isNotEmpty)
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: CercaText.sora(fontSize: 11, color: AppColors.cercaTextMuted),
                      ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            preview,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: CercaText.sora(
                              fontSize: 12.5,
                              color: unread > 0 ? AppColors.cercaTextPrimary : AppColors.cercaTextSecondary,
                              fontWeight: unread > 0 ? FontWeight.w600 : FontWeight.w400,
                            ),
                          ),
                        ),
                        if (unread > 0) ...[
                          const SizedBox(width: 8),
                          UnreadBadge(count: unread),
                        ] else if (!conversation.isWritable) ...[
                          const SizedBox(width: 8),
                          Text('Finalizado', style: CercaText.sora(fontSize: 10.5, color: AppColors.cercaTextMuted)),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small pill with an unread count, shared by the inbox rows and the tab bar.
class UnreadBadge extends StatelessWidget {
  const UnreadBadge({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 18),
      height: 18,
      padding: const EdgeInsets.symmetric(horizontal: 5),
      alignment: Alignment.center,
      decoration: BoxDecoration(color: AppColors.cercaPrimary, borderRadius: BorderRadius.circular(9)),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: CercaText.sora(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text, this.actionLabel, this.onAction});

  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    // Scrollable so pull-to-refresh still works on an empty or failed list.
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(32, 80, 32, 32),
      children: [
        Text(
          text,
          textAlign: TextAlign.center,
          style: CercaText.sora(fontSize: 13, color: AppColors.cercaTextSecondary, height: 1.55),
        ),
        if (actionLabel != null && onAction != null) ...[
          const SizedBox(height: 14),
          Center(child: TextButton(onPressed: onAction, child: Text(actionLabel!))),
        ],
      ],
    );
  }
}
