import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../models/vault_file.dart';
import '../security/encryption_service.dart';
import '../security/key_manager.dart';

class FileCryptoStore {
  final _keyManager = KeyManager();
  final _encryptionService = EncryptionService();
  final _uuid = const Uuid();

  Box<VaultFile> get _box => Hive.box<VaultFile>('vault_files');

  /// Returns the strictly private vault directory.
  /// Android: /data/user/0/com.safeshell/app_flutter/vault/
  /// This path is NEVER visible to USB/PC connections.
  Future<Directory> get _vaultDir async {
    final appDocDir = await getApplicationDocumentsDirectory();
    final vaultDir = Directory(p.join(appDocDir.path, 'vault'));

    if (!await vaultDir.exists()) {
      await vaultDir.create(recursive: true);
    }

    // Extra safety: Create .nomedia even in internal storage
    // just in case of weird OS behavior or root access scanners.
    final noMedia = File(p.join(vaultDir.path, '.nomedia'));
    if (!await noMedia.exists()) {
      await noMedia.create();
    }

    return vaultDir;
  }

  /// Import a file: Encrypt -> Save to Private Vault -> Return VaultFile
  /// Does NOT delete original (caller must handle that for SAF/MediaStore reasons).
  Future<VaultFile> importFile(File sourceFile) async {
    final bytes = await sourceFile.readAsBytes();
    final keyBytes = await _keyManager.getKeyBytes();

    if (keyBytes == null) throw StateError('Vault is locked or key missing');

    final encryptedBytes = await _encryptionService.encrypt(bytes, keyBytes);
    final fileId = _uuid.v4();

    final dir = await _vaultDir;
    final encPath = p.join(dir.path, '$fileId.bin');

    await File(encPath).writeAsBytes(encryptedBytes);

    // Create thumbnail if image (deferred for performance, but basic logic here)
    // For now, we just store the file.

    final mimeType = _guessMime(sourceFile.path);
    final vaultFile = VaultFile(
      id: fileId,
      name: p.basename(sourceFile.path),
      type: mimeType,
      size: bytes.length,
      createdAt: DateTime.now(),
      encPath: encPath,
      mode: VaultMode.private,
      category: VaultFile.categorize(mimeType),
    );

    await _box.put(fileId, vaultFile);
    return vaultFile;
  }

  /// Store bytes directly (e.g. from picker stream).
  Future<VaultFile> importBytes(Uint8List bytes, String filename) async {
    final keyBytes = await _keyManager.getKeyBytes();
    if (keyBytes == null) throw StateError('Vault is locked');

    final encryptedBytes = await _encryptionService.encrypt(bytes, keyBytes);
    final fileId = _uuid.v4();

    final dir = await _vaultDir;
    final encPath = p.join(dir.path, '$fileId.bin');
    await File(encPath).writeAsBytes(encryptedBytes);

    final mimeType = _guessMime(filename);
    final vaultFile = VaultFile(
      id: fileId,
      name: filename,
      type: mimeType,
      size: bytes.length,
      createdAt: DateTime.now(),
      encPath: encPath,
      mode: VaultMode.private,
      category: VaultFile.categorize(mimeType),
    );

    await _box.put(fileId, vaultFile);
    return vaultFile;
  }

  /// Decrypt a file for viewing.
  Future<Uint8List> decryptFile(VaultFile file) async {
    final keyBytes = await _keyManager.getKeyBytes();
    if (keyBytes == null) throw StateError('Vault is locked');

    final encFile = File(file.encPath!);
    if (!await encFile.exists()) throw StateError('File not found in vault');

    final encBytes = await encFile.readAsBytes();
    return await _encryptionService.decrypt(encBytes, keyBytes);
  }

  /// Delete file from vault.
  Future<void> deleteFile(String id) async {
    final file = _box.get(id);
    if (file != null) {
      final f = File(file.encPath!);
      if (await f.exists()) {
        await f.delete();
      }
      await _box.delete(id);
    }
  }

  /// Re-encrypt a file with a new key (used during key rotation).
  /// Reads encrypted file → decrypts with old key → re-encrypts with new key → overwrites.
  Future<void> reEncryptFile(
      String id, Uint8List oldKey, Uint8List newKey) async {
    final file = _box.get(id);
    if (file == null || file.encPath == null) return;
    if (file.mode != VaultMode.private) return; // Only re-encrypt private files

    final encFile = File(file.encPath!);
    if (!await encFile.exists()) return;

    final encBytes = await encFile.readAsBytes();

    // Decrypt with old key
    final plainBytes = await _encryptionService.decrypt(encBytes, oldKey);

    // Re-encrypt with new key
    final reEncryptedBytes = await _encryptionService.encrypt(
      Uint8List.fromList(plainBytes),
      newKey,
    );

    // Overwrite the file
    await encFile.writeAsBytes(reEncryptedBytes);
  }

  /// Clear entire vault (Dangerous).
  Future<void> wipeVault() async {
    final dir = await _vaultDir;
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
    await _box.clear();
  }

  String _guessMime(String path) {
    final ext = p.extension(path).toLowerCase();
    const map = {
      '.jpg': 'image/jpeg',
      '.jpeg': 'image/jpeg',
      '.png': 'image/png',
      '.gif': 'image/gif',
      '.webp': 'image/webp',
      '.bmp': 'image/bmp',
      '.svg': 'image/svg+xml',
      '.heic': 'image/heic',
      '.mp4': 'video/mp4',
      '.mov': 'video/quicktime',
      '.avi': 'video/x-msvideo',
      '.mkv': 'video/x-matroska',
      '.webm': 'video/webm',
      '.3gp': 'video/3gpp',
      '.mp3': 'audio/mpeg',
      '.wav': 'audio/wav',
      '.aac': 'audio/aac',
      '.flac': 'audio/flac',
      '.ogg': 'audio/ogg',
      '.pdf': 'application/pdf',
      '.doc': 'application/msword',
      '.docx':
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      '.xls': 'application/vnd.ms-excel',
      '.xlsx':
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      '.ppt': 'application/vnd.ms-powerpoint',
      '.pptx':
          'application/vnd.openxmlformats-officedocument.presentationml.presentation',
      '.txt': 'text/plain',
      '.csv': 'text/csv',
      '.json': 'application/json',
      '.xml': 'application/xml',
      '.zip': 'application/zip',
      '.rar': 'application/x-rar-compressed',
      '.7z': 'application/x-7z-compressed',
      '.tar': 'application/x-tar',
      '.gz': 'application/gzip',
      '.apk': 'application/vnd.android.package-archive',
    };
    return map[ext] ?? 'application/octet-stream';
  }

  Future<List<VaultFile>> getAllFiles() async {
    return _box.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  /// Add private file (used by VaultUsecase)
  Future<VaultFile> addPrivateFile({
    required String fileName,
    required Uint8List fileBytes,
  }) async {
    return await importBytes(fileBytes, fileName);
  }

  /// Decrypt file to a temp directory for viewing.
  /// Cleans up any previous temp copy first.
  Future<String> decryptToTempFile(VaultFile file) async {
    final bytes = await decryptFile(file);
    final tempDir = await getTemporaryDirectory();
    final safeName = 'ss_${file.id}_${file.name}';
    final tempPath = p.join(tempDir.path, safeName);
    final tempFile = File(tempPath);
    // Overwrite any stale copy
    await tempFile.writeAsBytes(bytes, flush: true);
    return tempPath;
  }

  /// Clean up any SafeShell temp files.
  Future<void> cleanTempFiles() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final listing = tempDir.listSync();
      for (final entity in listing) {
        if (entity is File && p.basename(entity.path).startsWith('ss_')) {
          await entity.delete();
        }
      }
    } catch (_) {}
  }

  /// Search files by name
  Future<List<VaultFile>> searchFiles(String query) async {
    final allFiles = _box.values.toList();
    return allFiles
        .where((f) => f.name.toLowerCase().contains(query.toLowerCase()))
        .toList();
  }

  /// Get files by category
  Future<List<VaultFile>> getFilesByCategory(String category) async {
    final allFiles = _box.values.toList();
    return allFiles.where((f) => f.category == category).toList();
  }
}
