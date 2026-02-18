import '../models/app_settings.dart';
import '../security/app_lock_service.dart';
import '../security/biometric_service.dart';
import '../security/key_manager.dart';
import '../services/audit_log_service.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// High-level lock/unlock logic with cooldown.
class LockUsecase {
  final AppLockService _appLockService;
  final BiometricService _biometricService;
  final AuditLogService _auditLogService;
  final KeyManager _keyManager;

  LockUsecase({
    required AppLockService appLockService,
    required BiometricService biometricService,
    required AuditLogService auditLogService,
    KeyManager? keyManager,
  })  : _appLockService = appLockService,
        _biometricService = biometricService,
        _auditLogService = auditLogService,
        _keyManager = keyManager ?? KeyManager();

  /// Get current settings
  Future<AppSettings> _getSettings() async {
    final box = await Hive.openBox<AppSettings>('app_settings_typed');
    if (box.isEmpty) {
      final settings = AppSettings();
      await box.put('settings', settings);
      return settings;
    }
    return box.get('settings')!;
  }

  Future<void> _saveSettings(AppSettings settings) async {
    final box = await Hive.openBox<AppSettings>('app_settings_typed');
    await box.put('settings', settings);
  }

  /// Check if app is locked
  Future<bool> isLockEnabled() async {
    final settings = await _getSettings();
    return settings.lockEnabled;
  }

  /// Check for cooldown
  Future<Duration> getCooldownRemaining() async {
    final settings = await _getSettings();
    if (settings.lockoutUntil == null) return Duration.zero;
    final remaining = settings.lockoutUntil!.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// Attempt unlock with biometrics
  Future<bool> unlockWithBiometric() async {
    final cooldown = await getCooldownRemaining();
    if (cooldown > Duration.zero) return false;

    final result = await _biometricService.authenticate(
      reason: 'Unlock SafeShell',
    );

    if (result) {
      await _resetFailedAttempts();
      await _auditLogService.log(
        type: 'unlock',
        details: {'method': 'biometric'},
      );
    } else {
      await _incrementFailedAttempts();
      await _auditLogService.log(
        type: 'failed_unlock',
        details: {'method': 'biometric'},
      );
    }

    return result;
  }

  /// Attempt unlock with PIN — also loads master key into memory.
  Future<bool> unlockWithPin(String pin) async {
    final cooldown = await getCooldownRemaining();
    if (cooldown > Duration.zero) return false;

    final result = await _appLockService.verifyPin(pin);

    if (result) {
      // Load master key into memory
      await _keyManager.unlock(pin);
      await _resetFailedAttempts();
      await _auditLogService.log(type: 'unlock', details: {'method': 'pin'});
    } else {
      await _incrementFailedAttempts();
      await _auditLogService.log(
        type: 'failed_unlock',
        details: {'method': 'pin'},
      );
    }

    return result;
  }

  /// Enable lock with PIN
  Future<void> enableLock(String pin, String mode) async {
    await _appLockService.setPin(pin);
    final settings = await _getSettings();
    settings.lockEnabled = true;
    settings.lockMode = mode;
    await _saveSettings(settings);
    await _auditLogService.log(type: 'lock_enabled', details: {'mode': mode});
  }

  /// Disable lock
  Future<void> disableLock() async {
    await _appLockService.removePin();
    final settings = await _getSettings();
    settings.lockEnabled = false;
    await _saveSettings(settings);
    await _auditLogService.log(type: 'lock_disabled');
  }

  /// Get failed attempt count
  Future<int> getFailedAttempts() async {
    final settings = await _getSettings();
    return settings.failedAttempts;
  }

  Future<void> _incrementFailedAttempts() async {
    final settings = await _getSettings();
    settings.failedAttempts++;
    final cooldown = _appLockService.getCooldownDuration(
      settings.failedAttempts,
    );
    if (cooldown > Duration.zero) {
      settings.lockoutUntil = DateTime.now().add(cooldown);
    }
    await _saveSettings(settings);
  }

  Future<void> _resetFailedAttempts() async {
    final settings = await _getSettings();
    settings.failedAttempts = 0;
    settings.lockoutUntil = null;
    await _saveSettings(settings);
  }

  /// Check if panic wipe should trigger
  Future<bool> shouldPanicWipe() async {
    final settings = await _getSettings();
    return settings.panicWipeEnabled &&
        settings.failedAttempts >= settings.panicWipeThreshold;
  }
}
