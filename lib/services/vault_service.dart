import 'dart:typed_data';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import '../models/vault_file.dart';
import 'file_crypto_store.dart';
import 'audit_log_service.dart';
import 'media_store_helper.dart';
import 'permission_service.dart';

/// High-level vault service providing all vault operations.
/// All files are encrypted at rest using AES-GCM and stored in app-private storage.
/// Storage path: ApplicationDocumentsDirectory/vault/ (never visible via USB/MTP).
class VaultService {
  final FileCryptoStore _fileCryptoStore;
  final AuditLogService _auditLogService;

  VaultService({
    FileCryptoStore? fileCryptoStore,
    AuditLogService? auditLogService,
  })  : _fileCryptoStore = fileCryptoStore ?? FileCryptoStore(),
        _auditLogService = auditLogService ?? AuditLogService();

  /// Import a picked file into the encrypted vault.
  ///
  /// [importMode] controls what happens to the original after import:
  ///   - [ImportMode.moveToVault] (default): delete original from gallery after
  ///     successful encryption. If deletion fails the vault copy is kept and
  ///     [result.deletionError] is set.
  ///   - [ImportMode.copyToVault]: keep original untouched.
  Future<AddFileResult> addFile(
    PlatformFile file, {
    ImportMode importMode = ImportMode.moveToVault,
    // Legacy bool kept for callers that haven't migrated yet
    bool? deleteOriginal,
  }) async {
    if (file.bytes == null && file.path == null) {
      throw ArgumentError('PlatformFile has neither bytes nor path');
    }

    // Resolve effective mode (legacy bool takes precedence if set)
    final effectiveMode = deleteOriginal != null
        ? (deleteOriginal ? ImportMode.moveToVault : ImportMode.copyToVault)
        : importMode;

    Uint8List bytes;
    if (file.bytes != null) {
      bytes = file.bytes!;
    } else {
      bytes = await File(file.path!).readAsBytes();
    }

    final vaultFile = await _fileCryptoStore.addPrivateFile(
      fileName: file.name,
      fileBytes: bytes,
    );

    String? deletionError;
    if (effectiveMode == ImportMode.moveToVault && file.path != null) {
      deletionError = await _deleteOriginal(file.path!);
    }

    await _auditLogService.log(
      type: 'file_add',
      details: {
        'fileId': vaultFile.id,
        'name': vaultFile.name,
        'category': vaultFile.category,
        'size': vaultFile.size,
        'importMode': effectiveMode.name,
        'originalDeleted': deletionError == null &&
            effectiveMode == ImportMode.moveToVault,
        if (deletionError != null) 'deletionError': deletionError,
      },
    );

    return AddFileResult(
      vaultFile: vaultFile,
      deletionError: deletionError,
    );
  }

  /// Attempts to permanently delete the original file at [path].
  /// Returns null on success, or an error description on failure.
  Future<String?> _deleteOriginal(String path) async {
    // 1. Direct file deletion (works for files we own / created)
    try {
      final f = File(path);
      if (await f.exists()) {
        await f.delete();
        return null;
      }
    } catch (_) {
      // Fall through to MediaStore
    }

    // 2. MediaStore deletion via platform channel (handles scoped-storage gallery files)
    try {
      await MediaStoreHelper.deleteFile(path);
      return null;
    } on FileSystemException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }

  /// Import raw bytes directly (e.g., from camera, screen capture).
  Future<VaultFile> addBytes({
    required Uint8List bytes,
    required String fileName,
  }) async {
    final vaultFile = await _fileCryptoStore.addPrivateFile(
      fileName: fileName,
      fileBytes: bytes,
    );

    await _auditLogService.log(
      type: 'file_add',
      details: {
        'fileId': vaultFile.id,
        'name': vaultFile.name,
        'category': vaultFile.category,
        'size': vaultFile.size,
      },
    );

    return vaultFile;
  }

  /// Open/view a vault file — decrypts to temp directory for viewing.
  /// Caller should use open_file package or similar to open the temp file.
  Future<String> openFile(VaultFile vaultFile) async {
    final path = await _fileCryptoStore.decryptToTempFile(vaultFile);
    await _auditLogService.log(
      type: 'file_open',
      details: {
        'fileId': vaultFile.id,
        'name': vaultFile.name,
        'category': vaultFile.category,
      },
    );
    return path;
  }

  /// Decrypt file to memory (returns raw bytes).
  Future<Uint8List> decryptFile(VaultFile vaultFile) async {
    final bytes = await _fileCryptoStore.decryptFile(vaultFile);
    await _auditLogService.log(
      type: 'file_decrypt',
      details: {
        'fileId': vaultFile.id,
        'name': vaultFile.name,
      },
    );
    return bytes;
  }

  /// Delete a vault file permanently.
  Future<void> deleteFile(String fileId) async {
    final files = await _fileCryptoStore.getAllFiles();
    final file = files.where((f) => f.id == fileId).firstOrNull;

    await _fileCryptoStore.deleteFile(fileId);
    await _auditLogService.log(
      type: 'file_delete',
      details: {
        'fileId': fileId,
        'name': file?.name ?? 'unknown',
        'category': file?.category,
      },
    );
  }

  /// Bulk delete multiple files.
  Future<void> bulkDelete(List<String> fileIds) async {
    for (final id in fileIds) {
      await deleteFile(id);
    }
    await _auditLogService.log(
      type: 'bulk_delete',
      details: {'count': fileIds.length},
    );
  }

  /// Get all vault files (sorted newest first).
  Future<List<VaultFile>> getAllFiles() {
    return _fileCryptoStore.getAllFiles();
  }

  /// Get files filtered by category.
  Future<List<VaultFile>> getFilesByCategory(String category) {
    return _fileCryptoStore.getFilesByCategory(category);
  }

  /// Search files by name.
  Future<List<VaultFile>> searchFiles(String query) {
    return _fileCryptoStore.searchFiles(query);
  }

  /// Get vault statistics: total files, size, breakdown by category.
  Future<VaultStats> getStats() async {
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

    return VaultStats(
      totalFiles: files.length,
      totalSize: totalSize,
      photos: photos,
      videos: videos,
      docs: docs,
      zip: zip,
      apk: apk,
      other: other,
    );
  }

  /// Clean up temp decrypted files (call when leaving vault or on app resume).
  Future<void> cleanTempFiles() {
    return _fileCryptoStore.cleanTempFiles();
  }

  /// Wipe entire vault (dangerous - use with extreme caution).
  Future<void> wipeVault() async {
    await _fileCryptoStore.wipeVault();
    await _auditLogService.log(
      type: 'vault_wipe',
      details: {'timestamp': DateTime.now().toIso8601String()},
    );
  }

  /// Export a vault file to external storage (decrypted).
  /// Returns the path to the exported file.
  Future<String> exportFile(VaultFile vaultFile) async {
    // Decrypt the file to bytes
    final bytes = await _fileCryptoStore.decryptFile(vaultFile);
    
    // Get Downloads directory
    Directory? downloadsDir;
    if (Platform.isAndroid) {
      downloadsDir = Directory('/storage/emulated/0/Download');
      if (!await downloadsDir.exists()) {
        downloadsDir = await getExternalStorageDirectory();
      }
    } else {
      downloadsDir = await getDownloadsDirectory();
    }
    
    if (downloadsDir == null) {
      throw Exception('Could not access downloads directory');
    }
    
    // Write decrypted file to Downloads
    final exportPath = p.join(downloadsDir.path, vaultFile.name);
    
    // Handle duplicates
    var finalPath = exportPath;
    var counter = 1;
    while (await File(finalPath).exists()) {
      final ext = p.extension(vaultFile.name);
      final nameWithoutExt = p.basenameWithoutExtension(vaultFile.name);
      finalPath = p.join(downloadsDir.path, '$nameWithoutExt ($counter)$ext');
      counter++;
    }
    
    await File(finalPath).writeAsBytes(bytes);
    
    await _auditLogService.log(
      type: 'file_export',
      details: {
        'fileId': vaultFile.id,
        'name': vaultFile.name,
        'exportPath': finalPath,
      },
    );
    
    return finalPath;
  }

  /// Share a vault file via system share dialog (decrypted).
  Future<void> shareFile(VaultFile vaultFile) async {
    // Decrypt to temp file
    final tempPath = await _fileCryptoStore.decryptToTempFile(vaultFile);
    
    // Share via share_plus
    final xFile = XFile(tempPath, name: vaultFile.name);
    await Share.shareXFiles(
      [xFile],
      subject: vaultFile.name,
    );
    
    await _auditLogService.log(
      type: 'file_share',
      details: {
        'fileId': vaultFile.id,
        'name': vaultFile.name,
      },
    );
  }
}

/// Vault statistics data class.
class VaultStats {
  final int totalFiles;
  final int totalSize; // bytes
  final int photos;
  final int videos;
  final int docs;
  final int zip;
  final int apk;
  final int other;

  VaultStats({
    required this.totalFiles,
    required this.totalSize,
    required this.photos,
    required this.videos,
    required this.docs,
    required this.zip,
    required this.apk,
    required this.other,
  });

  /// Human-readable size string (e.g., "1.2 MB").
  String get formattedSize {
    if (totalSize < 1024) return '$totalSize B';
    if (totalSize < 1024 * 1024) {
      return '${(totalSize / 1024).toStringAsFixed(1)} KB';
    }
    if (totalSize < 1024 * 1024 * 1024) {
      return '${(totalSize / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(totalSize / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  /// GB used (for quota display).
  double get sizeGB => totalSize / (1024 * 1024 * 1024);
}

/// Result returned by [VaultService.addFile].
class AddFileResult {
  /// The newly created vault record.
  final VaultFile vaultFile;

  /// Non-null when the original file could not be deleted (Move mode only).
  /// The vault copy is always present regardless of this value.
  final String? deletionError;

  AddFileResult({required this.vaultFile, this.deletionError});

  /// True when the original was successfully deleted (Move mode).
  bool get originalDeleted => deletionError == null;
}
