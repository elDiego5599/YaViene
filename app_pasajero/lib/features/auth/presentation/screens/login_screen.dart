import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/providers/auth_provider.dart';

class PremiumLoginScreen extends ConsumerStatefulWidget {
  const PremiumLoginScreen({super.key});

  @override
  ConsumerState<PremiumLoginScreen> createState() => _PremiumLoginScreenState();
}

class _PremiumLoginScreenState extends ConsumerState<PremiumLoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final ValueNotifier<bool> _isValid = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _obscurePassword = ValueNotifier<bool>(true);

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_validate);
    _passwordController.addListener(_validate);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _isValid.dispose();
    _obscurePassword.dispose();
    super.dispose();
  }

  void _validate() {
    final valid = ref.read(authProvider).isEmailValid(_emailController.text) &&
        _passwordController.text.length >= 6;
    if (valid != _isValid.value) {
      _isValid.value = valid;
      if (valid) HapticFeedback.mediumImpact();
    }
  }

  void _handleLogin() {
    FocusScope.of(context).unfocus();
    HapticFeedback.heavyImpact();
    final auth = ref.read(authProvider);
    void listener() {
      if (auth.state.status == AuthStatus.verified && mounted) {
        auth.removeListener(listener);
        context.replace('/map');
      } else if (auth.state.status == AuthStatus.error && mounted) {
        auth.removeListener(listener);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(auth.state.errorMessage ?? 'Error al iniciar sesión'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }

    auth.addListener(listener);
    auth.signInWithEmailAndPassword(
      _emailController.text,
      _passwordController.text,
    );
  }

  Future<void> _handleGoogle() async {
    FocusScope.of(context).unfocus();
    final auth = ref.read(authProvider);
    void listener() {
      if (auth.state.status == AuthStatus.verified && mounted) {
        auth.removeListener(listener);
        context.replace('/map');
      } else if (auth.state.status == AuthStatus.error && mounted) {
        auth.removeListener(listener);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(auth.state.errorMessage ?? 'Error al iniciar con Google'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }

    auth.addListener(listener);
    auth.signInWithGoogle();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF14274E),
      body: CustomPaint(
        painter: const _LoginMapPatternPainter(),
        child: SafeArea(
          bottom: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Column(
                      children: [
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF00A859)
                                          .withValues(alpha: 0.35),
                                      blurRadius: 50,
                                      spreadRadius: 10,
                                    ),
                                  ],
                                ),
                                child: SvgPicture.asset(
                                  'assets/icon/ya_viene_logo.svg',
                                  width: 96,
                                  height: 96,
                                ),
                              ),
                              const SizedBox(height: 20),
                              const Text(
                                'Ya Viene',
                                style: TextStyle(
                                  fontSize: 38,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: -1.2,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Tu ciudad en tiempo real.',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white.withValues(alpha: 0.75),
                                  letterSpacing: -0.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(28, 32, 28, 32),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(36),
                              topRight: Radius.circular(36),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Color(0x1A14274E),
                                blurRadius: 32,
                                offset: Offset(0, -10),
                              ),
                            ],
                          ),
                          child: SafeArea(
                            top: false,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Inicia sesión',
                                  style: TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0F172A),
                                    letterSpacing: -0.6,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'Con tu correo y una contraseña.',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                _EmailField(
                                  controller: _emailController,
                                ),
                                const SizedBox(height: 12),
                                ValueListenableBuilder<bool>(
                                  valueListenable: _obscurePassword,
                                  builder: (context, obscure, child) {
                                    return _PasswordField(
                                      controller: _passwordController,
                                      obscure: obscure,
                                      onToggleVisibility: () =>
                                          _obscurePassword.value = !obscure,
                                    );
                                  },
                                ),
                                const SizedBox(height: 24),
                                ValueListenableBuilder<bool>(
                                  valueListenable: _isValid,
                                  builder: (context, isValid, child) {
                                    return SizedBox(
                                      width: double.infinity,
                                      height: 56,
                                      child: ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: isValid
                                              ? const Color(0xFF14274E)
                                              : const Color(0xFFE2E8F0),
                                          foregroundColor: isValid
                                              ? Colors.white
                                              : const Color(0xFF94A3B8),
                                          disabledBackgroundColor:
                                              const Color(0xFFE2E8F0),
                                          disabledForegroundColor:
                                              const Color(0xFF94A3B8),
                                          elevation: 0,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(999),
                                          ),
                                        ),
                                        onPressed:
                                            isValid ? _handleLogin : null,
                                        child: Text(
                                          'Entrar',
                                          style: TextStyle(
                                            fontSize: 17,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: -0.3,
                                            color: isValid
                                                ? Colors.white
                                                : const Color(0xFF94A3B8),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(height: 16),
                                const Row(
                                  children: [
                                    Expanded(child: Divider()),
                                    Padding(
                                      padding:
                                          EdgeInsets.symmetric(horizontal: 12),
                                      child: Text(
                                        'o',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF94A3B8),
                                        ),
                                      ),
                                    ),
                                    Expanded(child: Divider()),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                SizedBox(
                                  width: double.infinity,
                                  height: 52,
                                  child: OutlinedButton.icon(
                                    onPressed: _handleGoogle,
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFF334155),
                                      backgroundColor: Colors.white,
                                      side: const BorderSide(
                                          color: Color(0xFFE2E8F0)),
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(999),
                                      ),
                                    ),
                                    icon: SvgPicture.asset(
                                      'assets/icon/google_logo.svg',
                                      width: 20,
                                      height: 20,
                                    ),
                                    label: const Text(
                                      'Iniciar con Google',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                                if (!kReleaseMode) ...[
                                  const SizedBox(height: 16),
                                  _DebugSkipButton(),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _EmailField extends StatelessWidget {
  final TextEditingController controller;

  const _EmailField({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.emailAddress,
        autocorrect: false,
        textInputAction: TextInputAction.next,
        style: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: Color(0xFF0F172A),
        ),
        decoration: InputDecoration(
          counterText: '',
          prefixIcon: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 18),
            child: Icon(
              Icons.alternate_email_rounded,
              color: Color(0xFF64748B),
              size: 22,
            ),
          ),
          hintText: 'correo@ejemplo.com',
          hintStyle: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: Colors.grey.withValues(alpha: 0.6),
          ),
          border: InputBorder.none,
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: Color(0xFF00A859), width: 2),
          ),
        ),
      ),
    );
  }
}

class _PasswordField extends StatelessWidget {
  final TextEditingController controller;
  final bool obscure;
  final VoidCallback onToggleVisibility;

  const _PasswordField({
    required this.controller,
    required this.obscure,
    required this.onToggleVisibility,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        textInputAction: TextInputAction.done,
        style: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: Color(0xFF0F172A),
        ),
        decoration: InputDecoration(
          counterText: '',
          prefixIcon: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 18),
            child: Icon(
              Icons.lock_outline_rounded,
              color: Color(0xFF64748B),
              size: 22,
            ),
          ),
          hintText: 'Contraseña (mín. 6 caracteres)',
          hintStyle: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: Colors.grey.withValues(alpha: 0.6),
          ),
          suffixIcon: IconButton(
            icon: Icon(
              obscure
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              color: const Color(0xFF64748B),
              size: 22,
            ),
            onPressed: onToggleVisibility,
          ),
          border: InputBorder.none,
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: Color(0xFF00A859), width: 2),
          ),
        ),
      ),
    );
  }
}

class _DebugSkipButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: TextButton(
        onPressed: () => context.replace('/map'),
        child: const Text(
          'Saltar inicio de sesión (Modo Pruebas)',
          style: TextStyle(
            color: Color(0xFF94A3B8),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _LoginMapPatternPainter extends CustomPainter {
  const _LoginMapPatternPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final dotPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..style = PaintingStyle.fill;
    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.045)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    for (double y = 28; y < size.height * 0.58; y += 34) {
      for (double x = 18; x < size.width; x += 34) {
        final offset = ((y / 34).round().isEven) ? 0.0 : 12.0;
        canvas.drawCircle(Offset(x + offset, y), 1.6, dotPaint);
      }
    }

    final routeA = Path()
      ..moveTo(-20, size.height * 0.18)
      ..cubicTo(
        size.width * 0.25,
        size.height * 0.10,
        size.width * 0.38,
        size.height * 0.32,
        size.width * 0.62,
        size.height * 0.24,
      )
      ..cubicTo(
        size.width * 0.80,
        size.height * 0.18,
        size.width * 0.88,
        size.height * 0.36,
        size.width + 20,
        size.height * 0.30,
      );
    canvas.drawPath(routeA, linePaint);

    final routeB = Path()
      ..moveTo(size.width * 0.12, -10)
      ..cubicTo(
        size.width * 0.06,
        size.height * 0.18,
        size.width * 0.28,
        size.height * 0.26,
        size.width * 0.22,
        size.height * 0.48,
      );
    canvas.drawPath(routeB, linePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
