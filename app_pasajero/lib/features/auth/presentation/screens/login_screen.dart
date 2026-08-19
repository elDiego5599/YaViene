import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/widgets/map_pattern_painter.dart';
import '../../../onboarding/onboarding_flow.dart';

enum _Step { email, password, profile }

class PremiumLoginScreen extends ConsumerStatefulWidget {
  const PremiumLoginScreen({super.key});

  @override
  ConsumerState<PremiumLoginScreen> createState() => _PremiumLoginScreenState();
}

class _PremiumLoginScreenState extends ConsumerState<PremiumLoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final ValueNotifier<bool> _isValidEmail = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _obscurePassword = ValueNotifier<bool>(true);
  final ValueNotifier<bool> _obscureConfirm = ValueNotifier<bool>(true);

  _Step _step = _Step.email;

  /// Evita el doble toque en Continuar/Entrar/Crear cuenta mientras corre
  /// la petición (dos registros seguidos rompen el flujo). Es un
  /// ValueNotifier para que el botón muestre el spinner y se deshabilite en
  /// vivo, sin congelarse con aspecto de botón muerto en redes lentas.
  final ValueNotifier<bool> _submitting = ValueNotifier<bool>(false);

  /// Evita que el listener de sesión (auto-login) compita con el flujo
  /// normal de inicio de sesión que ya navega por su cuenta.
  bool _loginFlowInProgress = false;
  AuthNotifier? _auth;
  VoidCallback? _sessionListener;

  @override
  void initState() {
    super.initState();
    unawaited(_bootstrap());
    _emailController.addListener(() {
      final valid = ref.read(authProvider).isEmailValid(_emailController.text);
      if (valid != _isValidEmail.value) {
        _isValidEmail.value = valid;
        if (valid) HapticFeedback.mediumImpact();
      }
    });
  }

  Future<void> _bootstrap() async {
    // Seguridad por si la sesión se restaura tarde: si Firebase ya tiene
    // sesión guardada, se entra directo al mapa (lo normal es que el splash
    // ya haya decidido, pero no cuesta).
    final auth = ref.read(authProvider);
    _auth = auth;
    _sessionListener = () {
      if (auth.state.status == AuthStatus.verified &&
          !_loginFlowInProgress &&
          mounted) {
        unawaited(goToHome(context));
      }
    };
    auth.addListener(_sessionListener!);
    if (auth.state.status == AuthStatus.verified && mounted) {
      unawaited(goToHome(context));
    }
  }

  @override
  void dispose() {
    if (_sessionListener != null) {
      _auth?.removeListener(_sessionListener!);
    }
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _nameController.dispose();
    _isValidEmail.dispose();
    _submitting.dispose();
    _obscurePassword.dispose();
    _obscureConfirm.dispose();
    super.dispose();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(message), backgroundColor: const Color(0xFFDC2626)),
    );
  }

  Future<void> _continueWithEmail() async {
    if (_submitting.value) return;
    _submitting.value = true;
    FocusScope.of(context).unfocus();
    final auth = ref.read(authProvider);
    final exists = await auth.checkEmail(_emailController.text);
    if (!mounted) return;
    _submitting.value = false;
    if (exists == null) {
      _showError(auth.state.errorMessage ?? 'Error al consultar el correo');
      return;
    }
    if (exists) {
      setState(() => _step = _Step.password);
    } else {
      setState(() => _step = _Step.profile);
    }
  }

  Future<void> _finishAuth() async {
    if (_submitting.value) return;
    _submitting.value = true;
    FocusScope.of(context).unfocus();
    HapticFeedback.heavyImpact();
    final auth = ref.read(authProvider);

    if (_step == _Step.profile) {
      if (_nameController.text.trim().length < 2) {
        _submitting.value = false;
        _showError('Escribe tu nombre');
        return;
      }
      if (_passwordController.text.length < 6) {
        _submitting.value = false;
        _showError('La contraseña debe tener al menos 6 caracteres');
        return;
      }
      if (_passwordController.text != _confirmController.text) {
        _submitting.value = false;
        _showError('Las contraseñas no coinciden');
        return;
      }
    }

    // El flag se activa solo cuando de verdad se va a autenticar: las
    // validaciones locales que regresan antes no deben silenciar el
    // auto-login (bug: _loginFlowInProgress quedaba true para siempre).
    _loginFlowInProgress = true;

    final success = _step == _Step.profile
        ? await auth.register(
            email: _emailController.text,
            name: _nameController.text,
            password: _passwordController.text,
          )
        : await auth.login(
            email: _emailController.text,
            password: _passwordController.text,
          );

    if (!mounted) return;
    _submitting.value = false;
    if (success) {
      _loginFlowInProgress = false;
      await goToHome(context);
      return;
    }
    _loginFlowInProgress = false;
    // El correo ya tenía cuenta (detección engañada): mejor que entrar a
    // registrar otra vez, se pasa al paso de contraseña.
    if (_step == _Step.profile &&
        auth.state.errorCode == 'email-already-in-use') {
      setState(() => _step = _Step.password);
      _passwordController.clear();
      _confirmController.clear();
      _showError('Ese correo ya tiene cuenta: entra con tu contraseña');
      return;
    }
    _showError(auth.state.errorMessage ?? 'No se pudo iniciar sesión');
  }

  Future<void> _handleGoogle() async {
    if (_submitting.value) return;
    _submitting.value = true;
    FocusScope.of(context).unfocus();
    _loginFlowInProgress = true;
    final auth = ref.read(authProvider);
    void listener() {
      if (!mounted) {
        auth.removeListener(listener);
        return;
      }
      if (auth.state.status == AuthStatus.verified) {
        auth.removeListener(listener);
        _submitting.value = false;
        _loginFlowInProgress = false;
        unawaited(goToHome(context));
      } else if (auth.state.status == AuthStatus.error) {
        auth.removeListener(listener);
        _submitting.value = false;
        _loginFlowInProgress = false;
        _showError(auth.state.errorMessage ?? 'Error al iniciar con Google');
      } else if (auth.state.status == AuthStatus.unauthenticated) {
        // El usuario canceló el selector de cuentas: no es un error, pero el
        // listener debe quitarse o bloquearía el auto-login para siempre.
        auth.removeListener(listener);
        _submitting.value = false;
        _loginFlowInProgress = false;
      }
    }

    auth.addListener(listener);
    auth.signInWithGoogle();
  }

  void _goBack() {
    setState(() => _step = _Step.email);
    _passwordController.clear();
    _confirmController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF14274E),
      body: CustomPaint(
        painter: const MapPatternPainter(),
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
                                  width: 88,
                                  height: 88,
                                ),
                              ),
                              const SizedBox(height: 18),
                              const Text(
                                'Ya Viene',
                                style: TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: -1.2,
                                ),
                              ),
                              const SizedBox(height: 4),
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
                          padding: const EdgeInsets.fromLTRB(28, 28, 28, 30),
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
                                  'Inicia sesión o regístrate',
                                  style: TextStyle(
                                    fontSize: 23,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0F172A),
                                    letterSpacing: -0.6,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _step == _Step.email
                                      ? 'Con tu correo y una contraseña.'
                                      : _step == _Step.password
                                          ? 'Ese correo ya tiene cuenta: pon tu contraseña.'
                                          : 'El correo es nuevo: crea tu perfil.',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                                const SizedBox(height: 22),
                                _Field(
                                  controller: _emailController,
                                  icon: Icons.alternate_email_rounded,
                                  hint: 'Email',
                                  keyboardType: TextInputType.emailAddress,
                                  textInputAction: TextInputAction.next,
                                  // Habilitado también en el paso de perfil:
                                  // quien toca "¿No tienes cuenta? Regístrate"
                                  // antes de escribir su correo no debe quedar
                                  // atrapado sin poder ponerlo.
                                  enabled: _step == _Step.email ||
                                      _step == _Step.profile,
                                ),
                                if (_step == _Step.password) ...[
                                  const SizedBox(height: 12),
                                  ValueListenableBuilder<bool>(
                                    valueListenable: _obscurePassword,
                                    builder: (context, obscure, child) {
                                      return _Field(
                                        controller: _passwordController,
                                        icon: Icons.lock_outline_rounded,
                                        hint: 'Contraseña',
                                        obscure: obscure,
                                        textInputAction: TextInputAction.done,
                                        onToggleVisibility: () =>
                                            _obscurePassword.value = !obscure,
                                      );
                                    },
                                  ),
                                ],
                                if (_step == _Step.profile) ...[
                                  const SizedBox(height: 12),
                                  _Field(
                                    controller: _nameController,
                                    icon: Icons.person_outline_rounded,
                                    hint: 'Nombre',
                                    textInputAction: TextInputAction.next,
                                  ),
                                  const SizedBox(height: 12),
                                  ValueListenableBuilder<bool>(
                                    valueListenable: _obscurePassword,
                                    builder: (context, obscure, child) {
                                      return _Field(
                                        controller: _passwordController,
                                        icon: Icons.lock_outline_rounded,
                                        hint: 'Contraseña (mín. 6)',
                                        obscure: obscure,
                                        textInputAction: TextInputAction.next,
                                        onToggleVisibility: () =>
                                            _obscurePassword.value = !obscure,
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  ValueListenableBuilder<bool>(
                                    valueListenable: _obscureConfirm,
                                    builder: (context, obscure, child) {
                                      return _Field(
                                        controller: _confirmController,
                                        icon: Icons.lock_rounded,
                                        hint: 'Repite la contraseña',
                                        obscure: obscure,
                                        textInputAction: TextInputAction.done,
                                        onToggleVisibility: () =>
                                            _obscureConfirm.value = !obscure,
                                      );
                                    },
                                  ),
                                ],
                                const SizedBox(height: 24),
                                ValueListenableBuilder<bool>(
                                  valueListenable: _submitting,
                                  builder: (context, submitting, child) {
                                    return ValueListenableBuilder<bool>(
                                      valueListenable: _isValidEmail,
                                      builder: (context, isValidEmail, child) {
                                        final canPress = !submitting &&
                                            (_step == _Step.email
                                                ? isValidEmail
                                                : true);
                                        // Navy también mientras envía: con
                                        // spinner y sin aspecto de botón muerto.
                                        final bright = canPress || submitting;
                                        return SizedBox(
                                          width: double.infinity,
                                          height: 56,
                                          child: ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: bright
                                                  ? const Color(0xFF14274E)
                                                  : const Color(0xFFE2E8F0),
                                              foregroundColor: bright
                                                  ? Colors.white
                                                  : const Color(0xFF94A3B8),
                                              disabledBackgroundColor: bright
                                                  ? const Color(0xFF14274E)
                                                  : const Color(0xFFE2E8F0),
                                              disabledForegroundColor: bright
                                                  ? Colors.white
                                                  : const Color(0xFF94A3B8),
                                              elevation: 0,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(999),
                                              ),
                                            ),
                                            onPressed: canPress
                                                ? _step == _Step.email
                                                    ? _continueWithEmail
                                                    : _finishAuth
                                                : null,
                                            child: submitting
                                                ? const SizedBox(
                                                    width: 22,
                                                    height: 22,
                                                    child:
                                                        CircularProgressIndicator(
                                                      strokeWidth: 2.5,
                                                      color: Colors.white,
                                                    ),
                                                  )
                                                : Text(
                                                    _step == _Step.email
                                                        ? 'Continuar'
                                                        : _step ==
                                                                _Step.password
                                                            ? 'Entrar'
                                                            : 'Crear cuenta',
                                                    style: TextStyle(
                                                      fontSize: 17,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      letterSpacing: -0.3,
                                                      color: bright
                                                          ? Colors.white
                                                          : const Color(
                                                              0xFF94A3B8),
                                                    ),
                                                  ),
                                          ),
                                        );
                                      },
                                    );
                                  },
                                ),
                                if (_step != _Step.email) ...[
                                  const SizedBox(height: 8),
                                  Center(
                                    child: TextButton(
                                      onPressed:
                                          _submitting.value ? null : _goBack,
                                      child: Text(
                                        _emailController.text.trim().isEmpty
                                            ? 'Regresar'
                                            : 'Cambiar de correo',
                                        style: const TextStyle(
                                          color: Color(0xFF64748B),
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (_step == _Step.password) ...[
                                    const SizedBox(height: 4),
                                    Center(
                                      child: TextButton(
                                        onPressed: _submitting.value
                                            ? null
                                            : () => setState(
                                                () => _step = _Step.profile),
                                        child: const Text(
                                          '¿No tienes cuenta? Crea una con este correo',
                                          style: TextStyle(
                                            color: Color(0xFF00A859),
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                                if (_step == _Step.email) ...[
                                  const SizedBox(height: 16),
                                  const Row(
                                    children: [
                                      Expanded(child: Divider()),
                                      Padding(
                                        padding: EdgeInsets.symmetric(
                                            horizontal: 12),
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
                                  ValueListenableBuilder<bool>(
                                    valueListenable: _submitting,
                                    builder: (context, submitting, child) {
                                      return SizedBox(
                                        width: double.infinity,
                                        height: 52,
                                        child: OutlinedButton.icon(
                                          onPressed:
                                              submitting ? null : _handleGoogle,
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor:
                                                const Color(0xFF334155),
                                            backgroundColor: Colors.white,
                                            side: const BorderSide(
                                                color: Color(0xFFE2E8F0)),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(999),
                                            ),
                                          ),
                                          icon: submitting
                                              ? const SizedBox(
                                                  width: 20,
                                                  height: 20,
                                                  child:
                                                      CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    color: Color(0xFF334155),
                                                  ),
                                                )
                                              : SvgPicture.asset(
                                                  'assets/icon/google_logo.svg',
                                                  width: 20,
                                                  height: 20,
                                                ),
                                          label: Text(
                                            submitting
                                                ? 'Iniciando…'
                                                : 'Iniciar con Google',
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  Center(
                                    child: TextButton(
                                      onPressed: _submitting.value
                                          ? null
                                          : () => setState(
                                              () => _step = _Step.profile),
                                      child: const Text(
                                        '¿No tienes cuenta? Regístrate',
                                        style: TextStyle(
                                          color: Color(0xFF00A859),
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
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

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final IconData icon;
  final String hint;
  final bool obscure;
  final bool enabled;
  final TextInputType? keyboardType;
  final TextInputAction textInputAction;
  final VoidCallback? onToggleVisibility;

  const _Field({
    required this.controller,
    required this.icon,
    required this.hint,
    this.obscure = false,
    this.enabled = true,
    this.keyboardType,
    this.textInputAction = TextInputAction.done,
    this.onToggleVisibility,
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
        enabled: enabled,
        keyboardType: keyboardType,
        autocorrect: false,
        textInputAction: textInputAction,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: Color(0xFF0F172A),
        ),
        decoration: InputDecoration(
          counterText: '',
          prefixIcon: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Icon(icon, color: const Color(0xFF64748B), size: 22),
          ),
          hintText: hint,
          hintStyle: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey.withValues(alpha: 0.6),
          ),
          suffixIcon: onToggleVisibility != null
              ? IconButton(
                  icon: Icon(
                    obscure
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: const Color(0xFF64748B),
                    size: 22,
                  ),
                  onPressed: onToggleVisibility,
                )
              : null,
          border: InputBorder.none,
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: Color(0xFF00A859), width: 2),
          ),
          disabledBorder: InputBorder.none,
        ),
      ),
    );
  }
}
