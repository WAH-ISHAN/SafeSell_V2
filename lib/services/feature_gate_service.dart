import 'package:flutter/material.dart';
import '../app/theme.dart';
import 'billing_service.dart';

/// Manages feature gating for free vs pro tiers
class FeatureGateService {
  final BillingService _billing = BillingService();
  
  // Feature limits
  static const int freeVaultFilesLimit = 10;
  static const bool freePasswordBackups = false;
  static const bool freeLogExport = false;
  
  /// Check if user has Pro subscription
  bool get isPro => _billing.isPro;
  
  /// Check if feature is available for current tier
  bool isFeatureAvailable(ProFeature feature) {
    if (isPro) return true;
    
    switch (feature) {
      case ProFeature.unlimitedFiles:
      case ProFeature.passwordBackups:
      case ProFeature.logExport:
        return false;
    }
  }
  
  /// Check if user can add more files to vault
  bool canAddFiles(int currentCount) {
    if (isPro) return true;
    return currentCount < freeVaultFilesLimit;
  }
  
  /// Show upgrade dialog explaining the feature
  Future<bool?> showUpgradeDialog(
    BuildContext context,
    ProFeature feature,
  ) async {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => _UpgradeDialog(feature: feature),
    );
  }
  
  /// Show upgrade prompt with custom message
  Future<bool?> showCustomUpgradePrompt(
    BuildContext context, {
    required String title,
    required String message,
    String? benefits,
  }) async {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SafeShellTheme.bgCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            const Icon(
              Icons.workspace_premium,
              color: SafeShellTheme.accentAlt,
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: SafeShellTheme.textPrimary,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message,
              style: const TextStyle(
                color: SafeShellTheme.textSecondary,
                fontSize: 14,
              ),
            ),
            if (benefits != null) ...[
              const SizedBox(height: 16),
              Text(
                benefits,
                style: const TextStyle(
                  color: SafeShellTheme.textMuted,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Maybe Later'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: SafeShellTheme.accentAlt,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Upgrade Now'),
          ),
        ],
      ),
    );
  }
}

/// Pro features enum
enum ProFeature {
  unlimitedFiles,
  passwordBackups,
  logExport,
}

class _UpgradeDialog extends StatelessWidget {
  final ProFeature feature;
  
  const _UpgradeDialog({required this.feature});
  
  String get _title {
    switch (feature) {
      case ProFeature.unlimitedFiles:
        return 'Unlimited Vault Files';
      case ProFeature.passwordBackups:
        return 'Password-Protected Backups';
      case ProFeature.logExport:
        return 'Security Log Export';
    }
  }
  
  String get _message {
    switch (feature) {
      case ProFeature.unlimitedFiles:
        return 'Free tier is limited to ${FeatureGateService.freeVaultFilesLimit} files. Upgrade to Pro for unlimited secure file storage.';
      case ProFeature.passwordBackups:
        return 'Password-protected backups allow you to restore your vault on any device without your vault key. This is a Pro feature.';
      case ProFeature.logExport:
        return 'Export your complete security audit log for external analysis and archival. This is a Pro feature.';
    }
  }
  
  String get _benefits {
    return '✓ Unlimited vault files\n'
           '✓ Password-protected backups\n'
           '✓ Security log export\n'
           '✓ Priority support\n'
           '✓ Early access to new features';
  }
  
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: SafeShellTheme.bgCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: SafeShellTheme.accentAlt.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.workspace_premium,
              color: SafeShellTheme.accentAlt,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Upgrade to Pro',
              style: TextStyle(
                color: SafeShellTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _title,
            style: const TextStyle(
              color: SafeShellTheme.accent,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _message,
            style: const TextStyle(
              color: SafeShellTheme.textSecondary,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Pro Features:',
            style: TextStyle(
              color: SafeShellTheme.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _benefits,
            style: const TextStyle(
              color: SafeShellTheme.textMuted,
              fontSize: 12,
              height: 1.5,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Maybe Later'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: SafeShellTheme.accentAlt,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
          child: const Text('Upgrade Now'),
        ),
      ],
    );
  }
}
