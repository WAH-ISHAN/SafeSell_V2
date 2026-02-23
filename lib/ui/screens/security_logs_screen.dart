import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/audit_event.dart';
import '../../services/audit_log_service.dart';
import '../widgets/premium_ui.dart';

class SecurityLogsScreen extends StatefulWidget {
  const SecurityLogsScreen({super.key});
  @override
  State<SecurityLogsScreen> createState() => _SecurityLogsScreenState();
}

class _SecurityLogsScreenState extends State<SecurityLogsScreen>
    with SingleTickerProviderStateMixin {
  final _auditLog = AuditLogService();

  late final AnimationController _bgC;

  bool _loading = true;
  List<AuditEvent> _events = [];

  @override
  void initState() {
    super.initState();
    _bgC = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat(reverse: true);

    _load();
  }

  Future<void> _load() async {
    final events = await _auditLog.getAllEvents();
    if (!mounted) return;
    setState(() {
      _events = events;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _bgC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'Security Logs',
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
          // ✅ same premium base
          const PremiumBackground(child: SizedBox.shrink()),

          // ✅ same subtle blobs like React screen
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
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF4DA3FF),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
                        itemCount: _events.length,
                        itemBuilder: (context, i) {
                          final e = _events[i];
                          final ui = _mapEvent(e);
                          return _SlideIn(
                            delay: Duration(milliseconds: 60 * i),
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: GlassCard(
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Row(
                                    children: [
                                      _IconTile(
                                        icon: ui.icon,
                                        iconColor: ui.color,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              ui.title,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w900,
                                                fontSize: 15,
                                                letterSpacing: -0.2,
                                              ),
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              ui.meta,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: const Color(0xFFEAF2FF)
                                                    .withValues(alpha: 0.55),
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
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  _LogUI _mapEvent(AuditEvent e) {
    final title = _label(e.type);
    final meta = _relativeMeta(e.timestamp);

    // React tones:
    // green => #10B981, amber => #F59E0B, blue => #4DA3FF
    switch (e.type) {
      case 'unlock':
      case 'login':
        return _LogUI(
          title: title,
          meta: meta,
          icon: Icons.verified_user_rounded,
          color: const Color(0xFF10B981),
        );

      case 'failed_unlock':
      case 'new_device':
      case 'device_new':
        return _LogUI(
          title: title == e.type ? 'New device detected' : title,
          meta: meta,
          icon: Icons.warning_amber_rounded,
          color: const Color(0xFFF59E0B),
        );

      case 'backup_export':
      case 'backup_import':
        return _LogUI(
          title: title,
          meta: meta,
          icon: Icons.schedule_rounded,
          color: const Color(0xFF4DA3FF),
        );

      default:
        // fallback: pick a “safe” blue
        return _LogUI(
          title: title,
          meta: meta,
          icon: Icons.shield_rounded,
          color: const Color(0xFF4DA3FF),
        );
    }
  }

  String _label(String type) {
    switch (type) {
      case 'unlock':
        return 'Vault unlocked';
      case 'login':
        return 'Login';
      case 'failed_unlock':
        return 'Failed unlock';
      case 'backup_export':
        return 'Backup exported';
      case 'backup_import':
        return 'Backup completed';
      default:
        // title-case-ish fallback
        return type.replaceAll('_', ' ').trim();
    }
  }

  String _relativeMeta(DateTime ts) {
    final now = DateTime.now();
    final d0 = DateTime(now.year, now.month, now.day);
    final d1 = DateTime(ts.year, ts.month, ts.day);

    final time = DateFormat('h:mm a').format(ts);

    if (d1 == d0) return 'Today • $time';
    if (d1 == d0.subtract(const Duration(days: 1))) return 'Yesterday • $time';

    return '${DateFormat('MMM dd').format(ts)} • $time';
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _IconTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;

  const _IconTile({required this.icon, required this.iconColor});

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
      child: Icon(icon, color: iconColor, size: 24),
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
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
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

class _LogUI {
  final String title;
  final String meta;
  final IconData icon;
  final Color color;

  const _LogUI({
    required this.title,
    required this.meta,
    required this.icon,
    required this.color,
  });
}