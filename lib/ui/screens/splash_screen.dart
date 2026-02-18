import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../security/screen_protection_service.dart';
import '../../models/app_settings.dart';
import '../../services/permission_service.dart';
import '../../ui/widgets/premium_ui.dart';
import '../../app/theme.dart';
import 'package:hive_flutter/hive_flutter.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnim;
  late Animation<double> _opacityAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _scaleAnim = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.elasticOut),
    );
    _opacityAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: const Interval(0.0, 0.5)),
    );
    _animController.forward();
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
      // Check stealth mode — if enabled, go to calculator instead
      if (settings.stealthEnabled) {
        await Future.delayed(const Duration(seconds: 2));
        if (!mounted) return;
        context.go('/calculator');
        return;
      }
    } catch (_) {
      // Settings box not ready, continue normally
    }

    // Request media permissions non-blockingly on first launch.
    // Navigation does NOT wait on the result — the user can grant later.
    PermissionService().requestMediaPermissions().ignore();

    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    // Navigate to /login — GoRouter redirect will handle:
    // • Not logged in → stays on /login
    // • Logged in, no key → /key-setup
    // • Logged in, key set, lock enabled → /lock
    // • Logged in, key set, unlocked → /dashboard
    context.go('/login');
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PremiumBackground(
        child: Center(
          child: AnimatedBuilder(
            listenable: _animController,
            builder: (context, child) {
              return Opacity(
                opacity: _opacityAnim.value,
                child: Transform.scale(
                  scale: _scaleAnim.value,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SafeShellLogo(size: 100),
                      const SizedBox(height: 24),
                      ShaderMask(
                        shaderCallback: (bounds) =>
                            SafeShellTheme.accentGradient.createShader(bounds),
                        child: const Text(
                          'SafeShell',
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Your Private Vault',
                        style: TextStyle(
                          color: SafeShellTheme.textMuted,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class AnimatedBuilder extends AnimatedWidget {
  final Widget Function(BuildContext, Widget?) builder;
  const AnimatedBuilder({
    super.key,
    required super.listenable,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return builder(context, null);
  }
}
