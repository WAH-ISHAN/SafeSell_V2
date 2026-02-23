import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../security/screen_protection_service.dart';
import '../../models/app_settings.dart';
import '../../services/permission_service.dart';
import '../../ui/widgets/premium_ui.dart';
import '../../app/theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late final AnimationController _introC;
  late final Animation<double> _logoIn;
  late final Animation<double> _logoFade;

  late final AnimationController _ringC;
  late final Animation<double> _ringRot;

  late final AnimationController _blobC;

  late final AnimationController _dotsC;

  @override
  void initState() {
    super.initState();

    // Intro (scale + fade)
    _introC = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _logoIn = CurvedAnimation(parent: _introC, curve: Curves.easeOutCubic);
    _logoFade = CurvedAnimation(parent: _introC, curve: const Interval(0.0, 1.0, curve: Curves.easeOut));
    _introC.forward();

    // Rotating ring
    _ringC = AnimationController(vsync: this, duration: const Duration(seconds: 10))..repeat();
    _ringRot = CurvedAnimation(parent: _ringC, curve: Curves.linear);

    // Blobs drift/pulse
    _blobC = AnimationController(vsync: this, duration: const Duration(milliseconds: 5200))
      ..repeat(reverse: true);

    // Loading dots
    _dotsC = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat();

    _navigate();
  }

  Future<void> _navigate() async {
    // Apply screen protection early
    try {
      final box = Hive.box<AppSettings>('app_settings_typed');
      final settings = box.get('settings') ?? AppSettings();

      if (settings.screenProtectionEnabled) {
        await ScreenProtectionService().enable();
      }

      if (settings.stealthEnabled) {
        await Future.delayed(const Duration(milliseconds: 2200));
        if (!mounted) return;
        context.go('/calculator');
        return;
      }
    } catch (_) {
      // ignore and continue
    }

    // Non-blocking permissions
    PermissionService().requestMediaPermissions().ignore();

    await Future.delayed(const Duration(milliseconds: 2500));
    if (!mounted) return;

    context.go('/login');
  }

  @override
  void dispose() {
    _introC.dispose();
    _ringC.dispose();
    _blobC.dispose();
    _dotsC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background (same PremiumBackground base)
          const PremiumBackground(child: SizedBox.shrink()),

          // Extra premium layers like Figma/React splash
          Positioned.fill(
            child: IgnorePointer(
              child: Stack(
                children: [
                  // vignette
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: Alignment.center,
                          radius: 1.0,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.55),
                          ],
                          stops: const [0.45, 1.0],
                        ),
                      ),
                    ),
                  ),
                  // subtle grid
                  Positioned.fill(
                    child: Opacity(
                      opacity: 0.06,
                      child: CustomPaint(painter: _GridPainter(step: 26)),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Animated blobs (top-right + bottom-left)
          AnimatedBuilder(
            animation: _blobC,
            builder: (_, __) {
              final t = _blobC.value; // 0..1..0
              final s1 = 1.0 + (0.18 * t);
              final o1 = 0.22 + (0.20 * t);

              final s2 = 1.0 + (0.26 * t);
              final o2 = 0.18 + (0.18 * t);

              return IgnorePointer(
                child: Stack(
                  children: [
                    Positioned(
                      top: 64,
                      right: 24,
                      child: Transform.scale(
                        scale: s1,
                        child: Opacity(
                          opacity: o1,
                          child: Container(
                            width: 260,
                            height: 260,
                            decoration: BoxDecoration(
                              color: const Color(0xFF4DA3FF),
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 96,
                      left: 24,
                      child: Transform.scale(
                        scale: s2,
                        child: Opacity(
                          opacity: o2,
                          child: Container(
                            width: 290,
                            height: 290,
                            decoration: BoxDecoration(
                              color: const Color(0xFF0A2A4F),
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Blur effect approximation (use BackdropFilter-free: soft edges)
                    Positioned.fill(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 110, sigmaY: 110),
                        child: const SizedBox.shrink(),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          // Center content
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Logo stack (ring + glow + gradient card)
                    AnimatedBuilder(
                      animation: Listenable.merge([_introC, _ringC]),
                      builder: (_, __) {
                        final inT = _logoIn.value;
                        final fade = _logoFade.value;
                        final scale = 0.86 + (0.14 * inT);

                        return Opacity(
                          opacity: fade,
                          child: Transform.translate(
                            offset: Offset(0, 10 * (1 - inT)),
                            child: Transform.scale(
                              scale: scale,
                              child: SizedBox(
                                width: 140,
                                height: 140,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    // rotating ring
                                    Transform.rotate(
                                      angle: _ringRot.value * 2 * math.pi,
                                      child: Container(
                                        width: 140,
                                        height: 140,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(44),
                                          border: Border.all(
                                            color: Colors.white.withOpacity(0.10),
                                            width: 1,
                                          ),
                                        ),
                                      ),
                                    ),

                                    // pulsing glow
                                    AnimatedBuilder(
                                      animation: _dotsC, // reuse ticking
                                      builder: (_, __) {
                                        final p = (math.sin(_dotsC.value * 2 * math.pi) + 1) / 2;
                                        final glowScale = 1.0 + (0.10 * p);
                                        final glowOpacity = 0.35 + (0.20 * p);
                                        return Transform.scale(
                                          scale: glowScale,
                                          child: Opacity(
                                            opacity: glowOpacity,
                                            child: Container(
                                              width: 112,
                                              height: 112,
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF4DA3FF).withOpacity(0.30),
                                                borderRadius: BorderRadius.circular(34),
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),

                                    // logo card
                                    Container(
                                      width: 112,
                                      height: 112,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(30),
                                        gradient: const LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [Color(0xFF4DA3FF), Color(0xFF2B7FDB)],
                                        ),
                                        border: Border.all(color: Colors.white.withOpacity(0.10)),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFF4DA3FF).withOpacity(0.55),
                                            blurRadius: 60,
                                          ),
                                          BoxShadow(
                                            color: const Color(0xFF4DA3FF).withOpacity(0.22),
                                            blurRadius: 110,
                                          ),
                                        ],
                                      ),
                                      child: Stack(
                                        children: [
                                          // shimmer
                                          AnimatedBuilder(
                                            animation: _dotsC,
                                            builder: (_, __) {
                                              final x = (-1.2 + (2.4 * _dotsC.value));
                                              return Transform.translate(
                                                offset: Offset(112 * x, 0),
                                                child: Opacity(
                                                  opacity: 0.30,
                                                  child: Container(
                                                    width: 112,
                                                    height: 112,
                                                    decoration: const BoxDecoration(
                                                      gradient: LinearGradient(
                                                        begin: Alignment.topLeft,
                                                        end: Alignment.bottomRight,
                                                        stops: [0.0, 0.35, 0.70],
                                                        colors: [
                                                          Colors.transparent,
                                                          Color(0x59FFFFFF),
                                                          Colors.transparent,
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                          const Center(
                                            child: Icon(
                                              Icons.shield_rounded,
                                              color: Colors.white,
                                              size: 56,
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
                        );
                      },
                    ),

                    const SizedBox(height: 28),

                    // Title + subtitle
                    AnimatedBuilder(
                      animation: _introC,
                      builder: (_, __) {
                        final t = _introC.value;
                        return Opacity(
                          opacity: t,
                          child: Transform.translate(
                            offset: Offset(0, 18 * (1 - t)),
                            child: Column(
                              children: const [
                                Text(
                                  'SafeShell',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 32,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.4,
                                  ),
                                ),
                                SizedBox(height: 6),
                                Text(
                                  'Private vault. Stealth mode.',
                                  style: TextStyle(
                                    color: SafeShellTheme.textSecondary,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 34),

                    // Loading dots + label
                    AnimatedBuilder(
                      animation: _dotsC,
                      builder: (_, __) {
                        return Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(3, (i) {
                                final phase = (_dotsC.value + i * 0.18) % 1.0;
                                final pulse = (math.sin(phase * 2 * math.pi) + 1) / 2;
                                final s = 1.0 + (0.35 * pulse);
                                final o = 0.25 + (0.75 * pulse);

                                return Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 6),
                                  child: Transform.scale(
                                    scale: s,
                                    child: Opacity(
                                      opacity: o,
                                      child: Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF4DA3FF),
                                          borderRadius: BorderRadius.circular(99),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Securing session…',
                              style: TextStyle(
                                color: const Color(0xFFEAF2FF).withOpacity(0.40),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Simple grid painter (for the subtle background grid)
class _GridPainter extends CustomPainter {
  final double step;
  const _GridPainter({required this.step});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0xFFEAF2FF).withOpacity(0.14);

    for (double x = 0; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
    for (double y = 0; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) => oldDelegate.step != step;
}