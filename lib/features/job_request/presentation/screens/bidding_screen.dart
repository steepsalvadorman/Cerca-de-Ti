import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/router/route_paths.dart';
import '../../../../core/router/back_navigation.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../cerca/application/cerca_controller.dart';
import '../../../cerca/application/cerca_format.dart';
import '../../../cerca/application/cerca_state.dart';
import '../../../cerca/presentation/widgets/cerca_header.dart';
import '../../../cerca/presentation/widgets/cerca_text_styles.dart';
import '../../../cerca/presentation/widgets/monogram_avatar.dart';
import '../../application/active_job_controller.dart';
import '../../application/job_session_controller.dart';
import '../../application/offers_controller.dart';
import '../../domain/job_offer.dart';

class BiddingScreen extends ConsumerStatefulWidget {
  const BiddingScreen({super.key});

  @override
  ConsumerState<BiddingScreen> createState() => _BiddingScreenState();
}

class _BiddingScreenState extends ConsumerState<BiddingScreen> {
  bool _choosing = false;

  Future<void> _choose(JobOffer offer) async {
    if (_choosing) return;
    setState(() => _choosing = true);
    try {
      await ref.read(activeJobControllerProvider.notifier).chooseOffer(offer.id);
      final result = ref.read(activeJobControllerProvider);
      if (result.hasError) throw result.error!;
      ref.read(cercaControllerProvider.notifier).chooseOffer();
      if (!mounted) return;
      context.go(RoutePaths.jobFee);
    } catch (e) {
      if (!mounted) return;
      final message = e is ApiException ? e.message : 'No se pudo elegir esta oferta.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _choosing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(cercaControllerProvider);
    final controller = ref.watch(cercaControllerProvider.notifier);
    final requestDraft = ref.watch(serviceRequestDraftProvider);
    final jobId = ref.watch(jobSessionControllerProvider);
    final offersAsync = jobId == null ? null : ref.watch(jobOffersProvider(jobId));

    final offers = [...offersAsync?.value ?? const <JobOffer>[]];
    if (state.sortBy == SortBy.price) {
      offers.sort((a, b) => a.price.compareTo(b.price));
    } else {
      offers.sort((a, b) => b.rating.compareTo(a.rating));
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            CercaHeader(title: 'Ofertas recibidas', onBack: () => context.goBack(RoutePaths.home)),
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
                        color: AppColors.cercaSurfaceTint,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            requestDraft.categoryLabel ?? 'Solicitud de servicio',
                            style: CercaText.sora(fontSize: 13.5, fontWeight: FontWeight.w600),
                          ),
                          if (requestDraft.description.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              requestDraft.description,
                              style: CercaText.sora(fontSize: 12, color: AppColors.cercaTextSecondary),
                            ),
                          ],
                          const SizedBox(height: 6),
                          Text(
                            '${offers.length} ${offers.length == 1 ? 'oferta recibida' : 'ofertas recibidas'}',
                            style: CercaText.sora(fontSize: 11.5, color: AppColors.cercaPrimary),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _SortChip(
                          label: 'Menor precio',
                          active: state.sortBy == SortBy.price,
                          onTap: () => controller.setSort(SortBy.price),
                        ),
                        const SizedBox(width: 8),
                        _SortChip(
                          label: 'Mejor calificación',
                          active: state.sortBy == SortBy.rating,
                          onTap: () => controller.setSort(SortBy.rating),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (offersAsync != null && offersAsync.isLoading && offers.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (offers.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          'Aún no llegan ofertas de técnicos. Esta pantalla se actualiza sola.',
                          style: CercaText.sora(fontSize: 13, color: AppColors.cercaTextSecondary, height: 1.5),
                        ),
                      )
                    else
                      for (final offer in offers)
                        _OfferCard(
                          offer: offer,
                          onChoose: _choosing ? null : () => _choose(offer),
                        ),
                    Text(
                      'Al elegir una oferta, Cerca cobra S/ 4 por la licitación. El pago del trabajo se acuerda directamente con el técnico.',
                      textAlign: TextAlign.center,
                      style: CercaText.sora(fontSize: 11, color: AppColors.cercaTextMuted, height: 1.4),
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

class _SortChip extends StatelessWidget {
  const _SortChip({required this.label, required this.active, required this.onTap});
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: active ? AppColors.cercaPrimary : Colors.white,
          border: Border.all(color: active ? AppColors.cercaPrimary : AppColors.cercaBorder),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: CercaText.sora(fontSize: 12, fontWeight: FontWeight.w600, color: active ? Colors.white : AppColors.cercaTextPrimary),
        ),
      ),
    );
  }
}

class _OfferCard extends StatelessWidget {
  const _OfferCard({required this.offer, required this.onChoose});
  final JobOffer offer;
  final VoidCallback? onChoose;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: offer.verified ? AppColors.cercaBorder : AppColors.cercaUnverifiedBorder),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Row(
            children: [
              MonogramAvatar(text: offer.mono, size: 38, borderRadius: 10, fontSize: 13),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(offer.name, style: CercaText.sora(fontSize: 13, fontWeight: FontWeight.w600)),
                        const SizedBox(width: 5),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                          decoration: BoxDecoration(
                            color: offer.verified ? AppColors.cercaSurfaceTint : AppColors.cercaWarnBg,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            offer.verified ? '✓ Verificado' : 'Sin verificar',
                            style: CercaText.sora(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: offer.verified ? AppColors.cercaPrimary : AppColors.cercaWarnTextStrong,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text.rich(
                      TextSpan(
                        style: CercaText.sora(fontSize: 11.5, color: AppColors.cercaTextSecondary),
                        children: [
                          TextSpan(text: '${offer.oficio} · '),
                          TextSpan(text: '★', style: CercaText.sora(fontSize: 11.5, color: AppColors.cercaStar)),
                          TextSpan(text: ' ${offer.rating}'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(formatSoles(offer.price), style: CercaText.sora(fontSize: 16, fontWeight: FontWeight.w700)),
                  Text(offer.eta, style: CercaText.sora(fontSize: 10.5, color: AppColors.cercaTextSecondary)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onChoose,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.cercaPrimary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 9),
              ),
              child: Text('Elegir', style: CercaText.sora(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}
