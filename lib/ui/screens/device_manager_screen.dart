import 'dart:ui';

import 'package:flutter/material.dart';

import '../../models/registered_device.dart';
import '../../services/device_info_service.dart';

class DeviceManagerScreen extends StatefulWidget {
  const DeviceManagerScreen({super.key});

  @override
  State<DeviceManagerScreen> createState() => _DeviceManagerScreenState();
}

class _DeviceManagerScreenState extends State<DeviceManagerScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bgC;
  final DeviceInfoService _deviceService = DeviceInfoService();

  @override
  void initState() {
    super.initState();
    _bgC = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat(reverse: true);
    _deviceService.init().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _bgC.dispose();
    super.dispose();
  }

  // ── Actions ──────────────────────────────────────────────────────────────

  Future<void> _showDeviceDetails(RegisteredDevice device) async {
    Map<String, String> details;
    if (device.isCurrentDevice) {
      details = await _deviceService.getCurrentDeviceDetails();
    } else {
      details = {
        'Device Name': device.name,
        'Model': device.displayModel,
        'OS': device.osVersion,
        'Platform': device.platform,
        'Registered': _formatDate(device.registeredAt),
        'Last Seen': device.lastSeenText,
        'Trusted': device.isTrusted ? 'Yes' : 'No',
      };
    }

    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _DeviceDetailsSheet(
        device: device,
        details: details,
        onRename: (name) => _renameDevice(device, name),
        onToggleTrust: () => _toggleTrust(device),
        onRemove: device.isCurrentDevice ? null : () => _removeDevice(device),
      ),
    );
  }

  Future<void> _renameDevice(RegisteredDevice device, String name) async {
    await _deviceService.renameDevice(device, name);
    if (mounted) setState(() {});
  }

  Future<void> _toggleTrust(RegisteredDevice device) async {
    await _deviceService.toggleTrust(device);
    if (mounted) setState(() {});
  }

  Future<void> _removeDevice(RegisteredDevice device) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A2030),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Remove Device?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
        ),
        content: Text(
          'Remove "${device.name}" from your registered devices?',
          style: TextStyle(color: Colors.white.withAlpha(178)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Remove',
              style: TextStyle(
                color: Color(0xFFEF4444),
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    await _deviceService.removeDevice(device);
    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${device.name} removed'),
          backgroundColor: const Color(0xFF1A2030),
        ),
      );
    }
  }

  String _formatDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final devices = _deviceService.devices;
    final isLoading = _deviceService.loading;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'Device Manager',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -0.2),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF0B0F14),
                  const Color(0xFF0B0F14),
                  Color.alphaBlend(
                    cs.primary.withAlpha(36),
                    const Color(0xFF0B0F14),
                  ),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          AnimatedBuilder(
            animation: _bgC,
            builder: (context, child) {
              final t = _bgC.value;
              return Stack(
                children: [
                  Positioned(
                    top: -120 + (t * 18),
                    right: -120 - (t * 18),
                    child: _GlowBlob(
                      size: 520,
                      color: const Color(0xFF4DA3FF).withAlpha(31),
                      blur: 120,
                    ),
                  ),
                  Positioned(
                    bottom: 60 - (t * 12),
                    left: -110 + (t * 16),
                    child: _GlowBlob(
                      size: 460,
                      color: const Color(0xFF0A2A4F).withAlpha(77),
                      blur: 110,
                    ),
                  ),
                ],
              );
            },
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(height: 88, color: Colors.transparent),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 412),
                child: isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                        children: [
                          _buildInfoBanner(devices),
                          const SizedBox(height: 14),
                          if (devices.isEmpty)
                            _buildEmptyState()
                          else
                            ...devices.map(
                              (d) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _DeviceCard(
                                  device: d,
                                  onDetails: () => _showDeviceDetails(d),
                                  onRemove: d.isCurrentDevice
                                      ? null
                                      : () => _removeDevice(d),
                                ),
                              ),
                            ),
                          const SizedBox(height: 8),
                          _buildSecurityTip(),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBanner(List<RegisteredDevice> devices) {
    final total = devices.length;
    final trusted = devices.where((d) => d.isTrusted).length;

    return _GlassCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          const _ChipIcon(icon: Icons.devices_rounded),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$total device${total != 1 ? 's' : ''} registered',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$trusted trusted • ${total - trusted} untrusted',
                  style: TextStyle(
                    color: Colors.white.withAlpha(140),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return _GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      child: Column(
        children: [
          Icon(
            Icons.devices_other_rounded,
            size: 48,
            color: Colors.white.withAlpha(77),
          ),
          const SizedBox(height: 12),
          Text(
            'No devices registered',
            style: TextStyle(
              color: Colors.white.withAlpha(178),
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'This device will be registered automatically.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withAlpha(102),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityTip() {
    return _GlassCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: const Color(0xFF4DA3FF).withAlpha(204),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "Remove any device you don't recognise immediately. "
              'Unknown devices may indicate unauthorised access.',
              style: TextStyle(
                color: Colors.white.withAlpha(140),
                fontWeight: FontWeight.w600,
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Device Card ───────────────────────────────────────────────────────────────

class _DeviceCard extends StatelessWidget {
  final RegisteredDevice device;
  final VoidCallback onDetails;
  final VoidCallback? onRemove;

  const _DeviceCard({
    required this.device,
    required this.onDetails,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final isOnline = device.isOnline;
    final isCurrent = device.isCurrentDevice;

    return _GlassCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              _DeviceIcon(icon: _platformIcon(device.platform)),
              if (isOnline)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 11,
                    height: 11,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF22C55E),
                      border: Border.all(
                        color: const Color(0xFF0B0F14),
                        width: 2,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        device.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    if (isCurrent)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: const Color(0xFF4DA3FF).withAlpha(31),
                          border: Border.all(
                            color: const Color(0xFF4DA3FF).withAlpha(77),
                          ),
                        ),
                        child: const Text(
                          'This device',
                          style: TextStyle(
                            color: Color(0xFF4DA3FF),
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  device.model,
                  style: TextStyle(
                    color: Colors.white.withAlpha(140),
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      isOnline ? Icons.circle : Icons.circle_outlined,
                      size: 8,
                      color: isOnline
                          ? const Color(0xFF22C55E)
                          : Colors.white.withAlpha(77),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      isOnline
                          ? 'Online • Active now'
                          : 'Offline • ${device.lastSeenText}',
                      style: TextStyle(
                        color: Colors.white.withAlpha(115),
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      device.isTrusted
                          ? Icons.verified_user_rounded
                          : Icons.gpp_bad_rounded,
                      size: 12,
                      color: device.isTrusted
                          ? const Color(0xFF22C55E).withAlpha(204)
                          : const Color(0xFFEF4444).withAlpha(204),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      device.isTrusted ? 'Trusted' : 'Untrusted',
                      style: TextStyle(
                        color: device.isTrusted
                            ? const Color(0xFF22C55E).withAlpha(204)
                            : const Color(0xFFEF4444).withAlpha(204),
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    _GhostButton(label: 'Details', onTap: onDetails),
                    if (onRemove != null)
                      _DangerGhostButton(
                        label: 'Remove',
                        onTap: onRemove!,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _platformIcon(String platform) {
    switch (platform) {
      case 'android':
        return Icons.phone_android_rounded;
      case 'ios':
        return Icons.phone_iphone_rounded;
      case 'windows':
        return Icons.laptop_windows_rounded;
      case 'macos':
        return Icons.laptop_mac_rounded;
      default:
        return Icons.devices_rounded;
    }
  }
}

// ── Details Bottom Sheet ──────────────────────────────────────────────────────

class _DeviceDetailsSheet extends StatefulWidget {
  final RegisteredDevice device;
  final Map<String, String> details;
  final Future<void> Function(String) onRename;
  final VoidCallback onToggleTrust;
  final VoidCallback? onRemove;

  const _DeviceDetailsSheet({
    required this.device,
    required this.details,
    required this.onRename,
    required this.onToggleTrust,
    this.onRemove,
  });

  @override
  State<_DeviceDetailsSheet> createState() => _DeviceDetailsSheetState();
}

class _DeviceDetailsSheetState extends State<_DeviceDetailsSheet> {
  late final TextEditingController _nameCtrl;
  bool _renaming = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.device.name);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveRename() async {
    await widget.onRename(_nameCtrl.text);
    setState(() => _renaming = false);
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0F1520).withAlpha(242),
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(
              top: BorderSide(color: Colors.white.withAlpha(26)),
            ),
          ),
          padding: EdgeInsets.fromLTRB(
            24,
            20,
            24,
            24 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(51),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _DeviceIcon(icon: _platformIcon(widget.device.platform)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _renaming
                        ? TextField(
                            controller: _nameCtrl,
                            autofocus: true,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 17,
                            ),
                            decoration: InputDecoration(
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                              border: InputBorder.none,
                              hintText: 'Device name',
                              hintStyle: TextStyle(
                                color: Colors.white.withAlpha(77),
                              ),
                            ),
                            onSubmitted: (_) => _saveRename(),
                          )
                        : Text(
                            widget.device.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 17,
                            ),
                          ),
                  ),
                  IconButton(
                    onPressed: () {
                      if (_renaming) {
                        _saveRename();
                      } else {
                        setState(() => _renaming = true);
                      }
                    },
                    icon: Icon(
                      _renaming ? Icons.check_rounded : Icons.edit_rounded,
                      color: const Color(0xFF4DA3FF),
                      size: 20,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(color: Colors.white12),
              const SizedBox(height: 12),
              ...widget.details.entries.map(
                (e) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 110,
                        child: Text(
                          e.key,
                          style: TextStyle(
                            color: Colors.white.withAlpha(115),
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          e.value,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Divider(color: Colors.white12),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _ActionButton(
                      label: widget.device.isTrusted
                          ? 'Mark Untrusted'
                          : 'Mark Trusted',
                      icon: widget.device.isTrusted
                          ? Icons.gpp_bad_rounded
                          : Icons.verified_user_rounded,
                      color: widget.device.isTrusted
                          ? const Color(0xFFF59E0B)
                          : const Color(0xFF22C55E),
                      onTap: () {
                        widget.onToggleTrust();
                        Navigator.pop(context);
                      },
                    ),
                  ),
                  if (widget.onRemove != null) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ActionButton(
                        label: 'Remove',
                        icon: Icons.delete_outline_rounded,
                        color: const Color(0xFFEF4444),
                        onTap: () {
                          Navigator.pop(context);
                          widget.onRemove!();
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _platformIcon(String platform) {
    switch (platform) {
      case 'android':
        return Icons.phone_android_rounded;
      case 'ios':
        return Icons.phone_iphone_rounded;
      case 'windows':
        return Icons.laptop_windows_rounded;
      case 'macos':
        return Icons.laptop_mac_rounded;
      default:
        return Icons.devices_rounded;
    }
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: color.withAlpha(31),
          border: Border.all(color: color.withAlpha(77)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w900,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shared UI ─────────────────────────────────────────────────────────────────

class _GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;

  const _GlassCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            color: Colors.white.withAlpha(15),
            border: Border.all(color: Colors.white.withAlpha(26)),
            boxShadow: [
              BoxShadow(
                blurRadius: 30,
                spreadRadius: 2,
                color: Colors.black.withAlpha(64),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _GlowBlob extends StatelessWidget {
  final Color color;
  final double size;
  final double blur;

  const _GlowBlob({
    required this.color,
    required this.size,
    required this.blur,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          boxShadow: [BoxShadow(blurRadius: blur, color: color)],
        ),
      ),
    );
  }
}

class _ChipIcon extends StatelessWidget {
  final IconData icon;
  const _ChipIcon({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white.withAlpha(15),
        border: Border.all(color: Colors.white.withAlpha(26)),
      ),
      child: Icon(icon, color: const Color(0xFF4DA3FF), size: 20),
    );
  }
}

class _DeviceIcon extends StatelessWidget {
  final IconData icon;
  const _DeviceIcon({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white.withAlpha(15),
        border: Border.all(color: Colors.white.withAlpha(26)),
      ),
      child: Icon(icon, color: Colors.white.withAlpha(217), size: 20),
    );
  }
}

class _GhostButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _GhostButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.white.withAlpha(15),
          border: Border.all(color: Colors.white.withAlpha(26)),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _DangerGhostButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _DangerGhostButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.white.withAlpha(15),
          border: Border.all(
            color: const Color(0xFFEF4444).withAlpha(89),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Color(0xFFEF4444),
            fontSize: 13,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}
