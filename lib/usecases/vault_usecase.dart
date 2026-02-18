import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../models/vault_file.dart';
import '../services/file_crypto_store.dart';
import '../services/audit_log_service.dart';
import '../services/media_store_helper.dart';

/// High-level vault operations.
/// All files are stored encrypted in app-private storage (no gallery mode).
class VaultUsecase {
  final FileCryptoStore _fileCryptoStore;
  final AuditLogService _auditLogService;

  VaultUsecase({
    required FileCryptoStore fileCryptoStore,
    required AuditLogService auditLogService,
  })  : _fileCryptoStore = fileCryptoStore,
        _auditLogService = auditLogService;

  /// Import a picked file into the encrypted vault.
  /// If [deleteOriginal] is true, attempts to delete the source file after import.
  Future<VaultFile?> addFile(
    PlatformFile file, {
    bool deleteOriginal = false,
  }) async {
    if (file.bytes == null && file.path == null) return null;

    Uint8List bytes;
    if (file.bytes != null) {
      bytes = file.bytes!;
    } else {
      final f = File(file.path!);
      bytes = await f.readAsBytes();
    }

    final vaultFile = await _fileCryptoStore.addPrivateFile(
      fileName: file.name,
      fileBytes: bytes,
    );

    bool deletedOriginal = false;
    if (deleteOriginal && file.path != null) {
      try {
        await MediaStoreHelper.deleteFile(file.path!);
        deletedOriginal = true;
      } catch (_) {
        deletedOriginal = false;
      }
    }

    await _auditLogService.log(
      type: 'file_add',
      details: {
        'fileId': vaultFile.id,
        'name': vaultFile.name,
        'deletedOriginal': deletedOriginal,
      },
    );

    return vaultFile;
  }

  /// Open a vault file — decrypts to temp for viewing.
  Future<String?> openFile(VaultFile vaultFile) async {
    final path = await _fileCryptoStore.decryptToTempFile(vaultFile);
    await _auditLogService.log(
      type: 'file_open',
      details: {'fileId': vaultFile.id, 'name': vaultFile.name},
    );
    return path;
  }

  /// Delete a vault file.
  Future<void> deleteFile(String id) async {
    final files = await _fileCryptoStore.getAllFiles();
    final file = files.where((f) => f.id == id).firstOrNull;

    await _fileCryptoStore.deleteFile(id);
    await _auditLogService.log(
      type: 'file_delete',
      details: {'fileId': id, 'name': file?.name ?? 'unknown'},
    );
  }

  /// Bulk delete files.
  Future<void> bulkDelete(List<String> ids) async {
    for (final id in ids) {
      await deleteFile(id);
    }
  }

  /// Search files by name.
  Future<List<VaultFile>> searchFiles(String query) {
    return _fileCryptoStore.searchFiles(query);
  }

  /// Get all files (sorted newest first).
  Future<List<VaultFile>> getAllFiles() {
    return _fileCryptoStore.getAllFiles();
  }

  /// Get files by category.
  Future<List<VaultFile>> getFilesByCategory(String category) {
    return _fileCryptoStore.getFilesByCategory(category);
  }

  /// Clean up temp decrypted files.
  Future<void> cleanTemp() {
    return _fileCryptoStore.cleanTempFiles();
  }

  /// Get vault stats: count of files per category, total size.
  Future<Map<String, dynamic>> getVaultStats() async {
    final files = await _fileCryptoStore.getAllFiles();
    int totalSize = 0;
    int photos = 0, videos = 0, docs = 0, zip = 0, apk = 0, other = 0;

    for (final f in files) {
      totalSize += f.size;
      switch (f.category) {
        case 'photos':
          photos++;
          break;
        case 'videos':
          videos++;
          break;
        case 'docs':
          docs++;
          break;
        case 'zip':
          zip++;
          break;
        case 'apk':
          apk++;
          break;
        default:
          other++;
      }
    }

    return {
      'totalFiles': files.length,
      'totalSize': totalSize,
      'photos': photos,
      'videos': videos,
      'docs': docs,
      'zip': zip,
      'apk': apk,
      'other': other,
    };
  }
}
