import 'dart:ui';
import 'package:flutter/material.dart';
import '../../app/theme.dart';

// ─── Premium Background ─────────────────────────────────────
class PremiumBackground extends StatelessWidget {
  final Widget child;
  const PremiumBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: SafeShellTheme.bgGradient),
      child: Stack(
        children: [
          // Ambient glow orbs
          const Positioned(
            top: -80,
            left: -60,
            child: GlowBlob(color: SafeShellTheme.accent, size: 250),
          ),
          const Positioned(
            bottom: -100,
            right: -80,
            child: GlowBlob(color: SafeShellTheme.accentAlt, size: 300),
          ),
          const Positioned(
            top: 200,
            right: -50,
            child: GlowBlob(color: SafeShellTheme.accentPink, size: 180),
          ),
          // Grid overlay
          Positioned.fill(child: CustomPaint(painter: GridPainter())),
          child,
        ],
      ),
    );
  }
}

// ─── Glass Card ─────────────────────────────────────────────
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final double blur;
  final Color? borderColor;
  final VoidCallback? onTap;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius = 20,
    this.blur = 20,
    this.borderColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      margin: margin ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding ?? const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: SafeShellTheme.glass,
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(
                color: borderColor ?? SafeShellTheme.glassBorder,
                width: 0.5,
              ),
            ),
            child: DefaultTextStyle.merge(
              style: const TextStyle(color: SafeShellTheme.textPrimary),
              child: child,
            ),
          ),
        ),
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(borderRadius),
        child: card,
      );
    }
    return card;
  }
}

// ─── Glow Blob ──────────────────────────────────────────────
class GlowBlob extends StatelessWidget {
  final Color color;
  final double size;
  const GlowBlob({super.key, required this.color, this.size = 200});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color.o(0.3), color.o(0.0)]),
      ),
    );
  }
}

// ─── Grid Painter ───────────────────────────────────────────
class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = SafeShellTheme.glassBorder.o(0.05)
          ..strokeWidth = 0.5;

    const spacing = 40.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─── Top Blur Bar ───────────────────────────────────────────
class TopBlurBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final Widget? leading;
  final double height;

  const TopBlurBar({
    super.key,
    required this.title,
    this.actions,
    this.leading,
    this.height = 56,
  });

  @override
  Size get preferredSize => Size.fromHeight(height);

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: AppBar(
          title: Text(title),
          leading: leading,
          actions: actions,
          backgroundColor: SafeShellTheme.bgDark.o(0.5),
        ),
      ),
    );
  }
}

// ─── Gradient Button ────────────────────────────────────────
class GradientButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final LinearGradient? gradient;
  final double? width;
  final IconData? icon;
  final Color? textColor;

  const GradientButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.gradient,
    this.width,
    this.icon,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width ?? double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient:
            onPressed != null
                ? (gradient ?? SafeShellTheme.accentGradient)
                : null,
        color: onPressed == null ? SafeShellTheme.textMuted.o(0.3) : null,
        borderRadius: BorderRadius.circular(16),
        boxShadow:
            onPressed != null
                ? [
                  BoxShadow(
                    color: SafeShellTheme.accent.o(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ]
                : null,
      ),
      child: MaterialButton(
        onPressed: isLoading ? null : onPressed,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child:
            isLoading
                ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation(SafeShellTheme.bgDark),
                  ),
                )
                : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, color: textColor ?? SafeShellTheme.bgDark, size: 20),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      text,
                      style: TextStyle(
                        color: textColor ?? SafeShellTheme.bgDark,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
      ),
    );
  }
}

// ─── Security Level Badge ───────────────────────────────────
class SecurityBadge extends StatelessWidget {
  final String level;
  const SecurityBadge({super.key, required this.level});

  @override
  Widget build(BuildContext context) {
    Color color;
    IconData icon;
    switch (level.toLowerCase()) {
      case 'high':
        color = SafeShellTheme.success;
        icon = Icons.shield;
        break;
      case 'medium':
        color = SafeShellTheme.warning;
        icon = Icons.shield_outlined;
        break;
      default:
        color = SafeShellTheme.error;
        icon = Icons.warning_amber;
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 6),
        Text(
          level,
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ─── Mode Badge ─────────────────────────────────────────────
class ModeBadge extends StatelessWidget {
  final bool isPrivate;
  const ModeBadge({super.key, required this.isPrivate});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: (isPrivate ? SafeShellTheme.accentAlt : SafeShellTheme.accent).o(
          0.2,
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: (isPrivate ? SafeShellTheme.accentAlt : SafeShellTheme.accent)
              .o(0.4),
        ),
      ),
      child: Text(
        isPrivate ? 'PRIVATE' : 'GALLERY',
        style: TextStyle(
          color: isPrivate ? SafeShellTheme.accentAlt : SafeShellTheme.accent,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

// ─── Animated Logo ──────────────────────────────────────────
class SafeShellLogo extends StatelessWidget {
  final double size;
  const SafeShellLogo({super.key, this.size = 80});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: SafeShellTheme.accentGradient,
        boxShadow: [
          BoxShadow(
            color: SafeShellTheme.accent.o(0.4),
            blurRadius: 30,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Icon(
        Icons.shield_rounded,
        size: size * 0.5,
        color: SafeShellTheme.bgDark,
      ),
    );
  }
}

// ─── Empty State ────────────────────────────────────────────
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: SafeShellTheme.textMuted.o(0.5)),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                color: SafeShellTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: const TextStyle(
                  color: SafeShellTheme.textMuted, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            if (action != null) ...[const SizedBox(height: 24), action!],
          ],
        ),
      ),
    );
  }
}

// ─── PIN Input ──────────────────────────────────────────────
class PinInput extends StatefulWidget {
  final int length;
  final ValueChanged<String> onCompleted;
  final String? error;

  const PinInput({
    super.key,
    this.length = 6,
    required this.onCompleted,
    this.error,
  });

  @override
  State<PinInput> createState() => _PinInputState();
}

class _PinInputState extends State<PinInput> {
  String _pin = '';

  void _addDigit(int digit) {
    if (_pin.length >= widget.length) return;
    setState(() => _pin += digit.toString());
    if (_pin.length == widget.length) {
      widget.onCompleted(_pin);
    }
  }

  void _removeDigit() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  void _clear() {
    setState(() => _pin = '');
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Determine available width; clamp to usable range
        final availableWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.of(context).size.width;
        // Each row has 3 buttons; compute button diameter from available space
        // with a small horizontal gap between buttons
        final btnSize = ((availableWidth - 40) / 3).clamp(48.0, 80.0);
        final btnPad = (btnSize * 0.12).clamp(4.0, 14.0);

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // PIN dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(widget.length, (i) {
                final filled = i < _pin.length;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  width: filled ? 16 : 14,
                  height: filled ? 16 : 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: filled ? SafeShellTheme.accent : Colors.transparent,
                    border: Border.all(
                      color: widget.error != null
                          ? SafeShellTheme.error
                          : SafeShellTheme.accent.o(filled ? 1 : 0.3),
                      width: 2,
                    ),
                    boxShadow: filled
                        ? [
                            BoxShadow(
                              color: SafeShellTheme.accent.o(0.5),
                              blurRadius: 10,
                            ),
                          ]
                        : null,
                  ),
                );
              }),
            ),
            if (widget.error != null) ...[
              const SizedBox(height: 12),
              Text(
                widget.error!,
                style: const TextStyle(
                    color: SafeShellTheme.error, fontSize: 13),
              ),
            ],
            const SizedBox(height: 32),
            // Numpad rows 1-3
            ...List.generate(3, (row) {
              return Padding(
                padding: EdgeInsets.symmetric(vertical: btnPad * 0.5),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(3, (col) {
                    final digit = row * 3 + col + 1;
                    return _numButton(
                      digit.toString(),
                      () => _addDigit(digit),
                      btnSize: btnSize,
                      btnPad: btnPad,
                    );
                  }),
                ),
              );
            }),
            // Bottom row: C, 0, ⌫
            Padding(
              padding: EdgeInsets.symmetric(vertical: btnPad * 0.5),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _numButton('C', _clear,
                      isAction: true, btnSize: btnSize, btnPad: btnPad),
                  _numButton('0', () => _addDigit(0),
                      btnSize: btnSize, btnPad: btnPad),
                  _numButton('⌫', _removeDigit,
                      isAction: true, btnSize: btnSize, btnPad: btnPad),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _numButton(
    String label,
    VoidCallback onTap, {
    bool isAction = false,
    required double btnSize,
    required double btnPad,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: btnPad),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(btnSize),
          child: Container(
            width: btnSize,
            height: btnSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isAction ? Colors.transparent : SafeShellTheme.glass,
              border: isAction
                  ? null
                  : Border.all(
                      color: SafeShellTheme.glassBorder,
                      width: 0.5,
                    ),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: TextStyle(
                color: isAction
                    ? SafeShellTheme.textMuted
                    : SafeShellTheme.textPrimary,
                fontSize: isAction
                    ? (btnSize * 0.28).clamp(14.0, 22.0)
                    : (btnSize * 0.36).clamp(16.0, 28.0),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Shimmer Loading ────────────────────────────────────────
class ShimmerLoading extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;

  const ShimmerLoading({
    super.key,
    this.width = double.infinity,
    this.height = 20,
    this.borderRadius = 8,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: SafeShellTheme.glass,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}
