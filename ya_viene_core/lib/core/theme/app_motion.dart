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
}
