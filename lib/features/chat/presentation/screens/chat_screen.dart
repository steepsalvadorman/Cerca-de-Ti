import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/router/route_paths.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/application/auth_controller.dart';
import '../../../cerca/presentation/widgets/back_circle_button.dart';
import '../../../cerca/presentation/widgets/cerca_text_styles.dart';
import '../../../cerca/presentation/widgets/monogram_avatar.dart';
import '../../../job_request/application/active_job_controller.dart';
import '../../../job_request/application/job_session_controller.dart';
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
  bool _sending = false;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _send(String jobId, String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await ref.read(chatRepositoryProvider).sendMessage(jobId, text: trimmed);
      _textController.clear();
    } catch (e) {
      if (!mounted) return;
      final message = e is ApiException ? e.message : 'No se pudo enviar el mensaje.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final jobId = ref.watch(jobSessionControllerProvider);
    final job = ref.watch(activeJobControllerProvider).value;
    final providersPage = ref.watch(providersControllerProvider).value;
    final currentUserId = ref.watch(authControllerProvider).value?.user.id;
    final messagesAsync = jobId == null ? null : ref.watch(chatMessagesProvider(jobId));
    final messages = messagesAsync?.value ?? const <ChatMessage>[];

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
    final statusLabel = switch (job?.status) {
      'active' => 'En camino',
      'completed' => 'Finalizado',
      'cancelled' => 'Cancelado',
      _ => 'Pendiente',
    };

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.cercaBorder))),
              child: Row(
                children: [
                  BackCircleButton(onTap: () => context.go(RoutePaths.home)),
                  const SizedBox(width: 10),
                  MonogramAvatar(text: providerMono, size: 34, borderRadius: 10, fontSize: 13),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(providerName, style: CercaText.sora(fontSize: 13.5, fontWeight: FontWeight.w600)),
                        Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(color: AppColors.cercaSuccessText, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 4),
                            Text(statusLabel, style: CercaText.sora(fontSize: 11, color: AppColors.cercaSuccessText)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: jobId == null
                  ? Center(child: Text('No hay una conversación activa.', style: CercaText.sora(fontSize: 13, color: AppColors.cercaTextSecondary)))
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      children: [
                        for (final message in messages)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _ChatBubble(message: message, isUser: message.senderId == currentUserId),
                          ),
                      ],
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
              child: Column(
                children: [
                  Row(
                    children: [
                      _QuickReplyChip('¿Cuánto falta?', onTap: jobId == null ? null : () => _send(jobId, '¿Cuánto falta?')),
                      const SizedBox(width: 8),
                      _QuickReplyChip('Gracias', onTap: jobId == null ? null : () => _send(jobId, 'Gracias')),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: AppColors.cercaBorder),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: TextField(
                            controller: _textController,
                            enabled: jobId != null && !_sending,
                            style: CercaText.sora(fontSize: 13),
                            decoration: InputDecoration(
                              hintText: 'Escribe un mensaje…',
                              hintStyle: CercaText.sora(fontSize: 13, color: AppColors.cercaTextMuted),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(vertical: 9),
                            ),
                            onSubmitted: jobId == null ? null : (text) => _send(jobId, text),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: jobId == null ? null : () => _send(jobId, _textController.text),
                        customBorder: const CircleBorder(),
                        child: Container(
                          width: 40,
                          height: 40,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(color: AppColors.cercaPrimary, shape: BoxShape.circle),
                          child: const Text('→', style: TextStyle(color: Colors.white, fontSize: 15)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message, required this.isUser});
  final ChatMessage message;
  final bool isUser;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
          decoration: BoxDecoration(
            color: isUser ? AppColors.cercaPrimary : Colors.white,
            border: isUser ? null : Border.all(color: AppColors.cercaBorder),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            message.text,
            style: CercaText.sora(fontSize: 13, height: 1.4, color: isUser ? Colors.white : AppColors.cercaTextPrimary),
          ),
        ),
      ),
    );
  }
}

class _QuickReplyChip extends StatelessWidget {
  const _QuickReplyChip(this.label, {this.onTap});
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.cercaBorder),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label, style: CercaText.sora(fontSize: 11.5, color: AppColors.cercaTextSecondary)),
      ),
    );
  }
}
