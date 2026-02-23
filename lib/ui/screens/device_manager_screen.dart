import 'dart:ui';
import 'package:flutter/material.dart';

import '../../models/registered_device.dart';
import '../../services/device_info_service.dart';
import '../widgets/premium_ui.dart';

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
          style: TextStyle(color: Colors.white.withValues(alpha: 0.70)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
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

    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${device.name} removed'),
        backgroundColor: const Color(0xFF141A24),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _formatDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final devices = _deviceService.devices;
    final isLoading = _deviceService.loading;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'Device Manager',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -0.2),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          // premium base
          const PremiumBackground(child: SizedBox.shrink()),

          // extra glow blobs (like React)
          AnimatedBuilder(
            animation: _bgC,
            builder: (_, __) {
              final t = Curves.easeInOut.transform(_bgC.value);
              return Stack(
                children: [
                  Positioned(
                    top: 140 + (t * 14),
                    right: -120 - (t * 18),
                    child: _GlowBlob(
                      size: 320,
                      blur: 120,
                      color: const Color(0xFF4DA3FF).withValues(alpha: 0.10),
                    ),
                  ),
                  Positioned(
                    bottom: 80 - (t * 10),
                    left: -120 + (t * 14),
                    child: _GlowBlob(
                      size: 300,
                      blur: 100,
                      color: const Color(0xFF0A2A4F).withValues(alpha: 0.20),
                    ),
                  ),
                ],
              );
            },
          ),

          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 412),
                child: isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF4DA3FF),
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
                        children: [
                          _InfoBanner(devices: devices),
                          const SizedBox(height: 14),

                          if (devices.isEmpty)
                            const _EmptyState()
                          else
                            ...List.generate(devices.length, (i) {
                              final d = devices[i];
                              return _SlideIn(
                                delay: Duration(milliseconds: 60 * i),
                                child: Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: _DeviceRowCard(
                                    device: d,
                                    onDetails: () => _showDeviceDetails(d),
                                    onRemove: d.isCurrentDevice
                                        ? null
                                        : () => _removeDevice(d),
                                  ),
                                ),
                              );
                            }),

                          const SizedBox(height: 6),
                          const _SecurityTip(),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Widgets

class _DeviceRowCard extends StatelessWidget {
  final RegisteredDevice device;
  final VoidCallback onDetails;
  final VoidCallback? onRemove;

  const _DeviceRowCard({
    required this.device,
    required this.onDetails,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final isOnline = device.isOnline;
    final isCurrent = device.isCurrentDevice;

    return GlassCard(
      child: InkWell(
        borderRadius: BorderRadius.circular(26),
        onTap: onDetails,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Stack(
                children: [
                  _IconTile(icon: _platformIcon(device.platform)),
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
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                        if (isCurrent) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              color: const Color(0xFF4DA3FF)
                                  .withValues(alpha: 0.12),
                              border: Border.all(
                                color: const Color(0xFF4DA3FF)
                                    .withValues(alpha: 0.20),
                              ),
                            ),
                            child: const Text(
                              'This device',
                              style: TextStyle(
                                color: Color(0xFF4DA3FF),
                                fontWeight: FontWeight.w900,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      device.displayModel.isNotEmpty
                          ? device.displayModel
                          : device.model,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: const Color(0xFFEAF2FF).withValues(alpha: 0.55),
                        fontWeight: FontWeight.w700,
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
                              : Colors.white.withValues(alpha: 0.30),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            isOnline
                                ? 'Online • Active now'
                                : 'Offline • ${device.lastSeenText}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: const Color(0xFFEAF2FF)
                                  .withValues(alpha: 0.45),
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 10),

              // delete button like React (trash icon)
              _IconAction(
                icon: Icons.delete_outline_rounded,
                onTap: onRemove,
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

class _IconAction extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _IconAction({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: Colors.white.withValues(alpha: 0.05),
          border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        ),
        child: Icon(
          icon,
          size: 20,
          color: disabled
              ? Colors.white.withValues(alpha: 0.25)
              : const Color(0xFFEAF2FF).withValues(alpha: 0.70),
        ),
      ),
    );
  }
}

class _IconTile extends StatelessWidget {
  final IconData icon;
  const _IconTile({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.white.withValues(alpha: 0.05),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Icon(icon, color: const Color(0xFF4DA3FF), size: 24),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  final List<RegisteredDevice> devices;
  const _InfoBanner({required this.devices});

  @override
  Widget build(BuildContext context) {
    final total = devices.length;
    final trusted = devices.where((d) => d.isTrusted).length;

    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                color: const Color(0xFF4DA3FF).withValues(alpha: 0.12),
                border: Border.all(
                  color: const Color(0xFF4DA3FF).withValues(alpha: 0.20),
                ),
              ),
              child: const Icon(
                Icons.devices_rounded,
                color: Color(0xFF4DA3FF),
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$total device${total == 1 ? '' : 's'} registered',
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
                      color: const Color(0xFFEAF2FF).withValues(alpha: 0.55),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 38, horizontal: 22),
        child: Column(
          children: [
            Icon(
              Icons.devices_other_rounded,
              size: 48,
              color: Colors.white.withValues(alpha: 0.30),
            ),
            const SizedBox(height: 12),
            Text(
              'No devices registered',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.75),
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'This device will be registered automatically.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: const Color(0xFFEAF2FF).withValues(alpha: 0.40),
                fontSize: 13,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SecurityTip extends StatelessWidget {
  const _SecurityTip();

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.info_outline_rounded,
              size: 18,
              color: const Color(0xFF4DA3FF).withValues(alpha: 0.85),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                "Remove any device you don't recognise immediately. "
                "Unknown devices may indicate unauthorised access.",
                style: TextStyle(
                  color: const Color(0xFFEAF2FF).withValues(alpha: 0.55),
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SlideIn extends StatefulWidget {
  final Widget child;
  final Duration delay;
  const _SlideIn({required this.child, required this.delay});

  @override
  State<_SlideIn> createState() => _SlideInState();
}

class _SlideInState extends State<_SlideIn> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _t;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 450));
    _t = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
    Future.delayed(widget.delay, () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        return Opacity(
          opacity: _t.value,
          child: Transform.translate(
            offset: Offset(-14 * (1 - _t.value), 0),
            child: widget.child,
          ),
        );
      },
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

// ─────────────────────────────────────────────────────────────────────────────
// Bottom Sheet (details) — same behavior, premium UI

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
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    await widget.onRename(name);
    if (!mounted) return;
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
            color: const Color(0xFF0F1520).withValues(alpha: 0.95),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(
              top: BorderSide(color: Colors.white.withValues(alpha: 0.10)),
            ),
          ),
          padding: EdgeInsets.fromLTRB(
            24,
            18,
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
                    color: Colors.white.withValues(alpha: 0.20),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              Row(
                children: [
                  _SheetIconTile(icon: _platformIcon(widget.device.platform)),
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
                              letterSpacing: -0.2,
                            ),
                            decoration: InputDecoration(
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                              border: InputBorder.none,
                              hintText: 'Device name',
                              hintStyle: TextStyle(
                                color: Colors.white.withValues(alpha: 0.35),
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
                              letterSpacing: -0.2,
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

              const SizedBox(height: 14),
              const Divider(color: Colors.white12),
              const SizedBox(height: 8),

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
                            color: const Color(0xFFEAF2FF)
                                .withValues(alpha: 0.45),
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

              const SizedBox(height: 10),
              const Divider(color: Colors.white12),
              const SizedBox(height: 10),

              Row(
                children: [
                  Expanded(
                    child: _SheetAction(
                      label: widget.device.isTrusted ? 'Mark Untrusted' : 'Mark Trusted',
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
                      child: _SheetAction(
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

class _SheetIconTile extends StatelessWidget {
  final IconData icon;
  const _SheetIconTile({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white.withValues(alpha: 0.10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Icon(icon, color: Colors.white.withValues(alpha: 0.85), size: 20),
    );
  }
}

class _SheetAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _SheetAction({
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
          color: color.withValues(alpha: 0.12),
          border: Border.all(color: color.withValues(alpha: 0.22)),
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