import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';

import '../../security/encryption_service.dart';
import '../../security/key_manager.dart';
import '../../services/backup_service.dart';
import '../../services/audit_log_service.dart';
import '../../services/feature_gate_service.dart';
import '../../ui/widgets/premium_ui.dart';
import '../../app/theme.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});
  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> with TickerProviderStateMixin {
  late final BackupService _backupService;
  final _auditLog = AuditLogService();
  final _featureGate = FeatureGateService();

  bool _exporting = false;
  bool _importing = false;
  double _progress = 0.0;

  // UI-only (for Figma "Last backup")
  DateTime? _lastBackupAt;

  late final AnimationController _c;
  late final Animation<double> _fade;
  late final Animation<double> _slideUp;

  @override
  void initState() {
    super.initState();

    _backupService = BackupService(
      encryptionService: EncryptionService(),
      keyManager: KeyManager(),
    );

    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 520));
    _fade = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
    _slideUp = Tween<double>(begin: 12, end: 0)
        .animate(CurvedAnimation(parent: _c, curve: Curves.easeOutCubic));
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  // ---------------- ACTIONS (keep your logic) ----------------
  Future<void> _export() async {
    final passwordChoice = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SafeShellTheme.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Text('Password Protection', style: TextStyle(color: SafeShellTheme.textPrimary)),
            if (!_featureGate.isPro) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: SafeShellTheme.accentAlt.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'PRO',
                  style: TextStyle(
                    color: SafeShellTheme.accentAlt,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        content: Text(
          _featureGate.isPro
              ? 'Do you want to protect this backup with a password?\n\n'
                  'If yes, you\'ll need the password to restore.\n'
                  'If no, your vault key will be used.'
              : 'Password-protected backups are a Pro feature.\n\n'
                  'Use vault key for free backup, or upgrade to use custom passwords.',
          style: const TextStyle(color: SafeShellTheme.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Use Vault Key')),
          if (_featureGate.isPro)
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Set Password'))
          else
            TextButton(
              onPressed: () {
                Navigator.pop(ctx, null);
                _showUpgradeForPassword();
              },
              child: const Text('Upgrade to Pro'),
            ),
        ],
      ),
    );

    if (passwordChoice == null) return;

    String? password;
    if (passwordChoice) {
      password = await _showPasswordDialog(isExport: true);
      if (password == null) return;
    }

    setState(() {
      _exporting = true;
      _progress = 0.0;
    });

    try {
      final path = await _backupService.exportBackup(
        password: password,
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );

      await _auditLog.log(
        type: 'backup_export',
        details: {'path': path, 'passwordProtected': password != null},
      );

      if (!mounted) return;
      setState(() {
        _lastBackupAt = DateTime.now();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Backup saved to:\n$path'), duration: const Duration(seconds: 4)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
    } finally {
      if (!mounted) return;
      setState(() {
        _exporting = false;
        _progress = 0.0;
      });
    }
  }

  Future<void> _import() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['ssb'],
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty || result.files.first.path == null) return;

    if (!mounted) return;
    final isProtected = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SafeShellTheme.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Backup Type', style: TextStyle(color: SafeShellTheme.textPrimary)),
        content: const Text(
          'Is this backup password-protected?',
          style: TextStyle(color: SafeShellTheme.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No (Vault Key)')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Yes (Password)')),
        ],
      ),
    );
    if (isProtected == null) return;

    String? password;
    if (isProtected) {
      password = await _showPasswordDialog(isExport: false);
      if (password == null) return;
    }

    setState(() {
      _importing = true;
      _progress = 0.0;
    });

    try {
      final count = await _backupService.importBackup(
        result.files.first.path!,
        password: password,
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );

      await _auditLog.log(type: 'backup_import', details: {'filesRestored': count});

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✓ Restored $count files successfully'), duration: const Duration(seconds: 3)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Import failed: $e'), duration: const Duration(seconds: 4)),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _importing = false;
        _progress = 0.0;
      });
    }
  }

  Future<String?> _showPasswordDialog({required bool isExport}) async {
    String? firstPassword;
    String? finalPassword;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        String? error;
        bool confirming = false;
        final controller = TextEditingController();

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: SafeShellTheme.bgCard,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text(
                isExport ? (confirming ? 'Confirm Password' : 'Set Backup Password') : 'Enter Backup Password',
                style: const TextStyle(color: SafeShellTheme.textPrimary),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Use a strong password. You\'ll need it to restore this backup.',
                    style: TextStyle(color: SafeShellTheme.textMuted, fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    obscureText: true,
                    style: const TextStyle(color: SafeShellTheme.textPrimary),
                    decoration: InputDecoration(
                      hintText: confirming ? 'Re-enter password' : 'Enter password',
                      hintStyle: const TextStyle(color: SafeShellTheme.textMuted, fontSize: 13),
                      errorText: error,
                      filled: true,
                      fillColor: SafeShellTheme.bgDark.withValues(alpha: 0.5),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onSubmitted: (value) {
                      if (value.isEmpty) {
                        setDialogState(() => error = 'Password required');
                        return;
                      }
                      if (value.length < 6) {
                        setDialogState(() => error = 'Min 6 characters');
                        return;
                      }

                      if (isExport && !confirming) {
                        firstPassword = value;
                        controller.clear();
                        setDialogState(() {
                          confirming = true;
                          error = null;
                        });
                      } else if (isExport && confirming) {
                        if (value == firstPassword) {
                          finalPassword = value;
                          Navigator.pop(ctx);
                        } else {
                          controller.clear();
                          setDialogState(() {
                            error = 'Passwords do not match';
                            confirming = false;
                            firstPassword = null;
                          });
                        }
                      } else {
                        finalPassword = value;
                        Navigator.pop(ctx);
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ],
            );
          },
        );
      },
    );

    return finalPassword;
  }

  Future<void> _showUpgradeForPassword() async {
    final shouldUpgrade = await _featureGate.showUpgradeDialog(context, ProFeature.passwordBackups);
    if (shouldUpgrade == true) {
      if (!mounted) return;
      context.push('/profile');
    }
  }

  // ---------------- UI HELPERS (Figma look) ----------------
  String _lastBackupLabel() {
    final dt = _lastBackupAt;
    if (dt == null) return 'Not yet';
    final now = DateTime.now();
    final isToday = dt.year == now.year && dt.month == now.month && dt.day == now.day;

    String two(int n) => n.toString().padLeft(2, '0');
    final hour12 = ((dt.hour + 11) % 12) + 1;
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    final time = '${hour12}:${two(dt.minute)} $ampm';
    return isToday ? 'Today • $time' : '${dt.year}-${two(dt.month)}-${two(dt.day)} • $time';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const PremiumBackground(child: SizedBox.shrink()),

          // Figma blobs
          Positioned(
            top: 160,
            right: -40,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          Positioned(
            bottom: 80,
            left: -50,
            child: Container(
              width: 288,
              height: 288,
              decoration: BoxDecoration(
                color: const Color(0xFF0A2A4F).withValues(alpha: 0.20),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // AppBar (same style as your app)
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_rounded, color: SafeShellTheme.textPrimary),
                        onPressed: () => context.pop(),
                      ),
                      ShaderMask(
                        shaderCallback: (b) => SafeShellTheme.accentGradient.createShader(b),
                        child: const Text(
                          'Backup',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                      const Spacer(),
                    ],
                  ),
                ),

                Expanded(
                  child: AnimatedBuilder(
                    animation: _c,
                    builder: (_, __) {
                      return Opacity(
                        opacity: _fade.value,
                        child: Transform.translate(
                          offset: Offset(0, _slideUp.value),
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
                            children: [
                              // Auto Backup card (like React)
                              GlassCard(
                                padding: const EdgeInsets.all(20),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(16),
                                        gradient: const LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [Color(0xFF10B981), Color(0xFF059669)],
                                        ),
                                      ),
                                      child: const Icon(Icons.cloud_rounded, color: Colors.white, size: 26),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Auto Backup',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 16,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: -0.2,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Your vault backups run automatically when connected to Wi-Fi.',
                                            style: TextStyle(
                                              color: const Color(0xFFEAF2FF).withValues(alpha: 0.60),
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              height: 1.35,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 12),

                              // Last backup card (like React)
                              GlassCard(
                                padding: const EdgeInsets.all(20),
                                child: Row(
                                  children: [
                                    const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 26),
                                    const SizedBox(width: 12),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Last Backup',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 15,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: -0.2,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _lastBackupLabel(),
                                          style: TextStyle(
                                            color: const Color(0xFFEAF2FF).withValues(alpha: 0.55),
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 14),

                              // Primary CTA (Run Backup Now)
                              GradientButton(
                                text: _exporting ? 'Backing up…' : 'Run Backup Now',
                                onPressed: _exporting ? null : _export, // map this CTA to export
                                isLoading: _exporting,
                                icon: Icons.refresh_rounded,
                                gradient: const LinearGradient(
                                  colors: [SafeShellTheme.accent, SafeShellTheme.accentAlt],
                                ),
                              ),

                              // Progress (only when exporting/importing)
                              if ((_exporting || _importing) && _progress > 0) ...[
                                const SizedBox(height: 12),
                                GlassCard(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            _exporting ? Icons.cloud_upload_rounded : Icons.cloud_download_rounded,
                                            color: SafeShellTheme.textPrimary,
                                            size: 18,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            _exporting ? 'Exporting…' : 'Importing…',
                                            style: const TextStyle(
                                              color: SafeShellTheme.textPrimary,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          const Spacer(),
                                          Text(
                                            '${(_progress * 100).toInt()}%',
                                            style: const TextStyle(
                                              color: SafeShellTheme.textSecondary,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      LinearProgressIndicator(
                                        value: _progress,
                                        backgroundColor: SafeShellTheme.bgDark.withValues(alpha: 0.30),
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          _exporting ? const Color(0xFF10B981) : SafeShellTheme.accentAlt,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],

                              const SizedBox(height: 12),

                              // Optional: Keep your Import UI as a secondary card (so your old features stay)
                              GlassCard(
                                padding: const EdgeInsets.all(18),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.settings_backup_restore_rounded,
                                            color: SafeShellTheme.textPrimary),
                                        const SizedBox(width: 10),
                                        const Expanded(
                                          child: Text(
                                            'Restore from backup (.ssb)',
                                            style: TextStyle(
                                              color: SafeShellTheme.textPrimary,
                                              fontWeight: FontWeight.w800,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                        if (_importing)
                                          const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: SafeShellTheme.accentAlt,
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      'Import an encrypted backup file to restore your vault.',
                                      style: TextStyle(
                                        color: SafeShellTheme.textSecondary.withValues(alpha: 0.85),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        height: 1.35,
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    GradientButton(
                                      text: 'Import Backup',
                                      onPressed: _importing ? null : _import,
                                      isLoading: _importing,
                                      icon: Icons.upload_rounded,
                                      gradient: const LinearGradient(
                                        colors: [SafeShellTheme.accentAlt, SafeShellTheme.accentPink],
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 14),

                              const GlassCard(
                                padding: EdgeInsets.all(16),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(Icons.info_outline_rounded, color: SafeShellTheme.accent, size: 20),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        'Backups are encrypted with your vault key. Without the key, backup files cannot be restored.',
                                        style: TextStyle(
                                          color: SafeShellTheme.textMuted,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          height: 1.35,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 60),
                            ],
                          ),
                        ),
                      );
                    },
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