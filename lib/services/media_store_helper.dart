import 'dart:io';
import 'package:flutter/services.dart';

class MediaStoreHelper {
  static const MethodChannel _channel = MethodChannel(
    'com.safeshell/media_store',
  );

  /// Attempts to delete a file using platform-specific logic.
  ///
  /// On Android, this tries standard [File.delete] first, and if that fails
  /// (common in Scoped Storage for gallery files), it falls back to finding
  /// the MediaStore URI and deleting via ContentResolver.
  static Future<void> deleteFile(String path) async {
    try {
      await _channel.invokeMethod('deleteFile', {'path': path});
    } on PlatformException catch (e) {
      throw FileSystemException('Failed to delete file: ${e.message}', path);
    }
  }
}
