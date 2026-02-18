import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/registered_device.dart';

class DeviceInfoService extends ChangeNotifier {
  static const _boxName = 'registered_devices';
  static const _currentDeviceIdKey = 'current_device_id';

  final DeviceInfoPlugin _plugin = DeviceInfoPlugin();
  Box<RegisteredDevice>? _box;

  bool _loading = true;
  bool get loading => _loading;

  List<RegisteredDevice> get devices =>
      _box?.values.toList().reversed.toList() ?? [];

  RegisteredDevice? get currentDevice => _box?.values
      .where((d) => d.isCurrentDevice)
      .fold<RegisteredDevice?>(null, (_, e) => e);

  // ── Initialisation ───────────────────────────────────────────────────────

  Future<void> init() async {
    if (!Hive.isAdapterRegistered(RegisteredDeviceAdapter().typeId)) {
      Hive.registerAdapter(RegisteredDeviceAdapter());
    }
    _box = await Hive.openBox<RegisteredDevice>(_boxName);
    await _registerCurrentDeviceIfNeeded();
    _loading = false;
    notifyListeners();
  }

  Future<void> _registerCurrentDeviceIfNeeded() async {
    final prefs = await _getPrefs();
    String? storedId = prefs[_currentDeviceIdKey] as String?;

    // Check if the device is already in box
    if (storedId != null && _box!.containsKey(storedId)) {
      // Just update lastSeenAt
      final d = _box!.get(storedId)!;
      d.lastSeenAt = DateTime.now();
      await d.save();
      return;
    }

    // Build real device info
    final info = await _buildCurrentDeviceInfo();
    storedId = const Uuid().v4();

    final device = RegisteredDevice(
      id: storedId,
      name: info.friendlyName,
      model: info.model,
      osVersion: info.osVersion,
      platform: info.platform,
      registeredAt: DateTime.now(),
      lastSeenAt: DateTime.now(),
      isTrusted: true,
      isCurrentDevice: true,
    );

    await _box!.put(storedId, device);
    // persist id for next launch
    final box2 = await Hive.openBox<String>('device_prefs');
    await box2.put(_currentDeviceIdKey, storedId);
  }

  // ── Device info collection ───────────────────────────────────────────────

  Future<_RawDeviceInfo> _buildCurrentDeviceInfo() async {
    try {
      if (Platform.isAndroid) {
        final a = await _plugin.androidInfo;
        return _RawDeviceInfo(
          friendlyName: '${a.brand} ${a.model}',
          model: a.model,
          osVersion: 'Android ${a.version.release} (API ${a.version.sdkInt})',
          platform: 'android',
        );
      } else if (Platform.isIOS) {
        final i = await _plugin.iosInfo;
        return _RawDeviceInfo(
          friendlyName: i.name,
          model: i.model,
          osVersion: 'iOS ${i.systemVersion}',
          platform: 'ios',
        );
      } else if (Platform.isWindows) {
        final w = await _plugin.windowsInfo;
        return _RawDeviceInfo(
          friendlyName: w.computerName,
          model: 'Windows PC',
          osVersion: 'Windows ${w.majorVersion}.${w.minorVersion}',
          platform: 'windows',
        );
      } else if (Platform.isMacOS) {
        final m = await _plugin.macOsInfo;
        return _RawDeviceInfo(
          friendlyName: m.computerName,
          model: m.model,
          osVersion: 'macOS ${m.osRelease}',
          platform: 'macos',
        );
      } else if (Platform.isLinux) {
        final l = await _plugin.linuxInfo;
        return _RawDeviceInfo(
          friendlyName: l.prettyName,
          model: l.name,
          osVersion: l.version ?? l.versionId ?? 'Linux',
          platform: 'linux',
        );
      }
    } catch (_) {}

    return const _RawDeviceInfo(
      friendlyName: 'This Device',
      model: 'Unknown',
      osVersion: 'Unknown OS',
      platform: 'unknown',
    );
  }

  // ── Public API ───────────────────────────────────────────────────────────

  /// Rename a device
  Future<void> renameDevice(RegisteredDevice device, String newName) async {
    device.name = newName.trim().isEmpty ? device.model : newName.trim();
    await device.save();
    notifyListeners();
  }

  /// Toggle trust status
  Future<void> toggleTrust(RegisteredDevice device) async {
    device.isTrusted = !device.isTrusted;
    await device.save();
    notifyListeners();
  }

  /// Remove a (non-current) device
  Future<void> removeDevice(RegisteredDevice device) async {
    if (device.isCurrentDevice) return; // cannot remove self
    await _box!.delete(device.id);
    notifyListeners();
  }

  /// Get live hardware info snapshot for the current device
  Future<Map<String, String>> getCurrentDeviceDetails() async {
    final info = await _buildCurrentDeviceInfo();
    return {
      'Device Name': info.friendlyName,
      'Model': info.model,
      'OS': info.osVersion,
      'Platform': info.platform,
    };
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> _getPrefs() async {
    try {
      final box = await Hive.openBox<String>('device_prefs');
      return Map<String, dynamic>.fromEntries(
        box.keys.map((k) => MapEntry(k.toString(), box.get(k))),
      );
    } catch (_) {
      return {};
    }
  }
}

class _RawDeviceInfo {
  final String friendlyName;
  final String model;
  final String osVersion;
  final String platform;

  const _RawDeviceInfo({
    required this.friendlyName,
    required this.model,
    required this.osVersion,
    required this.platform,
  });
}
