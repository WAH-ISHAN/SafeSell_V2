import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import 'profile_screen.dart';
import 'support_screen.dart';
import 'subscription_screen.dart';
import 'security_logs_screen.dart';
import 'device_manager_screen.dart';
import 'backup_screen.dart';
import 'vault_screen.dart';

import '../widgets/section_card.dart';
import '../widgets/premium_ui.dart';
import '../widgets/import_progress_sheet.dart';
import '../widgets/usb_shield_banner.dart';

import '../../services/vault_service.dart';
import '../../services/billing_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  // Intro
  late final AnimationController _c;
  late final Animation<double> _fade;
  late final Animation<double> _slideUp;

  // Background drift
  late final AnimationController _bgC;

  late final DateTime _now;
  late final String _greeting;

  // Services
  late final VaultService _vaultService;
  final _billing = BillingService();
  VaultStats? _vaultStats;
  bool _loadingStats = true;

  final _plan = const _Plan(
    name: "Free Plan",
    storageGB: 5,
    devices: 2,
    backup: "Auto enabled",
    risk: "Low",
  );

  double get _usedPct {
    if (_billing.isPro) return 0;
    if (_vaultStats == null) return 0;
    final pct = (_vaultStats!.sizeGB / _plan.storageGB) * 100.0;
    return pct.clamp(0, 100);
  }

  String get _usedGBDisplay {
    if (_vaultStats == null) return "0.0";
    return _vaultStats!.sizeGB.toStringAsFixed(2);
  }

  @override
  void initState() {
    super.initState();
    _vaultService = VaultService();
    _billing.init();

    _now = DateTime.now();
    final h = _now.hour;
    if (h < 12) {
      _greeting = "Good morning";
    } else if (h < 18) {
      _greeting = "Good afternoon";
    } else {
      _greeting = "Good evening";
    }

    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 650));
    _fade = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
    _slideUp = Tween<double>(begin: 18, end: 0)
        .animate(CurvedAnimation(parent: _c, curve: Curves.easeOutCubic));

    _bgC = AnimationController(vsync: this, duration: const Duration(seconds: 12))
      ..repeat(reverse: true);

    _c.forward();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final stats = await _vaultService.getStats();
    if (!mounted) return;
    setState(() {
      _vaultStats = stats;
      _loadingStats = false;
    });
  }

  @override
  void dispose() {
    _c.dispose();
    _bgC.dispose();
    super.dispose();
  }

  Future<void> _pickAndImport() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.any,
      );

      if (result != null && result.files.isNotEmpty && mounted) {
        final bool? shouldDelete = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF141A24),
            title: const Text("Import Options", style: TextStyle(color: Colors.white)),
            content: const Text(
              "Do you want to delete the original files from your gallery after importing them to the secure vault?",
              style: TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text("Keep Original"),
              ),
              TextButton(
                style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                onPressed: () => Navigator.pop(context, true),
                child: const Text("Delete Original"),
              ),
            ],
          ),
        );

        if (shouldDelete == null || !mounted) return;

        await showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => ImportProgressSheet(
            files: result.files,
            deleteOriginals: shouldDelete,
            cryptoStore: _vaultService,
          ),
        );

        await _loadStats();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error picking files: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'Dashboard',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -0.2),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.person_rounded),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _pickAndImport,
        backgroundColor: const Color(0xFF4DA3FF),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text("Add to Vault", style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Stack(
        children: [
          // Base premium background
          const PremiumBackground(child: SizedBox.shrink()),

          // Figma-style dashboard background overlay + drifting blobs + grain
          Positioned.fill(
            child: IgnorePointer(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: const Alignment(-0.75, -0.9),
                          radius: 1.2,
                          colors: [
                            const Color(0xFF4DA3FF).withOpacity(0.10),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.55],
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: const Alignment(0.95, -0.55),
                          radius: 1.2,
                          colors: [
                            const Color(0xFF0A2A4F).withOpacity(0.28),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.55],
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: const Alignment(-0.55, 0.95),
                          radius: 1.2,
                          colors: [
                            const Color(0xFF4DA3FF).withOpacity(0.07),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.55],
                        ),
                      ),
                    ),
                  ),

                  // drift blob 1
                  AnimatedBuilder(
                    animation: _bgC,
                    builder: (_, __) {
                      final t = _bgC.value;
                      final dx = lerpDouble(0, -18, _easeInOut(t))!;
                      final dy = lerpDouble(0, 14, _easeInOut(t))!;
                      final sc = lerpDouble(1.0, 1.03, _easeInOut(t))!;
                      return Transform.translate(
                        offset: Offset(dx, dy),
                        child: Transform.scale(
                          scale: sc,
                          child: Align(
                            alignment: Alignment.topRight,
                            child: Container(
                              margin: const EdgeInsets.only(top: -96, right: -96),
                              width: 520,
                              height: 520,
                              decoration: BoxDecoration(
                                color: const Color(0xFF4DA3FF).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  // drift blob 2
                  AnimatedBuilder(
                    animation: _bgC,
                    builder: (_, __) {
                      final t = _bgC.value;
                      final dx = lerpDouble(0, 16, _easeInOut(t))!;
                      final dy = lerpDouble(0, -12, _easeInOut(t))!;
                      final sc = lerpDouble(1.0, 1.04, _easeInOut(t))!;
                      return Transform.translate(
                        offset: Offset(dx, dy),
                        child: Transform.scale(
                          scale: sc,
                          child: Align(
                            alignment: Alignment.bottomLeft,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 64, left: -96),
                              width: 460,
                              height: 460,
                              decoration: BoxDecoration(
                                color: const Color(0xFF0A2A4F).withOpacity(0.30),
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  // blur pass
                  Positioned.fill(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 120, sigmaY: 120),
                      child: const SizedBox.shrink(),
                    ),
                  ),

                  // subtle grain
                  Positioned.fill(
                    child: Opacity(
                      opacity: 0.08,
                      child: CustomPaint(painter: _NoisePainter()),
                    ),
                  ),
                ],
              ),
            ),
          ),

          SafeArea(
            child: AnimatedBuilder(
              animation: _c,
              builder: (_, __) {
                return Opacity(
                  opacity: _fade.value,
                  child: Transform.translate(
                    offset: Offset(0, _slideUp.value),
                    child: _buildContent(context),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 412),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 10, 24, 110),
          children: [
            const UsbShieldBanner(),
            const SizedBox(height: 10),

            _HeaderRowFigma(
              greeting: _greeting,
              risk: _plan.risk,
            ),

            const SizedBox(height: 16),

            _PlanCardFigma(
              isPro: _billing.isPro,
              planName: _billing.isPro ? "Pro Plan" : _plan.name,
              usedText: _billing.isPro
                  ? '${_vaultStats?.totalFiles ?? 0} files • Unlimited storage'
                  : '$_usedGBDisplay GB / ${_plan.storageGB} GB used',
              usedPct: _usedPct,
              devices: _plan.devices,
              onUpgrade: _billing.isPro
                  ? null
                  : () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
                      ),
            ),

            const SizedBox(height: 18),

            _QuickStatsFigma(
              loading: _loadingStats,
              stats: _vaultStats,
              onViewAll: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const VaultScreen(initialCategory: 'all')),
              ),
              onTapCategory: (cat) => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => VaultScreen(initialCategory: cat)),
              ),
            ),

            const SizedBox(height: 18),

            _SmartSuggestionFigma(
              onEnable: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileScreen()), // or Settings screen if you have
              ),
            ),

            const SizedBox(height: 18),

            _QuickAccessGridFigma(
              devices: _plan.devices,
              onSecurityLogs: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SecurityLogsScreen()),
              ),
              onDeviceManager: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DeviceManagerScreen()),
              ),
              onBackup: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BackupScreen()),
              ),
              onSupport: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SupportScreen()),
              ),
            ),

            const SizedBox(height: 18),

            _PromoCardFigma(
              onLearnMore: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ======================= UI BLOCKS (Figma style) =======================

class _HeaderRowFigma extends StatelessWidget {
  final String greeting;
  final String risk;
  const _HeaderRowFigma({required this.greeting, required this.risk});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      greeting,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                        height: 1.05,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colors.white.withOpacity(0.10)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.verified_user_rounded, color: Color(0xFF4DA3FF), size: 16),
                        const SizedBox(width: 6),
                        Text(
                          'Security: $risk',
                          style: TextStyle(
                            color: const Color(0xFFEAF2FF).withOpacity(0.75),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Your vault is encrypted and monitoring is active.',
                style: TextStyle(
                  color: const Color(0xFFEAF2FF).withOpacity(0.55),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 14),
        const _LockOrb(),
      ],
    );
  }
}

class _LockOrb extends StatelessWidget {
  const _LockOrb();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 44,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF4DA3FF).withOpacity(0.20),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white.withOpacity(0.10)),
            ),
          ),
          // rotating gradient ring
          _RotatingGradientRing(
            size: 30,
            thickness: 6,
            duration: const Duration(seconds: 8),
            colors: const [Color(0xFF4DA3FF), Color(0xFF2B7FDB)],
          ),
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: const Color(0xFF0B0F14),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const Icon(Icons.lock_rounded, color: Colors.white70, size: 16),
        ],
      ),
    );
  }
}

class _PlanCardFigma extends StatelessWidget {
  final bool isPro;
  final String planName;
  final String usedText;
  final double usedPct;
  final int devices;
  final VoidCallback? onUpgrade;

  const _PlanCardFigma({
    required this.isPro,
    required this.planName,
    required this.usedText,
    required this.usedPct,
    required this.devices,
    required this.onUpgrade,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Stack(
        children: [
          Positioned(
            top: -60,
            right: -80,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                color: const Color(0xFF4DA3FF).withOpacity(0.10),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          Positioned(
            bottom: -90,
            left: -80,
            child: Container(
              width: 290,
              height: 290,
              decoration: BoxDecoration(
                color: const Color(0xFF0A2A4F).withOpacity(0.30),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF4DA3FF), Color(0xFF2B7FDB)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          blurRadius: 18,
                          color: const Color(0xFF4DA3FF).withOpacity(0.35),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          planName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          usedText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: const Color(0xFFEAF2FF).withOpacity(0.50),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  _UsageRing(value: usedPct),
                  const SizedBox(width: 10),
                  if (!isPro)
                    InkWell(
                      onTap: onUpgrade,
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF4DA3FF), Color(0xFF2B7FDB)],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              blurRadius: 14,
                              color: const Color(0xFF4DA3FF).withOpacity(0.28),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Upgrade',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            SizedBox(width: 4),
                            Icon(Icons.chevron_right_rounded, color: Colors.white, size: 18),
                          ],
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 14),

              Row(
                children: [
                  Expanded(
                    child: _MiniStatTile(
                      icon: Icons.radar_rounded,
                      label: 'Monitor',
                      value: 'ON',
                      accent: const Color(0xFF4DA3FF).withOpacity(0.35),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MiniStatTile(
                      icon: Icons.devices_rounded,
                      label: 'Devices',
                      value: '$devices',
                      accent: const Color(0xFFEAF2FF).withOpacity(0.18),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MiniStatTile(
                      icon: Icons.cloud_done_rounded,
                      label: 'Backup',
                      value: 'AUTO',
                      accent: const Color(0xFF0A2A4F).withOpacity(0.35),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color accent;

  const _MiniStatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
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
                colors: [accent, Colors.white.withOpacity(0.05)],
              ),
              boxShadow: const [
                BoxShadow(blurRadius: 14, color: Color(0x40000000)),
              ],
            ),
            child: Icon(icon, size: 18, color: Colors.white.withOpacity(0.85)),
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
                    color: const Color(0xFFEAF2FF).withOpacity(0.50),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
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
                    letterSpacing: -0.1,
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

class _UsageRing extends StatelessWidget {
  final double value; // 0..100
  const _UsageRing({required this.value});

  @override
  Widget build(BuildContext context) {
    const size = 44.0;
    const stroke = 5.0;
    final r = (size - stroke) / 2;
    final c = 2 * math.pi * r;
    final dash = (value / 100) * c;

    return SizedBox(
      width: 44,
      height: 44,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(size, size),
            painter: _RingPainter(
              stroke: stroke,
              bg: const Color(0x1EEAF2FF),
              fg: const Color(0xF24DA3FF),
              progress: dash / c,
            ),
          ),
          Text(
            '${value.round()}%',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double stroke;
  final Color bg;
  final Color fg;
  final double progress;

  _RingPainter({
    required this.stroke,
    required this.bg,
    required this.fg,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = (size.width - stroke) / 2;

    final bgPaint = Paint()
      ..color = bg
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;

    final fgPaint = Paint()
      ..color = fg
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, r, bgPaint);

    final start = -math.pi / 2;
    final sweep = 2 * math.pi * progress;
    canvas.drawArc(Rect.fromCircle(center: center, radius: r), start, sweep, false, fgPaint);
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.stroke != stroke ||
        oldDelegate.bg != bg ||
        oldDelegate.fg != fg;
  }
}

class _QuickStatsFigma extends StatelessWidget {
  final bool loading;
  final VaultStats? stats;
  final VoidCallback onViewAll;
  final void Function(String category) onTapCategory;

  const _QuickStatsFigma({
    required this.loading,
    required this.stats,
    required this.onViewAll,
    required this.onTapCategory,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Quick Stats',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
            ),
            TextButton(
              onPressed: onViewAll,
              child: const Text(
                'View all',
                style: TextStyle(
                  color: Color(0xFF4DA3FF),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (loading)
          const Padding(
            padding: EdgeInsets.all(18),
            child: Center(
              child: CircularProgressIndicator(color: Color(0xFF4DA3FF)),
            ),
          )
        else if (stats == null || stats!.totalFiles == 0)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.10)),
            ),
            child: Row(
              children: [
                Icon(Icons.folder_open_rounded, color: Colors.white.withOpacity(0.30), size: 22),
                const SizedBox(width: 12),
                Text(
                  'No files in vault yet',
                  style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          )
        else
          SizedBox(
            height: 56,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _StatChip(
                  icon: Icons.image_rounded,
                  label: 'Images',
                  count: stats!.photos,
                  color: const Color(0xFF4DA3FF),
                  onTap: () => onTapCategory('photos'),
                ),
                const SizedBox(width: 12),
                _StatChip(
                  icon: Icons.video_library_rounded,
                  label: 'Videos',
                  count: stats!.videos,
                  color: const Color(0xFF8B5CF6),
                  onTap: () => onTapCategory('videos'),
                ),
                const SizedBox(width: 12),
                _StatChip(
                  icon: Icons.description_rounded,
                  label: 'Docs',
                  count: stats!.docs,
                  color: const Color(0xFF10B981),
                  onTap: () => onTapCategory('docs'),
                ),
                const SizedBox(width: 12),
                _StatChip(
                  icon: Icons.folder_zip_rounded,
                  label: 'ZIP',
                  count: stats!.zip,
                  color: const Color(0xFFF59E0B),
                  onTap: () => onTapCategory('zip'),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final Color color;
  final VoidCallback onTap;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.count,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.10)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.10),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.75),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SmartSuggestionFigma extends StatelessWidget {
  final VoidCallback onEnable;
  const _SmartSuggestionFigma({required this.onEnable});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withOpacity(0.10)),
            ),
            child: const Icon(Icons.auto_awesome_rounded, color: Color(0xFF4DA3FF), size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Smart Suggestion',
                  style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  'Enable biometric unlock for 2× faster access and better security.',
                  style: TextStyle(
                    color: const Color(0xFFEAF2FF).withOpacity(0.55),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  children: [
                    InkWell(
                      onTap: onEnable,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withOpacity(0.10)),
                        ),
                        child: const Text(
                          'Enable',
                          style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () {},
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                        child: Text(
                          'Later',
                          style: TextStyle(
                            color: const Color(0xFFEAF2FF).withOpacity(0.70),
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Icon(Icons.bolt_rounded, color: Colors.white.withOpacity(0.35), size: 20),
        ],
      ),
    );
  }
}

class _QuickAccessGridFigma extends StatelessWidget {
  final int devices;
  final VoidCallback onSecurityLogs;
  final VoidCallback onDeviceManager;
  final VoidCallback onBackup;
  final VoidCallback onSupport;

  const _QuickAccessGridFigma({
    required this.devices,
    required this.onSecurityLogs,
    required this.onDeviceManager,
    required this.onBackup,
    required this.onSupport,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Quick Access',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18),
              ),
            ),
            Text(
              'Edit',
              style: TextStyle(
                color: const Color(0xFFEAF2FF).withOpacity(0.60),
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.25,
          children: [
            SectionCard(
              title: 'Security Logs',
              subtitle: 'View activity',
              icon: Icons.monitor_heart_rounded,
              onTap: onSecurityLogs,
            ),
            SectionCard(
              title: 'Device Manager',
              subtitle: '$devices devices',
              icon: Icons.devices_rounded,
              onTap: onDeviceManager,
            ),
            SectionCard(
              title: 'Backup',
              subtitle: 'Auto enabled',
              icon: Icons.cloud_upload_rounded,
              onTap: onBackup,
            ),
            SectionCard(
              title: 'Support',
              subtitle: 'Get help',
              icon: Icons.support_agent_rounded,
              onTap: onSupport,
            ),
          ],
        ),
      ],
    );
  }
}

class _PromoCardFigma extends StatelessWidget {
  final VoidCallback onLearnMore;
  const _PromoCardFigma({required this.onLearnMore});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Stack(
        children: [
          Positioned(
            top: -40,
            right: -40,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                color: const Color(0xFF4DA3FF).withOpacity(0.10),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sponsored',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.45),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Upgrade to Pro to remove ads',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Unlimited vault, stealth features, and advanced protection.',
                style: TextStyle(
                  color: const Color(0xFFEAF2FF).withOpacity(0.55),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 10),
              InkWell(
                onTap: onLearnMore,
                borderRadius: BorderRadius.circular(10),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Learn more',
                      style: TextStyle(color: Color(0xFF4DA3FF), fontSize: 14, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.chevron_right_rounded, color: const Color(0xFF4DA3FF), size: 18),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Plan {
  final String name;
  final double storageGB;
  final int devices;
  final String backup;
  final String risk;

  const _Plan({
    required this.name,
    required this.storageGB,
    required this.devices,
    required this.backup,
    required this.risk,
  });
}

// ======================= Small helpers =======================

double _easeInOut(double t) => Curves.easeInOut.transform(t);

class _RotatingGradientRing extends StatefulWidget {
  final double size;
  final double thickness;
  final Duration duration;
  final List<Color> colors;

  const _RotatingGradientRing({
    required this.size,
    required this.thickness,
    required this.duration,
    required this.colors,
  });

  @override
  State<_RotatingGradientRing> createState() => _RotatingGradientRingState();
}

class _RotatingGradientRingState extends State<_RotatingGradientRing> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: widget.duration)..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        return Transform.rotate(
          angle: _c.value * 2 * math.pi,
          child: CustomPaint(
            size: Size(widget.size, widget.size),
            painter: _GradientRingPainter(
              thickness: widget.thickness,
              colors: widget.colors,
            ),
          ),
        );
      },
    );
  }
}

class _GradientRingPainter extends CustomPainter {
  final double thickness;
  final List<Color> colors;

  _GradientRingPainter({required this.thickness, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    final rect = Rect.fromCircle(center: Offset(r, r), radius: r);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(colors: colors).createShader(rect);

    canvas.drawArc(rect.deflate(thickness / 2), 0, 2 * math.pi, false, paint);
  }

  @override
  bool shouldRepaint(covariant _GradientRingPainter oldDelegate) {
    return oldDelegate.thickness != thickness || oldDelegate.colors != colors;
  }
}

/// lightweight “grain” painter (no asset needed)
class _NoisePainter extends CustomPainter {
  final math.Random _r = math.Random(7);

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = Colors.white.withOpacity(0.10);
    const step = 3.0;
    for (double y = 0; y < size.height; y += step) {
      for (double x = 0; x < size.width; x += step) {
        final a = _r.nextDouble();
        if (a < 0.015) {
          canvas.drawRect(Rect.fromLTWH(x, y, 1.2, 1.2), p);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _NoisePainter oldDelegate) => false;
}