import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// App lock with salted PIN hashing and exponential cooldown.
/// PIN is stored as SHA-256(salt + pin) with 100,000 iterations (PBKDF2-like).
class AppLockService {
  static const _pinHashKey = 'app_lock_pin_hash';
  static const _pinSaltKey = 'app_lock_pin_salt';
  static const _iterations = 100000;
  static const _maxAttemptsBeforeCooldown = 5;
  static const _cooldownSteps = [30, 60, 300, 600, 1800]; // seconds

  final FlutterSecureStorage _secureStorage;

  AppLockService({FlutterSecureStorage? secureStorage})
    : _secureStorage =
          secureStorage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(encryptedSharedPreferences: true),
          );

  /// Check if a PIN is set
  Future<bool> hasPinSet() async {
    final hash = await _secureStorage.read(key: _pinHashKey);
    return hash != null && hash.isNotEmpty;
  }

  /// Set a new PIN
  Future<void> setPin(String pin) async {
    final salt = _generateSalt();
    final hash = _hashPin(pin, salt);
    await _secureStorage.write(key: _pinSaltKey, value: base64Encode(salt));
    await _secureStorage.write(key: _pinHashKey, value: hash);
  }

  /// Verify the PIN against stored hash
  Future<bool> verifyPin(String pin) async {
    final storedHash = await _secureStorage.read(key: _pinHashKey);
    final storedSaltB64 = await _secureStorage.read(key: _pinSaltKey);
    if (storedHash == null || storedSaltB64 == null) return false;

    final salt = base64Decode(storedSaltB64);
    final inputHash = _hashPin(pin, salt);
    return inputHash == storedHash;
  }

  /// Remove PIN
  Future<void> removePin() async {
    await _secureStorage.delete(key: _pinHashKey);
    await _secureStorage.delete(key: _pinSaltKey);
  }

  /// Calculate cooldown duration based on failed attempt count
  Duration getCooldownDuration(int failedAttempts) {
    if (failedAttempts < _maxAttemptsBeforeCooldown) return Duration.zero;
    final idx = min(
      failedAttempts - _maxAttemptsBeforeCooldown,
      _cooldownSteps.length - 1,
    );
    return Duration(seconds: _cooldownSteps[idx]);
  }

  /// Generate a 32-byte random salt
  Uint8List _generateSalt() {
    final random = Random.secure();
    return Uint8List.fromList(List.generate(32, (_) => random.nextInt(256)));
  }

  /// PBKDF2-like hash: iterate SHA-256(salt + pin) N times
  String _hashPin(String pin, List<int> salt) {
    var bytes = Uint8List.fromList([...salt, ...utf8.encode(pin)]);
    for (var i = 0; i < _iterations; i++) {
      bytes = Uint8List.fromList(sha256.convert(bytes).bytes);
    }
    return base64Encode(bytes);
  }
}
