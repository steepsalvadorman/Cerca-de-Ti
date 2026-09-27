import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/router/route_paths.dart';
import '../../../../core/router/back_navigation.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../cerca/application/cerca_controller.dart';
import '../../../cerca/application/cerca_format.dart';
import '../../../cerca/presentation/widgets/cerca_header.dart';
import '../../../cerca/presentation/widgets/cerca_text_styles.dart';
import '../../../cerca/presentation/widgets/primary_action_button.dart';
import '../../../technician/application/providers_controller.dart';
import '../../../technician/domain/tech_team.dart';
import '../../application/job_session_controller.dart';

class ProjectQuoteScreen extends ConsumerStatefulWidget {
  const ProjectQuoteScreen({super.key});

  @override
  ConsumerState<ProjectQuoteScreen> createState() => _ProjectQuoteScreenState();
}

class _ProjectQuoteScreenState extends ConsumerState<ProjectQuoteScreen> {
  bool _requesting = false;

  Future<void> _requestVisit(TechTeam team) async {
    if (_requesting) return;
    setState(() => _requesting = true);
    try {
      final job = await ref.read(jobRepositoryProvider).createJob(
            techTeamId: team.id,
            jobKind: 'project',
            mobilityIncluded: ref.read(cercaControllerProvider).mobilityIncluded,
          );
      ref.read(jobSessionControllerProvider.notifier).setJobId(job.id);
      ref.read(cercaControllerProvider.notifier).requestProjectVisit();
      if (!mounted) return;
      context.go(RoutePaths.tracking);
    } catch (e) {
      if (!mounted) return;
      final message = e is ApiException ? e.message : 'No se pudo solicitar la visita.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _requesting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(cercaControllerProvider);
    final controller = ref.watch(cercaControllerProvider.notifier);
    final providersAsync = ref.watch(providersControllerProvider);
    final providersPage = providersAsync.value;

    TechTeam? team;
    if (providersPage != null) {
      for (final t in providersPage.teams) {
        if (t.id == state.selectedTeamId) {
          team = t;
          break;
        }
      }
    }

    if (team == null) {
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

    final provider = team;
    final mobilityCost = state.mobilityIncluded ? team.mobilityCost : 0;
    final projectTotal = team.laborCost + team.materialsCost + mobilityCost;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            CercaHeader(title: 'Cotización de proyecto', onBack: () => context.goBack(RoutePaths.providerProfile)),
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
                          Text('Proyecto de ${provider.oficio}', style: CercaText.sora(fontSize: 13.5, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Text(
                            '${provider.name} · trabajo a mediano plazo con equipo de ${team.crew} personas',
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
                            child: Text('Fotos y detalles del terreno/obra', style: CercaText.sora(fontSize: 11, color: AppColors.cercaPrimary)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text('Estimado referencial', style: CercaText.sora(fontSize: 13.5, fontWeight: FontWeight.w600)),
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
                        children: [
                          _AmountRow('Mano de obra', formatSoles(team.laborCost)),
                          const SizedBox(height: 8),
                          _AmountRow('Materiales (referencial)', formatSoles(team.materialsCost)),
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            margin: const EdgeInsets.only(top: 2),
                            decoration: const BoxDecoration(
                              border: Border(top: BorderSide(color: AppColors.cercaBorder)),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Movilización del equipo', style: CercaText.sora(fontSize: 12.5, fontWeight: FontWeight.w600)),
                                      const SizedBox(height: 1),
                                      Text(
                                        'Traslado de personal y herramientas · ${formatSoles(team.mobilityCost)}',
                                        style: CercaText.sora(fontSize: 10.5, color: AppColors.cercaTextSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                                Switch(
                                  value: state.mobilityIncluded,
                                  activeThumbColor: Colors.white,
                                  activeTrackColor: AppColors.cercaPrimary,
                                  onChanged: (_) => controller.toggleMobility(),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.only(top: 10),
                            decoration: const BoxDecoration(
                              border: Border(top: BorderSide(color: AppColors.cercaBorder)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Total estimado', style: CercaText.sora(fontSize: 15, fontWeight: FontWeight.w700)),
                                Text(
                                  formatSoles(projectTotal),
                                  style: CercaText.sora(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.cercaPrimary),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Solicitar el proyecto es gratuito. El equipo confirma el valor final tras una visita técnica; la obra y la movilización se pagan directamente al equipo.',
                      style: CercaText.sora(fontSize: 11.5, color: AppColors.cercaTextMuted, height: 1.5),
                    ),
                  ],
                ),
              ),
            ),
            PrimaryActionButton(
              label: _requesting ? 'Solicitando…' : 'Solicitar visita y agendar',
              enabled: !_requesting,
              onTap: () => _requestVisit(team!),
            ),
          ],
        ),
      ),
    );
  }
}

class _AmountRow extends StatelessWidget {
  const _AmountRow(this.label, this.value);
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
