import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/route_paths.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/application/auth_controller.dart';
import '../../../cerca/application/cerca_controller.dart';
import '../../../cerca/application/cerca_seed_data.dart';
import '../../../cerca/application/cerca_state.dart';
import '../../../cerca/domain/entities/category.dart';
import '../../../cerca/presentation/widgets/cerca_text_styles.dart';
import '../../../cerca/presentation/widgets/monogram_avatar.dart';
import '../../../cerca/presentation/widgets/verified_badge.dart';
import '../../../technician/application/providers_controller.dart';
import '../../../technician/domain/tech_team.dart';
import '../../../technician/domain/technician.dart';

/// Either a [Technician] or a [TechTeam] — the two provider kinds shown
/// on the map/list, unified by the fields this screen actually reads.
sealed class _Provider {
  const _Provider();

  int get id;
  String get name;
  String get mono;
  String get oficio;
  double get rating;
  String get distance;
  String get priceLabel;
  double get pinTop;
  double get pinLeft;
}

class _TechnicianProvider extends _Provider {
  const _TechnicianProvider(this.value);
  final Technician value;

  @override
  int get id => value.id;
  @override
  String get name => value.name;
  @override
  String get mono => value.mono;
  @override
  String get oficio => value.oficio;
  @override
  double get rating => value.rating;
  @override
  String get distance => value.distance;
  @override
  String get priceLabel => value.priceLabel;
  @override
  double get pinTop => value.pinTop;
  @override
  double get pinLeft => value.pinLeft;
}

class _TeamProvider extends _Provider {
  const _TeamProvider(this.value);
  final TechTeam value;

  @override
  int get id => value.id;
  @override
  String get name => value.name;
  @override
  String get mono => value.mono;
  @override
  String get oficio => value.oficio;
  @override
  double get rating => value.rating;
  @override
  String get distance => value.distance;
  @override
  String get priceLabel => value.priceLabel;
  @override
  double get pinTop => value.pinTop;
  @override
  double get pinLeft => value.pinLeft;
}

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(cercaControllerProvider);
    final controller = ref.watch(cercaControllerProvider.notifier);
    final isPuntual = state.jobKind == JobKind.puntual;
    final categories = isPuntual ? CercaSeedData.categories : CercaSeedData.projectCategories;
    final userName = ref.watch(authControllerProvider).value?.user.name.trim().split(' ').first ?? '';
    final selectedCategory = ref.watch(selectedCategoryProvider);
    final providersAsync = ref.watch(providersControllerProvider);
    final providersPage = providersAsync.value;
    final List<_Provider> providers = providersPage == null
        ? const []
        : isPuntual
            ? providersPage.technicians.map(_TechnicianProvider.new).toList()
            : providersPage.teams.map(_TeamProvider.new).toList();

    return Scaffold(
      backgroundColor: AppColors.cercaBackground,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Hola, $userName', style: CercaText.sora(fontSize: 13, color: AppColors.cercaTextSecondary)),
                            const SizedBox(height: 2),
                            Text('¿Qué necesitas hoy?', style: CercaText.lora(fontSize: 20)),
                          ],
                        ),
                      ),
                      InkWell(
                        onTap: () => context.go(RoutePaths.clientAccount),
                        borderRadius: BorderRadius.circular(18),
                        child: MonogramAvatar(text: userName.isEmpty ? '?' : userName[0].toUpperCase(), size: 36, borderRadius: 18, fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 6, 20, 90),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: AppColors.cercaChipTrack,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: _ModeTab(
                                  label: 'Trabajos puntuales',
                                  active: isPuntual,
                                  onTap: () => controller.setJobKind(JobKind.puntual),
                                ),
                              ),
                              Expanded(
                                child: _ModeTab(
                                  label: 'Proyectos',
                                  active: !isPuntual,
                                  onTap: () => controller.setJobKind(JobKind.proyecto),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: AppColors.cercaBorder),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            isPuntual ? 'Buscar por oficio o problema…' : 'Buscar por tipo de proyecto…',
                            style: CercaText.sora(fontSize: 14, color: AppColors.cercaTextMuted),
                          ),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          height: 84,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: categories.length,
                            separatorBuilder: (_, _) => const SizedBox(width: 10),
                            itemBuilder: (context, i) => _CategoryChip(
                              category: categories[i],
                              active: selectedCategory == categories[i].id,
                              onTap: () =>
                                  ref.read(selectedCategoryProvider.notifier).toggle(categories[i].id),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (providersAsync.isLoading)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 40),
                            child: Center(child: CircularProgressIndicator()),
                          )
                        else if (providersAsync.hasError)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: Text(
                              'No se pudieron cargar los técnicos. Desliza para reintentar.',
                              style: CercaText.sora(fontSize: 13, color: AppColors.cercaTextSecondary),
                            ),
                          )
                        else ...[
                          _MapPreview(providers: providers, onSelect: (p) => _select(context, controller, p)),
                          const SizedBox(height: 18),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                isPuntual ? 'Técnicos cerca de ti' : 'Equipos cerca de ti',
                                style: CercaText.sora(fontSize: 15, fontWeight: FontWeight.w600),
                              ),
                              Text('Ver todos', style: CercaText.sora(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.cercaPrimary)),
                            ],
                          ),
                          const SizedBox(height: 10),
                          for (final p in providers)
                            _ProviderRow(provider: p, onTap: () => _select(context, controller, p)),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (isPuntual)
              Positioned(
                bottom: 20,
                right: 20,
                child: InkWell(
                  onTap: () => context.go(RoutePaths.jobMode),
                  borderRadius: BorderRadius.circular(30),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
                    decoration: BoxDecoration(
                      color: AppColors.cercaPrimary,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(color: AppColors.cercaPrimary.withValues(alpha: 0.35), blurRadius: 20, offset: const Offset(0, 8)),
                      ],
                    ),
                    child: Text(
                      '+ Publicar trabajo',
                      style: CercaText.sora(fontSize: 13.5, fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _select(BuildContext context, CercaController controller, _Provider provider) {
    if (provider is _TeamProvider) {
      controller.selectTeam(provider.id);
    } else {
      controller.selectTech(provider.id);
    }
    context.go(RoutePaths.providerProfile);
  }
}

class _ModeTab extends StatelessWidget {
  const _ModeTab({required this.label, required this.active, required this.onTap});
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? AppColors.cercaPrimary : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Text(
          label,
          style: CercaText.sora(fontSize: 12.5, fontWeight: FontWeight.w700, color: active ? Colors.white : AppColors.cercaTextSecondary),
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.category, required this.active, required this.onTap});

  final Category category;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Column(
          children: [
            Container(
              width: 46,
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: active ? AppColors.cercaPrimary : AppColors.cercaSurfaceTint,
                border: Border.all(color: active ? AppColors.cercaPrimary : const Color(0xFFEAD6D2)),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                category.mono,
                style: CercaText.sora(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: active ? Colors.white : AppColors.cercaPrimary,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              category.label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: CercaText.sora(
                fontSize: 10.5,
                color: active ? AppColors.cercaPrimary : AppColors.cercaTextSecondary,
                fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapPreview extends StatelessWidget {
  const _MapPreview({required this.providers, required this.onSelect});
  final List<_Provider> providers;
  final void Function(_Provider) onSelect;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 180,
        color: AppColors.cercaMapBackground,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              children: [
                Positioned(
                  left: constraints.maxWidth * 0.5 - 7,
                  top: constraints.maxHeight * 0.7 - 7,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: AppColors.cercaMapPin,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                    ),
                  ),
                ),
                for (final p in providers)
                  Positioned(
                    left: constraints.maxWidth * p.pinLeft - 15,
                    top: constraints.maxHeight * p.pinTop - 15,
                    child: InkWell(
                      onTap: () => onSelect(p),
                      child: Transform.rotate(
                        angle: -0.785398,
                        child: Container(
                          width: 30,
                          height: 30,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.cercaPrimary,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(15),
                              topRight: Radius.circular(15),
                              bottomLeft: Radius.circular(15),
                            ),
                            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 8, offset: const Offset(0, 3))],
                          ),
                          child: Transform.rotate(
                            angle: 0.785398,
                            child: Text(p.mono, style: CercaText.sora(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ProviderRow extends StatelessWidget {
  const _ProviderRow({required this.provider, required this.onTap});
  final _Provider provider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppColors.cercaBorder),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            MonogramAvatar(text: provider.mono, fontSize: 15),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          provider.name,
                          overflow: TextOverflow.ellipsis,
                          style: CercaText.sora(fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const VerifiedBadge(),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text.rich(
                    TextSpan(
                      style: CercaText.sora(fontSize: 12, color: AppColors.cercaTextSecondary),
                      children: [
                        TextSpan(text: '${provider.oficio} · ${provider.distance} · '),
                        TextSpan(text: '★', style: CercaText.sora(fontSize: 12, color: AppColors.cercaStar)),
                        TextSpan(text: ' ${provider.rating}'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Text(provider.priceLabel, style: CercaText.sora(fontSize: 12.5, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
