import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../security/key_manager.dart';
import '../../security/app_lock_service.dart';
import '../../models/app_settings.dart';
import '../../services/audit_log_service.dart';
import '../../ui/widgets/premium_ui.dart';
import '../../app/theme.dart';

class KeySetupScreen extends StatefulWidget {
  const KeySetupScreen({super.key});
  @override
  State<KeySetupScreen> createState() => _KeySetupScreenState();
}

class _KeySetupScreenState extends State<KeySetupScreen> {
  final _keyManager = KeyManager();
  final _auditLog = AuditLogService();
  final _importCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();

  String? _keyBase64;
  bool _keyVisible = false;
  bool _confirmed = false;
  bool _importing = false;
  bool _loading = true;
  String? _importError;
  String? _pinError;

  @override
  void initState() {
    super.initState();
    _loadKey();
  }

  Future<void> _loadKey() async {
    final key = await _keyManager.getKeyBase64();
    if (key != null) {
      setState(() {
        _keyBase64 = key;
        _loading = false;
      });
    } else {
      // Need PIN to generate new key
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _generateKey() async {
    final pin = _pinCtrl.text.trim();
    if (pin.isEmpty || pin.length < 4) {
      setState(() => _pinError = 'PIN must be at least 4 digits');
      return;
    }

    setState(() {
      _pinError = null;
      _loading = true;
    });

    try {
      final newKey = await _keyManager.generateAndStoreKey(pin);

      // Sync PIN with AppLockService for lock verification
      final lockService = AppLockService();
      await lockService.setPin(pin);

      // Auto-enable app lock
      final box = await Hive.openBox<AppSettings>('app_settings_typed');
      final settings = box.get('settings') ?? AppSettings();
      settings.lockEnabled = true;
      await box.put('settings', settings);

      await _auditLog.log(
        type: 'key_setup',
        details: {'method': 'auto_generated'},
      );
      setState(() {
        _keyBase64 = newKey;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _pinError = 'Failed to generate key: $e';
        _loading = false;
      });
    }
  }

  Future<void> _importKey() async {
    final input = _importCtrl.text.trim();
    final pin = _pinCtrl.text.trim();

    if (input.isEmpty) {
      setState(() => _importError = 'Please enter a key');
      return;
    }
    if (pin.isEmpty || pin.length < 4) {
      setState(
          () => _importError = 'Please enter a valid PIN (at least 4 digits)');
      return;
    }
    if (!_keyManager.validateKeyFormat(input)) {
      setState(
        () => _importError = 'Invalid key: must be base64-encoded 32 bytes',
      );
      return;
    }

    try {
      await _keyManager.importKey(input, pin);

      // Sync PIN with AppLockService for lock verification
      final lockService = AppLockService();
      await lockService.setPin(pin);

      // Auto-enable app lock
      final box = await Hive.openBox<AppSettings>('app_settings_typed');
      final settings = box.get('settings') ?? AppSettings();
      settings.lockEnabled = true;
      await box.put('settings', settings);

      await _auditLog.log(type: 'key_setup', details: {'method': 'imported'});
      setState(() {
        _keyBase64 = input;
        _importing = false;
        _importError = null;
      });
    } catch (e) {
      setState(() => _importError = 'Failed to import key: $e');
    }
  }

  void _copyKey() {
    if (_keyBase64 == null) return;
    Clipboard.setData(ClipboardData(text: _keyBase64!));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(
              Icons.warning_amber,
              color: SafeShellTheme.warning,
              size: 20,
            ),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Key copied! Store it safely. Clipboard will be cleared in 30s.',
              ),
            ),
          ],
        ),
        duration: Duration(seconds: 5),
      ),
    );
    // Clear clipboard after 30 seconds
    Future.delayed(const Duration(seconds: 30), () {
      Clipboard.setData(const ClipboardData(text: ''));
    });
  }

  void _continue() {
    if (!_confirmed) return;
    // Let GoRouter redirect chain enforce Lock → Dashboard
    context.go('/splash');
  }

  @override
  void dispose() {
    _importCtrl.dispose();
    _pinCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PremiumBackground(
        child: SafeArea(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(
                    color: SafeShellTheme.accent,
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 40),
                      const Center(
                        child: Icon(
                          Icons.vpn_key_rounded,
                          size: 60,
                          color: SafeShellTheme.accent,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: ShaderMask(
                          shaderCallback: (b) =>
                              SafeShellTheme.accentGradient.createShader(b),
                          child: const Text(
                            'Vault Key Setup',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Center(
                        child: Text(
                          'This key encrypts all your vault files.\nLose it and your data is gone forever.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: SafeShellTheme.textMuted,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // PIN input (required if no key exists)
                      if (_keyBase64 == null) ...[
                        GlassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(
                                    Icons.lock,
                                    color: SafeShellTheme.accent,
                                    size: 20,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Set Protection PIN',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: SafeShellTheme.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _pinCtrl,
                                obscureText: true,
                                keyboardType: TextInputType.number,
                                style: const TextStyle(
                                  color: SafeShellTheme.textPrimary,
                                ),
                                decoration: const InputDecoration(
                                  hintText: 'Enter PIN (min 4 digits)',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              if (_pinError != null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  _pinError!,
                                  style: const TextStyle(
                                    color: SafeShellTheme.error,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _generateKey,
                                  child: const Text('Generate Vault Key'),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Key display
                      if (_keyBase64 != null)
                        GlassCard(
                          borderColor: SafeShellTheme.accent.o(0.3),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.key,
                                    color: SafeShellTheme.accent,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Your Vault Key',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: SafeShellTheme.textPrimary,
                                    ),
                                  ),
                                  const Spacer(),
                                  IconButton(
                                    icon: Icon(
                                      _keyVisible
                                          ? Icons.visibility_off
                                          : Icons.visibility,
                                      color: SafeShellTheme.textMuted,
                                      size: 20,
                                    ),
                                    onPressed: () => setState(
                                      () => _keyVisible = !_keyVisible,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.copy,
                                      color: SafeShellTheme.textMuted,
                                      size: 20,
                                    ),
                                    onPressed: _copyKey,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: SafeShellTheme.bgDark.o(0.5),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: SelectableText(
                                  _keyVisible ? (_keyBase64 ?? '') : '•' * 44,
                                  style: TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 13,
                                    color: _keyVisible
                                        ? SafeShellTheme.accent
                                        : SafeShellTheme.textMuted,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 16),

                      // Import option
                      GlassCard(
                        onTap: () => setState(() => _importing = !_importing),
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.download,
                              color: SafeShellTheme.accentAlt,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'Import existing key',
                                style: TextStyle(
                                  color: SafeShellTheme.textPrimary,
                                ),
                              ),
                            ),
                            Icon(
                              _importing
                                  ? Icons.expand_less
                                  : Icons.expand_more,
                              color: SafeShellTheme.textMuted,
                            ),
                          ],
                        ),
                      ),
                      if (_importing) ...[
                        const SizedBox(height: 8),
                        GlassCard(
                          child: Column(
                            children: [
                              TextFormField(
                                controller: _importCtrl,
                                style: const TextStyle(
                                  color: SafeShellTheme.textPrimary,
                                  fontFamily: 'monospace',
                                  fontSize: 13,
                                ),
                                decoration: const InputDecoration(
                                  hintText: 'Paste base64 key here',
                                ),
                                maxLines: 2,
                              ),
                              if (_importError != null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  _importError!,
                                  style: const TextStyle(
                                    color: SafeShellTheme.error,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton(
                                  onPressed: _importKey,
                                  child: const Text('Import Key'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 24),
                      // Confirmation checkbox
                      GlassCard(
                        padding: const EdgeInsets.all(12),
                        borderColor:
                            _confirmed ? SafeShellTheme.success.o(0.3) : null,
                        child: Row(
                          children: [
                            Checkbox(
                              value: _confirmed,
                              onChanged: (v) =>
                                  setState(() => _confirmed = v ?? false),
                              activeColor: SafeShellTheme.accent,
                              side: const BorderSide(
                                color: SafeShellTheme.textMuted,
                              ),
                            ),
                            const Expanded(
                              child: Text(
                                'I have safely stored my vault key. I understand that losing it means losing access to my encrypted files.',
                                style: TextStyle(
                                  color: SafeShellTheme.textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      GradientButton(
                        text: 'Continue to SafeShell',
                        onPressed: _confirmed ? _continue : null,
                        icon: Icons.arrow_forward,
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
