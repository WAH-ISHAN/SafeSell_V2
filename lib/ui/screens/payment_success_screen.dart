import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../app/theme.dart';
import '../widgets/premium_ui.dart';

class PaymentSuccessScreen extends StatelessWidget {
  const PaymentSuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PremiumBackground(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: GlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    size: 100,
                    color: SafeShellTheme.success,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Upgrade Successful!',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Welcome to SafeShell Pro. Your vault is now protected with advanced security features and unlimited storage.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: SafeShellTheme.textMuted),
                  ),
                  const SizedBox(height: 40),
                  GradientButton(
                    text: 'Go to Dashboard',
                    onPressed: () {
                      context.go('/dashboard');
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
