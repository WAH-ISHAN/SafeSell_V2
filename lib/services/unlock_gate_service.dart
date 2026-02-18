import 'package:flutter/material.dart';
import '../security/app_lock_service.dart';
import '../security/biometric_service.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/app_settings.dart';
import '../app/theme.dart';

/// Service to gate sensitive operations (export, share, open, delete) with unlock verification.
/// Uses PIN or biometric authentication before allowing the action to proceed.
class UnlockGateService {
  final AppLockService _appLock = AppLockService();
  final BiometricService _biometric = BiometricService();

  /// Show unlock dialog and return true if user successfully authenticated.
  /// Returns false if user cancels or fails authentication.
  Future<bool> requestUnlock(
    BuildContext context, {
    required String title,
    String? subtitle,
  }) async {
    final box = Hive.box<AppSettings>('app_settings_typed');
    final settings = box.get('settings') ?? AppSettings();

    if (!settings.lockEnabled) {
      // Lock not enabled - allow operation
      return true;
    }

    // Try biometric first if available and enabled
    final hasBiometric = await _biometric.isAvailable();
    if (hasBiometric && settings.lockMode.contains('biometric')) {
      final bioResult = await _biometric.authenticate(
        reason: subtitle ?? 'Authenticate to continue',
      );
      if (bioResult) return true;
    }

    // Fall back to PIN dialog
    if (settings.lockMode.contains('pin')) {
      if (!context.mounted) return false;
      final result = await showDialog<bool>(
        context: context,
        barrierDismissible: true,
        builder: (ctx) => _UnlockDialog(
          title: title,
          subtitle: subtitle,
          appLock: _appLock,
        ),
      );
      return result ?? false;
    }

    // Lock enabled but no auth method configured - deny
    return false;
  }
}

class _UnlockDialog extends StatefulWidget {
  final String title;
  final String? subtitle;
  final AppLockService appLock;

  const _UnlockDialog({
    required this.title,
    this.subtitle,
    required this.appLock,
  });

  @override
  State<_UnlockDialog> createState() => _UnlockDialogState();
}

class _UnlockDialogState extends State<_UnlockDialog> {
  String? _error;
  bool _verifying = false;
  final _pinController = TextEditingController();
  final _pinFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    // Auto-focus the PIN field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pinFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _pinController.dispose();
    _pinFocus.dispose();
    super.dispose();
  }

  Future<void> _verify(String pin) async {
    setState(() {
      _verifying = true;
      _error = null;
    });

    final valid = await widget.appLock.verifyPin(pin);
    if (!mounted) return;

    if (valid) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _error = 'Incorrect PIN';
        _verifying = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: SafeShellTheme.bgCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.lock_outline,
              color: SafeShellTheme.accent,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              widget.title,
              style: const TextStyle(
                color: SafeShellTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            if (widget.subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                widget.subtitle!,
                style: const TextStyle(
                  color: SafeShellTheme.textMuted,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 24),
            if (_verifying)
              const CircularProgressIndicator(
                color: SafeShellTheme.accent,
              )
            else
              SizedBox(
                width: 200,
                child: TextField(
                  controller: _pinController,
                  focusNode: _pinFocus,
                  autofocus: true,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  maxLength: 6,
                  style: const TextStyle(
                    color: SafeShellTheme.textPrimary,
                    fontSize: 24,
                    letterSpacing: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    hintText: '••••',
                    hintStyle: TextStyle(
                      color: SafeShellTheme.textMuted.withValues(alpha: 0.3),
                      letterSpacing: 12,
                    ),
                    counterText: '',
                    errorText: _error,
                    errorStyle: const TextStyle(
                      color: SafeShellTheme.error,
                      fontSize: 12,
                    ),
                    filled: true,
                    fillColor: SafeShellTheme.bgDark.withValues(alpha: 0.3),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: SafeShellTheme.textMuted,
                        width: 1,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: SafeShellTheme.accent,
                        width: 2,
                      ),
                    ),
                  ),
                  onSubmitted: (value) {
                    if (value.isNotEmpty) {
                      _verify(value);
                    }
                  },
                ),
              ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text(
                'Cancel',
                style: TextStyle(color: SafeShellTheme.textMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
