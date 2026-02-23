import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../widgets/premium_ui.dart';

class PaymentSuccessScreen extends StatefulWidget {
  const PaymentSuccessScreen({super.key});

  @override
  State<PaymentSuccessScreen> createState() => _PaymentSuccessScreenState();
}

class _PaymentSuccessScreenState extends State<PaymentSuccessScreen>
    with TickerProviderStateMixin {
  late final AnimationController _pulseC;
  late final AnimationController _confettiC;

  late final List<_ConfettiParticle> _particles;

  @override
  void initState() {
    super.initState();

    _pulseC = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _confettiC = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _particles = _ConfettiParticle.generate(
      count: 30,
      rng: math.Random(),
    );
  }

  @override
  void dispose() {
    _pulseC.dispose();
    _confettiC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PremiumBackground(
        child: Stack(
          children: [
            // Confetti layer
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _confettiC,
                  builder: (_, __) {
                    return CustomPaint(
                      painter: _ConfettiPainter(
                        t: _confettiC.value,
                        particles: _particles,
                      ),
                    );
                  },
                ),
              ),
            ),

            SafeArea(
              child: Column(
                children: [
                  // Header (simple app bar feel)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 12, 0),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back,
                              color: SafeShellTheme.textPrimary),
                          onPressed: () => context.go('/dashboard'),
                        ),
                        const SizedBox(width: 4),
                        const Expanded(
                          child: Text(
                            'Payment Successful',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 420),
                          child: Column(
                            children: [
                              const SizedBox(height: 10),

                              // Success Icon (scale-in + pulsing glow)
                              TweenAnimationBuilder<double>(
                                tween: Tween(begin: 0.0, end: 1.0),
                                duration: const Duration(milliseconds: 650),
                                curve: Curves.elasticOut,
                                builder: (_, v, child) {
                                  return Transform.scale(
                                    scale: v,
                                    child: child,
                                  );
                                },
                                child: AnimatedBuilder(
                                  animation: _pulseC,
                                  builder: (_, __) {
                                    final p =
                                        (math.sin(_pulseC.value * math.pi * 2) +
                                                1) /
                                            2; // 0..1
                                    final glowScale = 1.0 + (p * 0.20);

                                    return SizedBox(
                                      width: 120,
                                      height: 120,
                                      child: Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          Transform.scale(
                                            scale: glowScale,
                                            child: Container(
                                              width: 110,
                                              height: 110,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: const Color(0xFF4DA3FF)
                                                    .withAlpha(50),
                                              ),
                                            ),
                                          ),
                                          Container(
                                            width: 110,
                                            height: 110,
                                            decoration: const BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: Colors.transparent,
                                              boxShadow: [
                                                BoxShadow(
                                                  blurRadius: 22,
                                                  spreadRadius: 2,
                                                  color: Color(0x994DA3FF),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const Icon(
                                            Icons.check_circle_rounded,
                                            size: 96,
                                            color: SafeShellTheme.accent,
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),

                              const SizedBox(height: 18),

                              // Message
                              TweenAnimationBuilder<double>(
                                tween: Tween(begin: 0, end: 1),
                                duration: const Duration(milliseconds: 500),
                                curve: Curves.easeOut,
                                builder: (_, v, child) {
                                  return Opacity(
                                    opacity: v,
                                    child: Transform.translate(
                                      offset: Offset(0, (1 - v) * 16),
                                      child: child,
                                    ),
                                  );
                                },
                                child: Column(
                                  children: const [
                                    Text(
                                      'Welcome to Premium!',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Color(0xFFEAF2FF),
                                        fontSize: 28,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: -0.2,
                                      ),
                                    ),
                                    SizedBox(height: 10),
                                    Text(
                                      'Your subscription is now active. Enjoy unlimited storage and premium features.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: SafeShellTheme.textMuted,
                                        fontSize: 14,
                                        height: 1.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 22),

                              // Feature Highlights (3 glass tiles)
                              TweenAnimationBuilder<double>(
                                tween: Tween(begin: 0, end: 1),
                                duration: const Duration(milliseconds: 600),
                                curve: Curves.easeOut,
                                builder: (_, v, child) {
                                  return Opacity(
                                    opacity: v,
                                    child: Transform.translate(
                                      offset: Offset(0, (1 - v) * 16),
                                      child: child,
                                    ),
                                  );
                                },
                                child: Column(
                                  children: const [
                                    _FeatureTile(text: '✨ Unlimited vault storage'),
                                    SizedBox(height: 10),
                                    _FeatureTile(text: '🔒 Advanced encryption features'),
                                    SizedBox(height: 10),
                                    _FeatureTile(text: '⚡ Priority support'),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 18),

                              // Action buttons
                              TweenAnimationBuilder<double>(
                                tween: Tween(begin: 0, end: 1),
                                duration: const Duration(milliseconds: 650),
                                curve: Curves.easeOut,
                                builder: (_, v, child) {
                                  return Opacity(
                                    opacity: v,
                                    child: Transform.translate(
                                      offset: Offset(0, (1 - v) * 16),
                                      child: child,
                                    ),
                                  );
                                },
                                child: Column(
                                  children: [
                                    GradientButton(
                                      text: 'Start Using Vault',
                                      onPressed: () => context.go('/vault'),
                                    ),
                                    const SizedBox(height: 12),
                                    _SecondaryGlassButton(
                                      text: 'Go to Dashboard',
                                      icon: Icons.home_rounded,
                                      onPressed: () => context.go('/dashboard'),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 6),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* ------------------------ Feature Tile ------------------------ */

class _FeatureTile extends StatelessWidget {
  final String text;
  const _FeatureTile({required this.text});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Color(0xFFEAF2FF),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/* --------------------- Secondary Glass Button --------------------- */

class _SecondaryGlassButton extends StatelessWidget {
  final String text;
  final IconData icon;
  final VoidCallback onPressed;

  const _SecondaryGlassButton({
    required this.text,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: 56,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: const Color(0xFF0A2A4F).withAlpha(70),
          border: Border.all(color: Colors.white.withAlpha(26)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: const Color(0xFFEAF2FF).withAlpha(230), size: 20),
            const SizedBox(width: 10),
            Text(
              text,
              style: const TextStyle(
                color: Color(0xFFEAF2FF),
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* ------------------------ Confetti ------------------------ */

class _ConfettiParticle {
  final double x; // 0..1
  final double size; // px
  final double speed; // 1..?
  final double phase; // 0..1
  final double hue; // 0..360

  const _ConfettiParticle({
    required this.x,
    required this.size,
    required this.speed,
    required this.phase,
    required this.hue,
  });

  static List<_ConfettiParticle> generate({
    required int count,
    required math.Random rng,
  }) {
    return List.generate(count, (_) {
      return _ConfettiParticle(
        x: rng.nextDouble(),
        size: 4 + rng.nextDouble() * 4,
        speed: 0.7 + rng.nextDouble() * 1.3,
        phase: rng.nextDouble(),
        hue: rng.nextDouble() * 360,
      );
    });
  }
}

class _ConfettiPainter extends CustomPainter {
  final double t; // 0..1 (repeats)
  final List<_ConfettiParticle> particles;

  _ConfettiPainter({required this.t, required this.particles});

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      // looped falling: each particle has its own phase + speed
      final local = (t * p.speed + p.phase) % 1.0;
      final y = (local * (size.height + 60)) - 30; // start above
      final x = p.x * size.width;

      final rot = local * math.pi * 2;
      final opacity = (1.0 - local).clamp(0.0, 1.0);

      final paint = Paint()
        ..color = _hslToColor(p.hue, 0.80, 0.60).withAlpha((opacity * 255).toInt());

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(rot);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size),
          Radius.circular(p.size),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  // Simple HSL → Color (no external deps)
  Color _hslToColor(double h, double s, double l) {
    h = h % 360;
    final c = (1 - (2 * l - 1).abs()) * s;
    final x = c * (1 - ((h / 60) % 2 - 1).abs());
    final m = l - c / 2;

    double r = 0, g = 0, b = 0;
    if (h < 60) {
      r = c;
      g = x;
    } else if (h < 120) {
      r = x;
      g = c;
    } else if (h < 180) {
      g = c;
      b = x;
    } else if (h < 240) {
      g = x;
      b = c;
    } else if (h < 300) {
      r = x;
      b = c;
    } else {
      r = c;
      b = x;
    }

    int to255(double v) => ((v + m) * 255).round().clamp(0, 255);
    return Color.fromARGB(255, to255(r), to255(g), to255(b));
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) =>
      oldDelegate.t != t || oldDelegate.particles != particles;
}