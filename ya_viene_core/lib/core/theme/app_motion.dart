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
  //
  // Los cuatro de en medio se alargaron un poco (eran 180, 220, 280 y 360)
  // al pasar a las curvas enfatizadas de más abajo: esas hacen casi todo el
  // recorrido en el primer tercio, y con los tiempos viejos la llegada se
  // comprimía tanto que el cambio se leía como un golpe. Con algo más de
  // cola se ve frenar. `instante` no se toca: es respuesta al dedo, y ahí
  // cualquier espera se nota como retraso.

  /// Respuesta al dedo: el color de un chip al pulsarlo, un botón que se
  /// hunde. Tiene que sentirse inmediato sin llegar a ser un corte.
  static const Duration instante = Duration(milliseconds: 120);

  /// Un elemento cambia por dentro sin moverse de sitio.
  static const Duration rapido = Duration(milliseconds: 200);

  /// El paso por defecto: lo que dura casi todo.
  static const Duration normal = Duration(milliseconds: 280);

  /// Algo cambia de tamaño o de sitio: una hoja que se abre, una tarjeta
  /// que crece.
  static const Duration pausado = Duration(milliseconds: 360);

  /// Recorre distancia de verdad: entradas, superposiciones, guías.
  static const Duration entrada = Duration(milliseconds: 440);

  // --- Y para lo que no es un solo elemento ---
  //
  // Los cinco escalones de arriba miden una cosa que se mueve. Fuera de
  // ellos quedaban cinco duraciones sueltas escritas a mano —700, 560, 450,
  // 320/55, 1800— que no son eso: son un grupo entero entrando, o un bucle
  // que no termina nunca. Nombrarlas aquí es lo que impide que vuelvan a
  // ser seis, y luego siete.

  /// Cuánto se retrasa cada elemento respecto al anterior en una entrada
  /// escalonada. Lo justo para leerse como un barrido y no como una lista
  /// que tarda: por debajo los elementos entran a la vez, por encima el
  /// último se hace esperar.
  static const Duration escalon = Duration(milliseconds: 55);

  /// El grupo entero, del primer elemento al último. Un menú lateral y una
  /// pantalla de entrada son el mismo gesto a distinta escala, así que
  /// entran al mismo paso.
  static const Duration grupo = Duration(milliseconds: 560);

  /// Un bucle que dice "trabajando": lo bastante vivo para leerse como
  /// actividad y no como decoración.
  static const Duration pulso = Duration(milliseconds: 1100);

  /// Un bucle que dice "vivo" sin pedir atención: el halo del bus en el
  /// mapa, el punto de la conexión. Va despacio a propósito —está siempre
  /// en pantalla, y lo que está siempre no puede tener prisa.
  static const Duration latido = Duration(milliseconds: 1800);

  /// Entra: arranca suelto y frena al llegar, que es como se mueve algo que
  /// pesa.
  ///
  /// Es la desaceleración enfatizada de Material 3, no `easeOutCubic`: esa
  /// frena de forma pareja y lo que llega parece clavarse en su sitio; esta
  /// recorre casi todo el camino de entrada y se toma la última parte con
  /// calma, que es donde el ojo mira.
  static const Curve curvaEntrada = Cubic(0.05, 0.7, 0.1, 1.0);

  /// Sale: espejo de [curvaEntrada], para que ida y vuelta no se sientan de
  /// dos aplicaciones distintas. La aceleración enfatizada de Material 3:
  /// se despega despacio y se va rápido, sin quedarse a medio camino.
  ///
  /// Puesta de `reverseCurve` o de `switchOutCurve` se recorre marcha
  /// atrás, y ahí hace lo contrario: lo que sale se aparta de golpe y se
  /// apaga despacio. Para un fundido que deja sitio a otra cosa es lo que
  /// conviene —lo viejo no estorba a lo nuevo—, así que se deja también
  /// en esos huecos.
  static const Curve curvaSalida = Cubic(0.3, 0.0, 0.8, 0.15);

  /// Algo que cambia de tamaño sin irse: la hoja de abajo que crece al
  /// tocar un bus, una tarjeta que gana una línea. Arranca y llega con
  /// suavidad, porque ni viene de fuera ni se va.
  static const Curve curvaCambio = Curves.easeInOutCubicEmphasized;

  /// Va y vuelve sin parar —pulsos, latidos, esqueletos de carga—: sin
  /// arranque ni frenada marcados, o se oye el bucle.
  static const Curve curvaCiclo = Curves.easeInOut;
}
