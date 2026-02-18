import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// Lightweight connectivity checker using DNS lookup.
/// No external packages needed.
class ConnectivityService {
  ConnectivityService._();
  static final ConnectivityService instance = ConnectivityService._();

  final ValueNotifier<bool> isOnline = ValueNotifier<bool>(true);

  Timer? _timer;

  /// Start periodic connectivity checks.
  void startMonitoring({Duration interval = const Duration(seconds: 10)}) {
    _check(); // immediate
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) => _check());
  }

  /// Stop monitoring.
  void stopMonitoring() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _check() async {
    try {
      final result = await InternetAddress.lookup(
        'google.com',
      ).timeout(const Duration(seconds: 5));
      isOnline.value = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      isOnline.value = false;
    }
  }

  /// One-shot check.
  Future<bool> checkNow() async {
    await _check();
    return isOnline.value;
  }
}
