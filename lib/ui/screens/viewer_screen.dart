import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../../security/app_lock_service.dart';
import '../../security/biometric_service.dart';
import '../../services/audit_log_service.dart';
import '../../app/theme.dart';
import '../../ui/widgets/premium_ui.dart';

/// Launched when SafeShell is chosen as the viewer for an image/video via
/// Android ACTION_VIEW intent (Protected Viewer mode).
///
/// Flow:
///   1. Query MainActivity's intent channel for the pending view URI/MIME.
///   2. Gate access with biometric or PIN.
///   3. Copy the content to a private temp file (no decryption needed —
///      the file is not in the vault; this is just the OS-level viewer path).
///   4. Display the file in-app.
///   5. Delete the temp copy on close.
///
/// NOTE: This screen is the entry-point for files that are NOT yet in the
/// vault. It shows the file securely (behind auth) but does NOT automatically
/// import it. Users can tap "Import to Vault" to trigger Mode 1.
class ViewerScreen extends StatefulWidget {
  const ViewerScreen({super.key});

  @override
  State<ViewerScreen> createState() => _ViewerScreenState();
}

class _ViewerScreenState extends State<ViewerScreen> {
  static const _intentChannel = MethodChannel('com.safeshell/intent');

  final _appLock = AppLockService();
  final _biometric = BiometricService();
  final _audit = AuditLogService();

  _ViewerState _state = _ViewerState.authenticating;
  String? _errorMessage;
  String? _tempFilePath;
  String? _mimeType;
  bool _isImage = false;
  bool _isVideo = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _cleanupTemp();
    super.dispose();
  }

  Future<void> _start() async {
    // 1. Retrieve pending intent from native side
    final intent = await _intentChannel.invokeMapMethod<String, String?>(
      'getViewIntent',
    );

    if (intent == null || intent['uri'] == null) {
      _setError('No file to display.');
      return;
    }

    final uri = intent['uri']!;
    _mimeType = intent['mime'];
    _isImage = _mimeType?.startsWith('image/') ?? false;
    _isVideo = _mimeType?.startsWith('video/') ?? false;

    // 2. Authenticate
    final authed = await _authenticate();
    if (!authed) {
      if (mounted) context.go('/splash');
      return;
    }

    // 3. Copy to private temp for display
    await _copyToTemp(uri);
  }

  Future<bool> _authenticate() async {
    // Try biometric first
    final hasBio = await _biometric.isAvailable();
    if (hasBio) {
      final ok = await _biometric.authenticate(
        reason: 'Authenticate to view this file securely',
      );
      if (ok) return true;
    }

    // Fall back to PIN
    if (!mounted) return false;
    final hasPinSet = await _appLock.hasPinSet();
    if (!hasPinSet) {
      // No auth set — allow with warning
      await _audit.log(
        type: 'viewer_open',
        details: {'authMethod': 'none', 'warning': 'no_pin_set'},
      );
      return true;
    }

    if (!mounted) return false;
    final pinOk = await _showPinDialog();
    return pinOk;
  }

  Future<bool> _showPinDialog() async {
    if (!mounted) return false;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _ViewerPinDialog(appLock: _appLock),
    );
    return confirmed ?? false;
  }

  Future<void> _copyToTemp(String uri) async {
    try {
      setState(() => _state = _ViewerState.loading);

      final cacheDir = await getTemporaryDirectory();
      final ext = _mimeType != null ? _mimeType!.split('/').last : 'bin';
      final tempPath = p.join(
        cacheDir.path,
        'viewer_${DateTime.now().millisecondsSinceEpoch}.$ext',
      );

      // Read via ContentResolver if it's a content:// URI
      if (uri.startsWith('content://')) {
        final bytes = await _intentChannel.invokeMethod<Uint8List>(
          'readContentUri',
          {'uri': uri},
        );
        if (bytes == null || bytes.isEmpty) {
          throw Exception('Could not read file content');
        }
        await File(tempPath).writeAsBytes(bytes);
      } else {
        // file:// URI
        final src = File(uri.replaceFirst('file://', ''));
        await src.copy(tempPath);
      }

      _tempFilePath = tempPath;
      await _audit.log(
        type: 'viewer_open',
        details: {'mime': _mimeType, 'uri': uri},
      );

      if (mounted) setState(() => _state = _ViewerState.viewing);
    } catch (e) {
      _setError('Could not open file: $e');
    }
  }

  void _cleanupTemp() {
    if (_tempFilePath != null) {
      try {
        File(_tempFilePath!).deleteSync();
      } catch (_) {}
      _tempFilePath = null;
    }
  }

  void _setError(String msg) {
    if (mounted) {
      setState(() {
        _state = _ViewerState.error;
        _errorMessage = msg;
      });
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SafeShellTheme.bgDark,
      appBar: AppBar(
        backgroundColor: SafeShellTheme.bgCard,
        leading: IconButton(
          icon: const Icon(Icons.close, color: SafeShellTheme.textPrimary),
          onPressed: () {
            _cleanupTemp();
            context.go('/splash');
          },
        ),
        title: const Text(
          'Protected Viewer',
          style: TextStyle(color: SafeShellTheme.textPrimary, fontSize: 16),
        ),
        actions: [
          if (_state == _ViewerState.viewing)
            TextButton.icon(
              icon: const Icon(Icons.lock, color: SafeShellTheme.accent, size: 18),
              label: const Text(
                'Import to Vault',
                style: TextStyle(color: SafeShellTheme.accent, fontSize: 13),
              ),
              onPressed: _importToVault,
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    switch (_state) {
      case _ViewerState.authenticating:
        return _centeredMessage(
          icon: Icons.lock_outline,
          iconColor: SafeShellTheme.accent,
          message: 'Authenticating…',
          showSpinner: true,
        );
      case _ViewerState.loading:
        return _centeredMessage(
          icon: Icons.hourglass_top,
          iconColor: SafeShellTheme.accent,
          message: 'Opening file…',
          showSpinner: true,
        );
      case _ViewerState.error:
        return _centeredMessage(
          icon: Icons.error_outline,
          iconColor: SafeShellTheme.error,
          message: _errorMessage ?? 'Unknown error',
        );
      case _ViewerState.viewing:
        return _buildViewer();
    }
  }

  Widget _buildViewer() {
    final path = _tempFilePath;
    if (path == null) {
      return _centeredMessage(
        icon: Icons.broken_image_outlined,
        iconColor: SafeShellTheme.error,
        message: 'File unavailable',
      );
    }

    if (_isImage) {
      return InteractiveViewer(
        child: Center(
          child: Image.file(
            File(path),
            fit: BoxFit.contain,
            errorBuilder: (_, e, __) => _centeredMessage(
              icon: Icons.broken_image_outlined,
              iconColor: SafeShellTheme.error,
              message: 'Cannot display image: $e',
            ),
          ),
        ),
      );
    }

    // Video / unsupported: show file info + open-with button
    return Center(
      child: GlassCard(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _isVideo ? Icons.videocam_outlined : Icons.insert_drive_file,
              color: SafeShellTheme.accent,
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              p.basename(path),
              style: const TextStyle(
                color: SafeShellTheme.textPrimary,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _mimeType ?? 'Unknown type',
              style: const TextStyle(
                color: SafeShellTheme.textMuted,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'In-app video playback is not supported.\n'
              'Import the file to the vault to manage it securely,\n'
              'or close this screen.',
              style: TextStyle(
                color: SafeShellTheme.textMuted,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _centeredMessage({
    required IconData icon,
    required Color iconColor,
    required String message,
    bool showSpinner = false,
  }) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: iconColor, size: 56),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(
              color: SafeShellTheme.textSecondary,
              fontSize: 15,
            ),
            textAlign: TextAlign.center,
          ),
          if (showSpinner) ...[
            const SizedBox(height: 20),
            const CircularProgressIndicator(
              color: SafeShellTheme.accent,
              strokeWidth: 2,
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _importToVault() async {
    if (_tempFilePath == null) return;
    // Navigate to vault screen with the file path pre-filled
    // The actual import (encrypt + delete original) is handled in VaultScreen/_addFile
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Open the Vault tab and use Add (+) to import this file.',
          ),
        ),
      );
    }
  }
}

// ─── Viewer states ──────────────────────────────────────────────────────────

enum _ViewerState { authenticating, loading, viewing, error }

// ─── PIN dialog for viewer ──────────────────────────────────────────────────

class _ViewerPinDialog extends StatefulWidget {
  final AppLockService appLock;
  const _ViewerPinDialog({required this.appLock});

  @override
  State<_ViewerPinDialog> createState() => _ViewerPinDialogState();
}

class _ViewerPinDialogState extends State<_ViewerPinDialog> {
  String? _error;
  bool _verifying = false;

  Future<void> _verify(String pin) async {
    setState(() {
      _verifying = true;
      _error = null;
    });
    final valid = await widget.appLock.verifyPin(pin);
    if (!mounted) return;
    if (valid) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _error = 'Incorrect PIN';
        _verifying = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: SafeShellTheme.bgCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.shield_outlined,
                color: SafeShellTheme.accent, size: 48),
            const SizedBox(height: 12),
            const Text(
              'Protected Viewer',
              style: TextStyle(
                color: SafeShellTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Enter your SafeShell PIN to view this file.',
              style: TextStyle(color: SafeShellTheme.textMuted, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (_verifying)
              const SizedBox(
                height: 48,
                child: Center(
                  child: CircularProgressIndicator(
                    color: SafeShellTheme.accent,
                    strokeWidth: 2,
                  ),
                ),
              )
            else
              PinInput(
                error: _error,
                onCompleted: _verify,
              ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text(
                'Cancel',
                style: TextStyle(color: SafeShellTheme.textMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
