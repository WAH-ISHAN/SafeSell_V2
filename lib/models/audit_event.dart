import 'package:hive/hive.dart';

part 'audit_event.g.dart';

@HiveType(typeId: 2)
class AuditEvent extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final DateTime timestamp;

  @HiveField(2)
  final String type; // login, unlock, failed_unlock, file_add, file_open, file_delete, key_setup, stealth_toggle, key_rotate, backup_export, backup_import

  @HiveField(3)
  final String payload; // JSON string

  @HiveField(4)
  final String eventHash;

  @HiveField(5)
  final String prevHash;

  AuditEvent({
    required this.id,
    required this.timestamp,
    required this.type,
    required this.payload,
    required this.eventHash,
    required this.prevHash,
  });
}
