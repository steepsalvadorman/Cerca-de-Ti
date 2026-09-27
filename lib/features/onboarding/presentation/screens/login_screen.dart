import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/router/landing_route.dart';
import '../../../../core/router/route_paths.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/application/auth_controller.dart';
import '../../../auth/domain/auth_user.dart';
import '../../../cerca/presentation/widgets/cerca_logo_mark.dart';
import '../../../cerca/presentation/widgets/cerca_text_styles.dart';
import '../widgets/google_sign_in_button.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _goToLanding(AuthUser user) async {
    final target = await landingRouteFor(ref, user);
    if (mounted) context.go(target);
  }

  Future<void> _doLogin(bool isLoading) async {
    if (isLoading) return;
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa tu correo y contraseña.')),
      );
      return;
    }

    await ref
        .read(authControllerProvider.notifier)
        .login(email: email, password: password);
    if (!mounted) return;

    final result = ref.read(authControllerProvider);
    result.whenOrNull(
      data: (session) {
        if (session != null) _goToLanding(session.user);
      },
      error: (error, _) {
        final message = error is ApiException
            ? error.message
            : 'No se pudo iniciar sesión.';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final isLoading = authState.isLoading;
    // With the keyboard up the form gets only the space above it; the
    // legal line and the register link would squeeze "Ingresar" out of view.
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;

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
          child: Padding(
            padding: const EdgeInsets.fromLTRB(26, 12, 26, 26),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CercaLogoMark(size: 17),
                    const SizedBox(width: 8),
                    Text(
                      'Cerca',
                      style: CercaText.lora(
                        fontSize: 17,
                        color: AppColors.cercaPrimary,
                      ),
                    ),
                  ],
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) => SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight,
                        ),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _LoginMark(animating: isLoading),
                              const SizedBox(height: 22),
                              if (isLoading)
                                Text(
                                  'Ingresando…',
                                  style: CercaText.sora(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.cercaPrimary,
                                  ),
                                )
                              else ...[
                                Text(
                                  'Bienvenido de vuelta',
                                  style: CercaText.lora(fontSize: 29),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'Técnicos verificados,\na un toque de tu puerta.',
                                  textAlign: TextAlign.center,
                                  style: CercaText.sora(
                                    fontSize: 16.5,
                                    fontWeight: FontWeight.w500,
                                    color: const Color(0xFF5A4E49),
                                    height: 1.6,
                                  ),
                                ),
                                const SizedBox(height: 22),
                                SizedBox(
                                  width: double.infinity,
                                  child: Column(
                                    children: [
                                      TextField(
                                        controller: _emailController,
                                        textAlign: TextAlign.center,
                                        keyboardType:
                                            TextInputType.emailAddress,
                                        style: CercaText.sora(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        decoration: InputDecoration(
                                          hintText: 'Correo electrónico',
                                          hintStyle: CercaText.sora(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.cercaTextMuted,
                                          ),
                                          filled: true,
                                          fillColor: Colors.white,
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                vertical: 17,
                                                horizontal: 16,
                                              ),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              18,
                                            ),
                                            borderSide: const BorderSide(
                                              color: AppColors.cercaBorder,
                                            ),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              18,
                                            ),
                                            borderSide: const BorderSide(
                                              color: AppColors.cercaBorder,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      TextField(
                                        controller: _passwordController,
                                        textAlign: TextAlign.center,
                                        obscureText: true,
                                        style: CercaText.sora(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        decoration: InputDecoration(
                                          hintText: 'Contraseña',
                                          hintStyle: CercaText.sora(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.cercaTextMuted,
                                          ),
                                          filled: true,
                                          fillColor: Colors.white,
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                vertical: 17,
                                                horizontal: 16,
                                              ),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              18,
                                            ),
                                            borderSide: const BorderSide(
                                              color: AppColors.cercaBorder,
                                            ),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              18,
                                            ),
                                            borderSide: const BorderSide(
                                              color: AppColors.cercaBorder,
                                            ),
                                          ),
                                        ),
                                        onSubmitted: (_) => _doLogin(isLoading),
                                      ),
                                      const SizedBox(height: 16),
                                      InkWell(
                                        onTap: () => _doLogin(isLoading),
                                        borderRadius: BorderRadius.circular(18),
                                        child: Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.all(22),
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                            color: AppColors.cercaPrimary,
                                            borderRadius: BorderRadius.circular(
                                              18,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: AppColors.cercaPrimary
                                                    .withValues(alpha: 0.32),
                                                blurRadius: 28,
                                                offset: const Offset(0, 12),
                                              ),
                                            ],
                                          ),
                                          child: Text(
                                            'Ingresar',
                                            style: CercaText.sora(
                                              fontSize: 19,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                      // Wide enough to clear the
                                      // 28px glow under "Ingresar",
                                      // which otherwise washes out the
                                      // divider rules.
                                      const SizedBox(height: 30),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Divider(
                                              color: AppColors.cercaBorder,
                                            ),
                                          ),
                                          Padding(
                                            padding:
                                                const EdgeInsets.symmetric(
                                                  horizontal: 10,
                                                ),
                                            child: Text(
                                              'o continúa con',
                                              style: CercaText.sora(
                                                fontSize: 12.5,
                                                color: AppColors.cercaTextMuted,
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            child: Divider(
                                              color: AppColors.cercaBorder,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 14),
                                      // No role here: someone signing in
                                      // already has one, and a first-time
                                      // account gets asked by the button.
                                      const GoogleSignInButton(),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (!keyboardOpen) ...[
                  Text(
                    'Al continuar aceptas nuestros términos y el uso de tu ubicación para mostrarte técnicos cercanos.',
                    textAlign: TextAlign.center,
                    style: CercaText.sora(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: AppColors.cercaTextMuted,
                      height: 1.5,
                    ),
                  ),
                  InkWell(
                    onTap: () => context.push(RoutePaths.register),
                    child: Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: Text(
                        '¿Eres nuevo? Crea tu cuenta',
                        style: CercaText.sora(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.cercaPrimary,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LoginMark extends StatefulWidget {
  const _LoginMark({required this.animating});

  final bool animating;

  @override
  State<_LoginMark> createState() => _LoginMarkState();
}

class _LoginMarkState extends State<_LoginMark> with TickerProviderStateMixin {
  late final AnimationController _rotate;
  late final AnimationController _breathe;
  late final AnimationController _ring;
  late final AnimationController _pop;

  @override
  void initState() {
    super.initState();
    _rotate = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
    _breathe = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
      lowerBound: 1.0,
      upperBound: 1.05,
    )..repeat(reverse: true);
    _ring = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _pop = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    if (widget.animating) {
      _ring.repeat();
      _pop.forward();
    }
  }

  @override
  void didUpdateWidget(_LoginMark oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animating && !oldWidget.animating) {
      _pop.forward(from: 0);
      _ring.repeat();
    } else if (!widget.animating && oldWidget.animating) {
      _ring.stop();
      _pop.reset();
    }
  }

  @override
  void dispose() {
    _rotate.dispose();
    _breathe.dispose();
    _ring.dispose();
    _pop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 118,
      height: 118,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _rotate,
            builder: (context, _) => Transform.rotate(
              angle: math.pi / 4 + _rotate.value * 2 * math.pi,
              child: Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: AppColors.cercaPrimary.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(19.2),
                ),
              ),
            ),
          ),
          if (widget.animating)
            AnimatedBuilder(
              animation: _ring,
              builder: (context, _) => Stack(
                alignment: Alignment.center,
                children: [
                  _ringLayer(_ring.value),
                  _ringLayer((_ring.value + 0.318) % 1.0),
                ],
              ),
            ),
          if (widget.animating)
            ScaleTransition(
              scale: CurvedAnimation(parent: _pop, curve: Curves.easeOut),
              child: Transform.rotate(
                angle: math.pi / 4,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF8A2C37), Color(0xFF6B1F28)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.cercaPrimary.withValues(alpha: 0.35),
                        blurRadius: 30,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (widget.animating)
            FadeTransition(
              opacity: CurvedAnimation(
                parent: _pop,
                curve: const Interval(0.4, 1.0),
              ),
              child: const Icon(Icons.check, color: Colors.white, size: 40),
            ),
          if (!widget.animating)
            AnimatedBuilder(
              animation: _breathe,
              builder: (context, child) =>
                  Transform.scale(scale: _breathe.value, child: child),
              child: const CercaLogoMark(size: 84),
            ),
        ],
      ),
    );
  }

  Widget _ringLayer(double t) {
    return Opacity(
      opacity: (0.55 * (1 - t)).clamp(0, 1),
      child: Transform.rotate(
        angle: math.pi / 4,
        child: Transform.scale(
          scale: 0.9 + t * 1.0,
          child: Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.cercaPrimary, width: 2),
              borderRadius: BorderRadius.circular(19.2),
            ),
          ),
        ),
      ),
    );
  }
}
