import 'package:hive/hive.dart';

part 'vault_file.g.dart';

@HiveType(typeId: 0)
enum VaultMode {
  @HiveField(0)
  private,
  @HiveField(1)
  galleryProtected,
}

@HiveType(typeId: 1)
class VaultFile extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String type; // mime type

  @HiveField(3)
  final int size; // bytes

  @HiveField(4)
  final DateTime createdAt;

  @HiveField(5)
  final String? encPath; // for private mode

  @HiveField(6)
  final String? uri; // for gallery_protected mode

  @HiveField(7)
  final VaultMode mode;

  @HiveField(8)
  final String category; // photos, videos, docs, zip, apk, other

  VaultFile({
    required this.id,
    required this.name,
    required this.type,
    required this.size,
    required this.createdAt,
    this.encPath,
    this.uri,
    required this.mode,
    required this.category,
  });

  VaultFile copyWith({
    String? id,
    String? name,
    String? type,
    int? size,
    DateTime? createdAt,
    String? encPath,
    String? uri,
    VaultMode? mode,
    String? category,
  }) {
    return VaultFile(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      size: size ?? this.size,
      createdAt: createdAt ?? this.createdAt,
      encPath: encPath ?? this.encPath,
      uri: uri ?? this.uri,
      mode: mode ?? this.mode,
      category: category ?? this.category,
    );
  }

  static String categorize(String mimeType) {
    if (mimeType.startsWith('image/')) {
      return 'photos';
    }
    if (mimeType.startsWith('video/')) {
      return 'videos';
    }
    if (mimeType.startsWith('application/pdf') ||
        mimeType.startsWith('text/') ||
        mimeType.contains('document') ||
        mimeType.contains('spreadsheet') ||
        mimeType.contains('presentation')) {
      return 'docs';
    }
    if (mimeType.contains('zip') ||
        mimeType.contains('rar') ||
        mimeType.contains('tar') ||
        mimeType.contains('gzip')) {
      return 'zip';
    }
    if (mimeType.contains('android') || mimeType.contains('apk')) {
      return 'apk';
    }
    return 'other';
  }
}
