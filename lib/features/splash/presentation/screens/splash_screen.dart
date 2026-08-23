import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/services/api_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  static const _brandBlue = Color(0xFF008BD2);

  late final AnimationController _entranceController;
  late final AnimationController _ambientController;
  late final Animation<double> _logoEntrance;
  late final Animation<double> _nameEntrance;
  late final Animation<double> _detailsEntrance;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2100),
    );
    _logoEntrance = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0, 0.42, curve: Curves.easeOutCubic),
    );
    _nameEntrance = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.21, 0.64, curve: Curves.easeOutCubic),
    );
    _detailsEntrance = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.5, 1, curve: Curves.easeOutCubic),
    );
    _entranceController.forward();
    _ambientController.repeat();
    _navigateToNext();
  }

  Future<void> _navigateToNext() async {
    final minimumDisplay = Future<void>.delayed(
      const Duration(milliseconds: 1600),
    );
    await Future.wait<void>([ApiService.initializeSession(), minimumDisplay]);
    if (!mounted) return;
    context.go(ApiService.isAuthenticated ? AppRouter.wallet : AppRouter.login);
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _ambientController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: const Color(0xFF0A0F1E),
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0F1E),
        body: Stack(
          fit: StackFit.expand,
          children: [
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF0A0F1E),
                    Color(0xFF0F172A),
                    Color(0xFF1A2744),
                  ],
                  stops: [0, 0.54, 1],
                ),
              ),
            ),
            const Positioned(
              top: -105,
              right: -110,
              child: _AmbientOrb(size: 310, color: Color(0x334F46E5)),
            ),
            const Positioned(
              bottom: -135,
              left: -125,
              child: _AmbientOrb(size: 330, color: Color(0x1F6366F1)),
            ),
            SafeArea(
              child: Center(
                child: Semantics(
                  container: true,
                  label: 'C-Walli. Đang khởi động.',
                  child: ExcludeSemantics(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 290,
                          height: 230,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              if (!reduceMotion)
                                AnimatedBuilder(
                                  animation: _ambientController,
                                  builder: (context, child) => CustomPaint(
                                    size: const Size.square(230),
                                    painter: _GlowRingsPainter(
                                      progress: _ambientController.value,
                                      color: _brandBlue,
                                    ),
                                  ),
                                ),
                              _EntranceTransition(
                                animation: _logoEntrance,
                                reduceMotion: reduceMotion,
                                offset: 14,
                                child: Image.asset(
                                  'assets/images/cmc_logo.png',
                                  width: 118,
                                  fit: BoxFit.contain,
                                  filterQuality: FilterQuality.high,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Transform.translate(
                          offset: const Offset(0, -43),
                          child: Column(
                            children: [
                              _EntranceTransition(
                                animation: _nameEntrance,
                                reduceMotion: reduceMotion,
                                offset: 12,
                                child: Text(
                                  'C-Walli',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 34,
                                    height: 1,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -1.02,
                                    color: _brandBlue,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 40),
                              _EntranceTransition(
                                animation: _detailsEntrance,
                                reduceMotion: reduceMotion,
                                offset: 10,
                                child: _LoadingDots(
                                  animation: _ambientController,
                                  reduceMotion: reduceMotion,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EntranceTransition extends StatelessWidget {
  final Animation<double> animation;
  final bool reduceMotion;
  final double offset;
  final Widget child;

  const _EntranceTransition({
    required this.animation,
    required this.reduceMotion,
    required this.offset,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (reduceMotion) return child;
    return FadeTransition(
      opacity: animation,
      child: AnimatedBuilder(
        animation: animation,
        child: child,
        builder: (context, child) => Transform.translate(
          offset: Offset(0, offset * (1 - animation.value)),
          child: child,
        ),
      ),
    );
  }
}

class _AmbientOrb extends StatelessWidget {
  final double size;
  final Color color;

  const _AmbientOrb({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
        ),
      ),
    );
  }
}

class _LoadingDots extends StatelessWidget {
  final Animation<double> animation;
  final bool reduceMotion;

  const _LoadingDots({required this.animation, required this.reduceMotion});

  @override
  Widget build(BuildContext context) {
    if (reduceMotion) {
      return const _StaticDots();
    }
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            final wave = math.sin(
              (animation.value * math.pi * 2) - (index * 0.8),
            );
            final strength = (wave + 1) / 2;
            return Container(
              width: 7,
              height: 7,
              margin: const EdgeInsets.symmetric(horizontal: 5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _SplashScreenState._brandBlue.withValues(
                  alpha: 0.34 + (strength * 0.66),
                ),
                boxShadow: [
                  BoxShadow(
                    color: _SplashScreenState._brandBlue.withValues(
                      alpha: strength * 0.28,
                    ),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
            );
          }),
        );
      },
    );
  }
}

class _StaticDots extends StatelessWidget {
  const _StaticDots();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        3,
        (_) => Container(
          width: 7,
          height: 7,
          margin: const EdgeInsets.symmetric(horizontal: 5),
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: _SplashScreenState._brandBlue,
          ),
        ),
      ),
    );
  }
}

class _GlowRingsPainter extends CustomPainter {
  final double progress;
  final Color color;

  const _GlowRingsPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    for (var index = 0; index < 3; index++) {
      final phase = (progress + (index / 3)) % 1;
      final radius = 53 + (phase * 54);
      final opacity = (1 - phase) * 0.22;
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = color.withValues(alpha: opacity),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GlowRingsPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
