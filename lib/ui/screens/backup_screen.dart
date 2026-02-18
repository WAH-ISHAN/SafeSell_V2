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

class _BackupScreenState extends State<BackupScreen> {
  late final BackupService _backupService;
  final _auditLog = AuditLogService();
  final _featureGate = FeatureGateService();
  bool _exporting = false;
  bool _importing = false;
  double _progress = 0.0;

  @override
  void initState() {
    super.initState();
    _backupService = BackupService(
      encryptionService: EncryptionService(),
      keyManager: KeyManager(),
    );
  }

  Future<void> _export() async {
    // Ask if user wants password protection
    final passwordChoice = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SafeShellTheme.bgCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            const Text(
              'Password Protection',
              style: TextStyle(color: SafeShellTheme.textPrimary),
            ),
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
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Use Vault Key'),
          ),
          if (_featureGate.isPro)
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Set Password'),
            )
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
      if (password == null) return; // User cancelled
    }

    setState(() {
      _exporting = true;
      _progress = 0.0;
    });

    try {
      final path = await _backupService.exportBackup(
        password: password,
        onProgress: (p) {
          if (mounted) {
            setState(() => _progress = p);
          }
        },
      );
      await _auditLog.log(
        type: 'backup_export',
        details: {
          'path': path,
          'passwordProtected': password != null,
        },
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Backup saved to:\n$path'),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _exporting = false;
          _progress = 0.0;
        });
      }
    }
  }

  Future<void> _import() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['ssb'],
      allowMultiple: false,
    );
    if (result == null ||
        result.files.isEmpty ||
        result.files.first.path == null) {
      return;
    }

    // Ask if backup is password-protected
    if (!mounted) return;
    final isProtected = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SafeShellTheme.bgCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text(
          'Backup Type',
          style: TextStyle(color: SafeShellTheme.textPrimary),
        ),
        content: const Text(
          'Is this backup password-protected?',
          style: TextStyle(color: SafeShellTheme.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No (Vault Key)'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes (Password)'),
          ),
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
          if (mounted) {
            setState(() => _progress = p);
          }
        },
      );
      await _auditLog.log(
        type: 'backup_import',
        details: {'filesRestored': count},
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ Restored $count files successfully'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Import failed: $e'),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _importing = false;
          _progress = 0.0;
        });
      }
    }
  }

  /// Show password input dialog for export or import
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Text(
                isExport
                    ? (confirming ? 'Confirm Password' : 'Set Backup Password')
                    : 'Enter Backup Password',
                style: const TextStyle(color: SafeShellTheme.textPrimary),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Use a strong password. You\'ll need it to restore this backup.',
                    style: TextStyle(
                      color: SafeShellTheme.textMuted,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    obscureText: true,
                    style: const TextStyle(color: SafeShellTheme.textPrimary),
                    decoration: InputDecoration(
                      hintText: confirming ? 'Re-enter password' : 'Enter password',
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
                      if (value.isEmpty) {
                        setDialogState(() => error = 'Password required');
                        return;
                      }
                      if (value.length < 6) {
                        setDialogState(() => error = 'Min 6 characters');
                        return;
                      }

                      if (isExport && !confirming) {
                        // First entry for export - need confirmation
                        firstPassword = value;
                        controller.clear();
                        setDialogState(() {
                          confirming = true;
                          error = null;
                        });
                      } else if (isExport && confirming) {
                        // Confirmation entry
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
                        // Import - single entry
                        finalPassword = value;
                        Navigator.pop(ctx);
                      }
                    },
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

    return finalPassword;
  }
  
  Future<void> _showUpgradeForPassword() async {
    final shouldUpgrade = await _featureGate.showUpgradeDialog(
      context,
      ProFeature.passwordBackups,
    );
    if (shouldUpgrade == true) {
      if (!mounted) return;
      context.push('/profile');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PremiumBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.arrow_back,
                          color: SafeShellTheme.textPrimary,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                      ShaderMask(
                        shaderCallback: (b) =>
                            SafeShellTheme.accentGradient.createShader(b),
                        child: const Text(
                          'Backup & Restore',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Export card
                GlassCard(
                  child: Column(
                    children: [
                      const Icon(
                        Icons.cloud_upload,
                        size: 40,
                        color: SafeShellTheme.accent,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Export Encrypted Backup',
                        style: TextStyle(
                          color: SafeShellTheme.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Creates an encrypted .ssb file containing all your vault files, metadata, and audit log.',
                        style: TextStyle(
                          color: SafeShellTheme.textMuted,
                          fontSize: 13,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      GradientButton(
                        text: 'Export Backup',
                        onPressed: _exporting ? null : _export,
                        isLoading: _exporting,
                        icon: Icons.download,
                      ),
                      if (_exporting && _progress > 0) ...[
                        const SizedBox(height: 12),
                        LinearProgressIndicator(
                          value: _progress,
                          backgroundColor: SafeShellTheme.bgDark.withValues(alpha: 0.3),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            SafeShellTheme.accent,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${(_progress * 100).toInt()}%',
                          style: const TextStyle(
                            color: SafeShellTheme.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Import card
                GlassCard(
                  child: Column(
                    children: [
                      const Icon(
                        Icons.cloud_download,
                        size: 40,
                        color: SafeShellTheme.accentAlt,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Import Backup',
                        style: TextStyle(
                          color: SafeShellTheme.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Restore your vault from an encrypted .ssb backup file.',
                        style: TextStyle(
                          color: SafeShellTheme.textMuted,
                          fontSize: 13,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      GradientButton(
                        text: 'Import Backup',
                        onPressed: _importing ? null : _import,
                        isLoading: _importing,
                        gradient: const LinearGradient(
                          colors: [
                            SafeShellTheme.accentAlt,
                            SafeShellTheme.accentPink,
                          ],
                        ),
                        icon: Icons.upload,
                      ),
                      if (_importing && _progress > 0) ...[
                        const SizedBox(height: 12),
                        LinearProgressIndicator(
                          value: _progress,
                          backgroundColor: SafeShellTheme.bgDark.withValues(alpha: 0.3),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            SafeShellTheme.accentAlt,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${(_progress * 100).toInt()}%',
                          style: const TextStyle(
                            color: SafeShellTheme.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Info
                const GlassCard(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: SafeShellTheme.accent,
                        size: 20,
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Backups are encrypted with your vault key. Without the key, backup files cannot be restored.',
                          style: TextStyle(
                            color: SafeShellTheme.textMuted,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
