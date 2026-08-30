import 'package:flutter/widgets.dart';

/// Cómo se mueve la app.
///
/// Android e iOS tienen un ajuste de accesibilidad —«Quitar animaciones» en
/// Android, «Reducir movimiento» en iOS— que la gente activa por razones
/// serias: vértigo, mareo por movimiento, migraña vestibular. Flutter lo
/// deja llegar hasta `MediaQuery`, pero no lo obedece por su cuenta: si la
/// app no lo mira, no pasa nada. La app no lo miraba en ningún sitio.
///
/// Todo lo que se mueva debe pedir aquí su duración en vez de escribirla.
abstract final class AppMotion {
  /// El sistema pide menos movimiento.
  static bool reducido(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context);

  /// La duración que toca: la pedida, o cero si el sistema pide menos
  /// movimiento. Cero no rompe nada —`AnimatedFoo` y `AnimationController`
  /// aceptan `Duration.zero` y saltan directo al estado final—, así que un
  /// widget puede pasar por aquí sin más cambios.
  static Duration duracion(BuildContext context, Duration deseada) =>
      reducido(context) ? Duration.zero : deseada;

  /// Para transiciones de pantalla y entradas, donde el corte seco se lee
  /// como un fallo. Quien pide menos movimiento no está pidiendo menos
  /// suavidad: lo que marea es el desplazamiento, no el fundido. La pauta
  /// de accesibilidad (WCAG 2.3.3) va justo por ahí, y es lo que hace iOS:
  /// se quita el deslizamiento y se deja el fundido, que no tiene dirección.
  ///
  /// Devuelve cuánto del efecto de movimiento aplicar: 1 normal, 0 reducido.
  /// Un desplazamiento se multiplica por esto y desaparece solo.
  static double desplazamiento(BuildContext context) =>
      reducido(context) ? 0.0 : 1.0;

  // --- Vocabulario de tiempos ---
  //
  // Había veinte duraciones distintas repartidas por la app —120, 150, 180,
  // 200, 220, 240, 250, 260, 300…—, escritas a mano en cada sitio. Treinta
  // milisegundos de diferencia no se ven por separado; lo que sí se nota es
  // que dos cosas que empiezan juntas no acaben juntas. Cinco escalones, y
  // cada uno con un trabajo.

  /// Respuesta al dedo: el color de un chip al pulsarlo, un botón que se
  /// hunde. Tiene que sentirse inmediato sin llegar a ser un corte.
  static const Duration instante = Duration(milliseconds: 120);

  /// Un elemento cambia por dentro sin moverse de sitio.
  static const Duration rapido = Duration(milliseconds: 180);

  /// El paso por defecto: lo que dura casi todo.
  static const Duration normal = Duration(milliseconds: 220);

  /// Algo cambia de tamaño o de sitio: una hoja que se abre, una tarjeta
  /// que crece.
  static const Duration pausado = Duration(milliseconds: 280);

  /// Recorre distancia de verdad: entradas, superposiciones, guías.
  static const Duration entrada = Duration(milliseconds: 360);

  /// Entra: arranca suelto y frena al llegar, que es como se mueve algo que
  /// pesa.
  static const Curve curvaEntrada = Curves.easeOutCubic;

  /// Sale: espejo de [curvaEntrada], para que ida y vuelta no se sientan de
  /// dos aplicaciones distintas.
  static const Curve curvaSalida = Curves.easeInCubic;

  /// Va y vuelve sin parar —pulsos, latidos, esqueletos de carga—: sin
  /// arranque ni frenada marcados, o se oye el bucle.
  static const Curve curvaCiclo = Curves.easeInOut;
}
