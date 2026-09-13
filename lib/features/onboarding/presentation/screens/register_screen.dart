import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/router/route_paths.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/application/auth_controller.dart';
import '../../../cerca/presentation/widgets/back_circle_button.dart';
import '../../../cerca/presentation/widgets/cerca_logo_mark.dart';
import '../../../cerca/presentation/widgets/cerca_text_styles.dart';
import '../widgets/google_sign_in_button.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String _role = 'client';

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _doRegister(bool isLoading) async {
    if (isLoading) return;
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completa tu nombre, correo y contraseña.')),
      );
      return;
    }

    await ref.read(authControllerProvider.notifier).register(
          email: email,
          password: password,
          name: name,
          role: _role,
        );
    if (!mounted) return;

    ref.read(authControllerProvider).whenOrNull(
      data: (session) {
        if (session != null) context.go(RoutePaths.welcome);
      },
      error: (error, _) {
        final message = error is ApiException ? error.message : 'No se pudo crear la cuenta.';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authControllerProvider).isLoading;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.cercaBackground, AppColors.cercaSurfaceTint],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 6),
                child: Row(
                  children: [
                    BackCircleButton(onTap: () => context.go(RoutePaths.login)),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  child: Column(
                    children: [
                      const CercaLogoMark(size: 44),
                      const SizedBox(height: 14),
                      Text('Crea tu cuenta', style: CercaText.lora(fontSize: 24)),
                      const SizedBox(height: 8),
                      Text(
                        'Cuéntanos quién eres',
                        style: CercaText.sora(fontSize: 15, color: AppColors.cercaTextSecondary),
                      ),
                      const SizedBox(height: 20),
                      _RoleToggle(
                        role: _role,
                        onChanged: (role) => setState(() => _role = role),
                      ),
                      const SizedBox(height: 16),
                      _RegisterField(controller: _nameController, hint: 'Tu nombre'),
                      const SizedBox(height: 10),
                      _RegisterField(controller: _emailController, hint: 'Correo electrónico', keyboardType: TextInputType.emailAddress),
                      const SizedBox(height: 10),
                      _RegisterField(controller: _passwordController, hint: 'Contraseña (mín. 8 caracteres)', obscureText: true),
                      const SizedBox(height: 16),
                      InkWell(
                        onTap: () => _doRegister(isLoading),
                        borderRadius: BorderRadius.circular(18),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.cercaPrimary,
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(color: AppColors.cercaPrimary.withValues(alpha: 0.32), blurRadius: 28, offset: const Offset(0, 12)),
                            ],
                          ),
                          child: isLoading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                                )
                              : Text(
                                  'Crear cuenta',
                                  style: CercaText.sora(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white),
                                ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(child: Divider(color: AppColors.cercaBorder)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: Text('o continúa con', style: CercaText.sora(fontSize: 12.5, color: AppColors.cercaTextMuted)),
                          ),
                          Expanded(child: Divider(color: AppColors.cercaBorder)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      GoogleSignInButton(role: _role),
                      const SizedBox(height: 24),
                      InkWell(
                        onTap: () => context.go(RoutePaths.login),
                        child: Text(
                          '¿Ya tienes cuenta? Inicia sesión',
                          style: CercaText.sora(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.cercaPrimary),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RegisterField extends StatelessWidget {
  const _RegisterField({
    required this.controller,
    required this.hint,
    this.keyboardType,
    this.obscureText = false,
  });

  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;
  final bool obscureText;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      style: CercaText.sora(fontSize: 15, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: CercaText.sora(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.cercaTextMuted),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 15, horizontal: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.cercaBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.cercaBorder),
        ),
      ),
    );
  }
}

class _RoleToggle extends StatelessWidget {
  const _RoleToggle({required this.role, required this.onChanged});

  final String role;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.cercaBorder),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(child: _RoleOption(label: 'Soy Cliente', selected: role == 'client', onTap: () => onChanged('client'))),
          Expanded(child: _RoleOption(label: 'Soy Técnico', selected: role == 'technician', onTap: () => onChanged('technician'))),
        ],
      ),
    );
  }
}

class _RoleOption extends StatelessWidget {
  const _RoleOption({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(11),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.cercaPrimary : Colors.transparent,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Text(
          label,
          style: CercaText.sora(fontSize: 13.5, fontWeight: FontWeight.w700, color: selected ? Colors.white : AppColors.cercaTextSecondary),
        ),
      ),
    );
  }
}
