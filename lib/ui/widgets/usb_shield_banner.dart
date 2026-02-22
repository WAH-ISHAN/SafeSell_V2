import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../app/theme.dart';
import '../../services/usb_protection_service.dart';
import 'premium_ui.dart';

class UsbShieldBanner extends StatelessWidget {
  const UsbShieldBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final usbService = UsbProtectionService();

    return ValueListenableBuilder<bool>(
      valueListenable: usbService.isUsbConnected,
      builder: (context, isConnected, child) {
        if (!isConnected) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            borderRadius: 16,
            borderColor: SafeShellTheme.accent.withValues(alpha: 0.5),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: SafeShellTheme.accent.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.usb_rounded,
                    color: SafeShellTheme.accent,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'USB Shield Active',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        'External device detected.',
                        style: TextStyle(
                          color: SafeShellTheme.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () {
                    // Navigate to USB Import flow
                    context.push('/usb-import');
                  },
                  style: TextButton.styleFrom(
                    backgroundColor:
                        SafeShellTheme.accent.withValues(alpha: 0.1),
                    foregroundColor: SafeShellTheme.accent,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  child: const Text('Scan & Import'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
