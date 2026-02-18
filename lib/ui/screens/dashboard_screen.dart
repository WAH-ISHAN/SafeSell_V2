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

import '../../services/vault_service.dart';
import '../../services/billing_service.dart';
import '../../services/feature_gate_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _fade;
  late final Animation<double> _slideUp;

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
    devices: 1,
    backup: "Auto",
    risk: "Low",
  );

  double get _usedPct {
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

    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _fade = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
    _slideUp = Tween<double>(
      begin: 18,
      end: 0,
    ).animate(CurvedAnimation(parent: _c, curve: Curves.easeOutCubic));

    _bgC = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat(reverse: true);

    _c.forward();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final stats = await _vaultService.getStats();
    if (mounted) {
      setState(() {
        _vaultStats = stats;
        _loadingStats = false;
      });
    }
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
        // Show confirmation dialog before importing
        final bool? shouldDelete = await showDialog<bool>(
          context: context,
          builder:
              (context) => AlertDialog(
                backgroundColor: const Color(0xFF141A24),
                title: const Text(
                  "Import Options",
                  style: TextStyle(color: Colors.white),
                ),
                content: const Text(
                  "Do you want to delete the original files from your gallery after importing them to the secure vault?",
                  style: TextStyle(color: Colors.white70),
                ),
                actions: [
                  TextButton(
                    onPressed:
                        () => Navigator.pop(context, false), // Keep original
                    child: const Text("Keep Original"),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                    ),
                    onPressed:
                        () => Navigator.pop(context, true), // Delete original
                    child: const Text("Delete Original"),
                  ),
                ],
              ),
        );

        if (shouldDelete == null || !mounted) return;

        // Show Progress Sheet
        await showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder:
              (context) => ImportProgressSheet(
                files: result.files,
                deleteOriginals: shouldDelete,
                cryptoStore: _vaultService,
              ),
        );

        // Refresh stats after import
        await _loadStats();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error picking files: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
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
            onPressed:
                () => Navigator.push(
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
        label: const Text(
          "Add to Vault",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Stack(
        children: [
          const PremiumBackground(child: SizedBox.shrink()),
          SafeArea(
            child: AnimatedBuilder(
              animation: _c,
              builder: (context, child) {
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
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 110),
          children: [
            _HeaderRow(greeting: _greeting, risk: _plan.risk),
            const SizedBox(height: 16),
            _buildUsageCard(context),
            const SizedBox(height: 18),
            _buildQuickStats(context),
            const SizedBox(height: 18),
            _buildQuickAccessGrid(context),
            const SizedBox(height: 18),
            _buildPromoCard(context),
          ],
        ),
      ),
    );
  }

  Widget _buildUsageCard(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4DA3FF), Color(0xFF2B7FDB)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 18,
                      color: const Color(0xFF4DA3FF).withValues(alpha: 0.35),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.workspace_premium_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          _billing.isPro ? "Pro Plan" : "Free Plan",
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                        if (_billing.isPro) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'PRO',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _billing.isPro
                          ? '${_vaultStats?.totalFiles ?? 0} files • Unlimited storage'
                          : '${_vaultStats?.totalFiles ?? 0}/${FeatureGateService.freeVaultFilesLimit} files • $_usedGBDisplay GB / ${_plan.storageGB} GB',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // Simple ring placeholder
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  value: _usedPct / 100,
                  strokeWidth: 3,
                  backgroundColor: Colors.white10,
                ),
              ),
              const SizedBox(width: 10),
              if (!_billing.isPro)
                TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const SubscriptionScreen(),
                    ),
                  ),
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.1),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text("Upgrade", style: TextStyle(fontSize: 12)),
                ),
            ],
          ),
          const SizedBox(height: 14),
          // Mini stats
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              const _MiniStat(
                label: "Monitor",
                value: "Active",
                icon: Icons.radar_rounded,
                color: Color(0xFF4DA3FF),
              ),
              _MiniStat(
                label: "Devices",
                value: "${_plan.devices}",
                icon: Icons.devices,
                color: Colors.white,
              ),
              _MiniStat(
                label: "Backup",
                value: _plan.backup,
                icon: Icons.cloud_done,
                color: const Color(0xFF10B981),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                "Quick Stats",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const VaultScreen(initialCategory: 'all'),
                  ),
                );
              },
              child: const Text("View all"),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _loadingStats
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(
                    color: Color(0xFF4DA3FF),
                  ),
                ),
              )
            : _vaultStats == null || _vaultStats!.totalFiles == 0
                ? Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.folder_open,
                          color: Colors.white.withValues(alpha: 0.3),
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          "No files in vault yet",
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  )
                : SizedBox(
                    height: 50,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        if (_vaultStats!.photos > 0)
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const VaultScreen(initialCategory: 'photos'),
                                ),
                              );
                            },
                            child: QuickStatPill(
                              icon: Icons.image,
                              label: "Images",
                              count: _vaultStats!.photos,
                              color: const Color(0xFF4DA3FF),
                            ),
                          ),
                        if (_vaultStats!.photos > 0 && _vaultStats!.videos > 0)
                          const SizedBox(width: 10),
                        if (_vaultStats!.videos > 0)
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const VaultScreen(initialCategory: 'videos'),
                                ),
                              );
                            },
                            child: QuickStatPill(
                              icon: Icons.video_library,
                              label: "Videos",
                              count: _vaultStats!.videos,
                              color: const Color(0xFF8B5CF6),
                            ),
                          ),
                        if ((_vaultStats!.photos > 0 || _vaultStats!.videos > 0) &&
                            _vaultStats!.docs > 0)
                          const SizedBox(width: 10),
                        if (_vaultStats!.docs > 0)
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const VaultScreen(initialCategory: 'docs'),
                                ),
                              );
                            },
                            child: QuickStatPill(
                              icon: Icons.description,
                              label: "Docs",
                              count: _vaultStats!.docs,
                              color: const Color(0xFF10B981),
                            ),
                          ),
                        if ((_vaultStats!.photos > 0 ||
                                _vaultStats!.videos > 0 ||
                                _vaultStats!.docs > 0) &&
                            _vaultStats!.zip > 0)
                          const SizedBox(width: 10),
                        if (_vaultStats!.zip > 0)
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const VaultScreen(initialCategory: 'zip'),
                                ),
                              );
                            },
                            child: QuickStatPill(
                              icon: Icons.folder_zip,
                              label: "Archives",
                              count: _vaultStats!.zip,
                              color: const Color(0xFFF59E0B),
                            ),
                          ),
                        if (_vaultStats!.apk > 0) ...[
                          const SizedBox(width: 10),
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const VaultScreen(initialCategory: 'apk'),
                                ),
                              );
                            },
                            child: QuickStatPill(
                              icon: Icons.android,
                              label: "APKs",
                              count: _vaultStats!.apk,
                              color: const Color(0xFF3DDC84),
                            ),
                          ),
                        ],
                        if (_vaultStats!.other > 0) ...[
                          const SizedBox(width: 10),
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const VaultScreen(initialCategory: 'other'),
                                ),
                              );
                            },
                            child: QuickStatPill(
                              icon: Icons.insert_drive_file,
                              label: "Other",
                              count: _vaultStats!.other,
                              color: const Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
      ],
    );
  }

  Widget _buildQuickAccessGrid(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.3,
      children: [
        SectionCard(
          title: 'Security Logs',
          subtitle: 'View activity',
          icon: Icons.monitor_heart_rounded,
          onTap:
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SecurityLogsScreen()),
              ),
        ),
        SectionCard(
          title: 'Device Manager',
          subtitle: '${_plan.devices} devices',
          icon: Icons.devices_rounded,
          onTap:
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DeviceManagerScreen()),
              ),
        ),
        SectionCard(
          title: 'Backup',
          subtitle: 'Auto enabled',
          icon: Icons.cloud_upload_rounded,
          onTap:
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BackupScreen()),
              ),
        ),
        SectionCard(
          title: 'Support',
          subtitle: 'Get help',
          icon: Icons.support_agent_rounded,
          onTap:
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SupportScreen()),
              ),
        ),
      ],
    );
  }

  Widget _buildPromoCard(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Sponsored",
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            "Upgrade to Pro",
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            "Get unlimited storage and remove ads.",
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed:
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const SubscriptionScreen(),
                    ),
                  ),
              child: const Text("Learn more →"),
            ),
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

class _HeaderRow extends StatelessWidget {
  final String greeting;
  final String risk;
  const _HeaderRow({required this.greeting, required this.risk});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          greeting,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(Icons.shield, color: Color(0xFF4DA3FF), size: 16),
            const SizedBox(width: 8),
            Text(
              "Security: $risk",
              style: const TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _MiniStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 11),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class QuickStatPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final Color color;
  const QuickStatPill({
    super.key,
    required this.icon,
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              "$count",
              style: const TextStyle(color: Colors.white70, fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }
}
