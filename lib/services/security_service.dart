import 'dart:async';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/app_settings.dart';
import '../security/key_manager.dart';

class SecurityService {
  static final SecurityService _instance = SecurityService._internal();
  factory SecurityService() => _instance;
  SecurityService._internal();

  Timer? _clipboardTimer;
  final _secureStorage = const FlutterSecureStorage();

  /// Automatically clear clipboard after the configured delay
  void scheduleClipboardClear() {
    _clipboardTimer?.cancel();

    try {
      final box = Hive.box<AppSettings>('app_settings_typed');
      final settings = box.get('settings') ?? AppSettings();

      if (settings.clipboardClearSeconds > 0) {
        _clipboardTimer =
            Timer(Duration(seconds: settings.clipboardClearSeconds), () async {
          final data = await Clipboard.getData(Clipboard.kTextPlain);
          if (data != null) {
            await Clipboard.setData(const ClipboardData(text: ''));
            print('[Security] Clipboard cleared automatically');
          }
        });
      }
    } catch (_) {}
  }

  /// Perform a "Panic Wipe" — delete all local data and keys
  Future<void> performPanicWipe() async {
    print('[Security] PERFOMING PANIC WIPE...');

    // 1. Clear Hive boxes
    await Hive.deleteFromDisk();

    // 2. Clear Secure Storage (Keys)
    await _secureStorage.deleteAll();

    // 3. Clear KeyManager (Memory)
    KeyManager().lock();

    // 4. Restart or exit app (we'll just let the next restart handle the empty state)
  }

  void dispose() {
    _clipboardTimer?.cancel();
  }
}
