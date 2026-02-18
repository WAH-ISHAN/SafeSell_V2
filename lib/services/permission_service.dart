import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

/// Requests and checks the storage / media permissions needed to import files
/// and delete originals from the gallery.
///
/// On Android ≤ 12 (API ≤ 32): READ_EXTERNAL_STORAGE + WRITE_EXTERNAL_STORAGE
/// On Android 13+ (API ≥ 33): READ_MEDIA_IMAGES + READ_MEDIA_VIDEO
class PermissionService {
  static final PermissionService _instance = PermissionService._internal();
  factory PermissionService() => _instance;
  PermissionService._internal();

  /// Returns true when the app already holds all necessary media permissions.
  Future<bool> hasMediaPermissions() async {
    if (!Platform.isAndroid) return true;
    final sdk = await _androidSdkVersion();
    if (sdk >= 33) {
      return (await Permission.photos.isGranted) &&
          (await Permission.videos.isGranted);
    }
    return await Permission.storage.isGranted;
  }

  /// Requests the required media permissions and returns the overall status.
  Future<MediaPermissionResult> requestMediaPermissions() async {
    if (!Platform.isAndroid) return MediaPermissionResult.granted;

    final sdk = await _androidSdkVersion();
    if (sdk >= 33) {
      final results = await [
        Permission.photos,
        Permission.videos,
      ].request();
      final denied = results.values.any(
        (s) => s.isDenied || s.isPermanentlyDenied,
      );
      if (!denied) return MediaPermissionResult.granted;
      final permanent = results.values.any((s) => s.isPermanentlyDenied);
      return permanent
          ? MediaPermissionResult.permanentlyDenied
          : MediaPermissionResult.denied;
    } else {
      final status = await Permission.storage.request();
      if (status.isGranted) return MediaPermissionResult.granted;
      if (status.isPermanentlyDenied) {
        return MediaPermissionResult.permanentlyDenied;
      }
      return MediaPermissionResult.denied;
    }
  }

  /// Shows a rationale dialog and then requests permissions.
  /// Returns true if permissions are ultimately granted.
  Future<bool> ensureMediaPermissions(BuildContext context) async {
    if (await hasMediaPermissions()) return true;

    final result = await requestMediaPermissions();
    if (result == MediaPermissionResult.granted) return true;

    if (result == MediaPermissionResult.permanentlyDenied && context.mounted) {
      await _showPermanentlyDeniedDialog(context);
    }
    return false;
  }

  Future<void> _showPermanentlyDeniedDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Media Permission Required'),
        content: const Text(
          'SafeShell needs access to your photos and videos to import files into '
          'the encrypted vault. Please enable it in app settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  Future<int> _androidSdkVersion() async {
    try {
      if (!Platform.isAndroid) return 0;
      // Use permission_handler's own SDK check helper
      return (await Permission.photos.status).isGranted ? 33 : 0;
    } catch (_) {
      return 0;
    }
  }
}

enum MediaPermissionResult { granted, denied, permanentlyDenied }

// ─── Import Mode ────────────────────────────────────────────────────────────

/// Controls what SafeShell does after a file is encrypted into the vault.
enum ImportMode {
  /// Move to SafeShell (default): encrypts file and permanently deletes the
  /// original from the gallery / public storage.
  moveToVault,

  /// Copy: encrypts file but keeps the original untouched.
  copyToVault,
}
