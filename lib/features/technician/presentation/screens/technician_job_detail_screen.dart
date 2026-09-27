import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/router/route_paths.dart';
import '../../../../core/router/back_navigation.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../cerca/presentation/widgets/cerca_header.dart';
import '../../../cerca/presentation/widgets/cerca_text_styles.dart';
import '../../../cerca/presentation/widgets/primary_action_button.dart';
import '../../../job_request/application/active_job_controller.dart';
import '../../../job_request/application/job_session_controller.dart';
import '../../../job_request/application/technician_jobs_controller.dart';
import '../../../job_request/domain/job_request.dart';
import '../../../tracking/application/tracking_controller.dart';
import '../../application/tech_profile_controller.dart';

class TechnicianJobDetailScreen extends ConsumerStatefulWidget {
  const TechnicianJobDetailScreen({super.key});

  @override
  ConsumerState<TechnicianJobDetailScreen> createState() => _TechnicianJobDetailScreenState();
}

class _TechnicianJobDetailScreenState extends ConsumerState<TechnicianJobDetailScreen> {
  final _priceController = TextEditingController();
  final _etaController = TextEditingController();
  bool _submitting = false;
  bool _advancing = false;

  @override
  void dispose() {
    _priceController.dispose();
    _etaController.dispose();
    super.dispose();
  }

  Future<void> _submitOffer(String jobId) async {
    final price = int.tryParse(_priceController.text.trim());
    final eta = _etaController.text.trim();
    if (price == null || price <= 0 || eta.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ingresa un precio válido y un tiempo estimado.')));
      return;
    }
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      await ref.read(technicianJobsControllerProvider.notifier).submitOffer(jobId, price: price, eta: eta);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Oferta enviada.')));
      context.go(RoutePaths.technicianJobs);
    } catch (e) {
      if (!mounted) return;
      final message = e is ApiException ? e.message : 'No se pudo enviar la oferta.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _advance() async {
    if (_advancing) return;
    setState(() => _advancing = true);
    try {
      await ref.read(activeJobControllerProvider.notifier).advance();
      final result = ref.read(activeJobControllerProvider);
      if (result.hasError) throw result.error!;
    } catch (e) {
      if (!mounted) return;
      final message = e is ApiException ? e.message : 'No se pudo actualizar el estado.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _advancing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final jobId = ref.watch(jobSessionControllerProvider);
    final jobAsync = ref.watch(activeJobControllerProvider);
    final job = jobAsync.value;
    final myProfile = ref.watch(techProfileControllerProvider).value;
    final sharingStatus = ref.watch(locationSharingControllerProvider);

    ref.listen(locationSharingControllerProvider, (previous, next) {
      final message = switch (next) {
        LocationSharingStatus.permissionDenied => 'Necesitamos permiso de ubicación para compartirla.',
        LocationSharingStatus.serviceDisabled => 'Activa el GPS del dispositivo para compartir tu ubicación.',
        LocationSharingStatus.error => 'No se pudo actualizar tu ubicación.',
        _ => null,
      };
      if (message != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
    });

    if (jobId == null || (jobAsync.isLoading && job == null)) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (job == null) {
      return Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              CercaHeader(title: 'Detalle del trabajo', onBack: () => context.goBack(RoutePaths.technicianJobs)),
              Expanded(
                child: Center(
                  child: Text('No se pudo cargar este trabajo.', style: CercaText.sora(fontSize: 14)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final isAssignedToMe = myProfile != null && job.technicianProfileId == myProfile.id;
    final isOpenForBid = job.jobKind == 'bidding' && job.technicianProfileId == null;

    // The bottom button is taken by "Avanzar estado" while the job is under
    // way, which is exactly when the client most needs to be reachable —
    // so the chat also lives in the header for the assigned technician.
    final showHeaderChat = isAssignedToMe && !job.isCancelled;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            CercaHeader(
              title: 'Detalle del trabajo',
              onBack: () => context.goBack(RoutePaths.technicianJobs),
              trailing: showHeaderChat
                  ? IconButton(
                      tooltip: 'Chatear con el cliente',
                      onPressed: () => context.push(RoutePaths.chatFor(job.id)),
                      style: IconButton.styleFrom(backgroundColor: AppColors.cercaSurfaceTint),
                      icon: const Icon(Icons.chat_bubble_outline_rounded, color: AppColors.cercaPrimary, size: 20),
                    )
                  : null,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (job.title?.isNotEmpty == true) ...[
                      Text(job.title!, style: CercaText.lora(fontSize: 18)),
                      const SizedBox(height: 4),
                    ],
                    if (job.address?.isNotEmpty == true) ...[
                      Text(job.address!, style: CercaText.sora(fontSize: 13, color: AppColors.cercaTextSecondary)),
                      const SizedBox(height: 12),
                    ],
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: AppColors.cercaBorder),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        children: [
                          _Row('Estado', job.status),
                          const SizedBox(height: 6),
                          _Row('Tipo', job.jobKind),
                          if (isAssignedToMe) ...[
                            const SizedBox(height: 6),
                            _Row('Progreso', '${job.timelineStep} / 3'),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (isOpenForBid) ...[
                      Text('Enviar oferta', style: CercaText.sora(fontSize: 13.5, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _priceController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(hintText: 'Precio (ej: 27000)'),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _etaController,
                        decoration: const InputDecoration(hintText: 'Tiempo estimado (ej: Hoy, 16:00)'),
                      ),
                    ] else if (isAssignedToMe) ...[
                      Text('Este trabajo está asignado a ti.', style: CercaText.sora(fontSize: 13, color: AppColors.cercaTextSecondary)),
                      if (job.isActive) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: AppColors.cercaBorder),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Compartir mi ubicación', style: CercaText.sora(fontSize: 13, fontWeight: FontWeight.w600)),
                                    Text(
                                      sharingStatus == LocationSharingStatus.sharing ? 'El cliente puede ver dónde vas.' : 'Actívalo cuando salgas hacia el trabajo.',
                                      style: CercaText.sora(fontSize: 11.5, color: AppColors.cercaTextSecondary),
                                    ),
                                  ],
                                ),
                              ),
                              Switch(
                                value: sharingStatus == LocationSharingStatus.sharing,
                                activeThumbColor: AppColors.cercaPrimary,
                                onChanged: (value) {
                                  final notifier = ref.read(locationSharingControllerProvider.notifier);
                                  if (value) {
                                    notifier.start(jobId);
                                  } else {
                                    notifier.stop();
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
            if (isOpenForBid)
              PrimaryActionButton(
                label: _submitting ? 'Enviando…' : 'Enviar oferta',
                enabled: !_submitting,
                onTap: () => _submitOffer(jobId),
              )
            else if (isAssignedToMe && job.isActive && job.timelineStep < 3)
              PrimaryActionButton(
                label: _advancing ? 'Actualizando…' : 'Avanzar estado',
                enabled: !_advancing,
                onTap: _advance,
              )
            else if (isAssignedToMe)
              PrimaryActionButton(label: 'Chatear', onTap: () => context.push(RoutePaths.chatFor(job.id))),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: CercaText.sora(fontSize: 12.5, color: AppColors.cercaTextSecondary)),
        Text(value, style: CercaText.sora(fontSize: 12.5, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
