import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../providers/auth_providers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final ok = await ref.read(authProvider.notifier).login(
          _usernameController.text.trim(),
          _passwordController.text,
        );
    if (ok && mounted) context.go('/dashboard');
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    return Scaffold(
      backgroundColor: AppColors.navy,
      body: Stack(
        children: [
          const Positioned.fill(child: CustomPaint(painter: _DotGridPainter())),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: AppColors.sheet,
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    border: Border.all(color: AppColors.border),
                    boxShadow: AppColors.softShadow,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    children: [
                      Positioned(
                        top: -80,
                        left: 0,
                        right: 0,
                        height: 160,
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: RadialGradient(
                                colors: [
                                  AppColors.navy.withValues(alpha: 0.08),
                                  AppColors.navy.withValues(alpha: 0),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(
                            child: Container(
                              width: 64,
                              height: 64,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(AppRadius.lg),
                                border: Border.all(color: AppColors.border),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.navy.withValues(alpha: 0.08),
                                    blurRadius: 16,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: SvgPicture.asset(
                                'assets/logo/ya_viene_logo.svg',
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'YA VIENE',
                            textAlign: TextAlign.center,
                            style: AppType.ui(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 4,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            'CONTROL DE FLOTA',
                            textAlign: TextAlign.center,
                            style: AppType.ui(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 3,
                              color: AppColors.textMuted,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Container(
                            height: 1,
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.transparent,
                                  AppColors.borderStrong,
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 28),
                          Text(
                            'INICIAR SESIÓN',
                            textAlign: TextAlign.center,
                            style: AppType.ui(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Ingrese sus credenciales para continuar',
                            textAlign: TextAlign.center,
                            style: AppType.ui(
                              fontSize: 12.5,
                              color: AppColors.textMuted,
                            ),
                          ),
                          const SizedBox(height: 28),
                          TextField(
                            controller: _usernameController,
                            style: AppType.ui(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                            decoration: const InputDecoration(hintText: 'Usuario'),
                            textInputAction: TextInputAction.next,
                          ),
                          const SizedBox(height: 14),
                          Stack(
                            children: [
                              TextField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                style: AppType.ui(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                                decoration: const InputDecoration(hintText: 'Contraseña'),
                                onSubmitted: (_) => _submit(),
                              ),
                              Positioned(
                                right: 2,
                                top: 0,
                                bottom: 0,
                                child: IconButton(
                                  onPressed: () => setState(
                                    () => _obscurePassword = !_obscurePassword,
                                  ),
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                    size: 20,
                                    color: AppColors.textMuted,
                                  ),
                                  // Quien no ve la pantalla oye solo el
                                  // tooltip: «Mostrar» a secas no dice qué.
                                  tooltip: _obscurePassword
                                      ? 'Mostrar contraseña'
                                      : 'Ocultar contraseña',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            height: 26,
                            child: auth.error == null
                                ? null
                                : Center(
                                    child: Text(
                                      auth.error!,
                                      style: AppType.ui(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.danger,
                                      ),
                                    ),
                                  ),
                          ),
                          SizedBox(
                            height: 52,
                            child: FilledButton(
                              onPressed: auth.loading ? null : _submit,
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.online,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.pill),
                                ),
                                textStyle: AppType.ui(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 2.6,
                                ),
                                disabledBackgroundColor:
                                    AppColors.online.withValues(alpha: 0.5),
                              ),
                              child: auth.loading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text('INGRESAR'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DotGridPainter extends CustomPainter {
  const _DotGridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.06);
    const spacing = 36.0;
    for (double x = spacing / 2; x < size.width; x += spacing) {
      for (double y = spacing / 2; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1.1, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
