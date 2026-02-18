import 'package:flutter/material.dart';
import '../security/app_lock_service.dart';
import '../security/biometric_service.dart';
import '../app/theme.dart';
import '../ui/widgets/premium_ui.dart';

/// Gates ANY destructive or sensitive action with mandatory PIN **or** biometric
/// authentication, regardless of whether the app-lock setting is enabled.
///
/// Actions guarded by SecurityGate:
///   – Clear / Wipe entire vault
///   – Reset / Delete vault keys
///   – Export decrypted files to external storage
///   – Share decrypted files externally
///
/// Honest contract: SecurityGate never intercepts anything at the OS level.
/// It only governs in-app operations initiated by the user within SafeShell.
class SecurityGate {
  static final SecurityGate _instance = SecurityGate._internal();
  factory SecurityGate() => _instance;
  SecurityGate._internal();

  final _appLock = AppLockService();
  final _biometric = BiometricService();

  /// Presents an authentication challenge and returns `true` on success.
  ///
  /// [context] – used to show the PIN dialog.
  /// [action]  – human-readable name of what the user is about to do,
  ///             shown in the dialog (e.g. "Wipe Vault").
  /// [isDestructive] – if true, colours the confirm button red.
  Future<bool> authorize(
    BuildContext context, {
    required String action,
    bool isDestructive = false,
  }) async {
    if (!context.mounted) return false;

    // Prefer biometrics when available (faster UX)
    final hasBio = await _biometric.isAvailable();
    if (hasBio) {
      final ok = await _biometric.authenticate(
        reason: 'Confirm: $action',
      );
      if (ok) return true;
      // Bio failed / cancelled — fall through to PIN
    }

    if (!context.mounted) return false;
    final hasPinSet = await _appLock.hasPinSet();
    if (!hasPinSet) {
      if (!context.mounted) return false;
      // ignore: use_build_context_synchronously
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: SafeShellTheme.bgCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Set a PIN first',
            style: TextStyle(color: SafeShellTheme.textPrimary),
          ),
          content: const Text(
            'Destructive actions require a PIN to be set.\n'
            'Go to Settings → App Lock to configure one.',
            style: TextStyle(color: SafeShellTheme.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return false;
    }

    if (!context.mounted) return false;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _SecurityGateDialog(
        action: action,
        isDestructive: isDestructive,
        appLock: _appLock,
      ),
    );
    return confirmed ?? false;
  }
}

// ─── Internal PIN Dialog ─────────────────────────────────────────────────────

class _SecurityGateDialog extends StatefulWidget {
  final String action;
  final bool isDestructive;
  final AppLockService appLock;

  const _SecurityGateDialog({
    required this.action,
    required this.isDestructive,
    required this.appLock,
  });

  @override
  State<_SecurityGateDialog> createState() => _SecurityGateDialogState();
}

class _SecurityGateDialogState extends State<_SecurityGateDialog> {
  String? _error;
  bool _verifying = false;

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
        _error = 'Incorrect PIN — try again';
        _verifying = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: SafeShellTheme.bgCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              widget.isDestructive
                  ? Icons.warning_amber_rounded
                  : Icons.lock_outline,
              color: widget.isDestructive
                  ? SafeShellTheme.error
                  : SafeShellTheme.accent,
              size: 48,
            ),
            const SizedBox(height: 12),
            Text(
              widget.action,
              style: const TextStyle(
                color: SafeShellTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            const Text(
              'Enter your PIN to confirm this action.',
              style: TextStyle(
                color: SafeShellTheme.textMuted,
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (_verifying)
              const SizedBox(
                height: 48,
                child: Center(
                  child: CircularProgressIndicator(
                    color: SafeShellTheme.accent,
                    strokeWidth: 2,
                  ),
                ),
              )
            else
              PinInput(
                error: _error,
                onCompleted: _verify,
              ),
            const SizedBox(height: 8),
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
