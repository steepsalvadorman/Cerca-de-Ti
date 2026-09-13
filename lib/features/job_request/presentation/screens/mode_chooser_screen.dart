import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/router/route_paths.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../cerca/application/cerca_seed_data.dart';
import '../../../cerca/presentation/widgets/back_circle_button.dart';
import '../../../cerca/presentation/widgets/cerca_text_styles.dart';
import '../../../technician/application/providers_controller.dart';
import '../../application/job_session_controller.dart';

class ModeChooserScreen extends ConsumerStatefulWidget {
  const ModeChooserScreen({super.key});

  @override
  ConsumerState<ModeChooserScreen> createState() => _ModeChooserScreenState();
}

class _ModeChooserScreenState extends ConsumerState<ModeChooserScreen> {
  bool _creating = false;
  String? _categoryId;
  final _descriptionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final draft = ref.read(serviceRequestDraftProvider);
    _categoryId = draft.categoryId ?? ref.read(selectedCategoryProvider);
    _descriptionController.text = draft.description;
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  bool _saveDraft() {
    final categoryId = _categoryId;
    final description = _descriptionController.text.trim();
    if (categoryId == null || description.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona una especialidad y describe el trabajo que necesitas.')),
      );
      return false;
    }
    final category = CercaSeedData.categories.firstWhere((item) => item.id == categoryId);
    ref.read(serviceRequestDraftProvider.notifier).save(
          categoryId: category.id,
          categoryLabel: category.label,
          description: description,
        );
    return true;
  }

  void _findTechnicians() {
    if (!_saveDraft()) return;
    ref.read(selectedCategoryProvider.notifier).select(_categoryId!);
    context.go(RoutePaths.home);
  }

  Future<void> _startBidding() async {
    if (_creating || !_saveDraft()) return;
    setState(() => _creating = true);
    try {
      final draft = ref.read(serviceRequestDraftProvider);
      final job = await ref.read(jobRepositoryProvider).createJob(
            jobKind: 'bidding',
            title: draft.title,
          );
      ref.read(jobSessionControllerProvider.notifier).setJobId(job.id);
      if (!mounted) return;
      context.go(RoutePaths.jobBidding);
    } catch (e) {
      if (!mounted) return;
      final message = e is ApiException ? e.message : 'No se pudo enviar la solicitud.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 6),
              child: Row(
                children: [
                  BackCircleButton(onTap: () => context.go(RoutePaths.home)),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('¿Qué servicio necesitas?', style: CercaText.lora(fontSize: 21)),
                    const SizedBox(height: 4),
                    Text(
                      'Cuéntanos el oficio y el trabajo antes de elegir cómo contratar.',
                      style: CercaText.sora(fontSize: 13, color: AppColors.cercaTextSecondary, height: 1.5),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _categoryId,
                      decoration: InputDecoration(
                        labelText: 'Especialidad técnica',
                        hintText: 'Selecciona un oficio',
                        prefixIcon: const Icon(Icons.handyman_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      items: [
                        for (final category in CercaSeedData.categories)
                          DropdownMenuItem(value: category.id, child: Text(category.label)),
                      ],
                      onChanged: (value) => setState(() => _categoryId = value),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _descriptionController,
                      minLines: 3,
                      maxLines: 4,
                      maxLength: 180,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        labelText: 'Trabajo requerido',
                        hintText: 'Ej.: reparar una fuga debajo del lavadero',
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('¿Cómo prefieres contratar?', style: CercaText.lora(fontSize: 19)),
                    const SizedBox(height: 12),
                    _OptionCard(
                      number: '1',
                      title: 'Contactar directo',
                      description: 'Veremos únicamente técnicos de la especialidad elegida para que compares y contactes uno.',
                      cta: 'Buscar técnicos ›',
                      onTap: _findTechnicians,
                    ),
                    const SizedBox(height: 14),
                    _OptionCard(
                      number: '2',
                      title: 'Licitación entre técnicos',
                      description: 'Envía tu solicitud y recibe ofertas de varios técnicos verificados. Elige la mejor combinación de precio y calidad.',
                      cta: _creating ? 'Enviando…' : 'Solicitar ofertas ›',
                      onTap: _startBidding,
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

class _OptionCard extends StatelessWidget {
  const _OptionCard({
    required this.number,
    required this.title,
    required this.description,
    required this.cta,
    required this.onTap,
  });

  final String number;
  final String title;
  final String description;
  final String cta;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppColors.cercaBorder),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: AppColors.cercaSurfaceTint,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(number, style: CercaText.sora(fontWeight: FontWeight.w700, color: AppColors.cercaPrimary)),
            ),
            Text(title, style: CercaText.sora(fontSize: 15.5, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(description, style: CercaText.sora(fontSize: 12.5, color: AppColors.cercaTextSecondary, height: 1.5)),
            const SizedBox(height: 10),
            Text(cta, style: CercaText.sora(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.cercaPrimary)),
          ],
        ),
      ),
    );
  }
}
