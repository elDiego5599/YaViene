import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_theme.dart';
import '../providers/auth_providers.dart';

/// Abre un enlace fuera del panel (el navegador o la app que lo atienda).
/// Es un provider para que las pruebas vean qué se abrió sin abrir nada.
final abrirEnlaceProvider = Provider<Future<bool> Function(Uri)>(
  (ref) =>
      (uri) => launchUrl(uri, mode: LaunchMode.externalApplication),
);

/*
  La entrada del panel. Era una tarjeta angosta con el formulario solo sobre
  el fondo de tinta, y el dueño la vio barata. Ahora es una tarjeta partida,
  como la de las consolas de pago: a la izquierda, sobre tinta y con el filo
  curvo, el camino para quien no puede entrar; a la derecha, en blanco, el
  logo y el formulario. Sin emojis ni íconos de adorno: lo que da el tono
  es la tipografía, el aire y una sola curva.

  El panel no restablece contraseñas solo —las cuentas de flota las crea y
  las cuida el equipo—, así que «¿Olvidaste tu contraseña?» no lleva a un
  formulario: abre el WhatsApp del equipo, el mismo número que publica la
  web en empresas.html, con el mensaje ya escrito.

  test/login_screen_test.dart fija el camino al equipo, que no hay emojis y
  que nada desborda de 1600 a 640 de ancho con la letra del sistema al doble.
*/
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  static final contactoEquipo = Uri.https('wa.me', '/573004438626', {
    'text': 'Hola, olvidé la contraseña del panel de control de Ya Viene.',
  });

  /// El mismo número, para leerlo o dictarlo si WhatsApp no abre.
  static const telefonoEquipo = '+57 300 443 8626';

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  /// Por debajo de este ancho de tarjeta las dos mitades no caben lado a
  /// lado con aire (el formulario pide ~380 y el panel ~340), y el panel del
  /// equipo baja bajo el formulario.
  static const _anchoPartido = 760.0;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final ok = await ref
        .read(authProvider.notifier)
        .login(_usernameController.text.trim(), _passwordController.text);
    if (ok && mounted) context.go('/dashboard');
  }

  Future<void> _escribirAlEquipo() async {
    final messenger = ScaffoldMessenger.of(context);
    final abierto = await ref.read(abrirEnlaceProvider)(
      LoginScreen.contactoEquipo,
    );
    if (abierto) return;
    messenger.showSnackBar(
      const SnackBar(
        content: Text(
          'No se pudo abrir WhatsApp. Escríbenos al '
          '${LoginScreen.telefonoEquipo}.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final animar = !MediaQuery.disableAnimationsOf(context);
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 940),
            // La tarjeta entra subiendo 16 pt mientras aparece. Quien pidió
            // menos movimiento al sistema la ve ya puesta.
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: animar ? 0 : 1, end: 1),
              duration: const Duration(milliseconds: 560),
              curve: Curves.easeOutCubic,
              builder: (context, t, child) => Opacity(
                opacity: t,
                child: Transform.translate(
                  offset: Offset(0, 16 * (1 - t)),
                  child: child,
                ),
              ),
              child: _tarjeta(),
            ),
          ),
        ),
      ),
    );
  }

  /// Doble filo: una bandeja casi invisible con su línea fina y, dentro, la
  /// tarjeta con un radio 8 pt menor, para que las dos curvas corran
  /// paralelas. La sombra es ancha y tenue: la tarjeta flota sobre la arena
  /// sin la mancha oscura de una sombra corta.
  Widget _tarjeta() {
    const radio = 34.0;
    const bandeja = 8.0;
    return Container(
      padding: const EdgeInsets.all(bandeja),
      decoration: BoxDecoration(
        color: AppColors.navy.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(radio),
        border: Border.all(color: AppColors.navy.withValues(alpha: 0.06)),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withValues(alpha: 0.10),
            blurRadius: 64,
            offset: const Offset(0, 28),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radio - bandeja),
        child: ColoredBox(
          color: AppColors.surface,
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < _anchoPartido) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(36, 40, 36, 36),
                      child: _formulario(),
                    ),
                    _PanelEquipo(curva: 0, onEscribir: _escribirAlEquipo),
                  ],
                );
              }
              // Las dos mitades miden lo que la más alta; nunca menos de
              // 560, que es lo que la tarjeta pide para respirar.
              return IntrinsicHeight(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 560),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        flex: 11,
                        child: _PanelEquipo(
                          curva: 64,
                          onEscribir: _escribirAlEquipo,
                        ),
                      ),
                      Expanded(
                        flex: 13,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(40, 48, 56, 48),
                          child: Center(child: _formulario()),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _formulario() {
    final auth = ref.watch(authProvider);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            SvgPicture.asset(
              'assets/logo/ya_viene_logo.svg',
              width: 40,
              height: 40,
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'YA VIENE',
                    style: AppType.ui(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 3.2,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'CONTROL DE FLOTA',
                    style: AppType.ui(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 2.6,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 44),
        Text(
          'Iniciar sesión',
          style: AppType.ui(
            fontSize: 30,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.6,
            height: 1.1,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Ingresa con la cuenta de tu empresa.',
          style: AppType.ui(fontSize: 13.5, color: AppColors.textMuted),
        ),
        const SizedBox(height: 32),
        TextField(
          controller: _usernameController,
          style: AppType.ui(fontSize: 14, fontWeight: FontWeight.w500),
          decoration: _campo('Usuario', Icons.person_outline),
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          style: AppType.ui(fontSize: 14, fontWeight: FontWeight.w500),
          decoration: _campo('Contraseña', Icons.lock_outline).copyWith(
            suffixIcon: Padding(
              padding: const EdgeInsets.only(right: 6),
              child: IconButton(
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 19,
                  color: AppColors.textMuted,
                ),
                // Quien no ve la pantalla oye solo el tooltip: «Mostrar» a
                // secas no dice qué.
                tooltip: _obscurePassword
                    ? 'Mostrar contraseña'
                    : 'Ocultar contraseña',
              ),
            ),
          ),
          onSubmitted: (_) => _submit(),
        ),
        // El renglón del error guarda su alto aunque esté vacío, para que el
        // botón no salte al aparecer; con la letra grande crece lo que haga
        // falta.
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 34),
          child: auth.error == null
              ? null
              : Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    auth.error!,
                    textAlign: TextAlign.center,
                    style: AppType.ui(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.danger,
                    ),
                  ),
                ),
        ),
        SizedBox(
          height: 54,
          child: FilledButton(
            onPressed: auth.loading ? null : _submit,
            // Tinta, como el panel de al lado: la tarjeta se lee con dos
            // colores y el verde queda para lo que significa en el panel,
            // un bus transmitiendo.
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.navy,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AppColors.navy.withValues(alpha: 0.5),
              shape: const StadiumBorder(),
              textStyle: AppType.ui(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 2.6,
              ),
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
    );
  }

  /// Campo en cápsula, relleno en gris muy claro y sin borde hasta que se
  /// enfoca: así el formulario se ve como dos piezas y no como dos cajas.
  static InputDecoration _campo(String pista, IconData icono) {
    final capsula = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.pill),
      borderSide: BorderSide.none,
    );
    return InputDecoration(
      hintText: pista,
      filled: true,
      fillColor: AppColors.surfaceRaised,
      contentPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
      prefixIcon: Padding(
        padding: const EdgeInsets.only(left: 18, right: 10),
        child: Icon(icono, size: 19, color: AppColors.textMuted),
      ),
      prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
      border: capsula,
      enabledBorder: capsula,
      focusedBorder: capsula.copyWith(
        borderSide: const BorderSide(color: AppColors.navy, width: 1.4),
      ),
    );
  }
}

/// La mitad de tinta: para quien no puede entrar. [curva] es cuánto se mete
/// el filo derecho al bajar; 0 cuando el panel va debajo del formulario.
class _PanelEquipo extends StatelessWidget {
  const _PanelEquipo({required this.curva, required this.onEscribir});

  final double curva;
  final VoidCallback onEscribir;

  @override
  Widget build(BuildContext context) {
    final contenido = DecoratedBox(
      // El color va aparte del resplandor: en una misma BoxDecoration el
      // degradado tapa el color, y la tinta se volvería transparente.
      decoration: const BoxDecoration(color: AppColors.navy),
      child: DecoratedBox(
        decoration: BoxDecoration(
          // Un resplandor verde abajo a la izquierda, casi imperceptible: la
          // marca asoma sin pintar la tinta de verde.
          gradient: RadialGradient(
            center: const Alignment(-1, 1),
            radius: 1.2,
            colors: [
              AppColors.online.withValues(alpha: 0.22),
              AppColors.navy.withValues(alpha: 0),
            ],
          ),
        ),
        child: CustomPaint(
          painter: const _DotGridPainter(),
          child: Padding(
            // El filo curvo se come hasta [curva] pt a la derecha: el texto
            // se aparta eso más su margen.
            padding: EdgeInsets.fromLTRB(44, 48, 44 + curva, 48),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Text(
                    'SOPORTE',
                    style: AppType.ui(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2.4,
                      color: Colors.white.withValues(alpha: 0.82),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  '¿Olvidaste tu contraseña?',
                  style: AppType.ui(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                    height: 1.15,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Nuestro equipo restablece el acceso de tu empresa. '
                  'Escríbenos y lo resolvemos contigo.',
                  style: AppType.ui(
                    fontSize: 14,
                    height: 1.55,
                    color: Colors.white.withValues(alpha: 0.74),
                  ),
                ),
                const SizedBox(height: 30),
                _BotonEquipo(onPressed: onEscribir),
                const SizedBox(height: 16),
                Text(
                  'WhatsApp ${LoginScreen.telefonoEquipo}',
                  style: AppType.mono(
                    fontSize: 12,
                    letterSpacing: 0.4,
                    color: Colors.white.withValues(alpha: 0.62),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (curva == 0) return contenido;
    return ClipPath(clipper: _FiloCurvo(curva), child: contenido);
  }
}

/// Cápsula de contorno con la flecha en su propio círculo, pegada al borde
/// derecho. Al pasar el puntero la cápsula se aclara y la flecha se corre
/// en diagonal, hacia donde lleva.
class _BotonEquipo extends StatefulWidget {
  const _BotonEquipo({required this.onPressed});

  final VoidCallback onPressed;

  @override
  State<_BotonEquipo> createState() => _BotonEquipoState();
}

class _BotonEquipoState extends State<_BotonEquipo> {
  bool _encima = false;

  @override
  Widget build(BuildContext context) {
    const curva = Cubic(0.32, 0.72, 0, 1);
    const duracion = Duration(milliseconds: 380);
    return MouseRegion(
      onEnter: (_) => setState(() => _encima = true),
      onExit: (_) => setState(() => _encima = false),
      child: Material(
        color: Colors.transparent,
        shape: StadiumBorder(
          side: BorderSide(color: Colors.white.withValues(alpha: 0.5)),
        ),
        child: InkWell(
          onTap: widget.onPressed,
          customBorder: const StadiumBorder(),
          child: AnimatedContainer(
            duration: duracion,
            curve: curva,
            decoration: ShapeDecoration(
              shape: const StadiumBorder(),
              color: Colors.white.withValues(alpha: _encima ? 0.08 : 0),
            ),
            padding: const EdgeInsets.fromLTRB(22, 6, 6, 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    'Escribir al equipo',
                    style: AppType.ui(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.14),
                  ),
                  child: AnimatedSlide(
                    duration: duracion,
                    curve: curva,
                    offset: _encima ? const Offset(0.1, -0.1) : Offset.zero,
                    child: const Icon(
                      Icons.arrow_outward,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// El filo derecho del panel baja en S: arranca en la esquina de arriba y
/// termina [curva] pt adentro, como una página que se levanta.
class _FiloCurvo extends CustomClipper<Path> {
  const _FiloCurvo(this.curva);

  final double curva;

  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    return Path()
      ..moveTo(0, 0)
      ..lineTo(w, 0)
      ..cubicTo(w - curva * 1.5, h * 0.4, w, h * 0.62, w - curva, h)
      ..lineTo(0, h)
      ..close();
  }

  @override
  bool shouldReclip(_FiloCurvo oldClipper) => oldClipper.curva != curva;
}

class _DotGridPainter extends CustomPainter {
  const _DotGridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.06);
    const spacing = 28.0;
    for (double x = spacing / 2; x < size.width; x += spacing) {
      for (double y = spacing / 2; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1.0, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
