import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';

/// AES-GCM 256-bit encryption service.
/// Encrypted format: [12-byte nonce][ciphertext][16-byte MAC]
class EncryptionService {
  final AesGcm _algorithm = AesGcm.with256bits();

  /// Encrypt plaintext bytes using the given key bytes.
  /// Returns: nonce(12) + ciphertext + mac(16)
  Future<Uint8List> encrypt(Uint8List plaintext, Uint8List keyBytes) async {
    final secretKey = SecretKeyData(keyBytes);
    final secretBox = await _algorithm.encrypt(plaintext, secretKey: secretKey);

    // Concatenate: nonce + ciphertext + mac
    final nonce = Uint8List.fromList(secretBox.nonce);
    final cipherText = Uint8List.fromList(secretBox.cipherText);
    final mac = Uint8List.fromList(secretBox.mac.bytes);

    final result = Uint8List(nonce.length + cipherText.length + mac.length);
    result.setRange(0, nonce.length, nonce);
    result.setRange(nonce.length, nonce.length + cipherText.length, cipherText);
    result.setRange(nonce.length + cipherText.length, result.length, mac);

    return result;
  }

  /// Decrypt encrypted bytes (nonce + ciphertext + mac) using the given key.
  Future<Uint8List> decrypt(Uint8List encryptedData, Uint8List keyBytes) async {
    if (encryptedData.length < 28) {
      throw ArgumentError(
        'Encrypted data too short (min 28 bytes: 12 nonce + 16 mac)',
      );
    }

    final secretKey = SecretKeyData(keyBytes);

    // Extract components
    final nonce = encryptedData.sublist(0, 12);
    final mac = encryptedData.sublist(encryptedData.length - 16);
    final cipherText = encryptedData.sublist(12, encryptedData.length - 16);

    final secretBox = SecretBox(cipherText, nonce: nonce, mac: Mac(mac));

    final decrypted = await _algorithm.decrypt(secretBox, secretKey: secretKey);

    return Uint8List.fromList(decrypted);
  }
}
