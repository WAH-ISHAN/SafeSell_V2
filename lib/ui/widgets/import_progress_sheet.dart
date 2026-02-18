import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../../services/vault_service.dart';
import 'primary_button.dart';

class ImportProgressSheet extends StatefulWidget {
  final List<PlatformFile> files;
  final bool deleteOriginals;
  final VaultService cryptoStore; // Using VaultService for cleaner API

  const ImportProgressSheet({
    super.key,
    required this.files,
    required this.deleteOriginals,
    required this.cryptoStore,
  });

  @override
  State<ImportProgressSheet> createState() => _ImportProgressSheetState();
}

class _ImportProgressSheetState extends State<ImportProgressSheet> {
  int _currentIndex = 0;
  String _statusMessage = "Preparing...";
  bool _completed = false;
  final List<String> _errors = [];

  @override
  void initState() {
    super.initState();
    _startImport();
  }

  Future<void> _startImport() async {
    for (int i = 0; i < widget.files.length; i++) {
      if (!mounted) return;

      final file = widget.files[i];
      setState(() {
        _currentIndex = i;
        _statusMessage = "Encrypting ${file.name}...";
      });

      try {
        // Import via VaultService (handles encryption, storage, and audit logging)
        await widget.cryptoStore.addFile(
          file,
          deleteOriginal: widget.deleteOriginals,
        );
        
        if (widget.deleteOriginals) {
          setState(() => _statusMessage = "Securing (Deleting original)...");
          // VaultService already handles deletion, just update UI
        }
      } catch (e) {
        _errors.add("Failed to import ${file.name}: $e");
      }
    }

    if (!mounted) return;
    setState(() {
      _completed = true;
      _statusMessage =
          _errors.isEmpty
              ? "All files secured successfully"
              : "Import finished with ${_errors.length} errors";
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Color(0xFF141A24),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Securing Files",
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 24),

          if (!_completed) ...[
            LinearProgressIndicator(
              value:
                  (_currentIndex + (_completed ? 0 : 0.5)) /
                  widget.files.length,
              backgroundColor: Colors.white.withValues(alpha: 0.1),
              color: const Color(0xFF4DA3FF),
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 16),
            Text(
              _statusMessage,
              style: TextStyle(
                color: const Color(0xFFEAF2FF).withValues(alpha: 0.7),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Processing ${_currentIndex + 1} of ${widget.files.length}",
              style: TextStyle(
                color: const Color(0xFFEAF2FF).withValues(alpha: 0.4),
                fontSize: 12,
              ),
            ),
          ] else ...[
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color:
                      _errors.isEmpty
                          ? const Color(0xFF10B981).withValues(alpha: 0.15)
                          : const Color(0xFFF59E0B).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _errors.isEmpty ? Icons.check_rounded : Icons.warning_rounded,
                  color:
                      _errors.isEmpty
                          ? const Color(0xFF10B981)
                          : const Color(0xFFF59E0B),
                  size: 32,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                _statusMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (_errors.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children:
                      _errors
                          .map(
                            (e) => Text(
                              "• $e",
                              style: const TextStyle(
                                color: Color(0xFFF87171),
                                fontSize: 13,
                              ),
                            ),
                          )
                          .toList(),
                ),
              ),
            const SizedBox(height: 24),
            PrimaryButton(
              text: "Done",
              onPressed: () => Navigator.pop(context, true),
              icon: Icons.check_circle_rounded,
            ),
          ],
        ],
      ),
    );
  }
}
