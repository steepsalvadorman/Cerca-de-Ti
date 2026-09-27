import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/route_paths.dart';
import '../../../../core/router/back_navigation.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../cerca/application/cerca_controller.dart';
import '../../../cerca/presentation/widgets/back_circle_button.dart';
import '../../../cerca/presentation/widgets/cerca_text_styles.dart';
import '../../../cerca/presentation/widgets/verified_badge.dart';
import '../../application/providers_controller.dart';
import '../../domain/tech_team.dart';

class _ProfileView {
  const _ProfileView({
    required this.mono,
    required this.name,
    required this.oficio,
    required this.distance,
    required this.rating,
    required this.reviews,
    required this.priceLabel,
    this.coverageKm,
    this.availableDays = const [],
    this.categories = const [],
    this.isVerified = false,
    this.team,
  });

  final String mono;
  final String name;
  final String oficio;
  final String distance;
  final double rating;
  final int reviews;
  final String priceLabel;
  final int? coverageKm;
  final List<String> availableDays;
  final List<String> categories;
  final bool isVerified;
  final TechTeam? team;
}

class TechnicianProfileScreen extends ConsumerWidget {
  const TechnicianProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(cercaControllerProvider);
    final providersAsync = ref.watch(providersControllerProvider);
    final providersPage = providersAsync.value;

    _ProfileView? profile;
    if (providersPage != null) {
      if (state.viewingTeam) {
        for (final t in providersPage.teams) {
          if (t.id == state.selectedTeamId) {
            profile = _ProfileView(mono: t.mono, name: t.name, oficio: t.oficio, distance: t.distance, rating: t.rating, reviews: t.reviews, priceLabel: t.priceLabel, team: t);
            break;
          }
        }
      } else {
        for (final t in providersPage.technicians) {
          if (t.id == state.selectedTechId) {
            profile = _ProfileView(
              mono: t.mono,
              name: t.name,
              oficio: t.oficio,
              distance: t.distance,
              rating: t.rating,
              reviews: t.reviews,
              priceLabel: t.priceLabel,
              coverageKm: t.coverageKm,
              availableDays: t.availableDays,
              categories: t.categories,
              isVerified: t.isVerified,
            );
            break;
          }
        }
      }
    }

    if (profile == null) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Center(
            child: providersAsync.isLoading
                ? const CircularProgressIndicator()
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('No se pudo cargar este perfil.', style: CercaText.sora(fontSize: 14)),
                      const SizedBox(height: 12),
                      TextButton(onPressed: () => context.goBack(RoutePaths.home), child: const Text('Volver')),
                    ],
                  ),
          ),
        ),
      );
    }

    final provider = profile;
    final isTeam = provider.team != null;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    // Keep the navigation control and the overlapping avatar
                    // in separate vertical zones on every screen size.
                    height: 142,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [AppColors.cercaPrimary, AppColors.cercaPrimaryGradientEnd],
                      ),
                    ),
                    child: SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 20, top: 8),
                        child: Align(
                          alignment: Alignment.topLeft,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              BackCircleButton(
                                onTap: () => context.goBack(RoutePaths.home),
                                color: Colors.white,
                                iconColor: AppColors.cercaPrimary,
                                border: false,
                              ),
                              const SizedBox(width: 7),
                              Text(
                                'Volver',
                                style: CercaText.sora(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Transform.translate(
                          offset: const Offset(0, -37),
                          child: Container(
                            width: 74,
                            height: 74,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AppColors.cercaSurfaceTint,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppColors.cercaBackground, width: 4),
                            ),
                            child: Text(provider.mono, style: CercaText.sora(fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.cercaPrimary)),
                          ),
                        ),
                        Transform.translate(
                          offset: const Offset(0, -27),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(provider.name, style: CercaText.lora(fontSize: 20)),
                                  if (provider.isVerified) ...[
                                    const SizedBox(width: 8),
                                    const VerifiedBadge(),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text('${provider.oficio} · ${provider.distance} de ti', style: CercaText.sora(fontSize: 13, color: AppColors.cercaTextSecondary)),
                              const SizedBox(height: 4),
                              Text.rich(
                                TextSpan(
                                  style: CercaText.sora(fontSize: 13),
                                  children: [
                                    TextSpan(text: '★ ', style: CercaText.sora(fontSize: 13, color: AppColors.cercaStar)),
                                    TextSpan(text: '${provider.rating} '),
                                    TextSpan(
                                      text: '(${provider.reviews} reseñas)',
                                      style: CercaText.sora(fontSize: 13, color: AppColors.cercaTextMuted),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              if (provider.team case TechTeam(:final crew, :final projects))
                                _StatsRow(items: [
                                  _Stat('$crew', 'Integrantes'),
                                  _Stat('$projects', 'Proyectos'),
                                  _Stat('${provider.rating}', 'Calificación'),
                                ])
                              else
                                _StatsRow(items: [
                                  _Stat('${provider.rating}', 'Calificación'),
                                  _Stat('${provider.reviews}', 'Reseñas'),
                                  _Stat(provider.distance, 'Distancia'),
                                ]),
                              const SizedBox(height: 7),
                              const _DataSourceLabel(
                                icon: Icons.auto_awesome_rounded,
                                text: 'Datos calculados y verificados por Cerca',
                              ),
                              const SizedBox(height: 16),
                              _ProfileSection(
                                title: 'Información del servicio',
                                source: 'Información proporcionada por el técnico',
                                children: [
                                  _DetailLine(
                                    icon: Icons.payments_outlined,
                                    label: 'Tarifa referencial',
                                    value: provider.priceLabel,
                                  ),
                                  if (provider.coverageKm != null)
                                    _DetailLine(
                                      icon: Icons.location_on_outlined,
                                      label: 'Cobertura',
                                      value: 'Hasta ${provider.coverageKm} km',
                                    ),
                                  if (provider.availableDays.isNotEmpty)
                                    _DetailLine(
                                      icon: Icons.calendar_today_outlined,
                                      label: 'Disponibilidad',
                                      value: _dayLabels(provider.availableDays),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              _VerificationCard(isVerified: provider.isVerified),
                              const SizedBox(height: 16),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 22),
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.cercaBorder))),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => isTeam ? context.push(RoutePaths.jobProjectQuote) : context.push(RoutePaths.jobDirect),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.cercaPrimary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(
                    isTeam ? 'Cotizar proyecto' : 'Solicitar cotización',
                    style: CercaText.sora(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _dayLabels(List<String> days) {
    const labels = {
      'lun': 'Lun',
      'mar': 'Mar',
      'mie': 'Mié',
      'jue': 'Jue',
      'vie': 'Vie',
      'sab': 'Sáb',
      'dom': 'Dom',
    };
    return days.map((day) => labels[day] ?? day).join(', ');
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.items});
  final List<_Stat> items;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(child: items[i]),
        ],
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.value, this.label);
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.cercaBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(value, style: CercaText.sora(fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(label, style: CercaText.sora(fontSize: 10, color: AppColors.cercaTextSecondary)),
        ],
      ),
    );
  }
}

class _DataSourceLabel extends StatelessWidget {
  const _DataSourceLabel({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 13, color: AppColors.cercaTextMuted),
        const SizedBox(width: 5),
        Flexible(child: Text(text, style: CercaText.sora(fontSize: 10.5, color: AppColors.cercaTextMuted))),
      ],
    );
  }
}

class _ProfileSection extends StatelessWidget {
  const _ProfileSection({required this.title, required this.source, required this.children});

  final String title;
  final String source;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
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
          Text(title, style: CercaText.sora(fontSize: 13.5, fontWeight: FontWeight.w600)),
          const SizedBox(height: 3),
          _DataSourceLabel(icon: Icons.edit_outlined, text: source),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 19, color: AppColors.cercaPrimary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: CercaText.sora(fontSize: 10.5, color: AppColors.cercaTextMuted)),
                const SizedBox(height: 1),
                Text(value, style: CercaText.sora(fontSize: 12.5, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VerificationCard extends StatelessWidget {
  const _VerificationCard({required this.isVerified});

  final bool isVerified;

  @override
  Widget build(BuildContext context) {
    final color = isVerified ? AppColors.cercaSuccessText : AppColors.cercaTextSecondary;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isVerified ? AppColors.cercaSuccessBg : AppColors.cercaBackground,
        border: Border.all(color: isVerified ? AppColors.cercaSuccessBorder : AppColors.cercaBorder),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(isVerified ? Icons.verified_user_rounded : Icons.info_outline_rounded, color: color, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isVerified ? 'Identidad y documentos verificados' : 'Verificación pendiente',
                  style: CercaText.sora(fontSize: 12.5, fontWeight: FontWeight.w600, color: color),
                ),
                const SizedBox(height: 3),
                Text(
                  isVerified
                      ? 'Cerca validó la documentación requerida para prestar servicios.'
                      : 'Este técnico todavía no completó toda la validación documental.',
                  style: CercaText.sora(fontSize: 11, color: AppColors.cercaTextSecondary, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
