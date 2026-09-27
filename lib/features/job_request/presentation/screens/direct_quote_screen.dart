import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/router/route_paths.dart';
import '../../../../core/router/back_navigation.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../cerca/application/cerca_controller.dart';
import '../../../cerca/presentation/widgets/cerca_header.dart';
import '../../../cerca/presentation/widgets/cerca_text_styles.dart';
import '../../../cerca/presentation/widgets/monogram_avatar.dart';
import '../../../cerca/presentation/widgets/verified_badge.dart';
import '../../../technician/application/providers_controller.dart';
import '../../../technician/domain/technician.dart';
import '../../application/job_session_controller.dart';

class DirectQuoteScreen extends ConsumerStatefulWidget {
  const DirectQuoteScreen({super.key});

  @override
  ConsumerState<DirectQuoteScreen> createState() => _DirectQuoteScreenState();
}

class _DirectQuoteScreenState extends ConsumerState<DirectQuoteScreen> {
  bool _accepting = false;

  Future<void> _acceptQuote(Technician provider) async {
    if (_accepting) return;
    setState(() => _accepting = true);
    try {
      final draft = ref.read(serviceRequestDraftProvider);
      final job = await ref.read(jobRepositoryProvider).createJob(
            technicianProfileId: provider.id,
            jobKind: 'direct',
            title: draft.isComplete ? draft.title : provider.oficio,
          );
      ref.read(jobSessionControllerProvider.notifier).setJobId(job.id);
      ref.read(cercaControllerProvider.notifier).acceptDirect();
      if (!mounted) return;
      context.go(RoutePaths.tracking);
    } catch (e) {
      if (!mounted) return;
      final message = e is ApiException ? e.message : 'No se pudo aceptar la cotización.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _accepting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cercaState = ref.watch(cercaControllerProvider);
    final requestDraft = ref.watch(serviceRequestDraftProvider);
    final providersAsync = ref.watch(providersControllerProvider);
    final providersPage = providersAsync.value;

    Technician? provider;
    if (providersPage != null) {
      for (final t in providersPage.technicians) {
        if (t.id == cercaState.selectedTechId) {
          provider = t;
          break;
        }
      }
    }

    if (provider == null) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Center(
            child: providersAsync.isLoading
                ? const CircularProgressIndicator()
                : TextButton(onPressed: () => context.goBack(RoutePaths.home), child: const Text('Volver')),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            CercaHeader(title: 'Cotización', onBack: () => context.goBack(RoutePaths.providerProfile)),
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            requestDraft.description.isNotEmpty
                                ? requestDraft.description
                                : 'Servicio de ${provider.oficio}',
                            style: CercaText.sora(fontSize: 13.5, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${requestDraft.categoryLabel ?? provider.oficio} · contratación directa',
                            style: CercaText.sora(fontSize: 12, color: AppColors.cercaTextSecondary, height: 1.5),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            width: double.infinity,
                            height: 70,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AppColors.cercaSurfaceTint,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text('Foto adjunta del problema', style: CercaText.sora(fontSize: 11, color: AppColors.cercaPrimary)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text('Cotización de ${provider.name}', style: CercaText.sora(fontSize: 13.5, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: AppColors.cercaBorder),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              MonogramAvatar(text: provider.mono, size: 38, borderRadius: 10, fontSize: 13),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(provider.name, style: CercaText.sora(fontSize: 13, fontWeight: FontWeight.w600)),
                                        const SizedBox(width: 5),
                                        const VerifiedBadge(),
                                      ],
                                    ),
                                    Text(provider.oficio, style: CercaText.sora(fontSize: 11.5, color: AppColors.cercaTextSecondary)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(provider.priceLabel, style: CercaText.lora(fontSize: 26, color: AppColors.cercaPrimary)),
                          const SizedBox(height: 6),
                          Text(
                            'Puede llegar hoy a las 17:00 · trae materiales básicos',
                            style: CercaText.sora(fontSize: 12, color: AppColors.cercaTextSecondary),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.cercaBackground,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '"Reviso la llave de paso y cambio el sello. Si es la cañería, te aviso antes de continuar."',
                              style: CercaText.sora(fontSize: 12.5, height: 1.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.cercaBorder))),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _accepting ? null : () => _acceptQuote(provider!),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.cercaPrimary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(_accepting ? 'Aceptando…' : 'Aceptar cotización', style: CercaText.sora(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
              child: Text(
                'El contacto directo es gratuito. El pago del trabajo se acuerda y se realiza directamente con el técnico.',
                textAlign: TextAlign.center,
                style: CercaText.sora(fontSize: 11, color: AppColors.cercaTextMuted, height: 1.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
