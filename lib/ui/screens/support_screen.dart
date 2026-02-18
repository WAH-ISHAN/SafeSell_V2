import 'dart:ui';
import 'package:flutter/material.dart';

import 'subscription_screen.dart';

/// ✅ React SupportScreen → Flutter SupportScreen (Premium)
/// - Animated premium background (2 moving blobs)
/// - Smart search + tag pills
/// - Contact tiles (Live Chat / Email / Help Center)
/// - Quick Help list (filter by search)
/// - Same glass style as your other screens

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen>
    with TickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _fade;
  late final Animation<double> _slideUp;

  late final AnimationController _bgC;

  final _q = TextEditingController();

  final List<_Faq> _faqs = [
    const _Faq(
      title: "How to recover my security key?",
      desc: "Learn what is recoverable and best practices.",
      tag: "Security",
      icon: Icons.shield_rounded,
      tone: _Tone.blue,
      onTap: null,
    ),
    const _Faq(
      title: "How to upgrade to Pro?",
      desc: "Plans, billing and removing ads.",
      tag: "Billing",
      icon: Icons.flash_on_rounded,
      tone: _Tone.green,
      onTap: _FaqAction.goSubscription,
    ),
    const _Faq(
      title: "How does encryption work?",
      desc: "A simple overview of encryption in SafeShell.",
      tag: "Privacy",
      icon: Icons.auto_awesome_rounded,
      tone: _Tone.purple,
      onTap: null,
    ),
    const _Faq(
      title: "I can't sign in (Google / Email).",
      desc: "Fix common login and network issues.",
      tag: "Account",
      icon: Icons.schedule_rounded,
      tone: _Tone.amber,
      onTap: null,
    ),
  ];

  @override
  void initState() {
    super.initState();

    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fade = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
    _slideUp = Tween<double>(
      begin: 18,
      end: 0,
    ).animate(CurvedAnimation(parent: _c, curve: Curves.easeOutCubic));
    _c.forward();

    _bgC = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat(reverse: true);

    _q.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _q.dispose();
    _bgC.dispose();
    _c.dispose();
    super.dispose();
  }

  List<_Faq> get _filteredFaqs {
    final needle = _q.text.trim().toLowerCase();
    if (needle.isEmpty) return _faqs;
    return _faqs.where((f) {
      return f.title.toLowerCase().contains(needle) ||
          f.desc.toLowerCase().contains(needle) ||
          f.tag.toLowerCase().contains(needle);
    }).toList();
  }

  void _setTag(String s) {
    _q.text = s;
    _q.selection = TextSelection.collapsed(offset: _q.text.length);
  }

  void _clearQ() => _q.clear();

  void _openLiveChat() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Opening live chat… (TODO)"),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _openEmailSupport() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Opening email support… (TODO)"),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _openHelpCenter() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Opening help center… (TODO)"),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _handleFaqTap(_Faq f) {
    if (f.onTap == _FaqAction.goSubscription) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Open FAQ: ${f.title} (TODO)"),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          "Support",
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -0.2),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: Stack(
        children: [
          // base
          Container(color: const Color(0xFF0B0F14)),

          // radial field (React bg language)
          const _PremiumRadialField(
            a: Alignment(-0.85, -0.85),
            aColor: Color(0x1F4DA3FF),
            b: Alignment(0.90, -0.65),
            bColor: Color(0x4D0A2A4F),
            c: Alignment(-0.20, 0.90),
            cColor: Color(0x1A8B5CF6),
          ),

          // animated blobs
          AnimatedBuilder(
            animation: _bgC,
            builder: (_, __) {
              final t = _bgC.value;
              return Stack(
                children: [
                  Positioned(
                    top: 110 + (t * 10),
                    right: -110 - (t * 14),
                    child: _GlowBlob(
                      color: const Color(0xFF4DA3FF).o(0.10),
                      size: 520,
                      blur: 120,
                    ),
                  ),
                  Positioned(
                    bottom: 40 - (t * 10),
                    left: -120 + (t * 12),
                    child: _GlowBlob(
                      color: const Color(0xFF0A2A4F).o(0.28),
                      size: 460,
                      blur: 110,
                    ),
                  ),
                ],
              );
            },
          ),

          // content
          SafeArea(
            child: AnimatedBuilder(
              animation: _c,
              builder: (_, __) {
                return Opacity(
                  opacity: _fade.value,
                  child: Transform.translate(
                    offset: Offset(0, _slideUp.value),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 412),
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                          children: [
                            // header
                            Text(
                              "Need help?",
                              style: TextStyle(
                                color: cs.onSurface,
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              "Find answers fast or contact the team.",
                              style: TextStyle(
                                color: const Color(0xFFEAF2FF).o(0.60),
                                fontWeight: FontWeight.w600,
                              ),
                            ),

                            const SizedBox(height: 16),

                            // search card
                            _GlassCard(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.search_rounded,
                                        size: 18,
                                        color: Color(0xFF4DA3FF),
                                      ),
                                      const SizedBox(width: 8),
                                      const Text(
                                        "Search help articles",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const Spacer(),
                                      if (_q.text.trim().isNotEmpty)
                                        TextButton(
                                          onPressed: _clearQ,
                                          child: Text(
                                            "Clear",
                                            style: TextStyle(
                                              color: const Color(
                                                0xFFEAF2FF,
                                              ).o(0.55),
                                              fontWeight: FontWeight.w800,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(16),
                                      color: Colors.white.o(0.05),
                                      border: Border.all(
                                        color: Colors.white.o(0.10),
                                      ),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.search_rounded,
                                          size: 18,
                                          color: const Color(
                                            0xFFEAF2FF,
                                          ).o(0.45),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: TextField(
                                            controller: _q,
                                            style: const TextStyle(
                                              color: Color(0xFFEAF2FF),
                                              fontWeight: FontWeight.w700,
                                              fontSize: 14,
                                            ),
                                            decoration: InputDecoration(
                                              border: InputBorder.none,
                                              hintText:
                                                  "Type: key recovery, billing, encryption…",
                                              hintStyle: TextStyle(
                                                color: const Color(
                                                  0xFFEAF2FF,
                                                ).o(0.35),
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      _TagPill(
                                        label: "Security",
                                        onTap: () => _setTag("Security"),
                                      ),
                                      _TagPill(
                                        label: "Billing",
                                        onTap: () => _setTag("Billing"),
                                      ),
                                      _TagPill(
                                        label: "Account",
                                        onTap: () => _setTag("Account"),
                                      ),
                                      _TagPill(
                                        label: "Privacy",
                                        onTap: () => _setTag("Privacy"),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 16),

                            // contact tiles
                            _SupportTile(
                              tone: _Tone.green,
                              icon: Icons.chat_bubble_rounded,
                              title: "Live Chat",
                              subtitle: "Chat with our support team",
                              metaLeft: "~2 min response",
                              metaRight: "Online",
                              onTap: _openLiveChat,
                            ),
                            const SizedBox(height: 10),
                            _SupportTile(
                              tone: _Tone.blue,
                              icon: Icons.email_rounded,
                              title: "Email Support",
                              subtitle: "Send us an email anytime",
                              metaLeft: "~24 hour response",
                              metaRight: "Ticket",
                              onTap: _openEmailSupport,
                            ),
                            const SizedBox(height: 10),
                            _SupportTile(
                              tone: _Tone.purple,
                              icon: Icons.menu_book_rounded,
                              title: "Help Center",
                              subtitle: "Browse articles and guides",
                              metaLeft: "250+ articles",
                              metaRight: "Browse",
                              rightIcon: Icons.open_in_new_rounded,
                              onTap: _openHelpCenter,
                            ),

                            const SizedBox(height: 18),

                            // quick help header
                            Row(
                              children: [
                                const Text(
                                  "Quick Help",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  "${_filteredFaqs.length} results",
                                  style: TextStyle(
                                    color: const Color(0xFFEAF2FF).o(0.45),
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),

                            // faq list
                            _GlassCard(
                              padding: const EdgeInsets.all(10),
                              child:
                                  _filteredFaqs.isEmpty
                                      ? Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 22,
                                        ),
                                        child: Column(
                                          children: [
                                            const Text(
                                              "No matches",
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              "Try searching \"billing\" or \"key recovery\".",
                                              style: TextStyle(
                                                color: const Color(
                                                  0xFFEAF2FF,
                                                ).o(0.55),
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                      : Column(
                                        children: [
                                          for (
                                            int i = 0;
                                            i < _filteredFaqs.length;
                                            i++
                                          ) ...[
                                            _FaqRow(
                                              faq: _filteredFaqs[i],
                                              onTap:
                                                  () => _handleFaqTap(
                                                    _filteredFaqs[i],
                                                  ),
                                            ),
                                            if (i != _filteredFaqs.length - 1)
                                              Divider(
                                                height: 10,
                                                color: Colors.white.o(0.06),
                                              ),
                                          ],
                                        ],
                                      ),
                            ),

                            const SizedBox(height: 14),

                            Text(
                              "Tip: Never share your private key. Support will never ask for it.",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: const Color(0xFFEAF2FF).o(0.35),
                                fontSize: 12,
                                height: 1.35,
                                fontWeight: FontWeight.w600,
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

          // blur under appbar
          const _TopBlur(),
        ],
      ),
    );
  }
}

/* ===================== Small UI parts ===================== */

class _TagPill extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _TagPill({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: Colors.white.o(0.05),
          border: Border.all(color: Colors.white.o(0.10)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: const Color(0xFFEAF2FF).o(0.70),
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _SupportTile extends StatelessWidget {
  final _Tone tone;
  final IconData icon;
  final String title;
  final String subtitle;
  final String metaLeft;
  final String metaRight;
  final IconData rightIcon;
  final VoidCallback onTap;

  const _SupportTile({
    required this.tone,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.metaLeft,
    required this.metaRight,
    this.rightIcon = Icons.chevron_right_rounded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = _toneColor(tone);

    return InkWell(
      borderRadius: BorderRadius.circular(26),
      onTap: onTap,
      child: _GlassCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  colors: [accent, _toneColor2(tone)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(blurRadius: 18, color: Colors.white.o(0.08)),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: const Color(0xFFEAF2FF).o(0.60),
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        metaLeft,
                        style: TextStyle(
                          color: const Color(0xFFEAF2FF).o(0.70),
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.o(0.20),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        metaRight,
                        style: TextStyle(
                          color: const Color(0xFFEAF2FF).o(0.70),
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.o(0.05),
                border: Border.all(color: Colors.white.o(0.10)),
              ),
              child: Icon(rightIcon, color: const Color(0xFFEAF2FF).o(0.40)),
            ),
          ],
        ),
      ),
    );
  }
}

class _FaqRow extends StatelessWidget {
  final _Faq faq;
  final VoidCallback onTap;
  const _FaqRow({required this.faq, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final accent = _toneColor(faq.tone);

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.transparent,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: LinearGradient(
                  colors: [accent.o(0.85), _toneColor2(faq.tone).o(0.70)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(color: Colors.white.o(0.10)),
              ),
              child: Icon(faq.icon, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      Text(
                        faq.title,
                        style: const TextStyle(
                          color: Color(0xFFEAF2FF),
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                          letterSpacing: -0.1,
                        ),
                      ),
                      _SmallChip(text: faq.tag),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    faq.desc,
                    style: TextStyle(
                      color: const Color(0xFFEAF2FF).o(0.55),
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right_rounded,
              color: const Color(0xFFEAF2FF).o(0.35),
            ),
          ],
        ),
      ),
    );
  }
}

class _SmallChip extends StatelessWidget {
  final String text;
  const _SmallChip({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Colors.white.o(0.05),
        border: Border.all(color: Colors.white.o(0.10)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: const Color(0xFFEAF2FF).o(0.60),
          fontWeight: FontWeight.w800,
          fontSize: 11,
        ),
      ),
    );
  }
}

/* ===================== Background helpers ===================== */

class _PremiumRadialField extends StatelessWidget {
  final Alignment a;
  final Color aColor;
  final Alignment b;
  final Color bColor;
  final Alignment c;
  final Color cColor;

  const _PremiumRadialField({
    required this.a,
    required this.aColor,
    required this.b,
    required this.bColor,
    required this.c,
    required this.cColor,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: a,
                radius: 1.2,
                colors: [aColor, Colors.transparent],
                stops: const [0.0, 0.55],
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: b,
                radius: 1.1,
                colors: [bColor, Colors.transparent],
                stops: const [0.0, 0.55],
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: c,
                radius: 1.2,
                colors: [cColor, Colors.transparent],
                stops: const [0.0, 0.55],
              ),
            ),
          ),
        ),
      ],
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

class _TopBlur extends StatelessWidget {
  const _TopBlur();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(height: 74, color: Colors.transparent),
          ),
        ),
      ),
    );
  }
}

/* ===================== Data ===================== */

enum _FaqAction { goSubscription }

enum _Tone { blue, green, purple, amber, red }

class _Faq {
  final String title;
  final String desc;
  final String tag;
  final IconData icon;
  final _Tone tone;
  final _FaqAction? onTap;

  const _Faq({
    required this.title,
    required this.desc,
    required this.tag,
    required this.icon,
    required this.tone,
    this.onTap,
  });
}

Color _toneColor(_Tone t) {
  switch (t) {
    case _Tone.green:
      return const Color(0xFF10B981);
    case _Tone.purple:
      return const Color(0xFF8B5CF6);
    case _Tone.amber:
      return const Color(0xFFF59E0B);
    case _Tone.red:
      return const Color(0xFFEF4444);
    case _Tone.blue:
      return const Color(0xFF4DA3FF);
  }
}

Color _toneColor2(_Tone t) {
  switch (t) {
    case _Tone.green:
      return const Color(0xFF059669);
    case _Tone.purple:
      return const Color(0xFF7C3AED);
    case _Tone.amber:
      return const Color(0xFFF97316);
    case _Tone.red:
      return const Color(0xFFF97316);
    case _Tone.blue:
      return const Color(0xFF2B7FDB);
  }
}

/* ===================== Glass card ===================== */

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
            color: Colors.white.o(0.06),
            border: Border.all(color: Colors.white.o(0.10)),
            boxShadow: [
              BoxShadow(
                blurRadius: 30,
                spreadRadius: 2,
                color: Colors.black.o(0.25),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

/// ✅ withOpacity deprecated warning avoid helper
extension _ColorOpacity on Color {
  Color o(double opacity) {
    final a = (opacity.clamp(0.0, 1.0) * 255).round();
    return withAlpha(a);
  }
}
