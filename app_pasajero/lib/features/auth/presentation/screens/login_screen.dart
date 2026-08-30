import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/widgets/entrance.dart';
import '../../../../core/widgets/ink_hero.dart';
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

  /// Envío del correo de restablecimiento: estado propio para no encender el
  /// spinner del botón principal (Entrar) por una acción distinta.
  final ValueNotifier<bool> _sendingReset = ValueNotifier<bool>(false);

  /// Evita que el listener de sesión (auto-login) compita con el flujo
  /// normal de inicio de sesión que ya navega por su cuenta.
  bool _loginFlowInProgress = false;
  AuthNotifier? _auth;
  VoidCallback? _sessionListener;

  /// F15: evita repetir el aviso de "no pudimos confirmar tu sesión" en
  /// cada rebuild — se muestra una sola vez, al llegar desde el splash.
  bool _timeoutNoticeHandled = false;

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
    _sendingReset.dispose();
    _obscurePassword.dispose();
    _obscureConfirm.dispose();
    super.dispose();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
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

  Future<void> _sendPasswordReset() async {
    if (_sendingReset.value) return;
    final email = _emailController.text.trim();
    if (email.isEmpty) return;
    _sendingReset.value = true;
    final auth = ref.read(authProvider);
    final error = await auth.sendPasswordReset(email);
    if (!mounted) return;
    _sendingReset.value = false;
    if (error != null) {
      _showError(error);
      return;
    }
    // A propósito condicional. Firebase, con la protección anti-enumeración
    // encendida, responde "listo" también cuando ese correo no tiene cuenta
    // con contraseña (nunca se registró, o entró con Google, que no tiene
    // contraseña que restablecer). Prometer "te lo enviamos" deja al usuario
    // esperando un correo que nunca se mandó; y cuando sí se manda, sale de
    // @firebaseapp.com y cae en spam más veces de las que uno quisiera.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Si $email tiene cuenta con contraseña, el enlace llega en unos '
          'minutos. Revisa spam y correo no deseado.',
        ),
        backgroundColor: AppColors.primaryDeep,
        duration: const Duration(seconds: 6),
      ),
    );
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
    // F15: si el splash llegó aquí porque no pudo confirmar la sesión a
    // tiempo (no porque de verdad no hubiera ninguna), se avisa una vez —
    // antes se veía idéntico a "no tienes sesión guardada".
    if (!_timeoutNoticeHandled) {
      _timeoutNoticeHandled = true;
      if (GoRouterState.of(context).uri.queryParameters['reason'] ==
          'timeout') {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _showError('No pudimos confirmar tu sesión: revisa tu conexión');
          }
        });
      }
    }
    return Scaffold(
      backgroundColor: AppColors.ink,
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
                    child: ScreenEntrance(
                      builder: (context, entra) => Column(
                        children: [
                          Expanded(
                            child: Center(
                              child: entra(
                                const InkHero(),
                                begin: const Offset(0, 0.05),
                              ),
                            ),
                          ),
                          entra(
                            Container(
                              width: double.infinity,
                              padding:
                                  const EdgeInsets.fromLTRB(28, 28, 28, 30),
                              // La hoja de entrada comparte superficie con las
                              // otras dos del producto —el selector de ruta y la
                              // de distancia—: arena, no blanco. Con el blanco
                              // puesto, las tres pantallas seguidas parecían de
                              // dos aplicaciones distintas.
                              decoration: const BoxDecoration(
                                color: AppColors.arena,
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
                                        color: AppColors.textPrimary,
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
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: 22),
                                    ValueListenableBuilder<TextEditingValue>(
                                      valueListenable: _emailController,
                                      builder: (context, emailValue, child) {
                                        // F17: solo se marca inválido en el paso
                                        // de email y con algo ya escrito — no al
                                        // llegar vacío a la pantalla.
                                        final showError = _step ==
                                                _Step.email &&
                                            emailValue.text.isNotEmpty &&
                                            !ref
                                                .read(authProvider)
                                                .isEmailValid(emailValue.text);
                                        return _Field(
                                          controller: _emailController,
                                          icon: Icons.alternate_email_rounded,
                                          hint: 'Email',
                                          keyboardType:
                                              TextInputType.emailAddress,
                                          textInputAction: TextInputAction.next,
                                          // Habilitado también en el paso de
                                          // perfil: quien toca "¿No tienes
                                          // cuenta? Regístrate" antes de escribir
                                          // su correo no debe quedar atrapado sin
                                          // poder ponerlo.
                                          enabled: _step == _Step.email ||
                                              _step == _Step.profile,
                                          errorText: showError
                                              ? 'Correo inválido'
                                              : null,
                                        );
                                      },
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
                                            textInputAction:
                                                TextInputAction.done,
                                            onToggleVisibility: () =>
                                                _obscurePassword.value =
                                                    !obscure,
                                          );
                                        },
                                      ),
                                      const SizedBox(height: 6),
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: ValueListenableBuilder<bool>(
                                          valueListenable: _sendingReset,
                                          builder: (context, sending, child) {
                                            return TextButton(
                                              onPressed: sending
                                                  ? null
                                                  : _sendPasswordReset,
                                              style: TextButton.styleFrom(
                                                padding: EdgeInsets.zero,
                                                minimumSize: const Size(0, 32),
                                                tapTargetSize:
                                                    MaterialTapTargetSize
                                                        .shrinkWrap,
                                              ),
                                              child: Text(
                                                sending
                                                    ? 'Enviando…'
                                                    : '¿Olvidaste tu contraseña?',
                                                style: const TextStyle(
                                                  color:
                                                      AppColors.textSecondary,
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            );
                                          },
                                        ),
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
                                            textInputAction:
                                                TextInputAction.next,
                                            onToggleVisibility: () =>
                                                _obscurePassword.value =
                                                    !obscure,
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
                                            textInputAction:
                                                TextInputAction.done,
                                            onToggleVisibility: () =>
                                                _obscureConfirm.value =
                                                    !obscure,
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
                                          builder:
                                              (context, isValidEmail, child) {
                                            final canPress = !submitting &&
                                                (_step == _Step.email
                                                    ? isValidEmail
                                                    : true);
                                            // Navy también mientras envía: con
                                            // spinner y sin aspecto de botón muerto.
                                            final bright =
                                                canPress || submitting;
                                            return SizedBox(
                                              width: double.infinity,
                                              height: 56,
                                              child: ElevatedButton(
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: bright
                                                      ? AppColors.primaryDeep
                                                      : AppColors.divider,
                                                  foregroundColor: bright
                                                      ? Colors.white
                                                      : AppColors.textDisabled,
                                                  disabledBackgroundColor:
                                                      bright
                                                          ? AppColors
                                                              .primaryDeep
                                                          : AppColors.divider,
                                                  disabledForegroundColor:
                                                      bright
                                                          ? Colors.white
                                                          : AppColors
                                                              .textDisabled,
                                                  elevation: 0,
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            999),
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
                                                                    _Step
                                                                        .password
                                                                ? 'Entrar'
                                                                : 'Crear cuenta',
                                                        style: TextStyle(
                                                          fontSize: 17,
                                                          fontWeight:
                                                              FontWeight.w800,
                                                          letterSpacing: -0.3,
                                                          color: bright
                                                              ? Colors.white
                                                              : AppColors
                                                                  .textDisabled,
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
                                          onPressed: _submitting.value
                                              ? null
                                              : _goBack,
                                          child: Text(
                                            _emailController.text.trim().isEmpty
                                                ? 'Regresar'
                                                : 'Cambiar de correo',
                                            style: const TextStyle(
                                              color: AppColors.textSecondary,
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
                                                : () => setState(() =>
                                                    _step = _Step.profile),
                                            child: const Text(
                                              '¿No tienes cuenta? '
                                              'Crea una con este correo',
                                              style: TextStyle(
                                                color:
                                                    AppColors.primaryAccessible,
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
                                                color: AppColors.textDisabled,
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
                                              onPressed: submitting
                                                  ? null
                                                  : _handleGoogle,
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor:
                                                    AppColors.textPrimary,
                                                backgroundColor: Colors.white,
                                                side: const BorderSide(
                                                    color: AppColors.divider),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          999),
                                                ),
                                              ),
                                              icon: submitting
                                                  ? const SizedBox(
                                                      width: 20,
                                                      height: 20,
                                                      child:
                                                          CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                        color: AppColors
                                                            .textPrimary,
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
                                              color:
                                                  AppColors.primaryAccessible,
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
                            start: 0.14,
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
  final String? errorText;

  const _Field({
    required this.controller,
    required this.icon,
    required this.hint,
    this.obscure = false,
    this.enabled = true,
    this.keyboardType,
    this.textInputAction = TextInputAction.done,
    this.onToggleVisibility,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      // El borde de reposo vive en `enabledBorder`, no aquí. Cuando el
      // Container lo pintaba, al enfocar quedaban dos anillos concéntricos
      // —el gris del Container y el azul de 2 px del campo— y el campo se
      // veía con doble contorno justo en el momento de escribir en él.
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        enabled: enabled,
        keyboardType: keyboardType,
        autocorrect: false,
        textInputAction: textInputAction,
        // Lo que uno escribe no va en negrita: w700 hacía que un correo
        // corriente pareciera un titular.
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary,
        ),
        decoration: InputDecoration(
          counterText: '',
          prefixIcon: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Icon(icon, color: AppColors.textSecondary, size: 22),
          ),
          hintText: hint,
          // Era `Colors.grey` al 60 %: sobre surfaceMuted daba ~1,5:1, o
          // sea ilegible. Y a 14 el texto saltaba de tamaño al empezar a
          // escribir; el marcador de posición mide lo que va a medir lo
          // que se escriba.
          hintStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: AppColors.textDisabled,
          ),
          suffixIcon: onToggleVisibility != null
              ? IconButton(
                  icon: Icon(
                    obscure
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: AppColors.textSecondary,
                    size: 22,
                  ),
                  // F3a: el ícono de ojo no tenía ninguna etiqueta accesible.
                  tooltip:
                      obscure ? 'Mostrar contraseña' : 'Ocultar contraseña',
                  onPressed: onToggleVisibility,
                )
              : null,
          border: InputBorder.none,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            borderSide: const BorderSide(color: AppColors.divider),
          ),
          // F16: mismo color de foco que el InputDecorationTheme global
          // (primaryDeep) — antes usaba primary, sin motivo para divergir.
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            borderSide:
                const BorderSide(color: AppColors.primaryDeep, width: 2),
          ),
          disabledBorder: InputBorder.none,
          errorText: errorText,
          errorStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.error,
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            borderSide: const BorderSide(color: AppColors.error, width: 1.5),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            borderSide: const BorderSide(color: AppColors.error, width: 2),
          ),
        ),
      ),
    );
  }
}
