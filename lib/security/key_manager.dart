import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:crypto/crypto.dart';
import 'encryption_service.dart';

class KeyManager {
  static final KeyManager _instance = KeyManager._internal();
  factory KeyManager() => _instance;
  KeyManager._internal();

  final _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      keyCipherAlgorithm: KeyCipherAlgorithm.RSA_ECB_PKCS1Padding,
      storageCipherAlgorithm: StorageCipherAlgorithm.AES_GCM_NoPadding,
    ),
  );

  /// Storage keys
  static const _wrappedMkV1Key = 'wrapped_mk'; // Old XOR format
  static const _wrappedMkV2Key = 'wrapped_mk_v2'; // New AES-GCM format
  static const _vaultCheckKey = 'vault_check';

  Uint8List? _cachedMasterKey; // The decrypted master key in memory

  /// Returns the master key bytes.
  /// Returns null if vault is locked (not unlocked via PIN/biometric).
  Future<Uint8List?> getKeyBytes() async {
    return _cachedMasterKey;
  }

  bool get isUnlocked => _cachedMasterKey != null;

  /// Setup a new vault with a PIN.
  /// Generates a random Master Key, wraps it with AES-GCM using PIN-derived KEK,
  /// and stores the wrapped key in SecureStorage.
  Future<void> setupVault(String pin) async {
    // 1. Generate random Master Key (MK) - 32 bytes
    final mk = _generateRandomBytes(32);

    // 2. Derive Key Encryption Key (KEK) from PIN
    final kek = _deriveKeyFromPin(pin);

    // 3. Wrap MK with KEK using AES-GCM
    final encService = EncryptionService();
    final wrappedBytes = await encService.encrypt(mk, kek);

    await _secureStorage.write(
      key: _wrappedMkV2Key,
      value: base64Encode(wrappedBytes),
    );
    await _secureStorage.write(key: _vaultCheckKey, value: 'setup_complete');

    // Clean up any old V1 key
    await _secureStorage.delete(key: _wrappedMkV1Key);

    _cachedMasterKey = mk;
  }

  /// Unlock the vault.
  /// Derives KEK from PIN, unwraps MK using AES-GCM.
  /// Returns true if unlock succeeded, false if PIN is wrong or no key exists.
  Future<bool> unlock(String pin) async {
    final kek = _deriveKeyFromPin(pin);

    // Try V2 (AES-GCM) first
    final v2Str = await _secureStorage.read(key: _wrappedMkV2Key);
    if (v2Str != null) {
      try {
        final wrappedBytes = base64Decode(v2Str);
        final encService = EncryptionService();
        final mk = await encService.decrypt(wrappedBytes, kek);
        _cachedMasterKey = Uint8List.fromList(mk);
        return true;
      } catch (e) {
        // Decryption failed — wrong PIN or corrupted data
        debugPrint('[SafeShell] V2 unlock failed: $e');
        return false;
      }
    }

    // Try V1 (old XOR format) — migrate if found
    final v1Str = await _secureStorage.read(key: _wrappedMkV1Key);
    if (v1Str != null) {
      try {
        final wrappedMk = base64Decode(v1Str);
        final mk = _xorUnwrap(wrappedMk, kek);
        _cachedMasterKey = mk;

        // Migrate: rewrap with AES-GCM and store as V2
        await _migrateV1toV2(mk, kek);
        return true;
      } catch (e) {
        debugPrint('[SafeShell] V1 unlock/migration failed: $e');
        return false;
      }
    }

    return false; // No key stored
  }

  /// Migrate a V1 (XOR) wrapped key to V2 (AES-GCM).
  Future<void> _migrateV1toV2(Uint8List mk, Uint8List kek) async {
    try {
      final encService = EncryptionService();
      final wrappedBytes = await encService.encrypt(mk, kek);

      await _secureStorage.write(
        key: _wrappedMkV2Key,
        value: base64Encode(wrappedBytes),
      );
      // Delete old V1 key
      await _secureStorage.delete(key: _wrappedMkV1Key);
      debugPrint(
          '[SafeShell] Successfully migrated key from V1 (XOR) to V2 (AES-GCM)');
    } catch (e) {
      debugPrint('[SafeShell] V1→V2 migration failed: $e');
      // Keep V1 key intact if migration fails
    }
  }

  /// Lock the vault (clear master key from memory).
  void lock() {
    _cachedMasterKey = null;
  }

  /// Check if vault has been set up (key exists in storage).
  Future<bool> isSetup() async {
    // Check V2 first, then V1 (for migration scenario)
    final hasV2 = await _secureStorage.containsKey(key: _wrappedMkV2Key);
    if (hasV2) return true;
    final hasV1 = await _secureStorage.containsKey(key: _wrappedMkV1Key);
    return hasV1;
  }

  /// Alias for isSetup()
  Future<bool> hasKey() async => isSetup();

  /// Derive a 32-byte KEK from a PIN using iterated SHA-256 (PBKDF2-like).
  Uint8List _deriveKeyFromPin(String pin) {
    List<int> bytes = utf8.encode(pin);
    for (int i = 0; i < 1000; i++) {
      bytes = sha256.convert(bytes).bytes;
    }
    return Uint8List.fromList(bytes);
  }

  /// Generate cryptographically secure random bytes.
  Uint8List _generateRandomBytes(int length) {
    final random = Random.secure();
    final bytes = Uint8List(length);
    for (int i = 0; i < length; i++) {
      bytes[i] = random.nextInt(256);
    }
    return bytes;
  }

  /// XOR unwrap (only used for V1 migration).
  Uint8List _xorUnwrap(Uint8List a, Uint8List b) {
    final res = Uint8List(a.length);
    for (int i = 0; i < a.length; i++) {
      res[i] = a[i] ^ b[i % b.length];
    }
    return res;
  }

  /// Get key as base64 string (for display/export).
  Future<String?> getKeyBase64() async {
    if (_cachedMasterKey == null) return null;
    return base64Encode(_cachedMasterKey!);
  }

  /// Generate and store a new key with PIN protection.
  Future<String> generateAndStoreKey(String pin) async {
    await setupVault(pin);
    return base64Encode(_cachedMasterKey!);
  }

  /// Validate key format (base64, 32 bytes when decoded).
  bool validateKeyFormat(String keyBase64) {
    try {
      final decoded = base64Decode(keyBase64);
      return decoded.length == 32;
    } catch (e) {
      return false;
    }
  }

  /// Import a key from base64 string, protected by PIN.
  Future<void> importKey(String keyBase64, String pin) async {
    final decoded = base64Decode(keyBase64);
    if (decoded.length != 32) {
      throw ArgumentError('Invalid key length. Must be 32 bytes.');
    }

    final kek = _deriveKeyFromPin(pin);
    final encService = EncryptionService();
    final wrappedBytes = await encService.encrypt(decoded, kek);

    await _secureStorage.write(
      key: _wrappedMkV2Key,
      value: base64Encode(wrappedBytes),
    );
    await _secureStorage.write(key: _vaultCheckKey, value: 'setup_complete');
    // Clean up any old V1 key
    await _secureStorage.delete(key: _wrappedMkV1Key);

    _cachedMasterKey = Uint8List.fromList(decoded);
  }

  /// Rotate key — generate new key, wrap with new PIN, return old key for re-encryption.
  Future<Uint8List> rotateKey(String currentPin, String newPin) async {
    final oldKey = _cachedMasterKey;
    if (oldKey == null) {
      throw StateError('Vault must be unlocked to rotate key');
    }

    // Generate new master key
    final newMk = _generateRandomBytes(32);

    // Encrypt with new PIN-derived KEK
    final newKek = _deriveKeyFromPin(newPin.isEmpty ? currentPin : newPin);
    final encService = EncryptionService();
    final wrappedBytes = await encService.encrypt(newMk, newKek);

    // Store new wrapped key
    await _secureStorage.write(
      key: _wrappedMkV2Key,
      value: base64Encode(wrappedBytes),
    );

    // Update cached key
    _cachedMasterKey = newMk;

    // Return old key so caller can re-encrypt files
    return oldKey;
  }
}
