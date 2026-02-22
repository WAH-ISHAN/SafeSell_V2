import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../security/key_manager.dart';
import '../services/audit_log_service.dart';

/// Listens for USB device attach/detach events from native Android code
/// and auto-locks the vault when a USB device is connected.
class UsbProtectionService {
  static final UsbProtectionService _instance =
      UsbProtectionService._internal();
  factory UsbProtectionService() => _instance;
  UsbProtectionService._internal();

  static const _eventChannel = EventChannel('com.safeshell/usb_events');
  final _auditLog = AuditLogService();
  final _keyManager = KeyManager();

  StreamSubscription? _subscription;

  /// Observable state of USB connection
  final ValueNotifier<bool> isUsbConnected = ValueNotifier<bool>(false);

  /// Callback to navigate to lock screen (set by the widget that owns navigation)
  VoidCallback? onLockTriggered;

  /// Start listening for USB events.
  void startListening() {
    _subscription?.cancel();
    _subscription = _eventChannel.receiveBroadcastStream().listen(
          _onEvent,
          onError: (e) => debugPrint('[SafeShell] USB event error: $e'),
        );
  }

  void stopListening() {
    _subscription?.cancel();
    _subscription = null;
  }

  void _onEvent(dynamic event) async {
    if (event is! Map) return;
    final type = event['type'] as String?;

    if (type == 'usb_attached') {
      debugPrint('[SafeShell] USB device attached — locking vault');
      isUsbConnected.value = true;
      _keyManager.lock();

      await _auditLog.log(
        type: 'usb_protection',
        details: {'event': 'usb_attached', 'action': 'vault_locked'},
      );

      // Trigger navigation to lock screen
      onLockTriggered?.call();
    } else if (type == 'usb_detached') {
      debugPrint('[SafeShell] USB device detached');
      isUsbConnected.value = false;
      await _auditLog.log(
        type: 'usb_protection',
        details: {'event': 'usb_detached'},
      );
    }
  }

  void dispose() {
    stopListening();
  }
}
