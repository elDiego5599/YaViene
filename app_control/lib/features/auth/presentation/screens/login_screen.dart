import 'dart:math' as math;
import 'dart:ui' as ui;

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

  /// Con la letra del sistema por encima de 1,3× el texto del panel ya no
  /// cabe antes de la curva sin partirse palabra por palabra: la tarjeta se
  /// apila como en una ventana angosta.
  static const _escalaPartida = 1.3;

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
            constraints: const BoxConstraints(maxWidth: 1040),
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
              final partido =
                  constraints.maxWidth >= _anchoPartido &&
                  MediaQuery.textScalerOf(context).scale(1) <= _escalaPartida;
              if (!partido) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(36, 40, 36, 36),
                      child: _formulario(),
                    ),
                    CustomPaint(
                      key: const ValueKey('fondo-equipo'),
                      painter: const _FondoEquipoPintor(partido: false),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(36, 40, 36, 44),
                        child: _PanelEquipo(onEscribir: _escribirAlEquipo),
                      ),
                    ),
                  ],
                );
              }
              // El texto del panel no pasa del 40 % de la tarjeta: a la
              // altura del botón y del número, que es donde el filo ya se
              // metió, sigue quedando aire antes de la curva
              // (login_screen_test.dart lo mide en cada tamaño).
              final anchoTexto = math.min(
                constraints.maxWidth * 0.40 - 52,
                340.0,
              );
              // Las dos mitades miden lo que la más alta; nunca menos de
              // 600, que con 1040 de ancho es la proporción de la imagen de
              // referencia (≈ 0,6).
              return IntrinsicHeight(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 600),
                  child: CustomPaint(
                    key: const ValueKey('fondo-equipo'),
                    painter: const _FondoEquipoPintor(partido: true),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // 56 % para el lado del equipo: el filo arranca
                        // arriba en el 52 %, y el formulario empieza
                        // después, sin que la curva lo toque.
                        Expanded(
                          flex: 56,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(52, 56, 0, 56),
                            // Un poco por encima del centro: abajo el filo
                            // se mete más y el texto necesita el ancho de
                            // arriba.
                            child: Align(
                              alignment: const Alignment(-1, -0.15),
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth: anchoTexto,
                                ),
                                child: _PanelEquipo(
                                  onEscribir: _escribirAlEquipo,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 44,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(24, 48, 56, 48),
                            child: Center(child: _formulario()),
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
            // El azul con que arranca el degradado de al lado, no la tinta
            // #0B1628, que el dueño vio muy oscura: la tarjeta se lee en un
            // solo azul. El blanco encima queda en 12,7:1.
            style: FilledButton.styleFrom(
              backgroundColor: FondoEquipo.azul,
              foregroundColor: Colors.white,
              disabledBackgroundColor: FondoEquipo.azul.withValues(alpha: 0.5),
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
        borderSide: const BorderSide(color: FondoEquipo.azul, width: 1.4),
      ),
    );
  }
}

/// Lo que va sobre el degradado: para quien no puede entrar.
class _PanelEquipo extends StatelessWidget {
  const _PanelEquipo({required this.onEscribir});

  final VoidCallback onEscribir;

  @override
  Widget build(BuildContext context) {
    // Blanco casi entero y no a media opacidad: el degradado llega al
    // verde de la marca, y un gris claro encima ya no daría 4,5:1
    // (login_screen_test.dart mide cada texto contra su color de fondo).
    return Column(
      key: const ValueKey('panel-equipo'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
          ),
          child: Text(
            'SOPORTE',
            style: AppType.ui(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 2.4,
              color: Colors.white.withValues(alpha: 0.92),
            ),
          ),
        ),
        const SizedBox(height: 22),
        Text(
          '¿Olvidaste tu contraseña?',
          style: AppType.ui(
            fontSize: 30,
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
            color: Colors.white.withValues(alpha: 0.94),
          ),
        ),
        const SizedBox(height: 30),
        _BotonEquipo(onPressed: onEscribir),
        const SizedBox(height: 16),
        Text(
          'WhatsApp ${LoginScreen.telefonoEquipo}',
          style: AppType.mono(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.4,
            color: Colors.white.withValues(alpha: 0.94),
          ),
        ),
      ],
    );
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

/// El fondo del lado del equipo, con sus cuentas a la vista para que las
/// pruebas midan lo mismo que se pinta.
///
/// El color es el degradado del «404» de la web (`error-404.css`: #17325F
/// arriba, #00A859 abajo). El azul de arriba es también el de la parte alta
/// del menú lateral del pasajero (`live_route_backdrop.dart`): más claro y
/// más vivo que la tinta #0B1628 que llevaba el panel, que se veía apagada.
abstract final class FondoEquipo {
  static const azul = Color(0xFF17325F);
  static const verde = Color(0xFF00A859);

  /// El filo, como en la imagen de referencia del dueño: arriba corta la
  /// tarjeta en el 52 % de su ancho, baja casi vertical y abajo se abre
  /// hasta el 29 %. Es un arco que cae con la potencia 2,4 de la altura:
  /// medido sobre la referencia, a media altura va en el 49 % y a tres
  /// cuartos en el 42 %.
  static const filoArriba = 0.52;
  static const filoAbajo = 0.29;

  /// Dónde cae el filo, en puntos desde la izquierda, a la altura [y] de
  /// una tarjeta de tamaño [tarjeta].
  static double filo(Size tarjeta, double y) {
    final t = (y / tarjeta.height).clamp(0.0, 1.0);
    return tarjeta.width *
        (filoArriba - (filoArriba - filoAbajo) * math.pow(t, 2.4));
  }

  /// Los dos extremos del degradado. En el 404 corre de arriba abajo; aquí
  /// va en diagonal, de la esquina de arriba a la izquierda hacia el filo,
  /// para que el verde caiga junto a la curva y el texto, que va a la
  /// izquierda, se quede sobre el tramo azul donde el blanco se lee. El eje
  /// termina un 20 % por debajo de la tarjeta: con la letra a 1,3× el
  /// número de WhatsApp baja hasta el tramo verde y, con el eje justo en el
  /// borde, quedaba en 4,0:1 (login_screen_test.dart pide 4,5). Apilado, la
  /// franja es ancha y baja: el eje llega al doble de su alto y el verde
  /// solo asoma en la esquina, por la misma razón con el cuerpo del texto.
  static (Offset, Offset) eje(Size lienzo, {required bool partido}) => partido
      ? (Offset.zero, Offset(lienzo.width * filoArriba, lienzo.height * 1.2))
      : (Offset.zero, Offset(lienzo.width * 0.5, lienzo.height * 2));

  /// El color del degradado en el punto [p] del lienzo.
  static Color colorEn(Offset p, Size lienzo, {required bool partido}) {
    final (a, b) = eje(lienzo, partido: partido);
    final d = b - a;
    final q = p - a;
    final t = ((q.dx * d.dx + q.dy * d.dy) / d.distanceSquared).clamp(0.0, 1.0);
    return Color.lerp(azul, verde, t)!;
  }
}

class _FondoEquipoPintor extends CustomPainter {
  const _FondoEquipoPintor({required this.partido});

  final bool partido;

  @override
  void paint(Canvas canvas, Size size) {
    final forma = Path();
    if (partido) {
      // El arco se traza en tramos de 4 pt: a esa escala la curva no deja
      // ver ningún quiebre.
      forma.moveTo(0, 0);
      final tramos = math.max(24, size.height ~/ 4);
      for (var i = 0; i <= tramos; i++) {
        final y = size.height * i / tramos;
        forma.lineTo(FondoEquipo.filo(size, y), y);
      }
      forma
        ..lineTo(0, size.height)
        ..close();
    } else {
      forma.addRect(Offset.zero & size);
    }
    final (a, b) = FondoEquipo.eje(size, partido: partido);
    canvas.drawPath(
      forma,
      Paint()
        ..isAntiAlias = true
        ..shader = ui.Gradient.linear(a, b, const [
          FondoEquipo.azul,
          FondoEquipo.verde,
        ]),
    );
    // La trama de puntos, solo dentro del color.
    canvas.save();
    canvas.clipPath(forma);
    final punto = Paint()..color = Colors.white.withValues(alpha: 0.07);
    const paso = 28.0;
    for (double x = paso / 2; x < size.width; x += paso) {
      for (double y = paso / 2; y < size.height; y += paso) {
        canvas.drawCircle(Offset(x, y), 1.0, punto);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_FondoEquipoPintor oldDelegate) =>
      oldDelegate.partido != partido;
}
