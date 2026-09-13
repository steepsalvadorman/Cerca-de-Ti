import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/route_paths.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/application/auth_controller.dart';
import '../../../auth/domain/auth_user.dart';
import '../../../cerca/presentation/widgets/cerca_logo_mark.dart';
import '../../../cerca/presentation/widgets/cerca_text_styles.dart';
import '../../../technician/application/tech_profile_controller.dart';

/// Lands here right after login/register. The role is no longer a manual
/// either/or choice (the backend fixes it at registration) — this screen
/// just greets the signed-in user and offers a single CTA matching their
/// real account role.
class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authControllerProvider).value;
    final user = session?.user;
    final techProfile = user?.isTechnician == true ? ref.watch(techProfileControllerProvider) : null;
    final technicianProfile = techProfile?.value;
    final hasCompleteTechProfile = technicianProfile != null &&
        technicianProfile.oficio.trim().isNotEmpty &&
        technicianProfile.categories.isNotEmpty;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.cercaBackground, AppColors.cercaSurfaceTint],
            stops: [0.55, 1.0],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 30),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  children: [
                    const CercaLogoMark(size: 70),
                    const SizedBox(height: 20),
                    Text(
                      user == null ? 'Cerca' : '¡Hola, ${user.name.trim().split(' ').first}!',
                      style: CercaText.lora(fontSize: 26),
                    ),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        'Técnicos verificados, cerca de ti. Encuentra ayuda de confianza para cualquier trabajo del hogar.',
                        textAlign: TextAlign.center,
                        style: CercaText.sora(
                          fontSize: 14.5,
                          color: AppColors.cercaTextSecondary,
                          height: 1.55,
                        ),
                      ),
                    ),
                  ],
                ),
                if (user == null)
                  const SizedBox(
                    height: 44,
                    child: Center(child: CircularProgressIndicator(strokeWidth: 2.4)),
                  )
                else if (user.isTechnician)
                  _RoleCard(
                    mono: 'T',
                    title: techProfile?.isLoading == true
                        ? 'Preparando tu perfil…'
                        : !hasCompleteTechProfile
                            ? 'Crear mi perfil profesional'
                            : 'Continuar como Técnico',
                    subtitle: !hasCompleteTechProfile
                        ? 'Completa tus servicios, cobertura, disponibilidad y verificación'
                        : 'Revisa tus trabajos y solicitudes abiertas a licitación',
                    onTap: () => context.go(
                      !hasCompleteTechProfile ? RoutePaths.techProfile : RoutePaths.technicianJobs,
                    ),
                  )
                else
                  _RoleCard(
                    mono: 'H',
                    title: 'Continuar como Cliente',
                    subtitle: 'Encuentra un técnico para tu próximo trabajo',
                    onTap: () => context.go(RoutePaths.home),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.mono,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String mono;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppColors.cercaBorder),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.cercaTextPrimary.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.cercaSurfaceTint,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                mono,
                style: CercaText.sora(fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.cercaPrimary),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: CercaText.sora(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: CercaText.sora(fontSize: 12.5, color: AppColors.cercaTextSecondary)),
                ],
              ),
            ),
            Text('›', style: CercaText.sora(fontSize: 16, color: AppColors.cercaTextMuted)),
          ],
        ),
      ),
    );
  }
}
