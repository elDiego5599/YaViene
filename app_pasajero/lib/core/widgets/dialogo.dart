import 'package:flutter/material.dart';
import 'package:ya_viene_core/ya_viene_core.dart';

/// La ventana que la app usa cuando tiene que preguntar o contar algo.
///
/// Las dos que había eran el `AlertDialog` de fábrica: esquinas de Material,
/// título y botones de texto alineados a la derecha, un velo gris neutro.
/// Al lado de la guía, que es de donde se llega a una de ellas, se leía como
/// una ventana de otra app. Esta es la tarjeta de la guía puesta en el
/// centro: el mismo blanco con su filo y su sombra, el mismo radio, el mismo
/// cuadro verde de icono y el mismo botón verde; lo que cambia es que todo
/// va centrado, porque aquí no hay nada al lado que señalar.
class Dialogo extends StatelessWidget {
  const Dialogo({
    super.key,
    required this.icono,
    required this.titulo,
    required this.mensaje,
    required this.principal,
    this.secundaria,
    this.detalle,
    this.contenido,
    this.delicado = false,
  });

  final IconData icono;
  final String titulo;
  final String mensaje;

  /// Dato corto que va pegado al título, en verde y pequeño: la versión,
  /// en «Acerca de».
  final String? detalle;

  /// Lo que se elige dentro de la ventana, entre el mensaje y los botones:
  /// la rueda de la distancia del aviso.
  final Widget? contenido;

  /// Lo que pasa si se acepta. El botón lleno.
  final DialogoAccion principal;

  /// La salida sin cambios. Sin ella la ventana solo tiene un botón.
  final DialogoAccion? secundaria;

  /// Aceptar se lleva algo que no vuelve —la ruta elegida, por ejemplo—.
  /// El icono va en coral para que se lea antes de pulsar; el botón sigue
  /// siendo el verde de siempre, porque un botón rojo gritaría demasiado
  /// para algo que se recupera eligiendo la ruta otra vez.
  final bool delicado;

  @override
  Widget build(BuildContext context) {
    final tinta = delicado ? AppColors.coralAccessible : AppColors.primary;
    return Center(
      child: Padding(
        // 24 a los lados, como el resto de márgenes de pantalla: en un
        // teléfono de 360 deja una ventana de 312, del ancho de la tarjeta
        // de la guía en ese mismo teléfono.
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          // La silueta es la de la tarjeta de la guía (`map_tour_overlay.
          // dart`): las dos flotan sobre el mismo velo, con el radio `card`
          // por fuera, la sombra del sistema y el blanco con `hairline`. La
          // bandeja de 6 —un filo claro que separa la ventana del velo sin
          // sombra negra— es solo del diálogo: la guía no la lleva porque
          // se coloca al píxel y 12 de más la desplazaban.
          child: Container(
            key: const ValueKey('dialogo_ventana'),
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0x1AFFFFFF),
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: const Color(0x24FFFFFF)),
              boxShadow: AppShadows.floating,
            ),
            // El recorte que el `Material` de antes daba con
            // `Clip.antiAlias`: sin él, lo que se desplaza pinta sus esquinas
            // rectas por encima del radio del núcleo (R-15).
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: AppColors.hairline),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // El cuadro de icono de la guía (38, radio md, verde al
                      // 12 %) crecido a 48: allí va al lado del título y aquí
                      // va solo, encima, y a 38 se perdía en el blanco. El
                      // radio se queda en md y no crece con el cuadro: los
                      // radios salen de la escala, no se inventan.
                      ExcludeSemantics(
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: tinta.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                          child: Icon(icono, color: tinta, size: 26),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Semantics(
                        header: true,
                        child: Text(
                          titulo,
                          style: AppTextStyles.subtitulo,
                          textAlign: TextAlign.center,
                        ),
                      ),
                      if (detalle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          detalle!,
                          style: AppTextStyles.etiqueta.copyWith(
                            color: AppColors.primaryAccessible,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        mensaje,
                        style: AppTextStyles.cuerpo.copyWith(
                          color: AppColors.textBody,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (contenido != null) ...[
                        const SizedBox(height: AppSpacing.md),
                        contenido!,
                      ],
                      const SizedBox(height: 20),
                      // El botón principal de la guía, tal cual.
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: FilledButton(
                          onPressed: principal.alPulsar,
                          style: FilledButton.styleFrom(
                            textStyle: AppTextStyles.boton,
                            backgroundColor: AppColors.primaryAccessible,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppRadius.lg),
                            ),
                          ),
                          child: Text(principal.texto),
                        ),
                      ),
                      if (secundaria != null) ...[
                        const SizedBox(height: AppSpacing.xs),
                        SizedBox(
                          width: double.infinity,
                          child: TextButton(
                            onPressed: secundaria!.alPulsar,
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.textSecondary,
                              textStyle: AppTextStyles.boton,
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(AppRadius.lg),
                              ),
                            ),
                            child: Text(secundaria!.texto),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class DialogoAccion {
  const DialogoAccion(this.texto, this.alPulsar);

  final String texto;
  final VoidCallback alPulsar;
}

/// Abre un [Dialogo] sobre el velo de la guía.
///
/// El velo es el de la guía —el azul noche al 62 %— y no el negro al 54 de
/// Material: sobre el mapa claro el negro ensuciaba los colores; el azul
/// los apaga sin volverlos grises. La ventana entra creciendo desde el 94 %
/// mientras aparece y sale por el mismo camino con la curva de salida, que
/// arranca despacio y se va rápido: al salir ya no hay nada que leer.
Future<T?> mostrarDialogo<T>(
  BuildContext context,
  Widget Function(BuildContext dialogContext) builder,
) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Cerrar',
    barrierColor: AppColors.primaryDeep.withValues(alpha: 0.62),
    transitionDuration: AppMotion.duracion(context, AppMotion.normal),
    pageBuilder: (dialogContext, _, __) => SafeArea(
      child: builder(dialogContext),
    ),
    transitionBuilder: (context, animation, _, child) {
      final entrada = CurvedAnimation(
        parent: animation,
        curve: AppMotion.curvaEntrada,
        reverseCurve: AppMotion.curvaSalida,
      );
      return FadeTransition(
        opacity: entrada,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.94, end: 1).animate(entrada),
          child: child,
        ),
      );
    },
  );
}
