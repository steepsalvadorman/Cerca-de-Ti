import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/router/route_paths.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/application/auth_controller.dart';
import '../../../cerca/application/cerca_controller.dart';
import '../../../cerca/application/cerca_seed_data.dart';
import '../../../cerca/presentation/widgets/cerca_header.dart';
import '../../../cerca/presentation/widgets/cerca_text_styles.dart';
import '../../../cerca/presentation/widgets/monogram_avatar.dart';
import '../../../cerca/presentation/widgets/primary_action_button.dart';
import '../../application/tech_profile_controller.dart';

class TechProfileScreen extends ConsumerStatefulWidget {
  const TechProfileScreen({super.key});

  @override
  ConsumerState<TechProfileScreen> createState() => _TechProfileScreenState();
}

class _TechProfileScreenState extends ConsumerState<TechProfileScreen> {
  final _oficioController = TextEditingController();
  bool _prefilled = false;
  bool _saved = false;

  @override
  void dispose() {
    _oficioController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final cercaState = ref.read(cercaControllerProvider);
    await ref.read(techProfileControllerProvider.notifier).save(
          oficio: _oficioController.text.trim(),
          coverageKm: cercaState.coverageKm,
          availableDays: cercaState.availableDays.toList(),
          categories: cercaState.techCategories.toList(),
        );
    if (!mounted) return;

    final result = ref.read(techProfileControllerProvider);
    result.whenOrNull(
      data: (_) => setState(() => _saved = true),
      error: (error, _) {
        final message = error is ApiException ? error.message : 'No se pudo guardar tu perfil.';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(cercaControllerProvider);
    final controller = ref.watch(cercaControllerProvider.notifier);
    final profileAsync = ref.watch(techProfileControllerProvider);
    final userName = ref.watch(authControllerProvider).value?.user.name.trim() ?? '';

    final profile = profileAsync.value;
    if (profile != null && !_prefilled) {
      _prefilled = true;
      _oficioController.text = profile.oficio;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        for (final c in profile.categories) {
          if (!state.techCategories.contains(c)) controller.toggleTechCategory(c);
        }
        for (final c in state.techCategories.toList()) {
          if (!profile.categories.contains(c)) controller.toggleTechCategory(c);
        }
        controller.setCoverageKm(profile.coverageKm);
        for (final d in profile.availableDays) {
          if (!state.availableDays.contains(d)) controller.toggleDay(d);
        }
        for (final d in state.availableDays.toList()) {
          if (!profile.availableDays.contains(d)) controller.toggleDay(d);
        }
      });
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            const CercaHeader(title: 'Mi perfil'),
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
                            const SizedBox(height: 2),
                            Text('Cambiar foto', style: CercaText.sora(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.cercaPrimary)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _FieldLabel('Nombre'),
                    _ReadonlyField(userName),
                    const SizedBox(height: 14),
                    _FieldLabel('Oficio principal'),
                    TextField(
                      controller: _oficioController,
                      style: CercaText.sora(fontSize: 13.5),
                      decoration: InputDecoration(
                        hintText: 'Ej: Gasfitero',
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.cercaBorder)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.cercaBorder)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _FieldLabel('Categorías que ofreces'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final c in CercaSeedData.categories)
                          _Chip(
                            label: c.label,
                            active: state.techCategories.contains(c.id),
                            onTap: () => controller.toggleTechCategory(c.id),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _FieldLabel('Radio de cobertura'),
                        Text(
                          '${state.coverageKm} km',
                          style: CercaText.sora(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.cercaPrimary),
                        ),
                      ],
                    ),
                    Slider(
                      value: state.coverageKm.toDouble(),
                      min: 1,
                      max: 25,
                      divisions: 24,
                      activeColor: AppColors.cercaPrimary,
                      onChanged: (v) => controller.setCoverageKm(v.round()),
                    ),
                    const SizedBox(height: 8),
                    _FieldLabel('Disponibilidad'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        for (final d in CercaSeedData.weekDays)
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: _DayChip(
                                label: d.label,
                                active: state.availableDays.contains(d.key),
                                onTap: () => controller.toggleDay(d.key),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    InkWell(
                      onTap: () => context.go(RoutePaths.techDocs),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: AppColors.cercaBorder),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text('Documentación y verificación', style: CercaText.sora(fontSize: 13, fontWeight: FontWeight.w600)),
                            ),
                            Text('›', style: CercaText.sora(fontSize: 14, color: AppColors.cercaTextMuted)),
                          ],
                        ),
                      ),
                    ),
                    if (_saved) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.cercaSuccessBg,
                          border: Border.all(color: AppColors.cercaSuccessBorder),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '✓ Cambios guardados correctamente.',
                          style: CercaText.sora(fontSize: 12.5, color: AppColors.cercaSuccessText),
                        ),
                      ),
                      const SizedBox(height: 10),
                      InkWell(
                        onTap: () => context.go(RoutePaths.technicianJobs),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.cercaPrimary),
                          ),
                          child: Text('Ir a mis trabajos →', style: CercaText.sora(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.cercaPrimary)),
                        ),
                      ),
                    ],
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
            PrimaryActionButton(
              label: profileAsync.isLoading ? 'Guardando…' : 'Guardar cambios',
              enabled: !profileAsync.isLoading,
              onTap: _save,
            ),
          ],
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: CercaText.sora(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.cercaTextSecondary),
    );
  }
}

class _ReadonlyField extends StatelessWidget {
  const _ReadonlyField(this.value);
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.cercaBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(value, style: CercaText.sora(fontSize: 13.5)),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.active, required this.onTap});
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
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

class _DayChip extends StatelessWidget {
  const _DayChip({required this.label, required this.active, required this.onTap});
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? AppColors.cercaPrimary : Colors.white,
          border: Border.all(color: active ? AppColors.cercaPrimary : AppColors.cercaBorder),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: CercaText.sora(fontSize: 11.5, fontWeight: FontWeight.w600, color: active ? Colors.white : AppColors.cercaTextPrimary),
        ),
      ),
    );
  }
}
