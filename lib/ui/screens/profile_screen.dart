import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../security/key_manager.dart';
import '../../models/app_settings.dart';
import '../../services/billing_service.dart';
import '../../services/vault_service.dart';


/// âœ… React ProfileScreen layout â†’ Flutter version
/// - same premium background language (radials + blobs + grain)
/// - header + â€œsecurity orbâ€
/// --- identity card (avatar + verified chip + plan/risk chips + info rows + mini stats)
/// - Pro upgrade CTA card
/// - Account list (Sign out)
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with TickerProviderStateMixin {
  late final AnimationController _bgC;
  late final AnimationController _c;
  late final Animation<double> _fade;
  late final Animation<double> _slideUp;

  final _km = KeyManager();
  final _billing = BillingService();
  final _vault = VaultService();

  VaultStats? _vaultStats;
  AppSettings? _settings;
  bool _statsLoading = true;

  String? _keyB64;
  bool _keyLoading = false;

  @override
  void initState() {
    super.initState();

    _bgC = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat(reverse: true);

    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fade = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
    _slideUp = Tween<double>(begin: 18, end: 0).animate(
      CurvedAnimation(parent: _c, curve: Curves.easeOutCubic),
    );
    _c.forward();

    _billing.init();
    _loadStats();
    _loadKey();
  }

  @override
  void dispose() {
    _bgC.dispose();
    _c.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    try {
      final stats = await _vault.getStats();
      // if you store settings elsewhere, keep your existing approach
      final settings = AppSettings();
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

  Future<void> _logout() async {
    try {
      _km.lock();
      await FirebaseAuth.instance.signOut();
    } catch (_) {}
    if (mounted) context.go('/login');
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  String _formatJoinDate(DateTime? dt) {
    if (dt == null) return 'Unknown';
    const m = [
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
    return '${m[dt.month - 1]} ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final name = (user?.displayName?.trim().isNotEmpty ?? false)
        ? user!.displayName!.trim()
        : 'User';
    final email = user?.email ?? 'Not signed in';
    final joined = _formatJoinDate(user?.metadata.creationTime);

    final planText = _billing.isPro ? 'Pro Plan' : 'Free Plan';
    final riskText = 'Low Risk'; // you can compute from security service later
    final vaultStatus = 'Encrypted';
    final keyStatus =
        (_keyLoading) ? 'Loading' : ((_keyB64?.isNotEmpty ?? false) ? 'Key Active' : 'No Key');
    final modeStatus = (_settings?.stealthEnabled ?? false) ? 'Stealth' : 'Normal';

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'Profile',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -0.2),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      body: Stack(
        children: [
          // base bg
          const ColoredBox(color: Color(0xFF0B0F14)),

          // premium radials (same â€œDashboard languageâ€)
          const Positioned.fill(
            child: _RadialBG(),
          ),

          // subtle grain
          Positioned.fill(
            child: IgnorePointer(
              child: Opacity(
                opacity: 0.08,
                child: CustomPaint(painter: _NoisePainter()),
              ),
            ),
          ),

          // animated blobs
          AnimatedBuilder(
            animation: _bgC,
            builder: (_, __) {
              final t = Curves.easeInOut.transform(_bgC.value);
              return Stack(
                children: [
                  Positioned(
                    top: -120 + (t * 18),
                    right: -120 - (t * 18),
                    child: _GlowBlob(
                      size: 520,
                      blur: 120,
                      color: const Color(0xFF4DA3FF).o(0.12),
                    ),
                  ),
                  Positioned(
                    bottom: 70 - (t * 12),
                    left: -120 + (t * 16),
                    child: _GlowBlob(
                      size: 460,
                      blur: 110,
                      color: const Color(0xFF0A2A4F).o(0.30),
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
                            // Header (Profile + subtitle + orb)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Profile',
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
                                        'Manage your account and security.',
                                        style: TextStyle(
                                          color: Color(0xFFEAF2FF),
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                _SecurityOrb(
                                  onTap: () => _snack('Security details (TODO)'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Identity card
                            _GlassCard(
                              padding: const EdgeInsets.all(18),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      // avatar
                                      Container(
                                        width: 80,
                                        height: 80,
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(26),
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
                                              color: const Color(0xFF4DA3FF)
                                                  .o(0.35),
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
                                                    name,
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
                                                if (user?.emailVerified ??
                                                    false) ...[
                                                  const SizedBox(width: 8),
                                                  _Chip(
                                                    icon: Icons.verified_rounded,
                                                    text: 'Verified',
                                                    fg: const Color(0xFF4DA3FF),
                                                    bg: Colors.white.o(0.05),
                                                    border:
                                                        Colors.white.o(0.10),
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
                                                  icon:
                                                      Icons.workspace_premium_rounded,
                                                  text: planText,
                                                  fg: const Color(0xFF4DA3FF),
                                                  bg: const Color(0xFF4DA3FF)
                                                      .o(0.15),
                                                  border:
                                                      const Color(0xFF4DA3FF)
                                                          .o(0.25),
                                                ),
                                                _Chip(
                                                  icon: Icons.shield_rounded,
                                                  text: riskText,
                                                  fg: const Color(0xFFEAF2FF)
                                                      .o(0.75),
                                                  bg: Colors.white.o(0.05),
                                                  border:
                                                      Colors.white.o(0.10),
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
                                    label: email,
                                  ),
                                  const SizedBox(height: 10),
                                  _InfoRow(
                                    icon: Icons.calendar_month_rounded,
                                    label: 'Joined $joined',
                                  ),

                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _MiniStat(
                                          icon: Icons.shield_rounded,
                                          label: 'Vault',
                                          value: vaultStatus,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: _MiniStat(
                                          icon: Icons.key_rounded,
                                          label: 'Key',
                                          value: keyStatus,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: _MiniStat(
                                          icon: Icons.tune_rounded,
                                          label: 'Mode',
                                          value: modeStatus,
                                        ),
                                      ),
                                    ],
                                  ),

                                  // optional: tiny vault stats line (React doesnâ€™t have it, but useful)
                                  const SizedBox(height: 14),
                                  _statsLoading
                                      ? Align(
                                          alignment: Alignment.centerLeft,
                                          child: Text(
                                            'Loading vault statsâ€¦',
                                            style: TextStyle(
                                              color: const Color(0xFFEAF2FF)
                                                  .o(0.55),
                                              fontWeight: FontWeight.w700,
                                              fontSize: 12,
                                            ),
                                          ),
                                        )
                                      : Align(
                                          alignment: Alignment.centerLeft,
                                          child: Text(
                                            '${_vaultStats?.totalFiles ?? 0} files â€¢ ${_vaultStats?.formattedSize ?? '0 B'}',
                                            style: TextStyle(
                                              color: const Color(0xFFEAF2FF)
                                                  .o(0.55),
                                              fontWeight: FontWeight.w700,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 16),

                            // Upgrade CTA card (like React)
                            _GlassCard(
                              padding: const EdgeInsets.all(16),
                              child: Stack(
                                children: [
                                  Positioned.fill(
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        borderRadius:
                                            BorderRadius.circular(26),
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            const Color(0xFF4DA3FF).o(0.10),
                                            Colors.transparent,
                                            const Color(0xFF0A2A4F).o(0.14),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    top: -20,
                                    right: -20,
                                    child: _GlowBlob(
                                      size: 180,
                                      blur: 60,
                                      color: const Color(0xFF4DA3FF).o(0.10),
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            width: 48,
                                            height: 48,
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                              gradient: const LinearGradient(
                                                colors: [
                                                  Color(0xFF4DA3FF),
                                                  Color(0xFF2B7FDB),
                                                ],
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  blurRadius: 18,
                                                  color: const Color(0xFF4DA3FF)
                                                      .o(0.28),
                                                ),
                                              ],
                                            ),
                                            child: const Icon(
                                              Icons.auto_awesome_rounded,
                                              color: Colors.white,
                                              size: 24,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          const Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Upgrade to Pro',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontWeight:
                                                        FontWeight.w900,
                                                    fontSize: 17,
                                                  ),
                                                ),
                                                SizedBox(height: 4),
                                                Text(
                                                  'Unlimited storage, stealth features, advanced protection & priority support.',
                                                  style: TextStyle(
                                                    color: Color(0xFFEAF2FF),
                                                    fontWeight:
                                                        FontWeight.w600,
                                                    fontSize: 13,
                                                    height: 1.35,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 14),
                                      _PrimaryButton(
                                        text: 'View Pro Plans',
                                        onTap: () =>
                                            context.push('/subscription'),
                                      ),
                                      const SizedBox(height: 10),
                                      Center(
                                        child: TextButton(
                                          onPressed: () =>
                                              context.push('/subscription'),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                'Compare features',
                                                style: TextStyle(
                                                  color: const Color(0xFF4DA3FF)
                                                      .o(0.95),
                                                  fontWeight: FontWeight.w900,
                                                  fontSize: 13,
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Icon(
                                                Icons.chevron_right_rounded,
                                                size: 18,
                                                color: const Color(0xFF4DA3FF)
                                                    .o(0.95),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 18),

                            // Account section (like React list)
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
                              child: _ActionRow(
                                tone: _ActionTone.danger,
                                icon: Icons.logout_rounded,
                                title: 'Sign Out',
                                subtitle: 'Log out from this device',
                                onTap: _logout,
                              ),
                            ),

                            // optional: quick key copy (handy for your app)
                            if ((_keyB64?.isNotEmpty ?? false)) ...[
                              const SizedBox(height: 14),
                              _GlassCard(
                                padding: const EdgeInsets.all(14),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.white.o(0.05),
                                        border: Border.all(
                                          color: Colors.white.o(0.10),
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.key_rounded,
                                        color: Color(0xFF4DA3FF),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        'Copy Vault Key',
                                        style: TextStyle(
                                          color: Colors.white.o(0.90),
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () async {
                                        await Clipboard.setData(
                                          ClipboardData(text: _keyB64!),
                                        );
                                        _snack('Copied to clipboard');
                                      },
                                      child: Text(
                                        'Copy',
                                        style: TextStyle(
                                          color: const Color(0xFF4DA3FF)
                                              .o(0.95),
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // top blur bar like your other screens
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

/* ============================ UI Helpers ============================ */

class _RadialBG extends StatelessWidget {
  const _RadialBG();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: const [
        // 20% 10% blue
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(-0.75, -0.85),
                radius: 1.25,
                colors: [Color(0x1A4DA3FF), Colors.transparent],
                stops: [0.0, 0.55],
              ),
            ),
          ),
        ),
        // 90% 25% navy
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0.90, -0.55),
                radius: 1.15,
                colors: [Color(0x470A2A4F), Colors.transparent],
                stops: [0.0, 0.55],
              ),
            ),
          ),
        ),
        // 30% 95% blue
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(-0.25, 0.85),
                radius: 1.25,
                colors: [Color(0x124DA3FF), Colors.transparent],
                stops: [0.0, 0.55],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SecurityOrb extends StatelessWidget {
  final VoidCallback onTap;
  const _SecurityOrb({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
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
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF4DA3FF).o(0.20),
              ),
            ),
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.o(0.05),
                border: Border.all(color: Colors.white.o(0.10)),
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
    );
  }
}

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

enum _ActionTone { danger }

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
                color: isDanger ? const Color(0xFFF87171) : const Color(0xFF4DA3FF),
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
              color: (isDanger ? const Color(0xFFF87171) : Colors.white).o(0.35),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  const _PrimaryButton({required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
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
        child: Center(
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 15,
            ),
          ),
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

/// âœ… avoid deprecated withOpacity
extension _ColorOpacity on Color {
  Color o(double opacity) {
    final a = (opacity.clamp(0.0, 1.0) * 255).round();
    return withAlpha(a);
  }
}
