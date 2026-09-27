// Placeholders del mapa: lo que se ve mientras carga el estilo.
// Extraído de map_widget.dart para que el arranque sea más legible.
import 'package:flutter/material.dart';
import 'package:ya_viene_core/ya_viene_core.dart';

class MapStylePlaceholder extends StatelessWidget {
  const MapStylePlaceholder({
    super.key,
    required this.layersReady,
    required this.placeholderShown,
    required this.onFadeEnd,
  });

  final bool layersReady;
  final bool placeholderShown;
  final VoidCallback onFadeEnd;

  @override
  Widget build(BuildContext context) {
    final visible = !layersReady && placeholderShown;
    return AnimatedOpacity(
      opacity: visible ? 1 : 0,
      // El velo se va con el paso de una entrada, no con el suyo propio: es
      // lo último que el usuario ve antes del mapa y no tiene por qué durar
      // más que cualquier otra cosa que aparece.
      duration: AppMotion.duracion(context, AppMotion.entrada),
      curve: AppMotion.curvaSalida,
      onEnd: () {
        if (!visible && placeholderShown) onFadeEnd();
      },
      child: placeholderShown
          ? Semantics(
              // El gesto de aquí abajo solo existe para tragarse los
              // toques mientras el mapa carga: sin rótulo es un nodo del
              // tamaño de la pantalla que se anuncia tocable y no hace
              // nada. Lo que hay que decir es que se está esperando.
              label: 'Preparando tu mapa',
              liveRegion: true,
              excludeSemantics: true,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {},
                child: ColoredBox(
                  color: AppColors.background,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.directions_bus_outlined,
                          size: 44,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Preparando tu mapa…',
                          style: AppTextStyles.cuerpoFuerte.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}

class MapStyleFailedBanner extends StatelessWidget {
  const MapStyleFailedBanner({
    super.key,
    required this.styleFailed,
    required this.onRetry,
  });

  final bool styleFailed;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (!styleFailed) return const SizedBox.shrink();
    return Positioned(
      top: 16,
      left: 16,
      right: 16,
      child: Semantics(
        // El aviso aparece sin que nadie lo pida y tapa el mapa entero
        // con su noticia: si no se anuncia al aparecer, no se anuncia.
        liveRegion: true,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            boxShadow: AppShadows.floating,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: 12),
            child: Row(
              children: [
                // La nube tachada es la frase dibujada: dicha aparte no
                // añade nada a «No se pudo cargar el mapa».
                const ExcludeSemantics(
                  child: Icon(Icons.cloud_off_outlined, color: AppColors.coral),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'No se pudo cargar el mapa',
                    style: AppTextStyles.cuerpoFuerte,
                  ),
                ),
                TextButton(
                  onPressed: onRetry,
                  // El peso venía suelto en el `Text` y el tamaño lo ponía
                  // Material por detrás. Es el mismo rol al que Material caía
                  // —`boton`—, escrito ahora donde se lee; bajarlo a la medida
                  // del aviso lo dejaba con el peso exacto de la frase y ya no
                  // parecía que se pudiera tocar.
                  style: TextButton.styleFrom(
                    textStyle: AppTextStyles.boton,
                  ),
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
