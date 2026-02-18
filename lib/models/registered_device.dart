import 'package:hive/hive.dart';

part 'registered_device.g.dart';

@HiveType(typeId: 10)
class RegisteredDevice extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  final String model;

  @HiveField(3)
  final String osVersion;

  @HiveField(4)
  final String platform; // 'android' | 'ios' | 'windows' | 'macos' | 'linux'

  @HiveField(5)
  final DateTime registeredAt;

  @HiveField(6)
  DateTime lastSeenAt;

  @HiveField(7)
  bool isTrusted;

  @HiveField(8)
  final bool isCurrentDevice;

  RegisteredDevice({
    required this.id,
    required this.name,
    required this.model,
    required this.osVersion,
    required this.platform,
    required this.registeredAt,
    required this.lastSeenAt,
    this.isTrusted = true,
    this.isCurrentDevice = false,
  });

  String get displayModel => model.isNotEmpty ? model : name;

  bool get isOnline => isCurrentDevice;

  String get lastSeenText {
    if (isCurrentDevice) return 'Active now';
    final diff = DateTime.now().difference(lastSeenAt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    return '${diff.inDays} days ago';
  }
}
