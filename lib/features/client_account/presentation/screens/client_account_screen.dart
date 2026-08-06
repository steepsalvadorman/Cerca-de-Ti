import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/router/route_paths.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/application/auth_controller.dart';
import '../../../cerca/application/cerca_format.dart';
import '../../../cerca/presentation/widgets/cerca_header.dart';
import '../../../cerca/presentation/widgets/cerca_text_styles.dart';
import '../../../cerca/presentation/widgets/monogram_avatar.dart';
import '../../../client/application/client_account_controller.dart';
import '../../../job_request/application/client_history_controller.dart';
import '../../../job_request/domain/job_request.dart';
import '../../../job_request/presentation/agreed_price_label.dart';
import '../../../technician/application/providers_controller.dart';
import '../../../technician/data/technician_repository.dart';

class ClientAccountScreen extends ConsumerWidget {
  const ClientAccountScreen({super.key});

  Future<void> _addAddress(BuildContext context, WidgetRef ref) async {
    final result = await _showAddDialog(context, title: 'Nueva dirección', labelHint: 'Ej: Casa', detailHint: 'Ej: Av. Providencia 1234');
    if (result == null) return;
    await ref.read(clientAccountControllerProvider.notifier).addAddress(label: result.$1, detail: result.$2);
    if (!context.mounted) return;
    _showErrorIfAny(context, ref);
  }

  Future<void> _addPaymentMethod(BuildContext context, WidgetRef ref) async {
    final result = await _showAddDialog(context, title: 'Nuevo método de pago', labelHint: 'Ej: Tarjeta terminada en 1234', detailHint: 'Ej: Visa · vence 08/28');
    if (result == null) return;
    await ref.read(clientAccountControllerProvider.notifier).addPaymentMethod(label: result.$1, detail: result.$2);
    if (!context.mounted) return;
    _showErrorIfAny(context, ref);
  }

  void _showErrorIfAny(BuildContext context, WidgetRef ref) {
    final result = ref.read(clientAccountControllerProvider);
    result.whenOrNull(
      error: (error, _) {
        final message = error is ApiException ? error.message : 'No se pudo guardar.';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      },
    );
  }

  Future<(String, String)?> _showAddDialog(
    BuildContext context, {
    required String title,
    required String labelHint,
    required String detailHint,
  }) {
    final labelController = TextEditingController();
    final detailController = TextEditingController();
    return showDialog<(String, String)>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title, style: CercaText.sora(fontSize: 16, fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: labelController, decoration: InputDecoration(hintText: labelHint)),
            const SizedBox(height: 10),
            TextField(controller: detailController, decoration: InputDecoration(hintText: detailHint)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
          TextButton(
            onPressed: () {
              final label = labelController.text.trim();
              final detail = detailController.text.trim();
              if (label.isEmpty || detail.isEmpty) return;
              Navigator.of(context).pop((label, detail));
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userName = ref.watch(authControllerProvider).value?.user.name.trim() ?? '';
    final accountAsync = ref.watch(clientAccountControllerProvider);
    final account = accountAsync.value;
    final history = ref.watch(clientHistoryProvider).value?.where((j) => j.isCompleted || j.status == 'cancelled').toList() ?? const [];
    final providersPage = ref.watch(providersControllerProvider).value;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            const CercaHeader(title: 'Mi cuenta'),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        MonogramAvatar(text: userName.isEmpty ? '?' : userName[0].toUpperCase(), size: 56, borderRadius: 16, fontSize: 18),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(userName, style: CercaText.sora(fontSize: 15, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text('Direcciones guardadas', style: CercaText.sora(fontSize: 13.5, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    if (accountAsync.isLoading && account == null)
                      const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Center(child: CircularProgressIndicator()))
                    else ...[
                      for (final address in account?.addresses ?? const [])
                        _InfoRow(title: address.label, detail: address.detail),
                      InkWell(
                        onTap: () => _addAddress(context, ref),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.cercaDashedBorder),
                          ),
                          child: Text('+ Agregar dirección', style: CercaText.sora(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.cercaPrimary)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text('Métodos de pago', style: CercaText.sora(fontSize: 13.5, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      for (final method in account?.paymentMethods ?? const [])
                        _InfoRow(title: method.label, detail: method.detail),
                      InkWell(
                        onTap: () => _addPaymentMethod(context, ref),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.cercaDashedBorder),
                          ),
                          child: Text('+ Agregar método de pago', style: CercaText.sora(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.cercaPrimary)),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Text('Historial de solicitudes', style: CercaText.sora(fontSize: 13.5, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    if (history.isEmpty)
                      Text('Aún no tienes solicitudes anteriores.', style: CercaText.sora(fontSize: 12.5, color: AppColors.cercaTextSecondary))
                    else
                      for (final job in history) _HistoryRow(job: job, providersPage: providersPage),
                    const SizedBox(height: 10),
                    Center(
                      child: InkWell(
                        onTap: () async {
                          await ref.read(authControllerProvider.notifier).logout();
                          if (context.mounted) context.go(RoutePaths.login);
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text('Cerrar sesión', style: CercaText.sora(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.cercaTextMuted)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.title, required this.detail});
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.cercaBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: CercaText.sora(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(detail, style: CercaText.sora(fontSize: 11.5, color: AppColors.cercaTextSecondary)),
              ],
            ),
          ),
          Text('›', style: CercaText.sora(fontSize: 14, color: AppColors.cercaTextMuted)),
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.job, required this.providersPage});
  final JobRequest job;
  final ProvidersPage? providersPage;

  @override
  Widget build(BuildContext context) {
    final completed = job.isCompleted;
    String techName = 'Técnico';
    if (providersPage != null) {
      if (job.technicianProfileId != null) {
        for (final t in providersPage!.technicians) {
          if (t.id == job.technicianProfileId) techName = t.name;
        }
      } else if (job.techTeamId != null) {
        for (final t in providersPage!.teams) {
          if (t.id == job.techTeamId) techName = t.name;
        }
      }
    }
    final category = job.title?.isNotEmpty == true ? job.title! : job.jobKind;
    final price = agreedPriceLabel(job, providersPage);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.cercaBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(category, style: CercaText.sora(fontSize: 13, fontWeight: FontWeight.w600)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: completed ? AppColors.cercaSuccessBg : AppColors.cercaDangerBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  completed ? 'Completado' : 'Cancelado',
                  style: CercaText.sora(fontSize: 10.5, fontWeight: FontWeight.w700, color: completed ? AppColors.cercaSuccessText : AppColors.cercaDangerText),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text('$techName · ${formatShortDate(job.createdAt)} · $price', style: CercaText.sora(fontSize: 11.5, color: AppColors.cercaTextSecondary)),
        ],
      ),
    );
  }
}
