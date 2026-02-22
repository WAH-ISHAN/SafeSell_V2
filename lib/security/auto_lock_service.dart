import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/app_settings.dart';
import 'key_manager.dart';

/// Service that monitors app background time and auto-locks the vault
/// after a configurable duration (default 10 seconds).
class AutoLockService {
  static final AutoLockService _instance = AutoLockService._internal();
  factory AutoLockService() => _instance;
  AutoLockService._internal();

  DateTime? _pausedAt;
  Timer? _lockTimer;

  static const Duration _defaultLockDelay = Duration(seconds: 10);

  /// Handle app lifecycle changes
  void handleLifecycleChange(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
        _pausedAt = DateTime.now();
        _startLockTimer();
        break;
      case AppLifecycleState.resumed:
        _stopLockTimer();
        _checkAndLockOnResume();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        // No action needed for these states
        break;
    }
  }

  void _startLockTimer() {
    _lockTimer?.cancel();

    // We start a timer as a fallback, but the primary check is on resume.
    // However, explicit locking while paused ensures memory is cleared
    // even if the process is killed or backgrounded for a long time.
    _lockTimer = Timer(_getAutoLockDuration(), () {
      _lockNow();
    });
  }

  void _stopLockTimer() {
    _lockTimer?.cancel();
    _lockTimer = null;
  }

  void _checkAndLockOnResume() {
    if (_pausedAt == null) return;

    final now = DateTime.now();
    final diff = now.difference(_pausedAt!);

    if (diff >= _getAutoLockDuration()) {
      _lockNow();
    }

    _pausedAt = null;
  }

  void _lockNow() {
    debugPrint('[AutoLock] Background timeout reached — locking vault');
    KeyManager().lock();
  }

  Duration _getAutoLockDuration() {
    try {
      final box = Hive.box<AppSettings>('app_settings_typed');
      final settings = box.get('settings');
      if (settings != null && settings.lockAfterSeconds > 0) {
        return Duration(seconds: settings.lockAfterSeconds);
      }
    } catch (e) {
      debugPrint('[AutoLock] Error reading settings: $e');
    }
    return _defaultLockDelay;
  }
}
