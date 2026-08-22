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
  });

  final double logoSize;
  final double titleFontSize;
  final double taglineFontSize;
  final double spacingAfterLogo;

  /// Contenido extra debajo de la tagline (p. ej. el spinner del splash).
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
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
        ),
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
