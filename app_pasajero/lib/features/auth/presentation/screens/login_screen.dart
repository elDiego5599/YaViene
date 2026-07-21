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
  ConsumerState<PremiumLoginScreen> createState() =>
      _PremiumLoginScreenState();
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
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
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
                                    color: const Color(0xFF00A859).withValues(alpha: 0.3),
                                    blurRadius: 50,
                                    spreadRadius: 10,
                                  ),
                                ],
                              ),
                              child: SvgPicture.asset(
                                'assets/icon/ya_viene_logo.svg',
                                width: 100,
                                height: 100,
                              ),
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              'Ya Viene',
                              style: TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: -1,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Tu ciudad en tiempo real.',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white.withValues(alpha: 0.7),
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
                            topLeft: Radius.circular(40),
                            topRight: Radius.circular(40),
                          ),
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
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Te enviaremos un código para validar tu cuenta.',
                                style: TextStyle(
                                  fontSize: 15,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                              const SizedBox(height: 32),
                              Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(20),
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
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 2,
                                  ),
                                  decoration: InputDecoration(
                                    counterText: '',
                                    prefixIcon: const Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 20),
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            '+57',
                                            style: TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF94A3B8),
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
                                    height: 60,
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: isValid
                                            ? const Color(0xFF00A859)
                                            : const Color(0xFFE2E8F0),
                                        foregroundColor: isValid
                                            ? Colors.white
                                            : const Color(0xFF94A3B8),
                                        elevation: isValid ? 8 : 0,
                                        shadowColor: isValid
                                            ? const Color(0xFF00A859)
                                                .withValues(alpha: 0.5)
                                            : null,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(30),
                                        ),
                                      ),
                                      onPressed: isValid ? _handleLogin : null,
                                      child: const Text(
                                        'Continuar',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                              _DebugSkipButton(),
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
    );
  }
}

class _DebugSkipButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    bool isDebug = false;
    assert(() { isDebug = true; return true; }());
    if (!isDebug) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: SizedBox(
        width: double.infinity,
        child: TextButton(
          onPressed: () => context.replace('/map'),
          child: const Text(
            'Saltar inicio de sesión (debug)',
            style: TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}
