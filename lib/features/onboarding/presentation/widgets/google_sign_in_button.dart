import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/router/route_paths.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/application/auth_controller.dart';
import '../../../cerca/presentation/widgets/cerca_text_styles.dart';
import 'social_provider_button.dart';

/// "Continuar con Google", shared by the login and register screens.
///
/// [role] is what the register screen already knows from its
/// client/technician toggle. The login screen has no such toggle and
/// passes nothing; if that turns out to be a brand-new account the
/// backend says so, and the sheet below asks before trying again.
class GoogleSignInButton extends ConsumerWidget {
  const GoogleSignInButton({super.key, this.role});

  final String? role;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SocialProviderButton(
      label: 'Continuar con Google',
      onTap: () => _signIn(context, ref),
      iconBackground: Colors.white,
      iconBorder: AppColors.cercaBorder,
      icon: const GoogleGlyph(),
    );
  }

  Future<void> _signIn(BuildContext context, WidgetRef ref) async {
    if (ref.read(authControllerProvider).isLoading) return;

    final controller = ref.read(authControllerProvider.notifier);
    await controller.signInWithGoogle(role: role);
    if (!context.mounted) return;

    var result = ref.read(authControllerProvider);
    final error = result.error;

    // The account is new and nobody has said which half of the app it
    // belongs to. Ask, then make the one extra attempt.
    if (error is ApiException && error.isRoleRequired) {
      final chosen = await _askForRole(context);
      if (chosen == null || !context.mounted) return;

      await controller.signInWithGoogle(role: chosen);
      if (!context.mounted) return;
      result = ref.read(authControllerProvider);
    }

    result.whenOrNull(
      data: (session) {
        if (session != null) context.go(RoutePaths.welcome);
      },
      error: (error, _) {
        final message =
            error is ApiException ? error.message : 'No se pudo ingresar con Google.';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      },
    );
  }

  Future<String?> _askForRole(BuildContext context) {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '¿Cómo usarás Cerca?',
                textAlign: TextAlign.center,
                style: CercaText.lora(fontSize: 21),
              ),
              const SizedBox(height: 8),
              Text(
                'Lo preguntamos una sola vez, al crear tu cuenta.',
                textAlign: TextAlign.center,
                style: CercaText.sora(fontSize: 14, color: AppColors.cercaTextSecondary),
              ),
              const SizedBox(height: 18),
              _RoleChoice(
                label: 'Soy Cliente',
                description: 'Busco técnicos cerca de mí',
                onTap: () => Navigator.of(sheetContext).pop('client'),
              ),
              const SizedBox(height: 10),
              _RoleChoice(
                label: 'Soy Técnico',
                description: 'Ofrezco mis servicios',
                onTap: () => Navigator.of(sheetContext).pop('technician'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleChoice extends StatelessWidget {
  const _RoleChoice({required this.label, required this.description, required this.onTap});

  final String label;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.cercaBorder),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: CercaText.sora(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 3),
            Text(
              description,
              style: CercaText.sora(fontSize: 13.5, color: AppColors.cercaTextSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

/// Google's "G", drawn as text so the app carries no brand asset.
class GoogleGlyph extends StatelessWidget {
  const GoogleGlyph({super.key});

  @override
  Widget build(BuildContext context) {
    return const Text(
      'G',
      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFF4285F4)),
    );
  }
}
