import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:ya_viene_core/ya_viene_core.dart';

/// F12: logo + halo + wordmark + tagline, compartido por splash, login y
/// onboarding. Antes cada pantalla repetía el mismo bloque con constantes
/// ligeramente distintas (tamaños de fuente, espaciados) sin ningún motivo
/// para divergir entre sí.
class InkHero extends StatelessWidget {
  const InkHero({
    super.key,
    this.logoSize = 88,
    this.titleFontSize = 36,
    this.taglineFontSize = 16,
    this.spacingAfterLogo = 18,
    this.trailing,
    this.heroTag = marcaHeroTag,
  });

  /// Etiqueta del `Hero` del logo. Compartida por splash, login y bienvenida,
  /// que es lo que hace que el logo vuele entre las tres en vez de saltar.
  static const String marcaHeroTag = 'ya-viene-marca';

  final double logoSize;
  final double titleFontSize;
  final double taglineFontSize;
  final double spacingAfterLogo;

  /// Contenido extra debajo de la tagline (p. ej. el spinner del splash).
  final Widget? trailing;

  /// En `null` el logo no vuela. Dos `Hero` con la misma etiqueta dentro de
  /// una misma pantalla revientan en tiempo de ejecución, así que quien
  /// necesite un segundo `InkHero` a la vez lo apaga aquí.
  final String? heroTag;

  /// Solo vuela el logo, no el bloque entero: el texto tendría que volver a
  /// componerse en cada cuadro del vuelo para caber en un ancho que cambia,
  /// y eso se ve como un temblor. El logo es una imagen vectorial y escala
  /// limpio.
  Widget _logo() {
    final marca = Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.35),
            blurRadius: 50,
            spreadRadius: 10,
          ),
        ],
      ),
      child: SvgPicture.asset(
        'assets/icon/ya_viene_logo.svg',
        width: logoSize,
        height: logoSize,
      ),
    );
    final tag = heroTag;
    if (tag == null) return marca;
    return Hero(tag: tag, child: marca);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _logo(),
        SizedBox(height: spacingAfterLogo),
        Text(
          'Ya Viene',
          style: TextStyle(
            fontSize: titleFontSize,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: -1.2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Tu ciudad en tiempo real.',
          style: TextStyle(
            fontSize: taglineFontSize,
            fontWeight: FontWeight.w500,
            color: Colors.white.withValues(alpha: 0.75),
            letterSpacing: -0.3,
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(height: 28),
          trailing!,
        ],
      ],
    );
  }
}
