import 'package:flutter/services.dart';

/// Manages FLAG_SECURE on Android via platform channel.
/// Blocks screenshots and recent apps preview when enabled.
class ScreenProtectionService {
  static const _channel = MethodChannel('com.safeshell/screen_protection');

  /// Enable FLAG_SECURE (block screenshots + recents preview)
  Future<void> enable() async {
    try {
      await _channel.invokeMethod('enableSecure');
    } on PlatformException catch (_) {
      // Silently fail on unsupported platforms
    }
  }

  /// Disable FLAG_SECURE
  Future<void> disable() async {
    try {
      await _channel.invokeMethod('disableSecure');
    } on PlatformException catch (_) {
      // Silently fail
    }
  }

  /// Set FLAG_SECURE based on boolean
  Future<void> setEnabled(bool enabled) async {
    if (enabled) {
      await enable();
    } else {
      await disable();
    }
  }
}
