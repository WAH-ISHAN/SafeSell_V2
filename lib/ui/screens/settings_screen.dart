import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../models/app_settings.dart';
import '../../models/vault_file.dart';
import '../../security/app_lock_service.dart';

import '../../security/screen_protection_service.dart';
import '../../security/key_manager.dart';
import '../../services/audit_log_service.dart';
import '../../services/billing_service.dart';
import '../../services/file_crypto_store.dart';
import '../../services/stealth_mode_service.dart';
import '../../services/security_gate.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../ui/widgets/premium_ui.dart';
import '../../app/theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late AppSettings _settings;
  bool _loading = true;
  final _screenService = ScreenProtectionService();
  final _auditLog = AuditLogService();
  final _billingService = BillingService();
  final _stealthService = StealthModeService();
  bool _keyRotating = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final box = await Hive.openBox<AppSettings>('app_settings_typed');
    final settings = box.get('settings') ?? AppSettings();
    await _billingService.init();
    if (mounted) {
      setState(() {
        _settings = settings;
        _loading = false;
      });
    }
  }

  Future<void> _saveSettings() async {
    final box = await Hive.openBox<AppSettings>('app_settings_typed');
    await box.put('settings', _settings);
  }

  Future<void> _toggleLock(bool value) async {
    if (value) {
      // Show PIN setup dialog
      final pin = await _showPinSetup();
      if (pin == null) return;
      final lockService = AppLockService();
      await lockService.setPin(pin);
      _settings.lockEnabled = true;
      await _saveSettings();
      await _auditLog.log(
        type: 'lock_enabled',
        details: {'mode': _settings.lockMode},
      );
    } else {
      final lockService = AppLockService();
      await lockService.removePin();
      _settings.lockEnabled = false;
      await _saveSettings();
      await _auditLog.log(type: 'lock_disabled');
    }
    setState(() {});
  }

  Future<String?> _showPinSetup() async {
    String? pin;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        String? firstPin;
        String? error;
        bool confirming = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: SafeShellTheme.bgCard,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Text(
                confirming ? 'Confirm PIN' : 'Set PIN',
                style: const TextStyle(color: SafeShellTheme.textPrimary),
              ),
              content: SizedBox(
                width: 300,
                child: PinInput(
                  error: error,
                  onCompleted: (value) {
                    if (!confirming) {
                      firstPin = value;
                      setDialogState(() {
                        confirming = true;
                        error = null;
                      });
                    } else {
                      if (value == firstPin) {
                        pin = value;
                        Navigator.pop(ctx);
                      } else {
                        setDialogState(() {
                          error = 'PINs do not match';
                          confirming = false;
                        });
                      }
                    }
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
              ],
            );
          },
        );
      },
    );
    return pin;
  }

  Future<void> _toggleScreenProtection(bool value) async {
    await _screenService.setEnabled(value);
    _settings.screenProtectionEnabled = value;
    await _saveSettings();
    setState(() {});
  }

  Future<void> _toggleStealth(bool value) async {
    if (value) {
      // Check if stealth PIN is already set
      final hasPinSet = await _stealthService.hasStealthPinSet();

      if (!hasPinSet) {
        // First time enabling - need to set stealth PIN
        final pin = await _showStealthPinSetup();
        if (pin == null) return; // User cancelled

        await _stealthService.setStealthPin(pin);
      }

      _settings.stealthEnabled = true;
      await _saveSettings();
      await _auditLog.log(
        type: 'stealth_toggle',
        details: {'enabled': true, 'firstTimeSetup': !hasPinSet},
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              hasPinSet
                  ? 'Stealth mode enabled'
                  : 'Stealth mode enabled. Remember your PIN!',
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } else {
      // Disabling stealth mode
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: SafeShellTheme.bgCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Disable Stealth Mode?',
            style: TextStyle(color: SafeShellTheme.textPrimary),
          ),
          content: const Text(
            'This will remove the calculator cover and show SafeShell normally.',
            style: TextStyle(color: SafeShellTheme.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text(
                'Disable',
                style: TextStyle(color: SafeShellTheme.error),
              ),
            ),
          ],
        ),
      );

      if (confirm != true) return;

      _settings.stealthEnabled = false;
      await _saveSettings();
      // Note: We keep the stealth PIN in case user re-enables
      await _auditLog.log(
        type: 'stealth_toggle',
        details: {'enabled': false},
      );
    }
    setState(() {});
  }

  Future<void> _toggleUsbProtection(bool value) async {
    _settings.usbProtection = value;
    await _saveSettings();
    setState(() {});
    await _auditLog.log(
      type: 'usb_protection_toggle',
      details: {'enabled': value},
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            value
                ? 'USB Protection ON — unlock required to export/share'
                : 'USB Protection OFF',
          ),
        ),
      );
    }
  }

  /// Show dialog to set up stealth PIN (first time)
  Future<String?> _showStealthPinSetup() async {
    String? pin;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        String? firstPin;
        String? error;
        bool confirming = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: SafeShellTheme.bgCard,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Text(
                confirming ? 'Confirm Stealth PIN' : 'Set Stealth PIN',
                style: const TextStyle(color: SafeShellTheme.textPrimary),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Enter a numeric code ending with "=" to unlock calculator',
                    style: TextStyle(
                      color: SafeShellTheme.textMuted,
                      fontSize: 13,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Example: 1234=',
                    style: TextStyle(
                      color: SafeShellTheme.textMuted,
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: 300,
                    child: TextField(
                      autofocus: true,
                      obscureText: true,
                      style: const TextStyle(color: SafeShellTheme.textPrimary),
                      decoration: InputDecoration(
                        hintText: confirming
                            ? 'Re-enter PIN'
                            : 'Enter PIN (e.g., 1234=)',
                        hintStyle: const TextStyle(
                          color: SafeShellTheme.textMuted,
                          fontSize: 13,
                        ),
                        errorText: error,
                        filled: true,
                        fillColor: SafeShellTheme.bgDark.withValues(alpha: 0.5),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: (value) {
                        if (value.isEmpty || !value.endsWith('=')) {
                          setDialogState(() {
                            error = 'PIN must end with "="';
                          });
                          return;
                        }

                        if (!confirming) {
                          firstPin = value;
                          setDialogState(() {
                            confirming = true;
                            error = null;
                          });
                        } else {
                          if (value == firstPin) {
                            pin = value;
                            Navigator.pop(ctx);
                          } else {
                            setDialogState(() {
                              error = 'PINs do not match';
                              confirming = false;
                              firstPin = null;
                            });
                          }
                        }
                      },
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
              ],
            );
          },
        );
      },
    );
    return pin;
  }

  Future<void> _rotateKey() async {
    if (_keyRotating) return;

    // SecurityGate: key rotation is a destructive action — require auth first
    if (!mounted) return;
    final authed = await SecurityGate().authorize(
      context,
      action: 'Rotate Vault Key',
      isDestructive: true,
    );
    if (!authed || !mounted) return;

    // Prompt for current PIN first
    final pin = await _showPinPrompt('Enter Current PIN');
    if (!mounted) return;
    if (pin == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SafeShellTheme.bgCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text(
          'Rotate Vault Key',
          style: TextStyle(color: SafeShellTheme.textPrimary),
        ),
        content: const Text(
          'This will generate a new key and re-encrypt all private vault files. This may take a while.',
          style: TextStyle(color: SafeShellTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Rotate',
              style: TextStyle(color: SafeShellTheme.accent),
            ),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _keyRotating = true);
    try {
      final keyManager = KeyManager();

      // rotateKey returns the OLD key bytes for re-encryption
      final oldKey = await keyManager.rotateKey(pin, pin);
      final newKeyBytes = await keyManager.getKeyBytes();
      if (newKeyBytes == null) throw StateError('Failed to get new key');

      // Re-encrypt all private vault files
      final store = FileCryptoStore();
      final files = await store.getAllFiles();
      int reEncrypted = 0;
      for (final file in files) {
        if (file.mode == VaultMode.private) {
          await store.reEncryptFile(file.id, oldKey, newKeyBytes);
          reEncrypted++;
        }
      }

      await _auditLog.log(
        type: 'key_rotate',
        details: {'filesCount': files.length, 'reEncrypted': reEncrypted},
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Key rotated — $reEncrypted files re-encrypted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _keyRotating = false);
    }
  }

  /// Prompt the user for a PIN (single entry, no confirmation).
  Future<String?> _showPinPrompt(String title) async {
    String? result;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: SafeShellTheme.bgCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            title,
            style: const TextStyle(color: SafeShellTheme.textPrimary),
          ),
          content: SizedBox(
            width: 300,
            child: PinInput(
              onCompleted: (value) {
                result = value;
                Navigator.pop(ctx);
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
    return result;
  }

  Future<void> _clearCache() async {
    imageCache.clear();
    imageCache.clearLiveImages();
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Cache cleared')));
    }
  }

  Future<void> _purchasePro() async {
    await _billingService.purchasePro();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: PremiumBackground(
          child: Center(
            child: CircularProgressIndicator(color: SafeShellTheme.accent),
          ),
        ),
      );
    }

    return Scaffold(
      body: PremiumBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                ShaderMask(
                  shaderCallback: (b) =>
                      SafeShellTheme.accentGradient.createShader(b),
                  child: const Text(
                    'Settings',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Security section
                const _SectionTitle('Security'),
                _toggleCard(
                  'App Lock',
                  'Require biometric/PIN to open',
                  Icons.lock_outline,
                  _settings.lockEnabled,
                  _toggleLock,
                ),
                _toggleCard(
                  'Screen Protection',
                  'Block screenshots & recents preview',
                  Icons.security,
                  _settings.screenProtectionEnabled,
                  _toggleScreenProtection,
                ),
                _toggleCard(
                  'Stealth Mode',
                  'Show calculator as app cover',
                  Icons.calculate,
                  _settings.stealthEnabled,
                  _toggleStealth,
                ),
                _toggleCard(
                  'USB Protection',
                  'Require unlock to export or share files',
                  Icons.usb,
                  _settings.usbProtection,
                  _toggleUsbProtection,
                ),

                if (_settings.lockEnabled && _settings.isPro)
                  _toggleCard(
                    'Panic Wipe',
                    'Wipe vault after too many failed attempts',
                    Icons.warning_amber,
                    _settings.panicWipeEnabled,
                    (v) async {
                      _settings.panicWipeEnabled = v;
                      await _saveSettings();
                      setState(() {});
                    },
                  ),

                // New Security Options
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      _dropdownRow(
                        label: 'Auto-Lock Timeout',
                        subtitle: 'Lock vault after app is backgrounded',
                        icon: Icons.timer,
                        value: _settings.lockAfterSeconds,
                        items: {
                          0: 'Immediate',
                          10: '10 seconds',
                          30: '30 seconds',
                          60: '1 minute',
                          300: '5 minutes',
                        },
                        onChanged: (v) async {
                          if (v != null) {
                            _settings.lockAfterSeconds = v;
                            await _saveSettings();
                            setState(() {});
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      _dropdownRow(
                        label: 'Clear Clipboard',
                        subtitle: 'Auto-clear copied text after delay',
                        icon: Icons.content_paste_off,
                        value: _settings.clipboardClearSeconds,
                        items: {
                          0: 'Disabled',
                          15: '15 seconds',
                          30: '30 seconds',
                          60: '1 minute',
                        },
                        onChanged: (v) async {
                          if (v != null) {
                            _settings.clipboardClearSeconds = v;
                            await _saveSettings();
                            setState(() {});
                          }
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),
                const _SectionTitle('Import Mode'),
                GlassCard(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Default when adding files',
                        style: TextStyle(
                          color: SafeShellTheme.textMuted,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _importModeOption(
                        label: 'Move to SafeShell (recommended)',
                        subtitle:
                            'Encrypt file in vault, delete original from device',
                        value: 'move',
                        icon: Icons.drive_file_move,
                        iconColor: SafeShellTheme.accentAlt,
                      ),
                      const SizedBox(height: 4),
                      _importModeOption(
                        label: 'Copy to SafeShell',
                        subtitle: 'Encrypt file in vault, keep original',
                        value: 'copy',
                        icon: Icons.copy,
                        iconColor: SafeShellTheme.accent,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),
                const _SectionTitle('Protected Viewer'),
                GlassCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.shield,
                              color: SafeShellTheme.accent, size: 22),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Protected Viewer',
                                  style: TextStyle(
                                    color: SafeShellTheme.textPrimary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  'View images/videos behind authentication',
                                  style: TextStyle(
                                    color: SafeShellTheme.textMuted,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'To use SafeShell as your default viewer, open a photo '
                        'or video from your gallery, tap the share/open-with icon, '
                        'and choose SafeShell. You can pin it as default from '
                        'Android Settings → Apps → SafeShell → Open by default.',
                        style: TextStyle(
                          color: SafeShellTheme.textMuted,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: () => openAppSettings(),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            gradient: SafeShellTheme.accentGradient,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.open_in_new,
                                  color: Colors.white, size: 16),
                              SizedBox(width: 8),
                              Text(
                                'Open App Settings',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),
                const _SectionTitle('Advanced'),
                GlassCard(
                  onTap: _keyRotating
                      ? null
                      : (_settings.isPro ? _rotateKey : null),
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.autorenew,
                        color: SafeShellTheme.accentAlt,
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Rotate Vault Key',
                              style: TextStyle(
                                color: SafeShellTheme.textPrimary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              _settings.isPro
                                  ? 'Re-encrypt all files with new key'
                                  : 'PRO feature',
                              style: const TextStyle(
                                color: SafeShellTheme.textMuted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_keyRotating)
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: SafeShellTheme.accent,
                          ),
                        )
                      else if (!_settings.isPro)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            gradient: SafeShellTheme.accentGradient,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'PRO',
                            style: TextStyle(
                              color: SafeShellTheme.bgDark,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                GlassCard(
                  onTap: () => context.go('/backup'),
                  padding: const EdgeInsets.all(16),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.backup,
                        color: SafeShellTheme.accent,
                        size: 22,
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Backup & Restore',
                        style: TextStyle(
                          color: SafeShellTheme.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Spacer(),
                      Icon(
                        Icons.chevron_right,
                        color: SafeShellTheme.textMuted,
                      ),
                    ],
                  ),
                ),

                GlassCard(
                  onTap: () => context.go('/security-logs'),
                  padding: const EdgeInsets.all(16),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.history,
                        color: SafeShellTheme.accent,
                        size: 22,
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Security Logs',
                        style: TextStyle(
                          color: SafeShellTheme.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Spacer(),
                      Icon(
                        Icons.chevron_right,
                        color: SafeShellTheme.textMuted,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),
                const _SectionTitle('Performance'),
                GlassCard(
                  onTap: _clearCache,
                  padding: const EdgeInsets.all(16),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.memory,
                        color: SafeShellTheme.warning,
                        size: 22,
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'RAM Optimization',
                              style: TextStyle(
                                color: SafeShellTheme.textPrimary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              'Clear image cache and in-memory data',
                              style: TextStyle(
                                color: SafeShellTheme.textMuted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.cleaning_services,
                        color: SafeShellTheme.textMuted,
                      ),
                    ],
                  ),
                ),

                if (!_settings.isPro) ...[
                  const SizedBox(height: 16),
                  const _SectionTitle('Upgrade'),
                  GlassCard(
                    borderColor: SafeShellTheme.accent.o(0.3),
                    child: Column(
                      children: [
                        ShaderMask(
                          shaderCallback: (b) =>
                              SafeShellTheme.accentGradient.createShader(b),
                          child: const Icon(
                            Icons.workspace_premium,
                            size: 40,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Upgrade to Pro',
                          style: TextStyle(
                            color: SafeShellTheme.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Key rotation • Panic wipe • Advanced checks',
                          style: TextStyle(
                            color: SafeShellTheme.textMuted,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 16),
                        GradientButton(
                          text: 'Subscribe',
                          onPressed: _purchasePro,
                          icon: Icons.star,
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _importModeOption({
    required String label,
    required String subtitle,
    required String value,
    required IconData icon,
    required Color iconColor,
  }) {
    final selected = _settings.importMode == value;
    return GestureDetector(
      onTap: () async {
        _settings.importMode = value;
        await _saveSettings();
        setState(() {});
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? SafeShellTheme.accent.withValues(alpha: 0.12)
              : Colors.transparent,
          border: Border.all(
            color: selected
                ? SafeShellTheme.accent.withValues(alpha: 0.4)
                : SafeShellTheme.glassBorder,
            width: 1,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: selected
                          ? SafeShellTheme.textPrimary
                          : SafeShellTheme.textSecondary,
                      fontWeight:
                          selected ? FontWeight.w600 : FontWeight.normal,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: SafeShellTheme.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle,
                  color: SafeShellTheme.accent, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _toggleCard(
    String title,
    String subtitle,
    IconData icon,
    bool value,
    Function(bool) onChanged,
  ) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(icon, color: SafeShellTheme.accent, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: SafeShellTheme.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: SafeShellTheme.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: SafeShellTheme.accent,
            inactiveTrackColor: SafeShellTheme.glassBorder,
          ),
        ],
      ),
    );
  }

  Widget _dropdownRow<T>({
    required String label,
    required String subtitle,
    required IconData icon,
    required T value,
    required Map<T, String> items,
    required ValueChanged<T?> onChanged,
  }) {
    return GlassCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: SafeShellTheme.accent, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: SafeShellTheme.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: SafeShellTheme.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          DropdownButton<T>(
            value: value,
            dropdownColor: SafeShellTheme.bgCard,
            underline: const SizedBox.shrink(),
            icon: const Icon(Icons.keyboard_arrow_down,
                color: SafeShellTheme.accent),
            style: const TextStyle(
                color: SafeShellTheme.accent,
                fontSize: 13,
                fontWeight: FontWeight.bold),
            items: items.entries.map((e) {
              return DropdownMenuItem<T>(
                value: e.key,
                child: Text(e.value),
              );
            }).toList(),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 20, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          color: SafeShellTheme.textMuted,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 1,
        ),
      ),
    );
  }
}
