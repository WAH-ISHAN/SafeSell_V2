import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/auth_service.dart';
import '../../services/connectivity_service.dart';
import '../../app/config.dart';
import '../widgets/primary_button.dart';
import '../widgets/text_field_m3.dart';
import '../widgets/premium_ui.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final _email = TextEditingController();
  final _pass = TextEditingController();

  final _auth = AuthService();

  bool _loading = false;
  bool _googleLoading = false;

  late final AnimationController _c;
  late final Animation<double> _fade;
  late final Animation<double> _slideUp;

  // background drift
  late final AnimationController _bgC;

  bool get _canContinue =>
      _email.text.trim().length > 2 && _pass.text.isNotEmpty;

  // Guest mode check
  bool _isOffline = false;

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

    _bgC = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat(reverse: true);

    _email.addListener(_rebuild);
    _pass.addListener(_rebuild);

    // Initial check for offline status
    ConnectivityService.instance.checkNow().then((online) {
      if (mounted) setState(() => _isOffline = !online);
    });
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _email.removeListener(_rebuild);
    _pass.removeListener(_rebuild);
    _email.dispose();
    _pass.dispose();
    _c.dispose();
    _bgC.dispose();
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

  Future<void> _goNextAfterLogin() async {
    if (!mounted) return;
    // Let GoRouter redirect chain enforce: Auth → KeySetup → Lock → Dashboard
    context.go('/splash');
  }

  Future<void> _login() async {
    final email = _email.text.trim();
    final pass = _pass.text;

    if (!_canContinue) {
      _snack('Enter your email and password to continue.', isError: true);
      return;
    }

    try {
      setState(() => _loading = true);
      await _auth.loginWithEmail(email, pass);
      if (!mounted) return;
      setState(() => _loading = false);
      await _goNextAfterLogin();
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _snack(e.userMessage, isError: true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _snack('Login failed: ${e.toString()}', isError: true);
    }
  }

  Future<void> _googleLogin() async {
    try {
      setState(() => _googleLoading = true);
      final cred = await _auth.loginWithGoogle();
      if (!mounted) return;

      setState(() => _googleLoading = false);

      // If cred is null, user cancelled silently
      if (cred != null) {
        await _goNextAfterLogin();
      }
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _googleLoading = false);
      _snack(e.userMessage, isError: true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _googleLoading = false);
      _snack('Google sign-in failed: ${e.toString()}', isError: true);
    }
  }

  void _continueAsGuest() {
    if (!AppConfig.guestModeEnabled) return;
    _snack('Entered Guest Mode (Local Vault Only)');
    // Let GoRouter redirect chain handle navigation
    context.go('/splash');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const PremiumBackground(child: SizedBox.shrink()),

          // Content
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
                          padding: const EdgeInsets.fromLTRB(20, 26, 20, 24),
                          children: [
                            const SizedBox(height: 18),
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
                                              'Sign in',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 16,
                                                fontWeight: FontWeight.w800,
                                                letterSpacing: -0.2,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Use email & password or Google',
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
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      TextButton(
                                        onPressed: () => _snack(
                                          "Need help? (Check Support)",
                                        ),
                                        child: Text(
                                          "Need help?",
                                          style: TextStyle(
                                            color: const Color(
                                              0xFFEAF2FF,
                                            ).withValues(alpha: 0.55),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          if (_email.text.isEmpty) {
                                            _snack(
                                              'Enter email to reset password',
                                              isError: true,
                                            );
                                            return;
                                          }
                                          _auth
                                              .sendPasswordReset(_email.text)
                                              .then(
                                                (_) =>
                                                    _snack('Reset email sent!'),
                                              )
                                              .catchError(
                                                (e) => _snack(
                                                  'Failed: $e',
                                                  isError: true,
                                                ),
                                              );
                                        },
                                        child: const Text(
                                          "Forgot password?",
                                          style: TextStyle(
                                            color: Color(0xFF4DA3FF),
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  PrimaryButton(
                                    text:
                                        _loading ? 'Signing in...' : 'Continue',
                                    onPressed: (_loading || !_canContinue)
                                        ? null
                                        : _login,
                                    icon: Icons.arrow_forward_rounded,
                                  ),
                                  const SizedBox(height: 18),
                                  const _DividerLabel(),
                                  const SizedBox(height: 14),
                                  Opacity(
                                    opacity: _googleLoading ? 0.80 : 1,
                                    child: IgnorePointer(
                                      ignoring: _googleLoading,
                                      child: GradientButton(
                                        text: _googleLoading
                                            ? 'Connecting...'
                                            : 'Continue with Google',
                                        icon: Icons.g_mobiledata_rounded,
                                        onPressed: _googleLogin,
                                        gradient: const LinearGradient(
                                          colors: [
                                            Color(0xFF2B3040),
                                            Color(0xFF1A1F2C),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (_isOffline &&
                                      AppConfig.guestModeEnabled) ...[
                                    const SizedBox(height: 14),
                                    Center(
                                      child: TextButton(
                                        onPressed: _continueAsGuest,
                                        child: const Text(
                                          "Offline? Continue as Guest",
                                          style: TextStyle(
                                            color: Color(0xFF94A3B8),
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            decoration:
                                                TextDecoration.underline,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 14),
                                  Center(
                                    child: Text(
                                      'By continuing, you agree to our Terms & Privacy.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: const Color(
                                          0xFFEAF2FF,
                                        ).withValues(alpha: 0.35),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 18),
                            Center(
                              child: Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    "Don't have an account? ",
                                    style: TextStyle(
                                      color: const Color(
                                        0xFFEAF2FF,
                                      ).withValues(alpha: 0.60),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  InkWell(
                                    onTap: _loading
                                        ? null
                                        : () => context.go('/register'),
                                    child: const Text(
                                      "Create account",
                                      style: TextStyle(
                                        color: Color(0xFF4DA3FF),
                                        fontWeight: FontWeight.w800,
                                        fontSize: 14,
                                      ),
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
    return Column(
      children: [
        const SafeShellLogo(size: 74),
        const SizedBox(height: 16),
        const Text(
          "Welcome Back",
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 32,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          "Sign in to access your secure vault",
          textAlign: TextAlign.center,
          style: TextStyle(
            color: const Color(0xFFEAF2FF).withValues(alpha: 0.60),
            fontSize: 15,
            fontWeight: FontWeight.w600,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

class _DividerLabel extends StatelessWidget {
  const _DividerLabel();

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(height: 1, color: Colors.white.withValues(alpha: 0.10)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF0B0F14).withValues(alpha: 0.50),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
          ),
          child: Text(
            "Or continue with",
            style: TextStyle(
              color: const Color(0xFFEAF2FF).withValues(alpha: 0.50),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
