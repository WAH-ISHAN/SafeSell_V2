import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:hive/hive.dart';
import 'package:open_file/open_file.dart';
import 'package:go_router/go_router.dart';
import '../../models/vault_file.dart';
import '../../models/app_settings.dart';
import '../../services/vault_service.dart';
import '../../services/unlock_gate_service.dart';
import '../../services/feature_gate_service.dart';
import '../../services/security_gate.dart';
import '../../services/permission_service.dart';
import '../../security/key_manager.dart';
import '../../ui/widgets/premium_ui.dart';
import '../../app/theme.dart';

class VaultScreen extends StatefulWidget {
  /// Optional initial category filter (e.g. from Dashboard "View All").
  final String? initialCategory;

  const VaultScreen({super.key, this.initialCategory});

  @override
  State<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends State<VaultScreen> {
  late final VaultService _vaultService;
  late final UnlockGateService _unlockGate;
  late final FeatureGateService _featureGate;
  AppSettings? _settings;
  List<VaultFile> _files = [];
  List<VaultFile> _filtered = [];
  String _selectedCategory = 'all';
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();
  bool _loading = true;
  bool _selectMode = false;
  final Set<String> _selected = {};

  static const _categories = [
    'all',
    'photos',
    'videos',
    'docs',
    'zip',
    'apk',
    'other',
  ];

  @override
  void initState() {
    super.initState();
    _vaultService = VaultService();
    _unlockGate = UnlockGateService();
    _featureGate = FeatureGateService();
    if (widget.initialCategory != null &&
        _categories.contains(widget.initialCategory)) {
      _selectedCategory = widget.initialCategory!;
    }
    _loadSettings();
    _loadFiles();
  }

  Future<void> _loadSettings() async {
    final box = await Hive.openBox<AppSettings>('app_settings_typed');
    final s = box.get('settings') ?? AppSettings();
    if (mounted) setState(() => _settings = s);
  }

  Future<void> _loadFiles() async {
    setState(() => _loading = true);
    final files = await _vaultService.getAllFiles();
    if (mounted) {
      setState(() {
        _files = files;
        _applyFilter();
        _loading = false;
      });
    }
  }

  void _applyFilter() {
    var list = _files.toList();
    if (_selectedCategory != 'all') {
      list = list.where((f) => f.category == _selectedCategory).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((f) => f.name.toLowerCase().contains(q)).toList();
    }
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _filtered = list;
  }

  Future<void> _addFile() async {
    // Check file limit for free tier
    if (!_featureGate.canAddFiles(_files.length)) {
      final shouldUpgrade = await _featureGate.showUpgradeDialog(
        context,
        ProFeature.unlimitedFiles,
      );
      if (shouldUpgrade == true && mounted) {
        context.push('/profile');
      }
      return;
    }

    // Ensure the vault is unlocked before we even pick a file
    if (!KeyManager().isUnlocked) {
      if (!mounted) return;
      final unlocked = await _unlockGate.requestUnlock(
        context,
        title: 'Unlock Vault',
        subtitle: 'Authentication required to import files into the vault',
      );
      if (!unlocked || !mounted) return;
    }

    final result = await FilePicker.platform.pickFiles(allowMultiple: false);
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;

    // Validate that we can actually read this file
    if (file.bytes == null && file.path == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not read file. Please try again.'),
        ),
      );
      return;
    }

    if (!mounted) return;

    // Determine import mode: use settings default, then ask user
    final settingsMode = _settings?.importMode ?? 'move';
    final defaultImportMode =
        settingsMode == 'copy' ? ImportMode.copyToVault : ImportMode.moveToVault;

    // Ask: Copy to vault or Move to vault (delete original)
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SafeShellTheme.bgCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text(
          'Import to Vault',
          style: TextStyle(color: SafeShellTheme.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'File: ${file.name}',
              style: const TextStyle(
                color: SafeShellTheme.textMuted,
                fontSize: 13,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.copy, color: SafeShellTheme.accent),
              title: const Text('Copy to vault',
                  style: TextStyle(color: SafeShellTheme.textPrimary)),
              subtitle: const Text('Encrypt & store, keep original',
                  style:
                      TextStyle(color: SafeShellTheme.textMuted, fontSize: 12)),
              trailing: defaultImportMode == ImportMode.copyToVault
                  ? const Icon(Icons.check, color: SafeShellTheme.accent, size: 16)
                  : null,
              onTap: () => Navigator.pop(ctx, 'copy'),
            ),
            const Divider(color: SafeShellTheme.glassBorder),
            ListTile(
              leading: const Icon(Icons.drive_file_move,
                  color: SafeShellTheme.accentAlt),
              title: const Text('Move to vault',
                  style: TextStyle(color: SafeShellTheme.textPrimary)),
              subtitle: const Text('Encrypt & store, delete original',
                  style:
                      TextStyle(color: SafeShellTheme.textMuted, fontSize: 12)),
              trailing: defaultImportMode == ImportMode.moveToVault
                  ? const Icon(Icons.check, color: SafeShellTheme.accentAlt, size: 16)
                  : null,
              onTap: () => Navigator.pop(ctx, 'move'),
            ),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;

    final importMode =
        choice == 'copy' ? ImportMode.copyToVault : ImportMode.moveToVault;

    setState(() => _loading = true);
    try {
      final addResult = await _vaultService.addFile(
        file,
        importMode: importMode,
      );
      await _loadFiles();
      if (mounted) {
        if (addResult.deletionError != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'File saved to vault, but original could not be deleted:\n'
                '${addResult.deletionError}',
              ),
              duration: const Duration(seconds: 5),
              backgroundColor: SafeShellTheme.error,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                importMode == ImportMode.moveToVault
                    ? 'File moved to vault (original deleted)'
                    : 'File copied to vault',
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().toLowerCase();
      if (msg.contains('lock') || msg.contains('key')) {
        // Vault became locked unexpectedly — offer to unlock and retry
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vault locked. Please unlock to continue.')),
        );
        final unlocked = await _unlockGate.requestUnlock(
          context,
          title: 'Vault Locked',
          subtitle: 'Re-authenticate to import the file',
        );
        if (unlocked && mounted) {
          setState(() => _loading = true);
          try {
            await _vaultService.addFile(file, importMode: importMode);
            await _loadFiles();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('File added to vault')),
              );
            }
          } catch (e2) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error: $e2')),
              );
              setState(() => _loading = false);
            }
          }
        } else {
          setState(() => _loading = false);
        }
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _openFile(VaultFile file) async {
    // Gate: require unlock before opening/decrypting
    final unlocked = await _unlockGate.requestUnlock(
      context,
      title: 'Unlock to Open File',
      subtitle: 'Authentication required to decrypt and open ${file.name}',
    );
    if (!unlocked) return;

    try {
      final path = await _vaultService.openFile(file);
      await OpenFile.open(path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error opening file: $e')));
      }
    }
  }

  Future<void> _deleteFile(VaultFile file) async {
    // Gate: require unlock before deleting
    final unlocked = await _unlockGate.requestUnlock(
      context,
      title: 'Unlock to Delete File',
      subtitle: 'Authentication required to delete ${file.name}',
    );
    if (!mounted || !unlocked) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SafeShellTheme.bgCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text(
          'Delete File',
          style: TextStyle(color: SafeShellTheme.textPrimary),
        ),
        content: Text(
          'Permanently delete "${file.name}" from the vault?',
          style: const TextStyle(color: SafeShellTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: SafeShellTheme.error),
            ),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await _vaultService.deleteFile(file.id);
    await _loadFiles();
  }

  Future<void> _exportFile(VaultFile file) async {
    // SecurityGate: explicit auth required before any export
    if (!mounted) return;
    final authed = await SecurityGate().authorize(
      context,
      action: 'Export “${file.name}”',
      isDestructive: false,
    );
    if (!authed || !mounted) return;

    try {
      final exportPath = await _vaultService.exportFile(file);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Exported to: $exportPath'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }

  Future<void> _shareFile(VaultFile file) async {
    // SecurityGate: explicit auth required before any share
    if (!mounted) return;
    final authed = await SecurityGate().authorize(
      context,
      action: 'Share “${file.name}”',
      isDestructive: false,
    );
    if (!authed || !mounted) return;

    try {
      await _vaultService.shareFile(file);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Share failed: $e')),
        );
      }
    }
  }

  Future<void> _bulkDelete() async {
    if (_selected.isEmpty) return;
    // SecurityGate: destructive action requiring explicit auth
    if (!mounted) return;
    final authed = await SecurityGate().authorize(
      context,
      action: 'Delete ${_selected.length} file${_selected.length == 1 ? '' : 's'}',
      isDestructive: true,
    );
    if (!authed || !mounted) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SafeShellTheme.bgCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text(
          'Delete Selected',
          style: TextStyle(color: SafeShellTheme.textPrimary),
        ),
        content: Text(
          'Permanently delete ${_selected.length} files?',
          style: const TextStyle(color: SafeShellTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Delete All',
              style: TextStyle(color: SafeShellTheme.error),
            ),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await _vaultService.bulkDelete(_selected.toList());
    _selected.clear();
    _selectMode = false;
    await _loadFiles();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    // Clean up temp decrypted files when leaving vault
    _vaultService.cleanTempFiles();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PremiumBackground(
        child: SafeArea(
          child: Column(
            children: [
              // App bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(
                  children: [
                    ShaderMask(
                      shaderCallback: (b) =>
                          SafeShellTheme.accentGradient.createShader(b),
                      child: const Text(
                        'Vault',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (_selectMode) ...[
                      Text(
                        '${_selected.length} selected',
                        style: const TextStyle(
                          color: SafeShellTheme.textMuted,
                          fontSize: 13,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete,
                          color: SafeShellTheme.error,
                        ),
                        onPressed: _bulkDelete,
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.close,
                          color: SafeShellTheme.textMuted,
                        ),
                        onPressed: () => setState(() {
                          _selectMode = false;
                          _selected.clear();
                        }),
                      ),
                    ] else ...[
                      IconButton(
                        icon: const Icon(
                          Icons.checklist,
                          color: SafeShellTheme.textMuted,
                        ),
                        onPressed: () => setState(() => _selectMode = true),
                      ),
                    ],
                  ],
                ),
              ),

              // Search bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: TextField(
                  controller: _searchCtrl,
                  style: const TextStyle(color: SafeShellTheme.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Search files...',
                    prefixIcon: const Icon(
                      Icons.search,
                      color: SafeShellTheme.textMuted,
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(
                              Icons.clear,
                              color: SafeShellTheme.textMuted,
                            ),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() {
                                _searchQuery = '';
                                _applyFilter();
                              });
                            },
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onChanged: (v) => setState(() {
                    _searchQuery = v;
                    _applyFilter();
                  }),
                ),
              ),

              // Category chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(
                  children: _categories.map((c) {
                    final sel = _selectedCategory == c;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(
                          c == 'all'
                              ? 'All'
                              : c[0].toUpperCase() + c.substring(1),
                        ),
                        selected: sel,
                        onSelected: (_) => setState(() {
                          _selectedCategory = c;
                          _applyFilter();
                        }),
                        selectedColor: SafeShellTheme.accent.o(0.2),
                        backgroundColor: SafeShellTheme.glass,
                        side: BorderSide(
                          color: sel
                              ? SafeShellTheme.accent
                              : SafeShellTheme.glassBorder,
                        ),
                        labelStyle: TextStyle(
                          color: sel
                              ? SafeShellTheme.accent
                              : SafeShellTheme.textMuted,
                          fontSize: 13,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

              // File list
              Expanded(
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: SafeShellTheme.accent,
                        ),
                      )
                    : _filtered.isEmpty
                        ? EmptyState(
                            icon: Icons.folder_open,
                            title: 'No files yet',
                            subtitle:
                                'Add files to your vault to keep them secure',
                            action: GradientButton(
                              text: 'Add File',
                              width: 160,
                              onPressed: _addFile,
                              icon: Icons.add,
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.only(top: 4, bottom: 100),
                            itemCount: _filtered.length,
                            itemBuilder: (_, i) => _fileCard(_filtered[i]),
                          ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addFile,
        backgroundColor: SafeShellTheme.accent,
        child: const Icon(Icons.add, color: SafeShellTheme.bgDark),
      ),
    );
  }

  Widget _fileCard(VaultFile file) {
    final isSelected = _selected.contains(file.id);
    return GlassCard(
      borderColor: isSelected ? SafeShellTheme.accent.o(0.5) : null,
      onTap: () {
        if (_selectMode) {
          setState(() {
            if (isSelected) {
              _selected.remove(file.id);
            } else {
              _selected.add(file.id);
            }
          });
        } else {
          _openFile(file);
        }
      },
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          if (_selectMode)
            Checkbox(
              value: isSelected,
              onChanged: (v) => setState(() {
                if (v == true) {
                  _selected.add(file.id);
                } else {
                  _selected.remove(file.id);
                }
              }),
              activeColor: SafeShellTheme.accent,
              side: const BorderSide(color: SafeShellTheme.textMuted),
            ),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _categoryColor(file.category).o(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _categoryIcon(file.category),
              color: _categoryColor(file.category),
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file.name,
                  style: const TextStyle(
                    color: SafeShellTheme.textPrimary,
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.lock,
                      size: 12,
                      color: SafeShellTheme.accentAlt,
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'Encrypted',
                      style: TextStyle(
                        color: SafeShellTheme.accentAlt,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatSize(file.size),
                      style: const TextStyle(
                        color: SafeShellTheme.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(
              Icons.more_vert,
              color: SafeShellTheme.textMuted,
              size: 20,
            ),
            color: SafeShellTheme.bgCard,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            onSelected: (action) {
              if (action == 'delete') {
                _deleteFile(file);
              } else if (action == 'export') {
                _exportFile(file);
              } else if (action == 'share') {
                _shareFile(file);
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'share',
                child: Row(
                  children: [
                    Icon(Icons.share, color: SafeShellTheme.textPrimary, size: 18),
                    SizedBox(width: 12),
                    Text(
                      'Share',
                      style: TextStyle(color: SafeShellTheme.textPrimary),
                    ),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'export',
                child: Row(
                  children: [
                    Icon(Icons.download, color: SafeShellTheme.textPrimary, size: 18),
                    SizedBox(width: 12),
                    Text(
                      'Export',
                      style: TextStyle(color: SafeShellTheme.textPrimary),
                    ),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, color: SafeShellTheme.error, size: 18),
                    SizedBox(width: 12),
                    Text(
                      'Delete',
                      style: TextStyle(color: SafeShellTheme.error),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _categoryIcon(String cat) {
    switch (cat) {
      case 'photos':
        return Icons.image;
      case 'videos':
        return Icons.videocam;
      case 'docs':
        return Icons.description;
      case 'zip':
        return Icons.archive;
      case 'apk':
        return Icons.android;
      default:
        return Icons.insert_drive_file;
    }
  }

  Color _categoryColor(String cat) {
    switch (cat) {
      case 'photos':
        return SafeShellTheme.accent;
      case 'videos':
        return SafeShellTheme.accentPink;
      case 'docs':
        return SafeShellTheme.accentAlt;
      case 'zip':
        return SafeShellTheme.warning;
      case 'apk':
        return SafeShellTheme.success;
      default:
        return SafeShellTheme.textMuted;
    }
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1073741824) return '${(bytes / 1048576).toStringAsFixed(1)} MB';
    return '${(bytes / 1073741824).toStringAsFixed(1)} GB';
  }
}
