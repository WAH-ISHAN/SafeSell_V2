import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Manages stealth mode PIN storage and verification.
/// Stealth PIN is separate from App Lock PIN, allowing different codes.
class StealthModeService {
  static const _pinHashKey = 'stealth_pin_hash';
  static const _pinSaltKey = 'stealth_pin_salt';
  static const _iterations = 100000;

  final FlutterSecureStorage _secureStorage;

  StealthModeService({FlutterSecureStorage? secureStorage})
      : _secureStorage =
            secureStorage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  /// Check if a stealth PIN is set
  Future<bool> hasStealthPinSet() async {
    final hash = await _secureStorage.read(key: _pinHashKey);
    return hash != null && hash.isNotEmpty;
  }

  /// Set a new stealth PIN (called when enabling stealth mode first time)
  Future<void> setStealthPin(String pin) async {
    final salt = _generateSalt();
    final hash = _hashPin(pin, salt);
    await _secureStorage.write(key: _pinSaltKey, value: base64Encode(salt));
    await _secureStorage.write(key: _pinHashKey, value: hash);
  }

  /// Verify the stealth PIN against stored hash
  Future<bool> verifyStealthPin(String pin) async {
    final storedHash = await _secureStorage.read(key: _pinHashKey);
    final storedSaltB64 = await _secureStorage.read(key: _pinSaltKey);
    if (storedHash == null || storedSaltB64 == null) return false;

    final salt = base64Decode(storedSaltB64);
    final inputHash = _hashPin(pin, salt);
    return inputHash == storedHash;
  }

  /// Remove stealth PIN (called when disabling stealth mode)
  Future<void> removeStealthPin() async {
    await _secureStorage.delete(key: _pinHashKey);
    await _secureStorage.delete(key: _pinSaltKey);
  }

  /// Update stealth PIN (useful for PIN change)
  Future<bool> updateStealthPin({
    required String currentPin,
    required String newPin,
  }) async {
    // Verify current PIN first
    final verified = await verifyStealthPin(currentPin);
    if (!verified) return false;

    // Set new PIN
    await setStealthPin(newPin);
    return true;
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
