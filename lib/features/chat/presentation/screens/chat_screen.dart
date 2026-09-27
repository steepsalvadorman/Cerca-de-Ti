import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/router/back_navigation.dart';
import '../../../../core/router/route_paths.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/application/auth_controller.dart';
import '../../../auth/domain/auth_user.dart';
import '../../../cerca/application/cerca_format.dart';
import '../../../cerca/presentation/widgets/back_circle_button.dart';
import '../../../cerca/presentation/widgets/cerca_text_styles.dart';
import '../../../cerca/presentation/widgets/monogram_avatar.dart';
import '../../../job_request/application/active_job_controller.dart';
import '../../../job_request/application/job_session_controller.dart';
import '../../../job_request/domain/job_request.dart';
import '../../../technician/application/providers_controller.dart';
import '../../application/chat_controller.dart';
import '../../domain/chat_message.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  bool _sending = false;
  int _lastMessageCount = 0;

  /// Messages already shown in the thread while their POST is in flight,
  /// so sending feels instant instead of waiting for two round trips.
  final List<ChatMessage> _pending = [];

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom({bool animated = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final target = _scrollController.position.maxScrollExtent;
      if (animated) {
        _scrollController.animateTo(target, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      } else {
        _scrollController.jumpTo(target);
      }
    });
  }

  Future<void> _send(String jobId, String text, {required bool canWrite}) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _sending || !canWrite) return;
    if (trimmed.length > 2000) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El mensaje no puede superar los 2000 caracteres.')),
      );
      return;
    }
    final pending = ChatMessage(
      id: 'pending-${DateTime.now().microsecondsSinceEpoch}',
      jobRequestId: jobId,
      senderId: ref.read(authControllerProvider).value?.user.id ?? '',
      senderRole: '',
      text: trimmed,
      createdAt: DateTime.now().toUtc().toIso8601String(),
    );
    setState(() {
      _sending = true;
      _pending.add(pending);
    });
    _textController.clear();
    _scrollToBottom();
    try {
      await ref.read(chatRepositoryProvider).sendMessage(jobId, text: trimmed);
      // Swap the placeholder for the real message as soon as the thread
      // reloads; if that reload is slow the next poll brings it anyway.
      try {
        await ref.refresh(chatMessagesProvider(jobId).future).timeout(const Duration(seconds: 8));
      } catch (_) {}
    } catch (e) {
      if (!mounted) return;
      // Give the text back so nothing typed is lost.
      if (_textController.text.isEmpty) _textController.text = trimmed;
      final message = e is ApiException ? e.message : 'No se pudo enviar el mensaje.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
          _pending.remove(pending);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final jobId = ref.watch(jobSessionControllerProvider);
    final job = ref.watch(activeJobControllerProvider).value;
    final providersPage = ref.watch(providersControllerProvider).value;
    final currentUser = ref.watch(authControllerProvider).value?.user;
    final currentUserId = currentUser?.id;
    // Reached with `go` there's nothing to pop: fall back to the screen the
    // chat was opened from for this role.
    final chatParent =
        currentUser?.isTechnician == true ? RoutePaths.technicianJobDetail : RoutePaths.tracking;
    final messagesAsync = jobId == null ? null : ref.watch(chatMessagesProvider(jobId));
    final canWrite = job?.isChatWritable ?? false;

    String providerName = '';
    String providerMono = '?';
    if (providersPage != null && job != null) {
      if (job.technicianProfileId != null) {
        for (final t in providersPage.technicians) {
          if (t.id == job.technicianProfileId) {
            providerName = t.name;
            providerMono = t.mono;
          }
        }
      } else if (job.techTeamId != null) {
        for (final t in providersPage.teams) {
          if (t.id == job.techTeamId) {
            providerName = t.name;
            providerMono = t.mono;
          }
        }
      }
    }

    final status = _ChatStatus.fromJob(job);
    final messageCount = messagesAsync?.value?.length ?? 0;
    if (messageCount != _lastMessageCount && messageCount > 0) {
      _lastMessageCount = messageCount;
      _scrollToBottom();
    }

    return BackFallbackScope(
      onFallback: () => context.go(chatParent),
      child: Scaffold(
        backgroundColor: AppColors.cercaBackground,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _ChatHeader(
                providerName: providerName,
                providerMono: providerMono,
                status: status,
                onBack: () => context.goBack(chatParent),
              ),
              if (jobId != null && !canWrite)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.cercaBorder),
                  ),
                  child: Text(
                    job?.isCompleted == true
                        ? 'Trabajo finalizado · solo lectura'
                        : 'Chat cerrado',
                    textAlign: TextAlign.center,
                    style: CercaText.sora(fontSize: 11.5, color: AppColors.cercaTextSecondary),
                  ),
                ),
              Expanded(
                child: jobId == null
                    ? const _ChatEmptyState(message: 'No hay una conversación activa.')
                    : messagesAsync!.when(
                        loading: () => const Center(
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.cercaPrimary),
                          ),
                        ),
                        error: (error, _) {
                          final message = error is ApiException ? error.message : 'No se pudieron cargar los mensajes.';
                          return _ChatEmptyState(
                            message: message,
                            actionLabel: 'Reintentar',
                            onAction: () => ref.invalidate(chatMessagesProvider(jobId)),
                          );
                        },
                        data: (loaded) {
                          final messages = [...loaded, ..._pending];
                          if (messages.isEmpty) {
                            return const _ChatEmptyState(
                              message: 'Coordina los detalles del trabajo aquí.\nEscribe el primer mensaje.',
                            );
                          }
                          return ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                            itemCount: messages.length,
                            itemBuilder: (context, index) {
                              final message = messages[index];
                              final isUser = message.senderId == currentUserId;
                              final prev = index > 0 ? messages[index - 1] : null;
                              final next = index < messages.length - 1 ? messages[index + 1] : null;
                              final isFirstInGroup = prev?.senderId != message.senderId;
                              final isLastInGroup = next?.senderId != message.senderId;

                              return Padding(
                                padding: EdgeInsets.only(top: isFirstInGroup ? 10 : 3),
                                child: _ChatBubble(
                                  message: message,
                                  isUser: isUser,
                                  showTimestamp: isLastInGroup,
                                  pending: _pending.contains(message),
                                ),
                              );
                            },
                          );
                        },
                      ),
              ),
              if (jobId != null && canWrite)
                _ChatComposer(
                  controller: _textController,
                  sending: _sending,
                  onSend: (text) => _send(jobId, text, canWrite: canWrite),
                  onQuickReply: (text) => _send(jobId, text, canWrite: canWrite),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChatHeader extends StatelessWidget {
  const _ChatHeader({
    required this.providerName,
    required this.providerMono,
    required this.status,
    required this.onBack,
  });

  final String providerName;
  final String providerMono;
  final _ChatStatus status;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.cercaBorder.withValues(alpha: 0.7))),
      ),
      child: Row(
        children: [
          BackCircleButton(onTap: onBack),
          const SizedBox(width: 10),
          MonogramAvatar(text: providerMono, size: 36, borderRadius: 12, fontSize: 13),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  providerName.isEmpty ? 'Chat del trabajo' : providerName,
                  style: CercaText.sora(fontSize: 14, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  status.label,
                  style: CercaText.sora(fontSize: 11.5, color: status.textColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatEmptyState extends StatelessWidget {
  const _ChatEmptyState({required this.message, this.actionLabel, this.onAction});
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: CercaText.sora(fontSize: 13, color: AppColors.cercaTextSecondary, height: 1.55),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 14),
              TextButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

class _ChatComposer extends StatelessWidget {
  const _ChatComposer({
    required this.controller,
    required this.sending,
    required this.onSend,
    required this.onQuickReply,
  });

  final TextEditingController controller;
  final bool sending;
  final ValueChanged<String> onSend;
  final ValueChanged<String> onQuickReply;

  static const _quickReplies = ['¿Cuánto falta?', 'Gracias'];

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.cercaBorder.withValues(alpha: 0.7))),
      ),
      padding: EdgeInsets.fromLTRB(16, 10, 12, 10 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 32,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _quickReplies.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final label = _quickReplies[index];
                return ActionChip(
                  label: Text(label, style: CercaText.sora(fontSize: 11.5, color: AppColors.cercaTextSecondary)),
                  backgroundColor: AppColors.cercaBackground,
                  side: BorderSide.none,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  onPressed: sending ? null : () => onQuickReply(label),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 120),
                  decoration: BoxDecoration(
                    color: AppColors.cercaBackground,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: TextField(
                    controller: controller,
                    enabled: !sending,
                    maxLength: 2000,
                    maxLines: null,
                    textInputAction: TextInputAction.newline,
                    buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                    style: CercaText.sora(fontSize: 14, height: 1.4),
                    decoration: InputDecoration(
                      hintText: 'Mensaje…',
                      hintStyle: CercaText.sora(fontSize: 14, color: AppColors.cercaTextMuted),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    onSubmitted: onSend,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: controller,
                builder: (context, value, _) {
                  final hasText = value.text.trim().isNotEmpty;
                  final active = hasText && !sending;
                  return Material(
                    color: active ? AppColors.cercaPrimary : AppColors.cercaChipTrack,
                    shape: const CircleBorder(),
                    child: InkWell(
                      onTap: active ? () => onSend(value.text) : null,
                      customBorder: const CircleBorder(),
                      child: SizedBox(
                        width: 40,
                        height: 40,
                        child: sending
                            ? const Padding(
                                padding: EdgeInsets.all(11),
                                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.cercaPrimary),
                              )
                            : Icon(
                                Icons.arrow_upward_rounded,
                                size: 20,
                                color: active ? Colors.white : AppColors.cercaTextMuted,
                              ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChatStatus {
  const _ChatStatus({required this.label, required this.textColor});

  final String label;
  final Color textColor;

  factory _ChatStatus.fromJob(JobRequest? job) {
    return switch (job?.status) {
      'active' => const _ChatStatus(label: 'En camino', textColor: AppColors.cercaSuccessText),
      'completed' => const _ChatStatus(label: 'Finalizado', textColor: AppColors.cercaTextMuted),
      'cancelled' => const _ChatStatus(label: 'Cancelado', textColor: AppColors.cercaWarnTextStrong),
      _ => const _ChatStatus(label: 'Pendiente', textColor: AppColors.cercaTextSecondary),
    };
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({
    required this.message,
    required this.isUser,
    required this.showTimestamp,
    this.pending = false,
  });

  final ChatMessage message;
  final bool isUser;
  final bool showTimestamp;
  final bool pending;

  @override
  Widget build(BuildContext context) {
    final maxWidth = math.min(MediaQuery.sizeOf(context).width * 0.72, 280.0);

    final bubble = Row(
      mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        Flexible(
          child: Container(
            constraints: BoxConstraints(maxWidth: maxWidth),
            padding: const EdgeInsets.fromLTRB(12, 9, 12, 8),
            decoration: BoxDecoration(
              color: isUser ? AppColors.cercaPrimary : Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(isUser ? 16 : 4),
                bottomRight: Radius.circular(isUser ? 4 : 16),
              ),
              boxShadow: isUser
                  ? null
                  : [
                      BoxShadow(
                        color: AppColors.cercaTextPrimary.withValues(alpha: 0.05),
                        blurRadius: 6,
                        offset: const Offset(0, 1),
                      ),
                    ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  message.text,
                  style: CercaText.sora(
                    fontSize: 14,
                    height: 1.45,
                    color: isUser ? Colors.white : AppColors.cercaTextPrimary,
                  ),
                ),
                if (showTimestamp) ...[
                  const SizedBox(height: 4),
                  Text(
                    pending ? 'Enviando…' : formatChatTime(message.createdAt),
                    style: CercaText.sora(
                      fontSize: 10,
                      color: isUser ? Colors.white.withValues(alpha: 0.65) : AppColors.cercaTextMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
    return pending ? Opacity(opacity: 0.7, child: bubble) : bubble;
  }
}
