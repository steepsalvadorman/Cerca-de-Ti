import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/route_paths.dart';
import '../../../../core/router/back_navigation.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/application/auth_controller.dart';
import '../../../cerca/application/cerca_seed_data.dart';
import '../../../cerca/domain/entities/doc_requirement.dart';
import '../../../cerca/presentation/widgets/back_circle_button.dart';
import '../../../cerca/presentation/widgets/cerca_text_styles.dart';
import '../../../cerca/presentation/widgets/monogram_avatar.dart';
import '../../../cerca/presentation/widgets/primary_action_button.dart';
import '../../../../core/network/api_exception.dart';
import '../../application/tech_docs_controller.dart';
import '../../domain/technician_document.dart';

class TechDocsScreen extends ConsumerStatefulWidget {
  const TechDocsScreen({super.key});

  @override
  ConsumerState<TechDocsScreen> createState() => _TechDocsScreenState();
}

class _TechDocsScreenState extends ConsumerState<TechDocsScreen> {
  /// Which document is mid-upload, so only its row shows a spinner.
  String? _uploading;

  Future<void> _upload(String documentKey) async {
    if (_uploading != null) return;
    setState(() => _uploading = documentKey);
    try {
      final uploaded = await ref.read(techDocsControllerProvider.notifier).upload(documentKey);
      if (!mounted || !uploaded) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Documento subido.')),
      );
    } catch (e) {
      if (!mounted) return;
      final message = e is ApiException ? e.message : 'No se pudo subir el documento.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _uploading = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final docsAsync = ref.watch(techDocsControllerProvider);
    final docs = docsAsync.value ?? const <TechnicianDocumentStatus>[];
    // Progress tracks the mandatory documents only, matching what the
    // backend actually verifies against. `seguro` is optional, so it is
    // still listed and uploadable but does not hold the technician back.
    final mandatory = CercaSeedData.docRequirements.where((d) => d.mandatory).toList();
    bool isUploaded(String key) => docs.any((d) => d.documentKey == key && d.isUploaded);
    final uploadedCount = mandatory.where((d) => isUploaded(d.key)).length;
    final totalCount = mandatory.length;
    final allUploaded = uploadedCount == totalCount;
    final userName = ref.watch(authControllerProvider).value?.user.name.trim() ?? '';
    final initials = userName.isEmpty ? '?' : userName[0].toUpperCase();

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              child: Row(
                children: [
                  BackCircleButton(onTap: () => context.goBack(RoutePaths.techProfile)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('Verifica tu perfil', style: CercaText.lora(fontSize: 19)),
                  ),
                  InkWell(
                    onTap: () => context.goBack(RoutePaths.techProfile),
                    borderRadius: BorderRadius.circular(16),
                    child: MonogramAvatar(text: initials, size: 32, borderRadius: 16, fontSize: 12),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Antes de recibir solicitudes, sube tu documentación. Así los hogares confían en abrirte la puerta.',
                      style: CercaText.sora(fontSize: 13.5, color: AppColors.cercaTextSecondary, height: 1.5),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Progreso', style: CercaText.sora(fontSize: 12, color: AppColors.cercaTextSecondary)),
                        Text(
                          '$uploadedCount de $totalCount',
                          style: CercaText.sora(fontSize: 12, color: AppColors.cercaTextSecondary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: totalCount == 0 ? 0 : uploadedCount / totalCount,
                        minHeight: 6,
                        backgroundColor: AppColors.cercaBorder,
                        color: AppColors.cercaPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    for (final doc in CercaSeedData.docRequirements)
                      _DocRow(
                        doc: doc,
                        uploaded: isUploaded(doc.key),
                        uploading: _uploading == doc.key,
                        onTap: _uploading == null ? () => _upload(doc.key) : null,
                      ),
                    if (allUploaded)
                      Container(
                        margin: const EdgeInsets.only(top: 16),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.cercaSuccessBg,
                          border: Border.all(color: AppColors.cercaSuccessBorder),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '✓ Documentación completa. Te avisaremos cuando quede verificada.',
                          style: CercaText.sora(fontSize: 13, color: AppColors.cercaSuccessText, height: 1.5),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            PrimaryActionButton(
              label: allUploaded ? 'Finalizar y ver mis trabajos' : 'Sube los documentos obligatorios',
              enabled: allUploaded,
              onTap: () => context.go(RoutePaths.technicianJobs),
            ),
          ],
        ),
      ),
    );
  }
}

class _DocRow extends StatelessWidget {
  const _DocRow({
    required this.doc,
    required this.uploaded,
    required this.uploading,
    required this.onTap,
  });

  final DocRequirement doc;
  final bool uploaded;
  final bool uploading;
  /// `null` while another document is uploading, which disables the row.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.cercaBorder)),
        ),
        child: Row(
          children: [
            MonogramAvatar(text: doc.mono, size: 38, borderRadius: 10, fontSize: 14),
            const SizedBox(width: 12),
            Expanded(
              child: Text(doc.label, style: CercaText.sora(fontSize: 14, fontWeight: FontWeight.w600)),
            ),
            if (uploading)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.cercaPrimary),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: uploaded ? AppColors.cercaSuccessBg : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  border: uploaded
                      ? Border.all(color: AppColors.cercaSuccessBorder)
                      : Border.all(color: const Color(0xFFD8CFC9), style: BorderStyle.solid),
                ),
                child: Text(
                  // "Subir" rather than "Pendiente": the row is now an
                  // action, not just a status badge.
                  uploaded ? 'Subido' : 'Subir',
                  style: CercaText.sora(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: uploaded ? AppColors.cercaSuccessText : AppColors.cercaTextMuted,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
