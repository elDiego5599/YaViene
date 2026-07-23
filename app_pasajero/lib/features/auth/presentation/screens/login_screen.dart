import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/providers/auth_provider.dart';
import 'otp_verification_screen.dart';

class PremiumLoginScreen extends ConsumerStatefulWidget {
  const PremiumLoginScreen({super.key});

  @override
  ConsumerState<PremiumLoginScreen> createState() => _PremiumLoginScreenState();
}

class _PremiumLoginScreenState extends ConsumerState<PremiumLoginScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final ValueNotifier<bool> _isValidPhone = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();
    _phoneController.addListener(() {
      final text = _phoneController.text.replaceAll(RegExp(r'\D'), '');
      if (text.length == 10 && !_isValidPhone.value) {
        _isValidPhone.value = true;
        HapticFeedback.mediumImpact();
      } else if (text.length < 10 && _isValidPhone.value) {
        _isValidPhone.value = false;
      }
    });
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _isValidPhone.dispose();
    super.dispose();
  }

  void _handleLogin() {
    FocusScope.of(context).unfocus();
    HapticFeedback.heavyImpact();
    final phone = _phoneController.text.replaceAll(RegExp(r'\D'), '');
    final auth = ref.read(authProvider);
    void listener() {
      if (auth.state.status == AuthStatus.codeSent && mounted) {
        auth.removeListener(listener);
        context.replace('/otp', extra: phone);
      } else if (auth.state.status == AuthStatus.error && mounted) {
        auth.removeListener(listener);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(auth.state.errorMessage ?? 'Error al enviar código'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }

    auth.addListener(listener);
    auth.verifyPhone(phone);
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
                                  width: 108,
                                  height: 108,
                                ),
                              ),
                              const SizedBox(height: 24),
                              const Text(
                                'Ya Viene',
                                style: TextStyle(
                                  fontSize: 40,
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
                          padding: const EdgeInsets.fromLTRB(32, 40, 32, 48),
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
                                  'Ingresa tu número',
                                  style: TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0F172A),
                                    letterSpacing: -0.6,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'Te enviaremos un código para validar tu cuenta.',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                                const SizedBox(height: 32),
                                Container(
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: const Color(0xFFE2E8F0),
                                    ),
                                  ),
                                  child: TextField(
                                    controller: _phoneController,
                                    keyboardType: TextInputType.phone,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                    ],
                                    maxLength: 10,
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 2,
                                      color: Color(0xFF0F172A),
                                    ),
                                    decoration: InputDecoration(
                                      counterText: '',
                                      prefixIcon: const Padding(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 20,
                                        ),
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              '+57',
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.w800,
                                                color: Color(0xFF64748B),
                                                letterSpacing: -0.3,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      border: InputBorder.none,
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(20),
                                        borderSide: const BorderSide(
                                          color: Color(0xFF00A859),
                                          width: 2,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 32),
                                ValueListenableBuilder<bool>(
                                  valueListenable: _isValidPhone,
                                  builder: (context, isValid, child) {
                                    return SizedBox(
                                      width: double.infinity,
                                      height: 58,
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
                                          'Continuar',
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
                                if (!kReleaseMode) _DebugSkipButton(),
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

class _DebugSkipButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: SizedBox(
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
