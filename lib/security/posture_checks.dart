import 'dart:io';
import 'package:flutter/foundation.dart';

/// Best-effort security posture checks.
/// Detects debug mode, emulator heuristics, and root indicators.
class PostureChecks {
  /// Run all checks and return a security level
  static Future<SecurityPosture> evaluate() async {
    final isDebug = _isDebugMode();
    final isEmulator = await _isEmulator();
    final isRooted = await _isRooted();

    final warnings = <String>[];
    if (isDebug) warnings.add('App is running in debug mode');
    if (isEmulator) warnings.add('Device appears to be an emulator');
    if (isRooted) warnings.add('Device may be rooted');

    SecurityLevel level;
    if (warnings.isEmpty) {
      level = SecurityLevel.high;
    } else if (warnings.length == 1) {
      level = SecurityLevel.medium;
    } else {
      level = SecurityLevel.low;
    }

    return SecurityPosture(
      level: level,
      warnings: warnings,
      isDebug: isDebug,
      isEmulator: isEmulator,
      isRooted: isRooted,
    );
  }

  static bool _isDebugMode() {
    return kDebugMode;
  }

  static Future<bool> _isEmulator() async {
    if (!Platform.isAndroid) return false;
    try {
      // Check common emulator fingerprints
      final checks = [
        File('/dev/qemu_pipe').existsSync(),
        File('/dev/goldfish_pipe').existsSync(),
        File('/sys/qemu_trace').existsSync(),
        Platform.environment.containsKey('ANDROID_EMULATOR'),
      ];
      return checks.any((c) => c);
    } catch (_) {
      return false;
    }
  }

  static Future<bool> _isRooted() async {
    if (!Platform.isAndroid) return false;
    try {
      final suPaths = [
        '/system/bin/su',
        '/system/xbin/su',
        '/sbin/su',
        '/data/local/su',
        '/data/local/bin/su',
        '/data/local/xbin/su',
        '/system/app/Superuser.apk',
        '/system/app/SuperSU.apk',
      ];
      for (final path in suPaths) {
        if (File(path).existsSync()) return true;
      }

      // Check if su is in PATH
      try {
        final result = await Process.run('which', ['su']);
        if (result.exitCode == 0) return true;
      } catch (_) {}

      return false;
    } catch (_) {
      return false;
    }
  }
}

enum SecurityLevel { low, medium, high }

class SecurityPosture {
  final SecurityLevel level;
  final List<String> warnings;
  final bool isDebug;
  final bool isEmulator;
  final bool isRooted;

  const SecurityPosture({
    required this.level,
    required this.warnings,
    required this.isDebug,
    required this.isEmulator,
    required this.isRooted,
  });

  String get levelName {
    switch (level) {
      case SecurityLevel.high:
        return 'High';
      case SecurityLevel.medium:
        return 'Medium';
      case SecurityLevel.low:
        return 'Low';
    }
  }
}
