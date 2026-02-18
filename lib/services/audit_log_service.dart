import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/audit_event.dart';

/// Tamper-evident audit log using chained SHA-256 hashes.
/// Each event hash = SHA256(prevHash + JSON(payload))
class AuditLogService {
  static const _boxName = 'audit_events';
  final Uuid _uuid = const Uuid();

  Box<AuditEvent>? _box;

  Future<Box<AuditEvent>> get box async {
    _box ??= await Hive.openBox<AuditEvent>(_boxName);
    return _box!;
  }

  /// Get the hash of the last event (or genesis hash)
  Future<String> _getLastHash() async {
    final b = await box;
    if (b.isEmpty) return 'GENESIS';
    return b.getAt(b.length - 1)!.eventHash;
  }

  /// Log a new audit event
  Future<void> log({
    required String type,
    Map<String, dynamic>? details,
  }) async {
    final b = await box;
    final prevHash = await _getLastHash();
    final payload = json.encode({
      'type': type,
      'timestamp': DateTime.now().toIso8601String(),
      'details': details ?? {},
    });

    final hashInput = prevHash + payload;
    final eventHash = sha256.convert(utf8.encode(hashInput)).toString();

    final event = AuditEvent(
      id: _uuid.v4(),
      timestamp: DateTime.now(),
      type: type,
      payload: payload,
      eventHash: eventHash,
      prevHash: prevHash,
    );

    await b.add(event);
  }

  /// Verify the entire audit chain integrity
  Future<AuditVerification> verifyChain() async {
    final b = await box;
    if (b.isEmpty) {
      return const AuditVerification(
        isValid: true,
        totalEvents: 0,
        message: 'No events to verify',
      );
    }

    String expectedPrevHash = 'GENESIS';
    for (int i = 0; i < b.length; i++) {
      final event = b.getAt(i)!;

      // Check prev hash chain
      if (event.prevHash != expectedPrevHash) {
        return AuditVerification(
          isValid: false,
          totalEvents: b.length,
          brokenAtIndex: i,
          message: 'Chain broken at event $i: prevHash mismatch',
        );
      }

      // Recompute hash
      final hashInput = event.prevHash + event.payload;
      final computedHash = sha256.convert(utf8.encode(hashInput)).toString();
      if (computedHash != event.eventHash) {
        return AuditVerification(
          isValid: false,
          totalEvents: b.length,
          brokenAtIndex: i,
          message: 'Chain broken at event $i: eventHash tampered',
        );
      }

      expectedPrevHash = event.eventHash;
    }

    return AuditVerification(
      isValid: true,
      totalEvents: b.length,
      message: 'All ${b.length} events verified',
    );
  }

  /// Get all events (newest first)
  Future<List<AuditEvent>> getAllEvents() async {
    final b = await box;
    return b.values.toList().reversed.toList();
  }

  /// Get recent events
  Future<List<AuditEvent>> getRecentEvents({int limit = 50}) async {
    final b = await box;
    final all = b.values.toList();
    final start = all.length > limit ? all.length - limit : 0;
    return all.sublist(start).reversed.toList();
  }

  /// Clear all events (for panic wipe)
  Future<void> clearAll() async {
    final b = await box;
    await b.clear();
  }
}

class AuditVerification {
  final bool isValid;
  final int totalEvents;
  final int? brokenAtIndex;
  final String message;

  const AuditVerification({
    required this.isValid,
    required this.totalEvents,
    this.brokenAtIndex,
    required this.message,
  });
}
