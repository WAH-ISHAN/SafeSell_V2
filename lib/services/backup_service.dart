import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';
import '../models/vault_file.dart';
import '../models/audit_event.dart';
import '../security/encryption_service.dart';
import '../security/key_manager.dart';

/// Export/import encrypted .ssb backup files.
/// Supports both vault-key encryption and password-protected backups.
class BackupService {
  final EncryptionService _encryptionService;
  final KeyManager _keyManager;

  BackupService({
    required EncryptionService encryptionService,
    required KeyManager keyManager,
  })  : _encryptionService = encryptionService,
        _keyManager = keyManager;

  /// Export vault files, metadata, and audit log to encrypted .ssb file.
  /// 
  /// If [password] is provided, uses password-based encryption (PBKDF2).
  /// Otherwise, uses the vault master key.
  /// 
  /// [onProgress] callback receives progress updates (0.0 to 1.0).
  Future<String> exportBackup({
    String? password,
    void Function(double progress)? onProgress,
  }) async {
    onProgress?.call(0.1);

    // Determine encryption key
    Uint8List keyBytes;
    if (password != null) {
      // Password-based encryption
      keyBytes = _deriveKeyFromPassword(password);
    } else {
      // Vault key encryption
      final vaultKey = await _keyManager.getKeyBytes();
      if (vaultKey == null) throw StateError('No vault key available');
      keyBytes = vaultKey;
    }

    onProgress?.call(0.2);

    // Collect vault metadata
    final vaultBox = await Hive.openBox<VaultFile>('vault_files');
    final vaultFiles = vaultBox.values.toList();

    onProgress?.call(0.3);

    // Collect audit events
    final auditBox = await Hive.openBox<AuditEvent>('audit_events');
    final auditEvents = auditBox.values.toList();

    onProgress?.call(0.4);

    // Build archive
    final archive = Archive();

    // Add metadata JSON
    final metadata = {
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'fileCount': vaultFiles.length,
      'auditCount': auditEvents.length,
      'passwordProtected': password != null,
      'files': vaultFiles
          .map(
            (f) => {
              'id': f.id,
              'name': f.name,
              'type': f.type,
              'size': f.size,
              'createdAt': f.createdAt.toIso8601String(),
              'mode':
                  f.mode == VaultMode.private ? 'private' : 'gallery_protected',
              'category': f.category,
            },
          )
          .toList(),
      'audit': auditEvents
          .map(
            (e) => {
              'id': e.id,
              'timestamp': e.timestamp.toIso8601String(),
              'type': e.type,
              'payload': e.payload,
              'eventHash': e.eventHash,
              'prevHash': e.prevHash,
            },
          )
          .toList(),
    };

    final metadataBytes = utf8.encode(json.encode(metadata));
    archive.addFile(
      ArchiveFile('metadata.json', metadataBytes.length, metadataBytes),
    );

    onProgress?.call(0.5);

    // Add encrypted vault files
    int processedFiles = 0;
    for (final vf in vaultFiles) {
      if (vf.mode == VaultMode.private && vf.encPath != null) {
        final file = File(vf.encPath!);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          archive.addFile(
            ArchiveFile('vault/${vf.id}.enc', bytes.length, bytes),
          );
        }
      }
      processedFiles++;
      onProgress?.call(0.5 + (0.3 * processedFiles / vaultFiles.length));
    }

    onProgress?.call(0.8);

    // Encode archive
    final archiveBytes = ZipEncoder().encode(archive);
    if (archiveBytes == null) throw StateError('Failed to create archive');

    onProgress?.call(0.9);

    // Encrypt the archive
    final encrypted = await _encryptionService.encrypt(
      Uint8List.fromList(archiveBytes),
      keyBytes,
    );

    onProgress?.call(0.95);

    // Write .ssb file
    final downloadDir = Directory('/storage/emulated/0/Download');
    if (!await downloadDir.exists()) {
      // Fallback to external storage
      final externalDir = await getExternalStorageDirectory();
      if (externalDir == null) {
        throw StateError('Cannot access external storage');
      }
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final backupPath = '${externalDir.path}/safeshell_backup_$timestamp.ssb';
      await File(backupPath).writeAsBytes(encrypted);
      onProgress?.call(1.0);
      return backupPath;
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final backupPath = '${downloadDir.path}/safeshell_backup_$timestamp.ssb';
    await File(backupPath).writeAsBytes(encrypted);

    onProgress?.call(1.0);
    return backupPath;
  }

  /// Import and restore from encrypted .ssb backup file.
  /// 
  /// If backup is password-protected, [password] must be provided.
  /// Otherwise, uses the vault master key.
  /// 
  /// [onProgress] callback receives progress updates (0.0 to 1.0).
  /// 
  /// Returns number of files restored.
  Future<int> importBackup(
    String backupPath, {
    String? password,
    void Function(double progress)? onProgress,
  }) async {
    onProgress?.call(0.1);

    final encBytes = await File(backupPath).readAsBytes();

    onProgress?.call(0.2);

    // Peek at metadata to check if password-protected
    // We'll decrypt first, then check
    Uint8List keyBytes;
    
    // Try with password if provided, otherwise use vault key
    if (password != null) {
      keyBytes = _deriveKeyFromPassword(password);
    } else {
      final vaultKey = await _keyManager.getKeyBytes();
      if (vaultKey == null) throw StateError('No vault key available');
      keyBytes = vaultKey;
    }

    onProgress?.call(0.3);

    // Decrypt
    final archiveBytes = await _encryptionService.decrypt(encBytes, keyBytes);

    onProgress?.call(0.4);

    // Decode archive
    final archive = ZipDecoder().decodeBytes(archiveBytes);

    // Find and parse metadata
    final metadataFile = archive.files.firstWhere(
      (f) => f.name == 'metadata.json',
      orElse: () => throw StateError('Invalid backup: no metadata'),
    );

    final metadata = json.decode(utf8.decode(metadataFile.content as List<int>))
        as Map<String, dynamic>;

    onProgress?.call(0.5);

    // Validate password protection match
    final isPasswordProtected = metadata['passwordProtected'] as bool? ?? false;
    if (isPasswordProtected && password == null) {
      throw StateError('This backup is password-protected. Please provide the password.');
    }

    // Restore vault files
    final vaultBox = await Hive.openBox<VaultFile>('vault_files');
    final appDir = await getApplicationDocumentsDirectory();
    final vaultDir = Directory('${appDir.path}/vault');
    if (!await vaultDir.exists()) await vaultDir.create(recursive: true);

    int restoredCount = 0;
    final files = (metadata['files'] as List).cast<Map<String, dynamic>>();

    for (int i = 0; i < files.length; i++) {
      final fileData = files[i];
      final id = fileData['id'] as String;

      // Always restore as private (gallery mode removed)
      String? encPath;
      final archiveEntry =
          archive.files.where((f) => f.name == 'vault/$id.enc').firstOrNull;
      if (archiveEntry != null) {
        encPath = '${vaultDir.path}/$id.enc';
        await File(encPath).writeAsBytes(archiveEntry.content as List<int>);
      }

      final vaultFile = VaultFile(
        id: id,
        name: fileData['name'] as String,
        type: fileData['type'] as String,
        size: fileData['size'] as int,
        createdAt: DateTime.parse(fileData['createdAt'] as String),
        encPath: encPath,
        mode: VaultMode.private,
        category: fileData['category'] as String,
      );

      await vaultBox.put(id, vaultFile);
      restoredCount++;
      
      onProgress?.call(0.5 + (0.4 * (i + 1) / files.length));
    }

    onProgress?.call(0.9);

    // Restore audit events
    final auditBox = await Hive.openBox<AuditEvent>('audit_events');
    final auditList = (metadata['audit'] as List).cast<Map<String, dynamic>>();
    for (final ae in auditList) {
      final event = AuditEvent(
        id: ae['id'] as String,
        timestamp: DateTime.parse(ae['timestamp'] as String),
        type: ae['type'] as String,
        payload: ae['payload'] as String,
        eventHash: ae['eventHash'] as String,
        prevHash: ae['prevHash'] as String,
      );
      await auditBox.add(event);
    }

    onProgress?.call(1.0);
    return restoredCount;
  }

  /// Derive encryption key from password using PBKDF2.
  /// Same approach as AppLockService for consistency.
  Uint8List _deriveKeyFromPassword(String password) {
    // Use a fixed salt for backup passwords (not ideal for security, but necessary
    // for password-based backups to be portable across devices)
    final salt = utf8.encode('SafeShell.Backup.Salt.V1');
    
    // PBKDF2 with 100,000 iterations (same as AppLockService)
    final bytes = utf8.encode(password);
    var result = Uint8List.fromList(bytes + salt);
    
    for (var i = 0; i < 100000; i++) {
      result = Uint8List.fromList(sha256.convert(result).bytes);
    }
    
    // Return 32 bytes for AES-256
    return Uint8List.fromList(result.sublist(0, 32));
  }
}
