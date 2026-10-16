import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import 'entrance.dart';
import 'fondo_malla.dart';

/// F12: logo + halo + wordmark + tagline, compartido por splash y
/// onboarding. Antes cada pantalla repetía el mismo bloque con constantes
/// ligeramente distintas (tamaños de fuente, espaciados) sin ningún motivo
/// para divergir entre sí.
class InkHero extends StatelessWidget {
  const InkHero({
    super.key,
    this.logoSize = 88,
    this.spacingAfterLogo = 18,
    this.trailing,
    this.heroTag = marcaHeroTag,
    this.entradaEscalonada,
  });

  /// Etiqueta del `Hero` del logo. Compartida por splash y bienvenida, que
  /// es lo que hace que el logo vuele de una a otra en vez de saltar.
  static const String marcaHeroTag = 'ya-viene-marca';

  /// Lo que se apaga la bajada frente al nombre: el de la letra chica sobre
  /// la malla del arranque, donde tiene que pasar AA.
  static const double alfaBajada = FondoMalla.alfaLetraChica;

  /// El dibujo sí se mide por pantalla, y no es capricho: en el arranque
  /// tiene que medir exactamente lo que mide en la pantalla nativa que
  /// releva (84, en el storyboard y en `launch_background.xml`). El nombre
  /// y la tagline no, porque la pantalla nativa no escribe nada: esos van
  /// en su rol y miden lo mismo en todas.
  final double logoSize;
  final double spacingAfterLogo;

  /// Contenido extra debajo de la tagline (p. ej. el spinner del splash).
  final Widget? trailing;

  /// En `null` el logo no vuela. Dos `Hero` con la misma etiqueta dentro de
  /// una misma pantalla revientan en tiempo de ejecución, así que quien
  /// necesite un segundo `InkHero` a la vez lo apaga aquí.
  final String? heroTag;

  /// Anima las piezas por separado y **deja el logo quieto**.
  ///
  /// Es para el splash, que es la pantalla que releva a la de arranque
  /// nativa. Esa ya dibuja el logo, en el mismo sitio y del mismo tamaño;
  /// si Flutter lo volviera a fundir desde cero, el relevo se vería como un
  /// parpadeo. Así el logo no se mueve y lo que entra es lo que la pantalla
  /// nativa no puede dibujar: el nombre, la tagline y el indicador.
  ///
  /// Quien no lo pase (la bienvenida) sigue envolviendo el bloque entero
  /// por fuera, como antes.
  final Entrada? entradaEscalonada;

  /// Solo vuela el logo, no el bloque entero: el texto tendría que volver a
  /// componerse en cada cuadro del vuelo para caber en un ancho que cambia,
  /// y eso se ve como un temblor. El logo es una imagen vectorial y escala
  /// limpio.
  Widget _logo() {
    final marca = Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          // El fondo ya trae su propio halo verde detrás de la marca; este
          // solo tiene que despegar el logo de él. Con spread 10 al 35 %
          // se sumaban en un disco verde con borde visible.
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.22),
            blurRadius: 46,
          ),
        ],
      ),
      // El nombre va escrito justo debajo: el logo dicho aparte solo
      // añade un «imagen» delante de «Ya Viene».
      child: ExcludeSemantics(
        child: SvgPicture.asset(
          'assets/icon/ya_viene_logo.svg',
          width: logoSize,
          height: logoSize,
        ),
      ),
    );
    final tag = heroTag;
    if (tag == null) return marca;
    return Hero(tag: tag, child: marca);
  }

  /// Aplica la entrada si la hay; si no, devuelve la pieza tal cual.
  Widget _quiza(Widget pieza, double start) {
    final entrada = entradaEscalonada;
    if (entrada == null) return pieza;
    return entrada(pieza, start: start, begin: const Offset(0, 0.06));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _logo(),
        SizedBox(height: spacingAfterLogo),
        _quiza(
          Text(
            'Ya Viene',
            style: AppTextStyles.marca.copyWith(color: Colors.white),
          ),
          0.10,
        ),
        const SizedBox(height: AppSpacing.xs),
        _quiza(
          Text(
            'Tu ciudad en tiempo real.',
            style: AppTextStyles.cuerpoFuerte.copyWith(
              color: Colors.white.withValues(alpha: alfaBajada),
            ),
          ),
          0.22,
        ),
        if (trailing != null) ...[
          const SizedBox(height: AppSpacing.xl),
          trailing!,
        ],
      ],
    );
  }
}
