import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../models/app_settings.dart';
import '../../security/biometric_service.dart';
import '../../security/app_lock_service.dart';
import '../../security/key_manager.dart';
import '../../services/audit_log_service.dart';
import '../../usecases/lock_usecase.dart';
import '../../ui/widgets/premium_ui.dart';
import '../../app/theme.dart';

class LockScreen extends StatefulWidget {
  const LockScreen({super.key});
  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  late final LockUsecase _lockUsecase;
  String? _error;
  bool _loading = false;
  Duration _cooldown = Duration.zero;
  bool _hasBiometric = false;

  @override
  void initState() {
    super.initState();
    _lockUsecase = LockUsecase(
      appLockService: AppLockService(),
      biometricService: BiometricService(),
      auditLogService: AuditLogService(),
    );
    _init();
  }

  Future<void> _init() async {
    final biometric = await BiometricService().isAvailable();
    final cooldown = await _lockUsecase.getCooldownRemaining();
    if (mounted) {
      setState(() {
        _hasBiometric = biometric;
        _cooldown = cooldown;
      });
    }
    if (_hasBiometric && _cooldown == Duration.zero) {
      _unlockBiometric();
    }
  }

  Future<void> _unlockBiometric() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await _lockUsecase.unlockWithBiometric();
    if (result) {
      // Biometric verified identity — now need PIN to load master key
      if (mounted) {
        setState(() => _loading = false);
      }
      _showPinForKeyLoad();
    } else {
      await _checkCooldown();
      if (mounted) {
        setState(() {
          _error = 'Biometric failed';
          _loading = false;
        });
      }
    }
  }

  /// After biometric success, prompt for PIN to unwrap the master key.
  /// Biometrics alone cannot derive the PIN-based KEK needed for AES-GCM unwrap.
  Future<void> _showPinForKeyLoad() async {
    String? pin;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: SafeShellTheme.bgCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Enter PIN to unlock vault',
            style: TextStyle(color: SafeShellTheme.textPrimary),
          ),
          content: SizedBox(
            width: 300,
            child: PinInput(
              onCompleted: (value) {
                pin = value;
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
    if (pin == null || !mounted) return;

    // Attempt to load master key with the provided PIN
    setState(() => _loading = true);
    try {
      final keyManager = KeyManager();
      await keyManager.unlock(pin!);
      _onUnlocked();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'PIN incorrect — vault key could not be loaded';
          _loading = false;
        });
      }
    }
  }

  Future<void> _unlockPin(String pin) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await _lockUsecase.unlockWithPin(pin);
    if (result) {
      _onUnlocked();
    } else {
      await _checkCooldown();
      final attempts = await _lockUsecase.getFailedAttempts();

      // Check panic wipe
      final shouldWipe = await _lockUsecase.shouldPanicWipe();
      if (shouldWipe) {
        // Panic wipe would clear vault here
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('⚠ Maximum attempts exceeded')),
          );
        }
      }

      if (mounted) {
        setState(() {
          _error = 'Incorrect PIN ($attempts failed attempts)';
          _loading = false;
        });
      }
    }
  }

  Future<void> _checkCooldown() async {
    final cooldown = await _lockUsecase.getCooldownRemaining();
    if (mounted) setState(() => _cooldown = cooldown);
  }

  void _onUnlocked() {
    if (!mounted) return;
    // Check stealth mode
    _checkStealthAndNavigate();
  }

  Future<void> _checkStealthAndNavigate() async {
    final box = await Hive.openBox<AppSettings>('app_settings_typed');
    final settings = box.get('settings') ?? AppSettings();
    if (!mounted) return;
    if (settings.stealthEnabled) {
      context.go('/calculator');
    } else {
      // Let GoRouter redirect chain handle navigation
      context.go('/splash');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PremiumBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SafeShellLogo(size: 70),
                  const SizedBox(height: 20),
                  const Text(
                    'Unlock SafeShell',
                    style: TextStyle(
                      color: SafeShellTheme.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_cooldown > Duration.zero) ...[
                    Text(
                      'Too many attempts. Try again in ${_cooldown.inSeconds}s',
                      style: const TextStyle(
                        color: SafeShellTheme.error,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 24),
                    GradientButton(
                      text: 'Retry',
                      onPressed: () async {
                        await _checkCooldown();
                        if (_cooldown <= Duration.zero && _hasBiometric) {
                          _unlockBiometric();
                        }
                      },
                    ),
                  ] else ...[
                    const Text(
                      'Enter your PIN',
                      style: TextStyle(
                        color: SafeShellTheme.textMuted,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 32),
                    PinInput(onCompleted: _unlockPin, error: _error),
                    if (_hasBiometric) ...[
                      const SizedBox(height: 16),
                      TextButton.icon(
                        onPressed: _unlockBiometric,
                        icon: const Icon(
                          Icons.fingerprint,
                          color: SafeShellTheme.accent,
                        ),
                        label: const Text(
                          'Use Biometric',
                          style: TextStyle(color: SafeShellTheme.accent),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'SafeShell uses biometrics only for authentication.\n'
                        'No biometric data is stored or transmitted.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color:
                              SafeShellTheme.textMuted.withValues(alpha: 0.6),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
