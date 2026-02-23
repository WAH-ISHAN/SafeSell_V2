import 'dart:math';
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

  final _manualCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();

  String? _keyBase64;

  bool _loading = true;
  bool _saving = false;

  bool _useManual = false;
  bool _reveal = false;
  bool _copied = false;

  String? _manualError;
  String? _pinError;

  @override
  void initState() {
    super.initState();
    _loadKey();
  }

  Future<void> _loadKey() async {
    final key = await _keyManager.getKeyBase64();
    setState(() {
      _keyBase64 = key;
      _loading = false;
    });
  }

  ({int score, String label, Color color}) _estimateStrength(String v) {
    final s = v.trim();
    if (s.isEmpty) {
      return (score: 0, label: 'Empty', color: const Color(0xFFEAF2FF));
    }
    int points = 0;
    if (s.length >= 12) points += 1;
    if (s.length >= 20) points += 1;
    if (RegExp(r'[A-Z]').hasMatch(s)) points += 1;
    if (RegExp(r'[a-z]').hasMatch(s)) points += 1;
    if (RegExp(r'[0-9]').hasMatch(s)) points += 1;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(s)) points += 1;
    final score = min(4, (points ~/ 2) + (s.length >= 28 ? 1 : 0));
    const map = [
      ('Weak', Color(0xFFEF4444)),
      ('Fair', Color(0xFFF59E0B)),
      ('Good', Color(0xFF10B981)),
      ('Strong', Color(0xFF4DA3FF)),
      ('Excellent', Color(0xFF8B5CF6)),
    ];
    return (score: score, label: map[score].$1, color: map[score].$2);
  }

  String get _activeKey {
    if (_useManual) return _manualCtrl.text.trim();
    return (_keyBase64 ?? '').trim();
  }

  Future<void> _generateKey() async {
    final pin = _pinCtrl.text.trim();
    if (pin.isEmpty || pin.length < 4) {
      setState(() => _pinError = 'PIN must be at least 4 digits');
      return;
    }
    setState(() {
      _pinError = null;
      _manualError = null;
      _saving = true;
    });
    try {
      final newKey = await _keyManager.generateAndStoreKey(pin);
      final lockService = AppLockService();
      await lockService.setPin(pin);
      final box = await Hive.openBox<AppSettings>('app_settings_typed');
      final settings = box.get('settings') ?? AppSettings();
      settings.lockEnabled = true;
      await box.put('settings', settings);
      await _auditLog.log(type: 'key_setup', details: {'method': 'auto_generated'});
      if (!mounted) return;
      setState(() {
        _keyBase64 = newKey;
        _saving = false;
        _useManual = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _pinError = 'Failed to generate key: $e';
        _saving = false;
      });
    }
  }

  Future<void> _importKey() async {
    final input = _manualCtrl.text.trim();
    final pin = _pinCtrl.text.trim();
    if (input.isEmpty) {
      setState(() => _manualError = 'Please enter a key');
      return;
    }
    if (pin.isEmpty || pin.length < 4) {
      setState(() => _pinError = 'Please enter a valid PIN (at least 4 digits)');
      return;
    }
    if (!_keyManager.validateKeyFormat(input)) {
      setState(() => _manualError = 'Invalid key: must be base64-encoded 32 bytes');
      return;
    }
    setState(() {
      _manualError = null;
      _pinError = null;
      _saving = true;
    });
    try {
      await _keyManager.importKey(input, pin);
      final lockService = AppLockService();
      await lockService.setPin(pin);
      final box = await Hive.openBox<AppSettings>('app_settings_typed');
      final settings = box.get('settings') ?? AppSettings();
      settings.lockEnabled = true;
      await box.put('settings', settings);
      await _auditLog.log(type: 'key_setup', details: {'method': 'imported'});
      if (!mounted) return;
      setState(() {
        _keyBase64 = input;
        _saving = false;
        _useManual = false;
        _manualCtrl.clear();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _manualError = 'Failed to import key: $e';
        _saving = false;
      });
    }
  }

  void _copyKey(String text) {
    if (text.trim().isEmpty) return;
    Clipboard.setData(ClipboardData(text: text));
    setState(() => _copied = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.verified_rounded, color: SafeShellTheme.accent, size: 20),
            SizedBox(width: 10),
            Expanded(child: Text('Key copied! Store it safely. Clipboard clears in 30s.')),
          ],
        ),
        duration: Duration(seconds: 3),
      ),
    );
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() => _copied = false);
    });
    Future.delayed(const Duration(seconds: 30), () {
      Clipboard.setData(const ClipboardData(text: ''));
    });
  }

  void _continue() {
    context.go('/splash');
  }

  @override
  void dispose() {
    _manualCtrl.dispose();
    _pinCtrl.dispose();
    super.dispose();
  }

  Widget _pillButton({
    required bool active,
    required String text,
    required IconData icon,
    required VoidCallback onTap,
    required Color activeColor,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 44,
          decoration: BoxDecoration(
            color: active ? activeColor : Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: active ? activeColor.withOpacity(0.35) : Colors.white.withOpacity(0.10),
            ),
            boxShadow: active
                ? [BoxShadow(color: activeColor.withOpacity(0.35), blurRadius: 16)]
                : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: active ? Colors.white : SafeShellTheme.textMuted),
              const SizedBox(width: 8),
              Text(
                text,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: active ? Colors.white : SafeShellTheme.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _strengthBar(String key) {
    final s = _estimateStrength(key);
    final value = max(0.10, s.score / 4.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Text('Strength',
                style: TextStyle(color: SafeShellTheme.textSecondary, fontSize: 12)),
            const Spacer(),
            Text(s.label,
                style: TextStyle(color: s.color, fontSize: 12, fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: Container(
            height: 8,
            color: Colors.white.withOpacity(0.10),
            child: Align(
              alignment: Alignment.centerLeft,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: MediaQuery.of(context).size.width * 0.75 * value,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  gradient: LinearGradient(
                    colors: [s.color, Colors.white.withOpacity(0.25)],
                  ),
                  boxShadow: [BoxShadow(color: s.color.withOpacity(0.35), blurRadius: 10)],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _keyDisplayCard() {
    final key = _activeKey;
    final shown = _reveal ? key : '•••• •••• •••• •••• •••• •••• ••••';
    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withOpacity(0.05),
                    Colors.transparent,
                    SafeShellTheme.bgDark.o(0.25),
                  ],
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _useManual
                            ? 'Your manual key'
                            : (_keyBase64 == null ? 'Auto key' : 'Auto-generated key'),
                        style: const TextStyle(
                            color: SafeShellTheme.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _useManual ? 'You control the format' : 'Recommended for most users',
                        style: const TextStyle(
                            color: SafeShellTheme.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                  const Spacer(),
                  _iconAction(
                    icon: _reveal
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                    tooltip: _reveal ? 'Hide' : 'Reveal',
                    onTap: () => setState(() => _reveal = !_reveal),
                  ),
                  const SizedBox(width: 8),
                  _iconAction(
                    icon: _copied ? Icons.check_rounded : Icons.copy_rounded,
                    tooltip: 'Copy',
                    accent: true,
                    onTap: () => _copyKey(key),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: SafeShellTheme.bgDark.o(0.45),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: SafeShellTheme.accent.o(0.10)),
                ),
                child: SelectableText(
                  shown,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 13,
                    height: 1.35,
                    color: _reveal ? SafeShellTheme.accent : SafeShellTheme.textMuted,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _strengthBar(key),
            ],
          ),
        ],
      ),
    );
  }

  Widget _iconAction({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    bool accent = false,
  }) {
    final bg =
        accent ? SafeShellTheme.accent.o(0.18) : Colors.white.withOpacity(0.05);
    final bd =
        accent ? SafeShellTheme.accent.o(0.25) : Colors.white.withOpacity(0.10);
    final fg = accent ? SafeShellTheme.accent : SafeShellTheme.textMuted;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: bd),
        ),
        child: Tooltip(message: tooltip, child: Icon(icon, size: 20, color: fg)),
      ),
    );
  }

  Widget _importantTip() {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: SafeShellTheme.accent, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Important',
                  style: TextStyle(
                      color: SafeShellTheme.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 14),
                ),
                const SizedBox(height: 6),
                const Text(
                  "Save your key in a safe place. If you lose it, encrypted files can't be recovered.",
                  style: TextStyle(
                      color: SafeShellTheme.textSecondary,
                      fontSize: 13,
                      height: 1.35),
                ),
                const SizedBox(height: 10),
                InkWell(
                  onTap: () => _copyKey(_activeKey),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Text('Copy key again',
                            style: TextStyle(
                                color: SafeShellTheme.accent,
                                fontSize: 13,
                                fontWeight: FontWeight.w700)),
                        SizedBox(width: 6),
                        Icon(Icons.chevron_right_rounded,
                            color: SafeShellTheme.accent, size: 18),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _pinCard() {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.lock_rounded, color: SafeShellTheme.accent, size: 20),
              SizedBox(width: 8),
              Text('Set Protection PIN',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: SafeShellTheme.textPrimary)),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _pinCtrl,
            obscureText: true,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: SafeShellTheme.textPrimary),
            decoration: InputDecoration(
              hintText: 'Enter PIN (min 4 digits)',
              hintStyle: const TextStyle(color: SafeShellTheme.textMuted),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    BorderSide(color: Colors.white.withOpacity(0.10)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: SafeShellTheme.accent.o(0.45)),
              ),
              filled: true,
              fillColor: SafeShellTheme.bgDark.o(0.25),
            ),
          ),
          if (_pinError != null) ...[
            const SizedBox(height: 8),
            Text(_pinError!,
                style: const TextStyle(
                    color: SafeShellTheme.error, fontSize: 12)),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed:
                  _saving ? null : (_useManual ? _importKey : _generateKey),
              child:
                  Text(_useManual ? 'Save Manual Key' : 'Generate Vault Key'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _manualInputCard() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: !_useManual
          ? const SizedBox.shrink()
          : GlassCard(
              key: const ValueKey('manualCard'),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.vpn_key_rounded,
                          color: SafeShellTheme.accentAlt, size: 20),
                      SizedBox(width: 8),
                      Text('Enter your key',
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: SafeShellTheme.textPrimary)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _manualCtrl,
                    maxLines: 2,
                    style: const TextStyle(
                        color: SafeShellTheme.textPrimary,
                        fontFamily: 'monospace',
                        fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Paste base64 key here',
                      hintStyle:
                          const TextStyle(color: SafeShellTheme.textMuted),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                            color: Colors.white.withOpacity(0.10)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide:
                            BorderSide(color: SafeShellTheme.accentAlt.o(0.45)),
                      ),
                      filled: true,
                      fillColor: SafeShellTheme.bgDark.o(0.25),
                    ),
                    onChanged: (_) => setState(() => _manualError = null),
                  ),
                  const SizedBox(height: 8),
                  const Text('Tip: longer is better. Keep it private.',
                      style: TextStyle(
                          color: SafeShellTheme.textSecondary, fontSize: 12)),
                  if (_manualError != null) ...[
                    const SizedBox(height: 8),
                    Text(_manualError!,
                        style: const TextStyle(
                            color: SafeShellTheme.error, fontSize: 12)),
                  ],
                  const SizedBox(height: 12),
                  _strengthBar(_manualCtrl.text.trim()),
                ],
              ),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasKey = _keyBase64 != null;
    return Scaffold(
      body: PremiumBackground(
        child: SafeArea(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(
                      color: SafeShellTheme.accent))
              : SingleChildScrollView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 22),
                      Row(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              borderRadius:
                                  BorderRadius.circular(18),
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Color(0xFF4DA3FF),
                                  Color(0xFF2B7FDB)
                                ],
                              ),
                              border: Border.all(
                                  color: Colors.white
                                      .withOpacity(0.10)),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF4DA3FF)
                                      .withOpacity(0.35),
                                  blurRadius: 18,
                                ),
                              ],
                            ),
                            child: const Icon(
                                Icons.shield_rounded,
                                color: Colors.white,
                                size: 26),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: const [
                                Text(
                                  'Create your vault key',
                                  style: TextStyle(
                                    color:
                                        SafeShellTheme.textPrimary,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    height: 1.1,
                                  ),
                                ),
                                SizedBox(height: 6),
                                Text(
                                  'This key encrypts & decrypts your vault. Keep it private. No one can recover it for you.',
                                  style: TextStyle(
                                    color: SafeShellTheme
                                        .textSecondary,
                                    fontSize: 13,
                                    height: 1.35,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      GlassCard(
                        padding: const EdgeInsets.all(10),
                        child: Row(
                          children: [
                            _pillButton(
                              active: !_useManual,
                              text: 'Auto Key',
                              icon: Icons.auto_awesome_rounded,
                              activeColor: SafeShellTheme.accent,
                              onTap: () => setState(() {
                                _useManual = false;
                                _manualError = null;
                              }),
                            ),
                            const SizedBox(width: 10),
                            _pillButton(
                              active: _useManual,
                              text: 'Manual Key',
                              icon: Icons.key_rounded,
                              activeColor: const Color(0xFF8B5CF6),
                              onTap: () => setState(() {
                                _useManual = true;
                                _manualError = null;
                              }),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      if (!_useManual && hasKey) _keyDisplayCard(),
                      _manualInputCard(),
                      const SizedBox(height: 14),
                      _pinCard(),
                      const SizedBox(height: 14),
                      _importantTip(),
                      const SizedBox(height: 16),
                      GradientButton(
                        text: _saving
                            ? 'Saving...'
                            : 'Save Key & Continue',
                        onPressed:
                            (_saving || (!hasKey && !_useManual))
                                ? null
                                : () {
                                    if (_useManual &&
                                        _keyBase64 == null) {
                                      _importKey();
                                      return;
                                    }
                                    if (!_useManual &&
                                        _keyBase64 == null) {
                                      _generateKey();
                                      return;
                                    }
                                    _continue();
                                  },
                        icon: Icons.arrow_forward_rounded,
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        "By continuing, you confirm you've stored your key safely.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: SafeShellTheme.textMuted,
                            fontSize: 12),
                      ),
                      const SizedBox(height: 34),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
