import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/router/route_paths.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../cerca/application/cerca_controller.dart';
import '../../../cerca/presentation/widgets/cerca_header.dart';
import '../../../cerca/presentation/widgets/cerca_text_styles.dart';
import '../../../cerca/presentation/widgets/primary_action_button.dart';
import '../../../job_request/application/active_job_controller.dart';
import '../../../job_request/presentation/agreed_price_label.dart';
import '../../../technician/application/providers_controller.dart';

class JobRatingScreen extends ConsumerStatefulWidget {
  const JobRatingScreen({super.key});

  @override
  ConsumerState<JobRatingScreen> createState() => _JobRatingScreenState();
}

class _JobRatingScreenState extends ConsumerState<JobRatingScreen> {
  final _commentController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit(int rating) async {
    if (_submitting || rating == 0) return;
    setState(() => _submitting = true);
    try {
      await ref.read(activeJobControllerProvider.notifier).rate(rating, comment: _commentController.text.trim());
      final result = ref.read(activeJobControllerProvider);
      if (result.hasError) throw result.error!;
    } catch (e) {
      if (!mounted) return;
      final message = e is ApiException ? e.message : 'No se pudo enviar tu calificación.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(cercaControllerProvider);
    final controller = ref.watch(cercaControllerProvider.notifier);
    final job = ref.watch(activeJobControllerProvider).value;
    final providersPage = ref.watch(providersControllerProvider).value;

    String providerName = '';
    if (providersPage != null && job != null) {
      if (job.technicianProfileId != null) {
        for (final t in providersPage.technicians) {
          if (t.id == job.technicianProfileId) providerName = t.name;
        }
      } else if (job.techTeamId != null) {
        for (final t in providersPage.teams) {
          if (t.id == job.techTeamId) providerName = t.name;
        }
      }
    }
    final rated = job?.rating != null;
    final agreedLabel = agreedPriceLabel(job, providersPage);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            CercaHeader(title: 'Calificación final', onBack: () => context.go(RoutePaths.tracking)),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: AppColors.cercaBorder),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Total pactado con el técnico', style: CercaText.sora(fontSize: 15, fontWeight: FontWeight.w700)),
                          Text(agreedLabel, style: CercaText.sora(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.cercaPrimary)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      margin: const EdgeInsets.only(bottom: 18),
                      decoration: BoxDecoration(
                        color: AppColors.cercaWarnBg,
                        border: Border.all(color: AppColors.cercaWarnBorder),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        job?.jobKind == 'bidding'
                            ? 'El trabajo se paga directo al técnico. Cerca solo cobró S/ 4 por gestionar la licitación.'
                            : 'El trabajo se paga directo al técnico. Cerca no cobra por el contacto directo ni procesa este pago.',
                        style: CercaText.sora(fontSize: 11.5, color: AppColors.cercaWarnText, height: 1.5),
                      ),
                    ),
                    if (rated)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.cercaSuccessBg,
                          border: Border.all(color: AppColors.cercaSuccessBorder),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          children: [
                            Text('✓', style: CercaText.sora(fontSize: 26)),
                            const SizedBox(height: 6),
                            Text('¡Gracias por tu calificación!', style: CercaText.sora(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.cercaSuccessText)),
                            const SizedBox(height: 4),
                            Text(
                              '$providerName recibió tu reseña. Recuerda coordinar el pago del trabajo directamente con él/ella.',
                              textAlign: TextAlign.center,
                              style: CercaText.sora(fontSize: 12, color: const Color(0xFF4C7A63), height: 1.5),
                            ),
                          ],
                        ),
                      )
                    else ...[
                      Text('¿Cómo estuvo el trabajo de $providerName?', style: CercaText.sora(fontSize: 13.5, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          for (var i = 1; i <= 5; i++)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: InkWell(
                                onTap: () => controller.setRating(i),
                                child: Text(
                                  '★',
                                  style: TextStyle(fontSize: 30, color: i <= state.rating ? AppColors.cercaStar : const Color(0xFFD8CFC9)),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _commentController,
                        maxLines: 3,
                        style: CercaText.sora(fontSize: 12.5),
                        decoration: InputDecoration(
                          hintText: 'Cuéntanos cómo fue tu experiencia (opcional)',
                          hintStyle: CercaText.sora(fontSize: 12.5, color: AppColors.cercaTextMuted),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.all(12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppColors.cercaBorder),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppColors.cercaBorder),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (!rated)
              PrimaryActionButton(
                label: _submitting ? 'Enviando…' : 'Confirmar y calificar',
                enabled: !_submitting && state.rating > 0,
                onTap: () => _submit(state.rating),
              ),
          ],
        ),
      ),
    );
  }
}
