import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/landing_route.dart';
import '../../../../core/router/route_paths.dart';
import '../../../auth/application/auth_controller.dart';
import '../../../auth/domain/auth_session.dart';
import '../../../cerca/presentation/widgets/cerca_logo_mark.dart';
import '../../../cerca/presentation/widgets/cerca_text_styles.dart';

/// Short Cerca brand intro. It advances once the ~2-second presentation
/// finishes AND
/// the stored session (if any) has been restored — whichever comes
/// last — landing on the signed-in person's hub (see [landingRouteFor])
/// or `/login` (signed out).
///
/// The first frame deliberately matches the native launch splash (flat
/// background, 98dp mark dead-center) so the hand-off from Android is
/// invisible; the intro then lifts the mark and fades the title in below.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> with TickerProviderStateMixin {
  static const _logoSize = 98.0;
  static const _logoLift = 44.0;
  static const _launchBackground = Color(0xFF241417);

  bool _navigated = false;

  late final AnimationController _intro;
  late final AnimationController _breathe;
  late final Animation<double> _lift;
  late final Animation<double> _glow;
  late final Animation<double> _title;
  late final Animation<double> _tagline;
  late final Animation<double> _breatheScale;
  final List<Timer> _timers = [];

  @override
  void initState() {
    super.initState();
    _intro = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) _breathe.repeat(reverse: true);
      });
    _breathe = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));

    _lift = CurvedAnimation(parent: _intro, curve: const Interval(0.0, 0.55, curve: Curves.easeOutCubic));
    _glow = CurvedAnimation(parent: _intro, curve: const Interval(0.0, 0.6, curve: Curves.easeOut));
    _title = CurvedAnimation(parent: _intro, curve: const Interval(0.25, 0.7, curve: Curves.easeOutCubic));
    _tagline = CurvedAnimation(parent: _intro, curve: const Interval(0.4, 0.85, curve: Curves.easeOutCubic));
    _breatheScale = Tween(begin: 1.0, end: 1.04).animate(CurvedAnimation(parent: _breathe, curve: Curves.easeInOut));

    // Android keeps its own launch splash on top until Flutter's first
    // frame reaches the screen and then fades it out, which on a cold start
    // can take well over a second. Starting on a fixed timer would play the
    // intro hidden behind it, so wait for the first rasterized frame (with a
    // fallback in case it's never reported, e.g. under flutter_test).
    Future.any([
      WidgetsBinding.instance.waitUntilFirstFrameRasterized,
      Future<void>.delayed(const Duration(milliseconds: 1000)),
    ]).then((_) {
      if (!mounted || _animationDone) return;
      _schedule(_nativeExitMs, _intro.forward);
      _schedule(_nativeExitMs + _presentationMs, _finishAnimation);
    });
  }

  /// Time the Android launch splash takes to fade out after the hand-off.
  static const _nativeExitMs = 250;

  /// How long the intro stays on screen once it starts playing.
  static const _presentationMs = 1800;
  void _schedule(int milliseconds, VoidCallback callback) {
    _timers.add(Timer(Duration(milliseconds: milliseconds), callback));
  }

  bool _animationDone = false;

  Future<void> _finishAnimation() async {
    _animationDone = true;
    final session = await ref.read(authControllerProvider.future);
    await _navigate(session);
  }

  Future<void> _navigate(AuthSession? session) async {
    if (_navigated || !mounted) return;
    _navigated = true;
    for (final timer in _timers) {
      timer.cancel();
    }
    final target = session == null ? RoutePaths.login : await landingRouteFor(ref, session.user);
    if (mounted) context.go(target);
  }

  Future<void> _goLogin() async {
    // Manual tap-to-skip: still waits for session restore so we route to
    // the right place instead of always bouncing to /login.
    if (!_animationDone) {
      for (final timer in _timers) {
        timer.cancel();
      }
      _animationDone = true;
    }
    final authState = ref.read(authControllerProvider);
    if (authState.isLoading) {
      await _navigate(await ref.read(authControllerProvider.future));
    } else {
      await _navigate(authState.value);
    }
  }

  @override
  void dispose() {
    for (final timer in _timers) {
      timer.cancel();
    }
    _intro.dispose();
    _breathe.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _goLogin,
      child: Scaffold(
        backgroundColor: _launchBackground,
        body: AnimatedBuilder(
          animation: _intro,
          builder: (context, _) => LayoutBuilder(
            builder: (context, constraints) {
              final centerY = constraints.maxHeight / 2;
              final lift = _logoLift * _lift.value;
              return Stack(
                children: [
                  Positioned.fill(
                    child: Opacity(
                      opacity: _glow.value,
                      child: const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            center: Alignment(0, -0.4),
                            radius: 1.1,
                            colors: [Color(0xFF241417), Color(0xFF150D0E), Color(0xFF0E0A09)],
                            stops: [0.0, 0.55, 1.0],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: centerY - _logoSize / 2 - lift,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: ScaleTransition(
                        scale: _breatheScale,
                        child: const CercaLogoMark(
                          size: _logoSize,
                          lightStroke: Color(0xFFD1717C),
                          accent: Color(0xFFE4939C),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: centerY + _logoSize / 2 - lift + 14,
                    left: 0,
                    right: 0,
                    child: Column(
                      children: [
                        _Reveal(
                          progress: _title.value,
                          child: Text('Cerca', style: CercaText.lora(fontSize: 30, color: const Color(0xFFF3ECE7))),
                        ),
                        const SizedBox(height: 6),
                        _Reveal(
                          progress: _tagline.value,
                          child: Text(
                            'Técnicos verificados, cerca de ti',
                            style: CercaText.sora(fontSize: 14, fontWeight: FontWeight.w500, color: const Color(0xFFB7A9A3)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Fades a line in while it rises the last few pixels into place.
class _Reveal extends StatelessWidget {
  const _Reveal({required this.progress, required this.child});

  final double progress;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: progress,
      child: Transform.translate(offset: Offset(0, 10 * (1 - progress)), child: child),
    );
  }
}
