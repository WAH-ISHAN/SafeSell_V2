import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../security/key_manager.dart';
import '../../models/app_settings.dart';
import '../../services/billing_service.dart';
import '../../services/vault_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with TickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _fade;
  late final Animation<double> _slideUp;

  late final AnimationController _bgC;

  final _km = KeyManager();
  final _billing = BillingService();
  final _vault = VaultService();
  String? _keyB64;
  bool _revealKey = false;
  bool _keyLoading = false;
  VaultStats? _vaultStats;
  AppSettings? _settings;
  bool _statsLoading = true;

  @override
  void initState() {
    super.initState();

    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fade = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
    _slideUp = Tween<double>(
      begin: 18,
      end: 0,
    ).animate(CurvedAnimation(parent: _c, curve: Curves.easeOutCubic));
    _c.forward();

    _bgC = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat(reverse: true);

    _billing.init();
    _loadKey();
    _loadStats();
  }

  @override
  void dispose() {
    _bgC.dispose();
    _c.dispose();
    super.dispose();
  }

  Future<void> _loadKey() async {
    try {
      setState(() => _keyLoading = true);
      final v = await _km.getKeyBase64();
      if (!mounted) return;
      setState(() {
        _keyB64 = v;
        _keyLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _keyLoading = false);
    }
  }

  Future<void> _loadStats() async {
    try {
      final stats = await _vault.getStats();
      final settingsBox = Hive.box<AppSettings>('app_settings_typed');
      final settings = settingsBox.values.isNotEmpty
          ? settingsBox.values.first
          : AppSettings();
      if (!mounted) return;
      setState(() {
        _vaultStats = stats;
        _settings = settings;
        _statsLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _statsLoading = false);
    }
  }

  String _maskKey(String k) {
    if (k.length <= 12) return "••••••••••••";
    return "${k.substring(0, 6)}••••••••••••••••${k.substring(k.length - 6)}";
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  String _formatJoinDate(DateTime? date) {
    if (date == null) return 'Unknown';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  Future<void> _logout() async {
    try {
      _km.lock();
      await FirebaseAuth.instance.signOut();
      try {
        final settingsBox = Hive.box<AppSettings>('app_settings_typed');
        await settingsBox.clear();
      } catch (_) {}
    } catch (_) {}
    if (mounted) context.go('/login');
  }

  // ── New account actions ───────────────────────────────────────────────

  bool _isEmailProvider() {
    final providers = FirebaseAuth.instance.currentUser?.providerData
            .map((p) => p.providerId)
            .toList() ??
        [];
    return providers.contains('password');
  }

  String _signInProvider() {
    final providers = FirebaseAuth.instance.currentUser?.providerData
            .map((p) => p.providerId)
            .toList() ??
        [];
    if (providers.contains('google.com')) return 'Google';
    if (providers.contains('password')) return 'Email / Password';
    if (providers.contains('apple.com')) return 'Apple';
    if (providers.isEmpty) return 'Guest';
    return providers.first;
  }

  String _formatLastLogin(DateTime? dt) {
    if (dt == null) return 'Unknown';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    return '${diff.inDays} days ago';
  }

  Future<void> _showEditNameDialog() async {
    final ctrl = TextEditingController(
      text: FirebaseAuth.instance.currentUser?.displayName ?? '',
    );
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A2030),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Display Name',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Enter your name',
            hintStyle: TextStyle(color: Colors.white.withAlpha(77)),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white.withAlpha(51)),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFF4DA3FF)),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text(
              'Save',
              style: TextStyle(
                  color: Color(0xFF4DA3FF), fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      try {
        await FirebaseAuth.instance.currentUser
            ?.updateDisplayName(result);
        if (mounted) {
          setState(() {});
          _snack('Name updated');
        }
      } catch (e) {
        if (mounted) _snack('Failed to update name');
      }
    }
  }

  Future<void> _sendPasswordReset() async {
    final email = FirebaseAuth.instance.currentUser?.email;
    if (email == null || email.isEmpty) {
      _snack('No email address associated with this account');
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) _snack('Password reset email sent to $email');
    } catch (e) {
      if (mounted) _snack('Failed to send reset email');
    }
  }

  Future<void> _showDeleteAccountDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A2030),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Delete Account?',
          style: TextStyle(
              color: Color(0xFFF87171), fontWeight: FontWeight.w900),
        ),
        content: Text(
          'This will permanently delete your account and all data. '
          'This action cannot be undone.',
          style:
              TextStyle(color: Colors.white.withAlpha(178), height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Delete',
              style: TextStyle(
                  color: Color(0xFFF87171), fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      final user = FirebaseAuth.instance.currentUser;
      _km.lock();
      await Hive.box<AppSettings>('app_settings_typed').clear();
      await user?.delete();
      if (mounted) context.go('/login');
    } catch (e) {
      if (mounted) {
        _snack(
          'Re-authentication required. Please sign out and back in first.',
        );
      }
    }
  }

  Future<void> _showManageSubDialog() async {
    if (!mounted) return;
    _snack('To cancel, manage your subscription in Google Play Store.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          "Profile",
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -0.2),
        ),
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      body: Stack(
        children: [
          const ColoredBox(color: Color(0xFF0B0F14)),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(-0.75, -0.85),
                  radius: 1.2,
                  colors: [const Color(0xFF4DA3FF).o(0.10), Colors.transparent],
                  stops: const [0.0, 0.55],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.85, -0.55),
                  radius: 1.1,
                  colors: [const Color(0xFF0A2A4F).o(0.28), Colors.transparent],
                  stops: const [0.0, 0.55],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(-0.25, 0.85),
                  radius: 1.2,
                  colors: [const Color(0xFF4DA3FF).o(0.07), Colors.transparent],
                  stops: const [0.0, 0.55],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: Opacity(
                opacity: 0.08,
                child: CustomPaint(painter: _NoisePainter()),
              ),
            ),
          ),
          AnimatedBuilder(
            animation: _bgC,
            builder: (_, __) {
              final t = _bgC.value;
              return Stack(
                children: [
                  Positioned(
                    top: -120 + (t * 18),
                    right: -120 - (t * 14),
                    child: _GlowBlob(
                      color: const Color(0xFF4DA3FF).o(0.12),
                      size: 520,
                      blur: 120,
                    ),
                  ),
                  Positioned(
                    bottom: 70 - (t * 12),
                    left: -120 + (t * 16),
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
          SafeArea(
            child: AnimatedBuilder(
              animation: _c,
              builder: (_, __) {
                return Opacity(
                  opacity: _fade.value,
                  child: Transform.translate(
                    offset: Offset(0, _slideUp.value),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 412),
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(20, 18, 20, 110),
                          children: [
                            _Header(
                              onTapOrb: () => _snack("Security details (TODO)"),
                            ),
                            const SizedBox(height: 16),

                            _GlassCard(
                              padding: const EdgeInsets.all(18),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 80,
                                        height: 80,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            26,
                                          ),
                                          gradient: const LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: [
                                              Color(0xFF4DA3FF),
                                              Color(0xFF2B7FDB),
                                            ],
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              blurRadius: 28,
                                              color: const Color(
                                                0xFF4DA3FF,
                                              ).o(0.35),
                                            ),
                                          ],
                                        ),
                                        child: const Icon(
                                          Icons.person_rounded,
                                          color: Colors.white,
                                          size: 40,
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    FirebaseAuth
                                                            .instance
                                                            .currentUser
                                                            ?.displayName ??
                                                        'User',
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 20,
                                                      fontWeight:
                                                          FontWeight.w900,
                                                      letterSpacing: -0.2,
                                                    ),
                                                  ),
                                                ),
                                                if (FirebaseAuth
                                                        .instance
                                                        .currentUser
                                                        ?.emailVerified ??
                                                    false) ...[
                                                  const SizedBox(width: 8),
                                                  _Chip(
                                                    icon:
                                                        Icons.verified_rounded,
                                                    text: "Verified",
                                                    fg: const Color(0xFF4DA3FF),
                                                    bg: Colors.white.o(0.05),
                                                    border: Colors.white.o(
                                                      0.10,
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                            const SizedBox(height: 10),
                                            Wrap(
                                              spacing: 10,
                                              runSpacing: 10,
                                              children: [
                                                _Chip(
                                                  icon: Icons.workspace_premium,
                                                  text: _billing.isPro
                                                      ? 'Pro Plan'
                                                      : 'Free Plan',
                                                  fg: const Color(0xFF4DA3FF),
                                                  bg: const Color(
                                                    0xFF4DA3FF,
                                                  ).o(0.15),
                                                  border: const Color(
                                                    0xFF4DA3FF,
                                                  ).o(0.25),
                                                ),
                                                _Chip(
                                                  icon: Icons.shield_rounded,
                                                  text: 'Protected',
                                                  fg: const Color(
                                                    0xFFEAF2FF,
                                                  ).o(0.75),
                                                  bg: Colors.white.o(0.05),
                                                  border: Colors.white.o(0.10),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  _InfoRow(
                                    icon: Icons.mail_rounded,
                                    label: FirebaseAuth
                                            .instance.currentUser?.email ??
                                        'Not signed in',
                                  ),
                                  const SizedBox(height: 10),
                                  _InfoRow(
                                    icon: Icons.calendar_month_rounded,
                                    label:
                                        "Joined ${_formatJoinDate(FirebaseAuth.instance.currentUser?.metadata.creationTime)}",
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _MiniStat(
                                          icon: Icons.folder_rounded,
                                          label: 'Files',
                                          value: _statsLoading
                                              ? '…'
                                              : '${_vaultStats?.totalFiles ?? 0}',
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: _MiniStat(
                                          icon: Icons.storage_rounded,
                                          label: 'Size',
                                          value: _statsLoading
                                              ? '…'
                                              : (_vaultStats?.formattedSize ?? '0 B'),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: _MiniStat(
                                          icon: Icons.security_rounded,
                                          label: 'Stealth',
                                          value: (_settings?.stealthEnabled ?? false)
                                              ? 'On'
                                              : 'Off',
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 16),

                            // ✅ Vault Key card
                            _GlassCard(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "Vault Key",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    "Keep this secret. Without it, recovery is impossible.",
                                    style: TextStyle(
                                      color: const Color(0xFFEAF2FF).o(0.55),
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                      height: 1.35,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  if (_keyLoading)
                                    Text(
                                      "Loading key…",
                                      style: TextStyle(
                                        color: const Color(0xFFEAF2FF).o(0.55),
                                        fontWeight: FontWeight.w700,
                                      ),
                                    )
                                  else if (_keyB64 == null || _keyB64!.isEmpty)
                                    Text(
                                      "No key found. Run Key Setup.",
                                      style: TextStyle(
                                        color: const Color(0xFFF87171).o(0.95),
                                        fontWeight: FontWeight.w800,
                                      ),
                                    )
                                  else
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(16),
                                        color: Colors.white.o(0.05),
                                        border: Border.all(
                                          color: Colors.white.o(0.10),
                                        ),
                                      ),
                                      child: SelectableText(
                                        _revealKey
                                            ? _keyB64!
                                            : _maskKey(_keyB64!),
                                        style: TextStyle(
                                          color: Colors.white.o(0.90),
                                          fontWeight: FontWeight.w800,
                                          fontSize: 12,
                                          height: 1.35,
                                        ),
                                      ),
                                    ),
                                  const SizedBox(height: 12),
                                  if (_keyB64 != null && _keyB64!.isNotEmpty)
                                    Wrap(
                                      spacing: 10,
                                      runSpacing: 10,
                                      children: [
                                        OutlinedButton.icon(
                                          onPressed: () => setState(
                                            () => _revealKey = !_revealKey,
                                          ),
                                          icon: Icon(
                                            _revealKey
                                                ? Icons.visibility_off_rounded
                                                : Icons.visibility_rounded,
                                          ),
                                          label: Text(
                                            _revealKey ? "Hide" : "Reveal",
                                          ),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: Colors.white,
                                            side: BorderSide(
                                              color: Colors.white.o(0.10),
                                            ),
                                            backgroundColor: Colors.white.o(
                                              0.06,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                            ),
                                          ),
                                        ),
                                        OutlinedButton.icon(
                                          onPressed: () async {
                                            await Clipboard.setData(
                                              ClipboardData(text: _keyB64!),
                                            );
                                            _snack("Copied to clipboard");
                                          },
                                          icon: const Icon(Icons.copy_rounded),
                                          label: const Text("Copy"),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: Colors.white,
                                            side: BorderSide(
                                              color: Colors.white.o(0.10),
                                            ),
                                            backgroundColor: Colors.white.o(
                                              0.06,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 18),

                            // ── Vault Stats ──────────────────────────────
                            const Text(
                              'Vault',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 10),
                            _GlassCard(
                              padding: const EdgeInsets.all(16),
                              child: _statsLoading
                                  ? const Center(
                                      child: Padding(
                                        padding: EdgeInsets.all(8),
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    )
                                  : Column(
                                      children: [
                                        _StatDetailRow(
                                          icon: Icons.folder_copy_rounded,
                                          label: 'Total files',
                                          value: '${_vaultStats?.totalFiles ?? 0}',
                                        ),
                                        const SizedBox(height: 10),
                                        _StatDetailRow(
                                          icon: Icons.storage_rounded,
                                          label: 'Total size',
                                          value:
                                              _vaultStats?.formattedSize ?? '0 B',
                                        ),
                                        const SizedBox(height: 10),
                                        const _StatDetailRow(
                                          icon: Icons.lock_rounded,
                                          label: 'Encryption',
                                          value: 'AES-256-GCM',
                                        ),
                                        const SizedBox(height: 10),
                                        _StatDetailRow(
                                          icon: Icons.workspace_premium_rounded,
                                          label: 'Plan limit',
                                          value: _billing.isPro
                                              ? 'Unlimited'
                                              : '10 files (Free)',
                                        ),
                                      ],
                                    ),
                            ),

                            const SizedBox(height: 18),

                            // ── Security ─────────────────────────────────
                            const Text(
                              'Security',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 10),
                            _GlassCard(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                children: [
                                  _StatDetailRow(
                                    icon: Icons.login_rounded,
                                    label: 'Last login',
                                    value: _formatLastLogin(
                                      FirebaseAuth.instance.currentUser
                                          ?.metadata.lastSignInTime,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  _StatDetailRow(
                                    icon: Icons.how_to_reg_rounded,
                                    label: 'Sign-in method',
                                    value: _signInProvider(),
                                  ),
                                  const SizedBox(height: 10),
                                  _StatDetailRow(
                                    icon: Icons.verified_user_rounded,
                                    label: 'Email verified',
                                    value: (FirebaseAuth
                                                    .instance
                                                    .currentUser
                                                    ?.emailVerified ??
                                                false)
                                        ? 'Yes'
                                        : 'No',
                                    valueColor:
                                        (FirebaseAuth.instance.currentUser
                                                    ?.emailVerified ??
                                                false)
                                            ? const Color(0xFF22C55E)
                                            : const Color(0xFFF59E0B),
                                  ),
                                  const SizedBox(height: 10),
                                  _StatDetailRow(
                                    icon: Icons.lock_person_rounded,
                                    label: 'Biometric lock',
                                    value:
                                        (_settings?.lockEnabled ?? false)
                                            ? 'Enabled'
                                            : 'Disabled',
                                    valueColor:
                                        (_settings?.lockEnabled ?? false)
                                            ? const Color(0xFF22C55E)
                                            : null,
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 18),

                            // ── Subscription ─────────────────────────────
                            const Text(
                              'Subscription',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 10),
                            _GlassCard(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 5,
                                        ),
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          gradient: _billing.isPro
                                              ? const LinearGradient(
                                                  colors: [
                                                    Color(0xFFFFD700),
                                                    Color(0xFFFFA500),
                                                  ],
                                                )
                                              : null,
                                          color: _billing.isPro
                                              ? null
                                              : Colors.white.o(0.08),
                                          border: _billing.isPro
                                              ? null
                                              : Border.all(
                                                  color: Colors.white.o(0.15),
                                                ),
                                        ),
                                        child: Text(
                                          _billing.isPro ? 'PRO' : 'FREE',
                                          style: TextStyle(
                                            color: _billing.isPro
                                                ? Colors.black
                                                : Colors.white.o(0.70),
                                            fontWeight: FontWeight.w900,
                                            fontSize: 12,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          _billing.isPro
                                              ? 'SafeShell Pro — Active'
                                              : 'Free Plan — Limited features',
                                          style: TextStyle(
                                            color: Colors.white.o(0.85),
                                            fontWeight: FontWeight.w800,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 14),
                                  if (!_billing.isPro) ...[
                                    _UpgradeButton(
                                      products: _billing.products,
                                      onPurchase: (p) async {
                                        await _billing.purchase(p);
                                        if (mounted) setState(() {});
                                      },
                                    ),
                                    const SizedBox(height: 10),
                                    Center(
                                      child: TextButton(
                                        onPressed: () async {
                                          await _billing.restorePurchases();
                                          if (mounted) setState(() {});
                                        },
                                        child: Text(
                                          'Restore purchases',
                                          style: TextStyle(
                                            color: Colors.white.o(0.50),
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ] else
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: TextButton.icon(
                                        onPressed: () => _showManageSubDialog(),
                                        icon: const Icon(
                                          Icons.subscriptions_rounded,
                                          size: 16,
                                        ),
                                        label:
                                            const Text('Manage subscription'),
                                        style: TextButton.styleFrom(
                                          foregroundColor:
                                              Colors.white.o(0.60),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 18),

                            // ── Account ───────────────────────────────────
                            const Text(
                              'Account',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 10),
                            _GlassCard(
                              padding: const EdgeInsets.all(8),
                              child: Column(
                                children: [
                                  _ActionRow(
                                    tone: _ActionTone.normal,
                                    icon: Icons.edit_rounded,
                                    title: 'Edit Display Name',
                                    subtitle: FirebaseAuth.instance.currentUser
                                            ?.displayName ??
                                        'Not set',
                                    onTap: _showEditNameDialog,
                                  ),
                                  if (_isEmailProvider()) ...[
                                    const Divider(
                                      color: Colors.white12,
                                      height: 1,
                                      indent: 16,
                                      endIndent: 16,
                                    ),
                                    _ActionRow(
                                      tone: _ActionTone.normal,
                                      icon: Icons.lock_reset_rounded,
                                      title: 'Change Password',
                                      subtitle:
                                          'Send a password reset email',
                                      onTap: _sendPasswordReset,
                                    ),
                                  ],
                                  const Divider(
                                    color: Colors.white12,
                                    height: 1,
                                    indent: 16,
                                    endIndent: 16,
                                  ),
                                  _ActionRow(
                                    tone: _ActionTone.danger,
                                    icon: Icons.logout_rounded,
                                    title: 'Sign Out',
                                    subtitle: 'Log out from this device',
                                    onTap: _logout,
                                  ),
                                  const Divider(
                                    color: Colors.white12,
                                    height: 1,
                                    indent: 16,
                                    endIndent: 16,
                                  ),
                                  _ActionRow(
                                    tone: _ActionTone.danger,
                                    icon: Icons.delete_forever_rounded,
                                    title: 'Delete Account',
                                    subtitle:
                                        'Permanently delete all data',
                                    onTap: _showDeleteAccountDialog,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Positioned(
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
          ),
        ],
      ),
    );
  }
}

/* -------------------- Header -------------------- */

class _Header extends StatelessWidget {
  final VoidCallback onTapOrb;
  const _Header({required this.onTapOrb});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Profile",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.3,
                  height: 1.05,
                ),
              ),
              SizedBox(height: 6),
              Text(
                "Manage your account and security.",
                style: TextStyle(
                  color: Color(0xFFEAF2FF),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        InkWell(
          onTap: onTapOrb,
          borderRadius: BorderRadius.circular(999),
          child: SizedBox(
            width: 44,
            height: 44,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF4DA3FF),
                  ),
                ),
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.o(0.10),
                  ),
                ),
                Container(
                  width: 26,
                  height: 26,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF4DA3FF), Color(0xFF2B7FDB)],
                    ),
                  ),
                ),
                const Icon(Icons.lock_rounded, color: Colors.white, size: 16),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/* -------------------- Small UI helpers -------------------- */

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.o(0.05),
            border: Border.all(color: Colors.white.o(0.10)),
          ),
          child: Icon(icon, size: 18, color: const Color(0xFF4DA3FF)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: const Color(0xFFEAF2FF).o(0.80),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _MiniStat({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.o(0.05),
        border: Border.all(color: Colors.white.o(0.10)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [const Color(0xFF4DA3FF).o(0.25), Colors.white.o(0.05)],
              ),
            ),
            child: Icon(icon, size: 16, color: Colors.white.o(0.85)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: const Color(0xFFEAF2FF).o(0.50),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color fg;
  final Color bg;
  final Color border;

  const _Chip({
    required this.icon,
    required this.text,
    required this.fg,
    required this.bg,
    required this.border,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: bg,
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: fg),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: fg,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

enum _ActionTone { danger, normal }

class _ActionRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final _ActionTone tone;

  const _ActionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.tone,
  });

  @override
  Widget build(BuildContext context) {
    final isDanger = tone == _ActionTone.danger;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDanger
                    ? const Color(0xFFEF4444).o(0.10)
                    : Colors.white.o(0.05),
                border: Border.all(
                  color: isDanger
                      ? const Color(0xFFEF4444).o(0.20)
                      : Colors.white.o(0.10),
                ),
              ),
              child: Icon(
                icon,
                color: isDanger
                    ? const Color(0xFFF87171)
                    : const Color(0xFF4DA3FF),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isDanger ? const Color(0xFFF87171) : Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: const Color(0xFFEAF2FF).o(0.55),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: (isDanger ? const Color(0xFFF87171) : Colors.white).o(
                0.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const _GlassCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            color: Colors.white.o(0.06),
            border: Border.all(color: Colors.white.o(0.10)),
            boxShadow: [
              BoxShadow(
                blurRadius: 30,
                spreadRadius: 2,
                color: Colors.black.o(0.25),
              ),
            ],
          ),
          child: child,
        ),
      ),
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

class _NoisePainter extends CustomPainter {
  static final math.Random _r = math.Random(7);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.o(0.06);
    const count = 900;
    for (int i = 0; i < count; i++) {
      final dx = _r.nextDouble() * size.width;
      final dy = _r.nextDouble() * size.height;
      canvas.drawCircle(Offset(dx, dy), _r.nextDouble() * 0.8, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// ✅ withOpacity deprecated warning avoid helper
extension _ColorOpacity on Color {
  Color o(double opacity) {
    final a = (opacity.clamp(0.0, 1.0) * 255).round();
    return withAlpha(a);
  }
}

// ── Stat Detail Row ──────────────────────────────────────────────────────────

class _StatDetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _StatDetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Colors.white.o(0.05),
            border: Border.all(color: Colors.white.o(0.08)),
          ),
          child: Icon(icon, size: 16, color: const Color(0xFF4DA3FF)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: const Color(0xFFEAF2FF).o(0.55),
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}

// ── Upgrade Button ────────────────────────────────────────────────────────────

class _UpgradeButton extends StatelessWidget {
  final List<dynamic> products;
  final Future<void> Function(dynamic) onPurchase;

  const _UpgradeButton({
    required this.products,
    required this.onPurchase,
  });

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return GestureDetector(
        onTap: () => context.push('/subscription'),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: const LinearGradient(
              colors: [Color(0xFF4DA3FF), Color(0xFF2B7FDB)],
            ),
          ),
          child: const Center(
            child: Text(
              'Upgrade to Pro',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 15,
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      children: products.map<Widget>((p) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: GestureDetector(
            onTap: () => onPurchase(p),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: const LinearGradient(
                  colors: [Color(0xFF4DA3FF), Color(0xFF2B7FDB)],
                ),
                boxShadow: [
                  BoxShadow(
                    blurRadius: 16,
                    color: const Color(0xFF4DA3FF).o(0.25),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.workspace_premium_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      p.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Text(
                    p.price,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
