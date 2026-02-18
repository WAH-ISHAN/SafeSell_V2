import 'package:flutter/material.dart';
import '../../services/connectivity_service.dart';

/// Banner shown at top of screen when offline.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: ConnectivityService.instance.isOnline,
      builder: (context, online, _) {
        if (online) return const SizedBox.shrink();
        return Material(
          color: Colors.transparent,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFBBF24).withValues(alpha: 0.15),
              border: Border(
                bottom: BorderSide(
                  color: const Color(0xFFFBBF24).withValues(alpha: 0.30),
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.wifi_off_rounded,
                  size: 18,
                  color: const Color(0xFFFBBF24).withValues(alpha: 0.90),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'You are offline. Local vault is still available.',
                    style: TextStyle(
                      color: const Color(0xFFFBBF24).withValues(alpha: 0.90),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => ConnectivityService.instance.checkNow(),
                  child: Text(
                    'Retry',
                    style: TextStyle(
                      color: const Color(0xFFFBBF24).withValues(alpha: 0.90),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
