import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:ya_viene_core/ya_viene_core.dart';

/// La ventana que recibe al pasajero la primera vez que llega al mapa.
///
/// La primera versión era el `Dialogo` de siempre con una mano saludando y
/// dos frases: se leía como un aviso más y no como la entrada a la app
/// (dueño, 2026-10-02: «no se ve elegante ni sofisticado»). Esta es la hoja
/// arena de la entrada hecha ventana: el logo, una pregunta y dos salidas.
/// Pocas palabras y grandes, como la entrada.
///
/// Se probó con la noche de la entrada (`LiveRouteBackdrop`) en una franja
/// de arriba y no gustó: ese fondo está dibujado para la pantalla entera y,
/// recortado a 176, se veía como una imagen ampliada.
class VentanaBienvenida extends StatelessWidget {
  const VentanaBienvenida({
    super.key,
    required this.alVerGuia,
    required this.alIrALaApp,
  });

  final VoidCallback alVerGuia;
  final VoidCallback alIrALaApp;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        // Los márgenes y el ancho del `Dialogo`: en un teléfono de 360 la
        // ventana mide 312, lo mismo que cualquier otra ventana de la app.
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          // El marco de las demás ventanas (`Dialogo`): bandeja de 6 con
          // filo claro por fuera, radio `card`, y el núcleo con su
          // `hairline` y radio `lg` por dentro. Sin él, la bienvenida era la
          // única ventana de la app sin marco.
          child: Container(
            key: const ValueKey('bienvenida_ventana'),
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0x1AFFFFFF),
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: const Color(0x24FFFFFF)),
              boxShadow: AppShadows.floating,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              child: DecoratedBox(
                position: DecorationPosition.foreground,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: AppColors.hairline),
                ),
                child: SingleChildScrollView(child: _hoja()),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// El logo de la entrada a 72 y no a 88: allí tiene la pantalla entera y
  /// aquí una ventana de 312. Sin `Hero`: no vuela a ningún sitio. El halo
  /// verde es el de la entrada, más corto porque el fondo aquí es claro.
  Widget _logo() {
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.22),
            blurRadius: 36,
          ),
        ],
      ),
      child: ExcludeSemantics(
        child: SvgPicture.asset(
          'assets/icon/ya_viene_logo.svg',
          width: 72,
          height: 72,
        ),
      ),
    );
  }

  Widget _hoja() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 12),
      // La hoja de la entrada: blanco cálido que cae a arena en el primer
      // quinto.
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.arenaAlta, AppColors.arena],
          stops: [0.0, 0.20],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        // Los dos botones a todo el ancho de la hoja, como en la entrada.
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(child: _logo()),
          const SizedBox(height: 20),
          Semantics(
            header: true,
            child: Text(
              'Todo listo',
              style: AppTextStyles.display,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '¿Te mostramos cómo funciona?',
            style: AppTextStyles.cuerpoFuerte.copyWith(
              color: AppColors.textBody,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          // El botón de la entrada («Permitir ubicación»): 56 de alto,
          // píldora y verde lleno. Es la misma voz que acaba de hablar.
          SizedBox(
            height: 56,
            child: FilledButton(
              onPressed: alVerGuia,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                textStyle: AppTextStyles.boton,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
              child: const Text('Ver la guía'),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          TextButton(
            onPressed: alIrALaApp,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              textStyle: AppTextStyles.boton,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
            child: const Text('Ir a la app'),
          ),
        ],
      ),
    );
  }
}
