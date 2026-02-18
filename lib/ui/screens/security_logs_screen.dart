import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:go_router/go_router.dart';
import '../../services/audit_log_service.dart';
import '../../services/feature_gate_service.dart';
import '../../models/audit_event.dart';
import '../../ui/widgets/premium_ui.dart';
import '../../app/theme.dart';
import 'package:intl/intl.dart';

class SecurityLogsScreen extends StatefulWidget {
  const SecurityLogsScreen({super.key});
  @override
  State<SecurityLogsScreen> createState() => _SecurityLogsScreenState();
}

class _SecurityLogsScreenState extends State<SecurityLogsScreen> {
  final _auditLog = AuditLogService();
  final _featureGate = FeatureGateService();
  List<AuditEvent> _allEvents = [];
  List<AuditEvent> _filteredEvents = [];
  AuditVerification? _verification;
  bool _loading = true;
  
  // Filters
  String _searchQuery = '';
  final Set<String> _selectedTypes = {};
  DateTime? _startDate;
  DateTime? _endDate;
  
  // Event type categories
  static const _eventCategories = {
    'Security': ['login', 'unlock', 'failed_unlock', 'lock_enabled', 'lock_disabled'],
    'Files': ['file_add', 'file_open', 'file_delete'],
    'Keys': ['key_setup', 'key_rotate'],
    'Backup': ['backup_export', 'backup_import'],
    'Settings': ['stealth_toggle'],
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final events = await _auditLog.getAllEvents();
    final verification = await _auditLog.verifyChain();
    if (mounted) {
      setState(() {
        _allEvents = events;
        _filteredEvents = events;
        _verification = verification;
        _loading = false;
      });
    }
  }
  
  void _applyFilters() {
    List<AuditEvent> filtered = List.from(_allEvents);
    
    // Filter by type
    if (_selectedTypes.isNotEmpty) {
      filtered = filtered.where((e) => _selectedTypes.contains(e.type)).toList();
    }
    
    // Filter by date range
    if (_startDate != null) {
      filtered = filtered.where((e) => e.timestamp.isAfter(_startDate!)).toList();
    }
    if (_endDate != null) {
      final endOfDay = DateTime(_endDate!.year, _endDate!.month, _endDate!.day, 23, 59, 59);
      filtered = filtered.where((e) => e.timestamp.isBefore(endOfDay)).toList();
    }
    
    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((e) {
        final type = e.type.toLowerCase();
        final label = _eventLabel(e.type).toLowerCase();
        if (label.contains(query) || type.contains(query)) {
          return true;
        }
        try {
          final payload = json.decode(e.payload) as Map<String, dynamic>;
          final details = payload['details'] as Map<String, dynamic>?;
          if (details != null) {
            return details.toString().toLowerCase().contains(query);
          }
        } catch (_) {}
        return false;
      }).toList();
    }
    
    setState(() => _filteredEvents = filtered);
  }
  
  Future<void> _exportLogs() async {
    // Check Pro status
    if (!_featureGate.isFeatureAvailable(ProFeature.logExport)) {
      final shouldUpgrade = await _featureGate.showUpgradeDialog(
        context,
        ProFeature.logExport,
      );
      if (shouldUpgrade == true) {
        if (!mounted) return;
        context.push('/profile');
      }
      return;
    }
    
    try {
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final file = File('${directory.path}/security_logs_$timestamp.json');
      
      final data = {
        'exportTime': DateTime.now().toIso8601String(),
        'totalEvents': _filteredEvents.length,
        'chainVerification': {
          'isValid': _verification?.isValid ?? false,
          'message': _verification?.message ?? 'Not verified',
        },
        'events': _filteredEvents.map((e) => {
          'id': e.id,
          'timestamp': e.timestamp.toIso8601String(),
          'type': e.type,
          'payload': json.decode(e.payload),
          'eventHash': e.eventHash,
          'prevHash': e.prevHash,
        }).toList(),
      };
      
      await file.writeAsString(json.encode(data));
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ Exported ${_filteredEvents.length} logs to:\n${file.path}'),
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
    }
  }
  
  void _clearFilters() {
    setState(() {
      _searchQuery = '';
      _selectedTypes.clear();
      _startDate = null;
      _endDate = null;
      _filteredEvents = _allEvents;
    });
  }

  Future<void> _showDateFilter() async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SafeShellTheme.bgCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text(
          'Filter by Date',
          style: TextStyle(color: SafeShellTheme.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text(
                'Start Date',
                style: TextStyle(color: SafeShellTheme.textMuted, fontSize: 12),
              ),
              subtitle: Text(
                _startDate != null
                    ? DateFormat('MMM d, yyyy').format(_startDate!)
                    : 'Not set',
                style: const TextStyle(color: SafeShellTheme.textPrimary),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.calendar_today, color: SafeShellTheme.accent),
                onPressed: () async {
                  final date = await showDatePicker(
                    context: ctx,
                    initialDate: _startDate ?? DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (date != null) {
                    setState(() => _startDate = date);
                  }
                },
              ),
            ),
            ListTile(
              title: const Text(
                'End Date',
                style: TextStyle(color: SafeShellTheme.textMuted, fontSize: 12),
              ),
              subtitle: Text(
                _endDate != null
                    ? DateFormat('MMM d, yyyy').format(_endDate!)
                    : 'Not set',
                style: const TextStyle(color: SafeShellTheme.textPrimary),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.calendar_today, color: SafeShellTheme.accent),
                onPressed: () async {
                  final date = await showDatePicker(
                    context: ctx,
                    initialDate: _endDate ?? DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (date != null) {
                    setState(() => _endDate = date);
                  }
                },
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _startDate = null;
                _endDate = null;
              });
              _applyFilters();
              Navigator.pop(ctx);
            },
            child: const Text('Clear'),
          ),
          TextButton(
            onPressed: () {
              _applyFilters();
              Navigator.pop(ctx);
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PremiumBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.arrow_back,
                        color: SafeShellTheme.textPrimary,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Expanded(
                      child: ShaderMask(
                        shaderCallback: (b) =>
                            SafeShellTheme.accentGradient.createShader(b),
                        child: const Text(
                          'Security Logs',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.file_download,
                        color: SafeShellTheme.accent,
                      ),
                      onPressed: _exportLogs,
                      tooltip: 'Export Logs',
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.refresh,
                        color: SafeShellTheme.accent,
                      ),
                      onPressed: _load,
                      tooltip: 'Refresh',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              
              // Search bar
              GlassCard(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: TextField(
                  style: const TextStyle(color: SafeShellTheme.textPrimary),
                  decoration: const InputDecoration(
                    hintText: 'Search logs...',
                    hintStyle: TextStyle(color: SafeShellTheme.textMuted, fontSize: 13),
                    border: InputBorder.none,
                    prefixIcon: Icon(Icons.search, color: SafeShellTheme.accent, size: 20),
                  ),
                  onChanged: (query) {
                    _searchQuery = query;
                    _applyFilters();
                  },
                ),
              ),
              const SizedBox(height: 8),
              
              // Filter chips
              SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    ..._eventCategories.entries.map((category) {
                      final isSelected = category.value.any((t) => _selectedTypes.contains(t));
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(category.key),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedTypes.addAll(category.value);
                              } else {
                                _selectedTypes.removeAll(category.value);
                              }
                            });
                            _applyFilters();
                          },
                          backgroundColor: SafeShellTheme.bgCard.withValues(alpha: 0.3),
                          selectedColor: SafeShellTheme.accent.withValues(alpha: 0.3),
                          labelStyle: TextStyle(
                            color: isSelected ? SafeShellTheme.accent : SafeShellTheme.textMuted,
                            fontSize: 12,
                          ),
                          checkmarkColor: SafeShellTheme.accent,
                        ),
                      );
                    }),
                    // Date filter button
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ActionChip(
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.calendar_today, size: 14, color: SafeShellTheme.accentAlt),
                            const SizedBox(width: 4),
                            Text(_startDate != null || _endDate != null ? 'Date ✓' : 'Date'),
                          ],
                        ),
                        onPressed: _showDateFilter,
                        backgroundColor: (_startDate != null || _endDate != null)
                            ? SafeShellTheme.accentAlt.withValues(alpha: 0.3)
                            : SafeShellTheme.bgCard.withValues(alpha: 0.3),
                        labelStyle: TextStyle(
                          color: (_startDate != null || _endDate != null)
                              ? SafeShellTheme.accentAlt
                              : SafeShellTheme.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    // Clear filters button
                    if (_selectedTypes.isNotEmpty || _searchQuery.isNotEmpty || _startDate != null || _endDate != null)
                      ActionChip(
                        label: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.clear, size: 14, color: SafeShellTheme.error),
                            SizedBox(width: 4),
                            Text('Clear'),
                          ],
                        ),
                        onPressed: _clearFilters,
                        backgroundColor: SafeShellTheme.error.withValues(alpha: 0.2),
                        labelStyle: const TextStyle(
                          color: SafeShellTheme.error,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // Chain verification status
              if (_verification != null)
                GlassCard(
                  borderColor:
                      (_verification!.isValid
                              ? SafeShellTheme.success
                              : SafeShellTheme.error)
                          .o(0.5),
                  child: Row(
                    children: [
                      Icon(
                        _verification!.isValid ? Icons.verified : Icons.error,
                        color: _verification!.isValid
                            ? SafeShellTheme.success
                            : SafeShellTheme.error,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _verification!.isValid
                                  ? 'Chain Verified ✓'
                                  : 'Chain Broken ✗',
                              style: TextStyle(
                                color: _verification!.isValid
                                    ? SafeShellTheme.success
                                    : SafeShellTheme.error,
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _verification!.message,
                              style: const TextStyle(
                                color: SafeShellTheme.textMuted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              
              // Stats bar
              if (!_loading)
                GlassCard(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Showing ${_filteredEvents.length} of ${_allEvents.length} events',
                        style: const TextStyle(
                          color: SafeShellTheme.textMuted,
                          fontSize: 12,
                        ),
                      ),
                      if (_filteredEvents.isNotEmpty)
                        Text(
                          'Latest: ${DateFormat('MMM d, HH:mm').format(_filteredEvents.first.timestamp)}',
                          style: const TextStyle(
                            color: SafeShellTheme.textMuted,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 8),

              // Events list
              Expanded(
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: SafeShellTheme.accent,
                        ),
                      )
                    : _filteredEvents.isEmpty
                    ? const EmptyState(
                        icon: Icons.filter_list_off,
                        title: 'No matching events',
                        subtitle: 'Try adjusting your filters',
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(top: 4, bottom: 20),
                        itemCount: _filteredEvents.length,
                        itemBuilder: (_, i) => _eventCard(_filteredEvents[i]),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _eventCard(AuditEvent event) {
    final dateStr = DateFormat('MMM d, HH:mm:ss').format(event.timestamp);
    Map<String, dynamic>? details;
    try {
      final payloadMap = json.decode(event.payload) as Map<String, dynamic>;
      details = payloadMap['details'] as Map<String, dynamic>?;
    } catch (_) {}

    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _eventColor(event.type).o(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              _eventIcon(event.type),
              color: _eventColor(event.type),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _eventLabel(event.type),
                  style: const TextStyle(
                    color: SafeShellTheme.textPrimary,
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  dateStr,
                  style: const TextStyle(
                    color: SafeShellTheme.textMuted,
                    fontSize: 11,
                  ),
                ),
                if (details != null && details.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    details.entries
                        .map((e) => '${e.key}: ${e.value}')
                        .join(' · '),
                    style: const TextStyle(
                      color: SafeShellTheme.textMuted,
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _eventIcon(String type) {
    switch (type) {
      case 'login':
        return Icons.login;
      case 'unlock':
        return Icons.lock_open;
      case 'failed_unlock':
        return Icons.lock;
      case 'file_add':
        return Icons.add_circle;
      case 'file_open':
        return Icons.open_in_new;
      case 'file_delete':
        return Icons.delete;
      case 'key_setup':
        return Icons.vpn_key;
      case 'key_rotate':
        return Icons.autorenew;
      case 'stealth_toggle':
        return Icons.calculate;
      case 'lock_enabled':
        return Icons.lock;
      case 'lock_disabled':
        return Icons.lock_open;
      case 'backup_export':
        return Icons.backup;
      case 'backup_import':
        return Icons.restore;
      default:
        return Icons.info;
    }
  }

  Color _eventColor(String type) {
    switch (type) {
      case 'failed_unlock':
        return SafeShellTheme.error;
      case 'file_delete':
        return SafeShellTheme.error;
      case 'login':
      case 'unlock':
        return SafeShellTheme.success;
      case 'key_setup':
      case 'key_rotate':
        return SafeShellTheme.accentAlt;
      default:
        return SafeShellTheme.accent;
    }
  }

  String _eventLabel(String type) {
    switch (type) {
      case 'login':
        return 'Login';
      case 'unlock':
        return 'Unlocked';
      case 'failed_unlock':
        return 'Failed Unlock';
      case 'file_add':
        return 'File Added';
      case 'file_open':
        return 'File Opened';
      case 'file_delete':
        return 'File Deleted';
      case 'key_setup':
        return 'Key Setup';
      case 'key_rotate':
        return 'Key Rotated';
      case 'stealth_toggle':
        return 'Stealth Mode';
      case 'lock_enabled':
        return 'Lock Enabled';
      case 'lock_disabled':
        return 'Lock Disabled';
      case 'backup_export':
        return 'Backup Exported';
      case 'backup_import':
        return 'Backup Imported';
      default:
        return type;
    }
  }
}
