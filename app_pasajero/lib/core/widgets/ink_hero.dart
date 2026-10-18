import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import 'fondo_malla.dart';

/// F12: logo + halo + wordmark + tagline de la bienvenida. El logo vuela
/// hasta aquí desde el arranque (`EscenaArranque`), con la misma etiqueta.
class InkHero extends StatelessWidget {
  const InkHero({super.key});

  /// Etiqueta del `Hero` del logo. Compartida por el arranque y la
  /// bienvenida, que es lo que hace que el logo vuele de uno a otra en vez
  /// de saltar.
  static const String marcaHeroTag = 'ya-viene-marca';

  /// Lo que se apaga la bajada frente al nombre: el de la letra chica sobre
  /// la malla de la bienvenida, donde tiene que pasar AA.
  static const double alfaBajada = FondoMalla.alfaLetraChica;

  static const double _lado = 88;

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
          width: _lado,
          height: _lado,
        ),
      ),
    );
    return Hero(tag: marcaHeroTag, child: marca);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _logo(),
        const SizedBox(height: 18),
        Text(
          'Ya Viene',
          style: AppTextStyles.marca.copyWith(color: Colors.white),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Tu ciudad en tiempo real.',
          style: AppTextStyles.cuerpoFuerte.copyWith(
            color: Colors.white.withValues(alpha: alfaBajada),
          ),
        ),
      ],
    );
  }
}
