import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/route_paths.dart';
import '../../../auth/application/auth_controller.dart';
import '../../../cerca/presentation/widgets/cerca_logo_mark.dart';
import '../../../cerca/presentation/widgets/cerca_text_styles.dart';

/// Short Cerca brand intro. It advances once the 2.2-second presentation
/// finishes AND
/// the stored session (if any) has been restored — whichever comes
/// last — landing on `/welcome` (signed in) or `/login` (signed out).
/// Matches the source design's staggered CSS keyframe timings,
/// reimplemented as a short Timer sequence driving Flutter's implicit
/// animations.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> with SingleTickerProviderStateMixin {
  bool _showTitle = false;
  bool _showTagline = false;
  bool _navigated = false;

  late final AnimationController _breathe;
  final List<Timer> _timers = [];

  @override
  void initState() {
    super.initState();
    _breathe = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
      lowerBound: 1.0,
      upperBound: 1.05,
    );

    _schedule(200, () => setState(() => _showTitle = true));
    _schedule(450, () => setState(() => _showTagline = true));
    _schedule(650, () => _breathe.repeat(reverse: true));
    _schedule(2200, _finishAnimation);
  }

  void _schedule(int milliseconds, VoidCallback callback) {
    _timers.add(Timer(Duration(milliseconds: milliseconds), callback));
  }

  bool _animationDone = false;

  Future<void> _finishAnimation() async {
    _animationDone = true;
    final session = await ref.read(authControllerProvider.future);
    _navigate(session != null);
  }

  void _navigate(bool signedIn) {
    if (_navigated || !mounted) return;
    _navigated = true;
    for (final timer in _timers) {
      timer.cancel();
    }
    context.go(signedIn ? RoutePaths.welcome : RoutePaths.login);
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
    final session = authState.value;
    if (authState.isLoading) {
      final resolved = await ref.read(authControllerProvider.future);
      _navigate(resolved != null);
    } else {
      _navigate(session != null);
    }
  }

  @override
  void dispose() {
    for (final timer in _timers) {
      timer.cancel();
    }
    _breathe.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _goLogin,
      child: Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, -0.4),
              radius: 1.1,
              colors: [Color(0xFF241417), Color(0xFF150D0E), Color(0xFF0E0A09)],
              stops: [0.0, 0.55, 1.0],
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 130,
                    height: 130,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        AnimatedBuilder(
                          animation: _breathe,
                          builder: (context, child) => Transform.scale(scale: _breathe.value, child: child),
                          child: const CercaLogoMark(
                            size: 98,
                            lightStroke: Color(0xFFD1717C),
                            accent: Color(0xFFE4939C),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  AnimatedOpacity(
                    opacity: _showTitle ? 1 : 0,
                    duration: const Duration(milliseconds: 600),
                    child: Text('Cerca', style: CercaText.lora(fontSize: 30, color: const Color(0xFFF3ECE7))),
                  ),
                  const SizedBox(height: 6),
                  AnimatedOpacity(
                    opacity: _showTagline ? 1 : 0,
                    duration: const Duration(milliseconds: 600),
                    child: Text(
                      'Técnicos verificados, cerca de ti',
                      style: CercaText.sora(fontSize: 14, fontWeight: FontWeight.w500, color: const Color(0xFFB7A9A3)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
