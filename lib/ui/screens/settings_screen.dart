import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:permission_handler/permission_handler.dart';

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
import '../../ui/widgets/premium_ui.dart';
import '../../app/theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with TickerProviderStateMixin {
  late AppSettings _settings;
  bool _loading = true;
  final _screenService = ScreenProtectionService();
  final _auditLog = AuditLogService();
  final _billingService = BillingService();
  final _stealthService = StealthModeService();
  bool _keyRotating = false;

  late final AnimationController _bgC;

  @override
  void initState() {
    super.initState();
    _bgC = AnimationController(vsync: this, duration: const Duration(seconds: 12))
      ..repeat(reverse: true);
    _load();
  }

  @override
  void dispose() {
    _bgC.dispose();
    super.dispose();
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
      final hasPinSet = await _stealthService.hasStealthPinSet();

      if (!hasPinSet) {
        final pin = await _showStealthPinSetup();
        if (pin == null) return;
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
      await _auditLog.log(type: 'stealth_toggle', details: {'enabled': false});
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
                        hintText:
                            confirming ? 'Re-enter PIN' : 'Enter PIN (e.g., 1234=)',
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
                          setDialogState(() => error = 'PIN must end with "="');
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

    if (!mounted) return;
    final authed = await SecurityGate().authorize(
      context,
      action: 'Rotate Vault Key',
      isDestructive: true,
    );
    if (!authed || !mounted) return;

    final pin = await _showPinPrompt('Enter Current PIN');
    if (!mounted) return;
    if (pin == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SafeShellTheme.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
            child: const Text('Rotate', style: TextStyle(color: SafeShellTheme.accent)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _keyRotating = true);
    try {
      final keyManager = KeyManager();
      final oldKey = await keyManager.rotateKey(pin, pin);
      final newKeyBytes = await keyManager.getKeyBytes();
      if (newKeyBytes == null) throw StateError('Failed to get new key');

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
          SnackBar(content: Text('Key rotated — $reEncrypted files re-encrypted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _keyRotating = false);
    }
  }

  Future<String?> _showPinPrompt(String title) async {
    String? result;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: SafeShellTheme.bgCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(title, style: const TextStyle(color: SafeShellTheme.textPrimary)),
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
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Cache cleared')));
    }
  }

  Future<void> _purchasePro() async {
    await _billingService.purchasePro();
  }

  // ======================= UI-only derived (React perfScore style) =======================

  int _calcPerfScore({required bool backgroundRun, required bool batterySaver, required bool biometrics}) {
    int score = 92;
    if (!backgroundRun) score -= 6;
    if (batterySaver) score -= 4;
    if (!biometrics) score -= 2;
    return score.clamp(70, 99);
  }

  _PerfStatus _statusFor(int score) => _PerfStatus.fromScore(score);

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

    // UI only toggles (React had them)
    final backgroundRun = true; // UI only (no logic change)
    final batterySaver = false; // UI only (no logic change)
    final biometrics = _settings.lockEnabled; // best mapping for display

    final perfScore = _calcPerfScore(
      backgroundRun: backgroundRun,
      batterySaver: batterySaver,
      biometrics: biometrics,
    );
    final status = _statusFor(perfScore);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -0.2),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: Stack(
        children: [
          // ===== Background =====
          Container(color: const Color(0xFF0B0F14)),
          const _PremiumRadialField(
            a: Alignment(-0.70, -0.85),
            aColor: Color(0x1A4DA3FF),
            b: Alignment(0.90, -0.55),
            bColor: Color(0x470A2A4F),
            c: Alignment(-0.30, 0.95),
            cColor: Color(0x124DA3FF),
          ),
          AnimatedBuilder(
            animation: _bgC,
            builder: (_, __) {
              final t = _bgC.value;
              return Stack(
                children: [
                  Positioned(
                    top: -90 + (t * 14),
                    right: -90 - (t * 18),
                    child: _GlowBlob(
                      color: const Color(0xFF4DA3FF).o(0.12),
                      size: 520,
                      blur: 120,
                    ),
                  ),
                  Positioned(
                    bottom: 70 - (t * 12),
                    left: -110 + (t * 16),
                    child: _GlowBlob(
                      color: const Color(0xFF0A2A4F).o(0.30),
                      size: 460,
                      blur: 110,
                    ),
                  ),
                ],
              );
            },
          ),
          const _TopBlur(),

          // ===== Content =====
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 412),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 96),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header text under AppBar (React style)
                      const SizedBox(height: 6),
                      const Text(
                        'Settings',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Customize your vault experience',
                        style: TextStyle(
                          color: const Color(0xFFEAF2FF).o(0.55),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // ===== Overview cards =====
                      GlassCard(
                        padding: const EdgeInsets.all(16),
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: IgnorePointer(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(22),
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        const Color(0xFF4DA3FF).o(0.10),
                                        Colors.transparent,
                                        const Color(0xFF0A2A4F).o(0.12),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    _GradientIconTile(
                                      icon: Icons.trending_up_rounded,
                                      colors: const [Color(0xFF10B981), Color(0xFF059669)],
                                      glow: const Color(0xFF10B981),
                                      size: 48,
                                      radius: 16,
                                      iconSize: 24,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'App Performance',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w800,
                                              fontSize: 16,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${status.text} • $perfScore%',
                                            style: TextStyle(
                                              color: status.color,
                                              fontWeight: FontWeight.w800,
                                              fontSize: 13,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    const _RoundIcon(Icons.memory_rounded),
                                    const SizedBox(width: 8),
                                    const _RoundIcon(Icons.verified_user_outlined),
                                  ],
                                ),

                                const SizedBox(height: 14),

                                ClipRRect(
                                  borderRadius: BorderRadius.circular(999),
                                  child: SizedBox(
                                    height: 10,
                                    child: Stack(
                                      children: [
                                        Container(color: Colors.white.o(0.10)),
                                        AnimatedContainer(
                                          duration: const Duration(milliseconds: 650),
                                          curve: Curves.easeOut,
                                          width: (MediaQuery.of(context).size.width.clamp(320, 412) - 40) *
                                              (perfScore / 100),
                                          decoration: const BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [Color(0xFF10B981), Color(0xFF059669)],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 12),

                                Row(
                                  children: [
                                    Expanded(
                                      child: _MiniStat(
                                        icon: Icons.flash_on_rounded,
                                        label: 'Background',
                                        value: backgroundRun ? 'On' : 'Off',
                                        tone: _MiniTone.neutral,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: _MiniStat(
                                        icon: Icons.battery_saver_rounded,
                                        label: 'Saver',
                                        value: batterySaver ? 'On' : 'Off',
                                        tone: batterySaver ? _MiniTone.warn : _MiniTone.neutral,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: _MiniStat(
                                        icon: Icons.fingerprint_rounded,
                                        label: 'Biometric',
                                        value: biometrics ? 'On' : 'Off',
                                        tone: biometrics ? _MiniTone.good : _MiniTone.warn,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      GlassCard(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        child: Row(
                          children: [
                            _GradientIconTile(
                              icon: Icons.visibility_off_rounded,
                              colors: const [Color(0xFF4DA3FF), Color(0xFF2B7FDB)],
                              glow: const Color(0xFF4DA3FF),
                              size: 40,
                              radius: 14,
                              iconSize: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Stealth Mode',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Ghost / Calculator (planned)',
                                    style: TextStyle(
                                      color: const Color(0xFFEAF2FF).o(0.55),
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            TextButton(
                              onPressed: () {},
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Learn',
                                    style: TextStyle(
                                      color: Color(0xFF4DA3FF),
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12,
                                    ),
                                  ),
                                  SizedBox(width: 2),
                                  Icon(Icons.chevron_right, color: Color(0xFF4DA3FF), size: 18),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 22),

                      // ===== Sections (React style) =====
                      const _SectionTitle2(title: 'System', icon: Icons.auto_awesome_rounded),
                      const SizedBox(height: 10),
                      _toggleCard(
                        'Background Run',
                        'Keep app running in background',
                        Icons.flash_on_rounded,
                        backgroundRun,
                        (_) {}, // UI only (no logic change)
                      ),
                      const SizedBox(height: 10),
                      _toggleCard(
                        'Battery Saver',
                        'Reduce battery consumption',
                        Icons.battery_saver_rounded,
                        batterySaver,
                        (_) {}, // UI only (no logic change)
                      ),

                      const SizedBox(height: 18),
                      const _SectionTitle2(title: 'Security', icon: Icons.lock_rounded),
                      const SizedBox(height: 10),

                      // ===== Existing logic bindings =====
                      _toggleCard(
                        'App Lock',
                        'Require biometric/PIN to open',
                        Icons.lock_outline,
                        _settings.lockEnabled,
                        _toggleLock,
                      ),
                      const SizedBox(height: 10),
                      _toggleCard(
                        'Screen Protection',
                        'Block screenshots & recents preview',
                        Icons.security,
                        _settings.screenProtectionEnabled,
                        _toggleScreenProtection,
                      ),
                      const SizedBox(height: 10),
                      _toggleCard(
                        'Stealth Mode',
                        'Show calculator as app cover',
                        Icons.calculate,
                        _settings.stealthEnabled,
                        _toggleStealth,
                      ),
                      const SizedBox(height: 10),
                      _toggleCard(
                        'USB Protection',
                        'Require unlock to export or share files',
                        Icons.usb,
                        _settings.usbProtection,
                        _toggleUsbProtection,
                      ),

                      if (_settings.lockEnabled && _settings.isPro) ...[
                        const SizedBox(height: 10),
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
                      ],

                      // ===== Dropdown rows (keep) =====
                      const SizedBox(height: 12),
                      _dropdownRow(
                        label: 'Auto-Lock Timeout',
                        subtitle: 'Lock vault after app is backgrounded',
                        icon: Icons.timer,
                        value: _settings.lockAfterSeconds,
                        items: const {
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
                      const SizedBox(height: 10),
                      _dropdownRow(
                        label: 'Clear Clipboard',
                        subtitle: 'Auto-clear copied text after delay',
                        icon: Icons.content_paste_off,
                        value: _settings.clipboardClearSeconds,
                        items: const {0: 'Disabled', 15: '15 seconds', 30: '30 seconds', 60: '1 minute'},
                        onChanged: (v) async {
                          if (v != null) {
                            _settings.clipboardClearSeconds = v;
                            await _saveSettings();
                            setState(() {});
                          }
                        },
                      ),

                      const SizedBox(height: 18),
                      const _SectionTitle2(title: 'Tools', icon: Icons.rotate_left_rounded),
                      const SizedBox(height: 10),

                      // Tools tiles (React section cards)
                      GlassCard(
                        onTap: _clearCache,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        child: const Row(
                          children: [
                            Icon(Icons.memory, color: SafeShellTheme.warning, size: 22),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'RAM Optimization',
                                    style: TextStyle(
                                      color: SafeShellTheme.textPrimary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Free up memory',
                                    style: TextStyle(
                                      color: SafeShellTheme.textMuted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.cleaning_services, color: SafeShellTheme.textMuted),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      GlassCard(
                        onTap: () => context.go('/support'),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        child: const Row(
                          children: [
                            Icon(Icons.headphones_rounded, color: SafeShellTheme.accent, size: 22),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Customer Support',
                                    style: TextStyle(
                                      color: SafeShellTheme.textPrimary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Get help',
                                    style: TextStyle(
                                      color: SafeShellTheme.textMuted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.chevron_right, color: SafeShellTheme.textMuted),
                          ],
                        ),
                      ),

                      const SizedBox(height: 18),

                      // ===== The rest of your original sections (kept) =====
                      const _SectionTitle('Import Mode'),
                      GlassCard(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                              subtitle: 'Encrypt file in vault, delete original from device',
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
                                Icon(Icons.shield, color: SafeShellTheme.accent, size: 22),
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
                              style: TextStyle(color: SafeShellTheme.textMuted, fontSize: 12),
                            ),
                            const SizedBox(height: 12),
                            GestureDetector(
                              onTap: () => openAppSettings(),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                decoration: BoxDecoration(
                                  gradient: SafeShellTheme.accentGradient,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.open_in_new, color: Colors.white, size: 16),
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
                        onTap: _keyRotating ? null : (_settings.isPro ? _rotateKey : null),
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            const Icon(Icons.autorenew, color: SafeShellTheme.accentAlt, size: 22),
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
                                    _settings.isPro ? 'Re-encrypt all files with new key' : 'PRO feature',
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
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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

                      const SizedBox(height: 10),
                      GlassCard(
                        onTap: () => context.go('/backup'),
                        padding: const EdgeInsets.all(16),
                        child: const Row(
                          children: [
                            Icon(Icons.backup, color: SafeShellTheme.accent, size: 22),
                            SizedBox(width: 12),
                            Text(
                              'Backup & Restore',
                              style: TextStyle(
                                color: SafeShellTheme.textPrimary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Spacer(),
                            Icon(Icons.chevron_right, color: SafeShellTheme.textMuted),
                          ],
                        ),
                      ),

                      const SizedBox(height: 10),
                      GlassCard(
                        onTap: () => context.go('/security-logs'),
                        padding: const EdgeInsets.all(16),
                        child: const Row(
                          children: [
                            Icon(Icons.history, color: SafeShellTheme.accent, size: 22),
                            SizedBox(width: 12),
                            Text(
                              'Security Logs',
                              style: TextStyle(
                                color: SafeShellTheme.textPrimary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Spacer(),
                            Icon(Icons.chevron_right, color: SafeShellTheme.textMuted),
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
                                shaderCallback: (b) => SafeShellTheme.accentGradient.createShader(b),
                                child: const Icon(Icons.workspace_premium, size: 40, color: Colors.white),
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

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===== Keep your original helpers =====

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
          color: selected ? SafeShellTheme.accent.withValues(alpha: 0.12) : Colors.transparent,
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
                      color: selected ? SafeShellTheme.textPrimary : SafeShellTheme.textSecondary,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
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
              const Icon(Icons.check_circle, color: SafeShellTheme.accent, size: 18),
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
                  title,
                  style: const TextStyle(
                    color: SafeShellTheme.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
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
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
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
            icon: const Icon(Icons.keyboard_arrow_down, color: SafeShellTheme.accent),
            style: const TextStyle(
              color: SafeShellTheme.accent,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
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

// ===== React-like section title (icon + title row) =====
class _SectionTitle2 extends StatelessWidget {
  final String title;
  final IconData icon;
  const _SectionTitle2({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: Colors.white.o(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.o(0.10)),
          ),
          child: Icon(icon, size: 18, color: SafeShellTheme.accent),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _RoundIcon extends StatelessWidget {
  final IconData icon;
  const _RoundIcon(this.icon);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white.o(0.05),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.o(0.10)),
      ),
      child: Icon(icon, size: 20, color: Colors.white.o(0.80)),
    );
  }
}

class _GradientIconTile extends StatelessWidget {
  final IconData icon;
  final List<Color> colors;
  final Color glow;
  final double size;
  final double radius;
  final double iconSize;

  const _GradientIconTile({
    required this.icon,
    required this.colors,
    required this.glow,
    this.size = 48,
    this.radius = 16,
    this.iconSize = 24,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors),
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [BoxShadow(color: glow.o(0.28), blurRadius: 18)],
      ),
      child: Icon(icon, size: iconSize, color: Colors.white),
    );
  }
}

enum _MiniTone { neutral, good, warn }

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final _MiniTone tone;

  const _MiniStat({
    required this.icon,
    required this.label,
    required this.value,
    this.tone = _MiniTone.neutral,
  });

  Color _toneColor() {
    switch (tone) {
      case _MiniTone.good:
        return const Color(0xFF10B981);
      case _MiniTone.warn:
        return const Color(0xFFF59E0B);
      case _MiniTone.neutral:
        return const Color(0xFFEAF2FF);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tc = _toneColor();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.o(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.o(0.10)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [SafeShellTheme.accent.o(0.25), Colors.white.o(0.05)],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, size: 16, color: Colors.white.o(0.85)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: const Color(0xFFEAF2FF).o(0.45),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    color: tone == _MiniTone.neutral ? const Color(0xFFEAF2FF).o(0.80) : tc,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PerfStatus {
  final String text;
  final Color color;
  const _PerfStatus(this.text, this.color);

  static _PerfStatus fromScore(int score) {
    if (score >= 92) return const _PerfStatus('Optimized', Color(0xFF10B981));
    if (score >= 84) return const _PerfStatus('Good', Color(0xFF4DA3FF));
    return const _PerfStatus('Balanced', Color(0xFFF59E0B));
  }
}

// ===== Background widgets =====

class _PremiumRadialField extends StatelessWidget {
  final Alignment a;
  final Color aColor;
  final Alignment b;
  final Color bColor;
  final Alignment c;
  final Color cColor;

  const _PremiumRadialField({
    required this.a,
    required this.aColor,
    required this.b,
    required this.bColor,
    required this.c,
    required this.cColor,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: a,
                radius: 1.2,
                colors: [aColor, Colors.transparent],
                stops: const [0.0, 0.55],
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: b,
                radius: 1.1,
                colors: [bColor, Colors.transparent],
                stops: const [0.0, 0.55],
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: c,
                radius: 1.2,
                colors: [cColor, Colors.transparent],
                stops: const [0.0, 0.55],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _GlowBlob extends StatelessWidget {
  final Color color;
  final double size;
  final double blur;

  const _GlowBlob({
    required this.color,
    required this.size,
    required this.blur,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          boxShadow: [BoxShadow(blurRadius: blur, color: color)],
        ),
      ),
    );
  }
}

class _TopBlur extends StatelessWidget {
  const _TopBlur();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(height: 74, color: Colors.transparent),
          ),
        ),
      ),
    );
  }
}

