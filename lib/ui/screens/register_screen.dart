import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/auth_service.dart';
import '../widgets/primary_button.dart';
import '../widgets/text_field_m3.dart';
import '../widgets/premium_ui.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with TickerProviderStateMixin {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _pass2 = TextEditingController();
  final _auth = AuthService();

  bool _loading = false;

  late final AnimationController _c;
  late final Animation<double> _fade;
  late final Animation<double> _slideUp;

  bool get _canCreate =>
      _email.text.trim().length > 3 &&
      _pass.text.length > 5 &&
      _pass.text == _pass2.text;

  @override
  void initState() {
    super.initState();

    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _fade = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
    _slideUp = Tween<double>(
      begin: 22,
      end: 0,
    ).animate(CurvedAnimation(parent: _c, curve: Curves.easeOutCubic));
    _c.forward();

    _email.addListener(_rebuild);
    _pass.addListener(_rebuild);
    _pass2.addListener(_rebuild);
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _email.removeListener(_rebuild);
    _pass.removeListener(_rebuild);
    _pass2.removeListener(_rebuild);
    _email.dispose();
    _pass.dispose();
    _pass2.dispose();
    _c.dispose();
    super.dispose();
  }

  void _snack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        backgroundColor:
            isError ? const Color(0xFFF87171) : const Color(0xFF141A24),
      ),
    );
  }

  Future<void> _register() async {
    if (_pass.text != _pass2.text) {
      _snack('Passwords do not match', isError: true);
      return;
    }
    if (!_canCreate) {
      _snack(
        'Please enter a valid email and a stronger password.',
        isError: true,
      );
      return;
    }

    try {
      setState(() => _loading = true);
      await _auth.registerWithEmail(_email.text, _pass.text);

      if (!mounted) return;
      setState(() => _loading = false);

      // Success -> Key Setup
      context.go('/key-setup');
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _snack(e.userMessage, isError: true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _snack('Registration failed: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          "Create Account",
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -0.2),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.go('/login'),
        ),
      ),
      body: Stack(
        children: [
          const PremiumBackground(child: SizedBox.shrink()),

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
                          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                          children: [
                            const SizedBox(height: 8),
                            const _HeaderBlock(),
                            const SizedBox(height: 22),

                            GlassCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              "Create account",
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 16,
                                                fontWeight: FontWeight.w800,
                                                letterSpacing: -0.2,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              "Takes less than 1 minute",
                                              style: TextStyle(
                                                color: const Color(
                                                  0xFFEAF2FF,
                                                ).withValues(alpha: 0.55),
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                          color: const Color(
                                            0xFF4DA3FF,
                                          ).withValues(alpha: 0.12),
                                          border: Border.all(
                                            color: const Color(
                                              0xFF4DA3FF,
                                            ).withValues(alpha: 0.20),
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.auto_awesome_rounded,
                                          size: 18,
                                          color: Color(0xFF4DA3FF),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 18),

                                  TextFieldM3(
                                    controller: _email,
                                    label: 'Email',
                                    icon: Icons.mail_rounded,
                                    keyboardType: TextInputType.emailAddress,
                                  ),
                                  const SizedBox(height: 12),

                                  TextFieldM3(
                                    controller: _pass,
                                    label: 'Password',
                                    icon: Icons.lock_rounded,
                                    obscure: true,
                                  ),
                                  const SizedBox(height: 12),

                                  TextFieldM3(
                                    controller: _pass2,
                                    label: 'Confirm Password',
                                    icon: Icons.lock_outline_rounded,
                                    obscure: true,
                                  ),

                                  if (_pass.text.isNotEmpty &&
                                      _pass2.text.isNotEmpty &&
                                      _pass.text != _pass2.text)
                                    const Padding(
                                      padding: EdgeInsets.only(top: 8),
                                      child: Text(
                                        "Passwords do not match",
                                        style: TextStyle(
                                          color: Color(0xFFF87171),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),

                                  const SizedBox(height: 16),

                                  PrimaryButton(
                                    text:
                                        _loading
                                            ? 'Creating...'
                                            : 'Create Account',
                                    onPressed:
                                        (_loading || !_canCreate)
                                            ? null
                                            : _register,
                                    icon: Icons.arrow_forward_rounded,
                                  ),

                                  const SizedBox(height: 12),

                                  Center(
                                    child: Wrap(
                                      alignment: WrapAlignment.center,
                                      children: [
                                        Text(
                                          "By creating an account you agree to our ",
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: const Color(
                                              0xFFEAF2FF,
                                            ).withValues(alpha: 0.40),
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            height: 1.4,
                                          ),
                                        ),
                                        InkWell(
                                          onTap:
                                              () => _snack(
                                                "Terms not yet implemented",
                                              ),
                                          child: const Text(
                                            "Terms",
                                            style: TextStyle(
                                              color: Color(0xFF4DA3FF),
                                              fontWeight: FontWeight.w800,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          " and ",
                                          style: TextStyle(
                                            color: const Color(
                                              0xFFEAF2FF,
                                            ).withValues(alpha: 0.40),
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        InkWell(
                                          onTap:
                                              () => _snack(
                                                "Privacy Policy not yet implemented",
                                              ),
                                          child: const Text(
                                            "Privacy Policy",
                                            style: TextStyle(
                                              color: Color(0xFF4DA3FF),
                                              fontWeight: FontWeight.w800,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ],
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
        ],
      ),
    );
  }
}

class _HeaderBlock extends StatelessWidget {
  const _HeaderBlock();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        SafeShellLogo(size: 74),
        SizedBox(height: 16),
        Text(
          "Create Secure Vault",
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 28,
            letterSpacing: -0.4,
          ),
        ),
        SizedBox(height: 6),
        Text(
          "Protect your private files with end-to-end encryption",
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0x99EAF2FF),
            fontSize: 15,
            fontWeight: FontWeight.w600,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}
