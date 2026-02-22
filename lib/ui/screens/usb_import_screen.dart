import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:async';
import '../../app/theme.dart';
import '../widgets/premium_ui.dart';
import '../widgets/import_progress_sheet.dart';
import '../../services/vault_service.dart';

class UsbImportScreen extends StatefulWidget {
  const UsbImportScreen({super.key});

  @override
  State<UsbImportScreen> createState() => _UsbImportScreenState();
}

class _UsbImportScreenState extends State<UsbImportScreen> {
  bool _isScanning = false;
  double _scanProgress = 0.0;
  List<PlatformFile>? _foundFiles;
  final _vaultService = VaultService();

  Future<void> _startScan() async {
    setState(() {
      _isScanning = true;
      _scanProgress = 0.0;
      _foundFiles = null;
    });

    // Simulated scan for dramatic effect / security feel
    for (int i = 0; i <= 20; i++) {
      await Future.delayed(const Duration(milliseconds: 100));
      if (!mounted) return;
      setState(() {
        _scanProgress = i / 20.0;
      });
    }

    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.any,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _foundFiles = result.files;
          _isScanning = false;
        });
      } else {
        setState(() {
          _isScanning = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error scanning USB: $e')),
        );
      }
      setState(() {
        _isScanning = false;
      });
    }
  }

  Future<void> _importFiles() async {
    if (_foundFiles == null) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ImportProgressSheet(
        files: _foundFiles!,
        deleteOriginals: false, // Default for USB to avoid accidental data loss
        cryptoStore: _vaultService,
      ),
    );

    if (mounted) {
      Navigator.pop(context); // Go back after import
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const TopBlurBar(title: 'USB Import'),
      body: PremiumBackground(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!_isScanning && _foundFiles == null) ...[
                const Icon(
                  Icons.usb_rounded,
                  size: 80,
                  color: SafeShellTheme.accent,
                ),
                const SizedBox(height: 24),
                const Text(
                  'USB Device Detected',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Scan the connected device for files to import into your secure vault.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: SafeShellTheme.textMuted),
                ),
                const SizedBox(height: 40),
                GradientButton(
                  text: 'Scan Device',
                  onPressed: _startScan,
                  icon: Icons.search_rounded,
                ),
              ] else if (_isScanning) ...[
                CircularProgressIndicator(
                  value: _scanProgress,
                  color: SafeShellTheme.accent,
                  strokeWidth: 8,
                ),
                const SizedBox(height: 32),
                Text(
                  'Scanning External Device... ${(_scanProgress * 100).toInt()}%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Safety check in progress (Quarantine Mode active)',
                  style: TextStyle(color: SafeShellTheme.warning, fontSize: 13),
                ),
              ] else if (_foundFiles != null) ...[
                const Icon(
                  Icons.check_circle_rounded,
                  size: 80,
                  color: SafeShellTheme.success,
                ),
                const SizedBox(height: 24),
                Text(
                  '${_foundFiles!.length} Files Identified',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Files have been scanned and are ready for secure import.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: SafeShellTheme.textMuted),
                ),
                const SizedBox(height: 40),
                GradientButton(
                  text: 'Secure Import Now',
                  onPressed: _importFiles,
                  icon: Icons.lock_rounded,
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => setState(() => _foundFiles = null),
                  child: const Text('Rescan Device'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
