import 'package:flutter/material.dart';
import 'package:ya_viene_core/ya_viene_core.dart';

/// Lo que dice una píldora de estado del mapa.
///
/// Nació dentro de la píldora de ubicación; salió de ahí cuando el aviso de
/// conexión pasó a hablar con la misma voz (dueño, 2026-09-30). Antes ese
/// aviso era un punto que latía con una frase al lado, de otra familia que
/// todo lo que tenía encima.
class PildoraDatos {
  const PildoraDatos({
    required this.key,
    required this.icon,
    required this.iconColor,
    required this.text,
    required this.tint,
    this.sub,
    this.actionLabel,
    this.onAction,
    this.actionDanger = false,
    this.trabajando = false,
    this.vivo = false,
    this.dicho,
  });

  final String key;
  final IconData icon;
  final Color iconColor;
  final String text;

  /// Segunda línea, más pequeña y en gris: enseña, no informa.
  final String? sub;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// La acción solo deshace, no destruye: se pinta en gris en vez de verde.
  ///
  /// Estaba en rojo de error. Quitar el punto de espera no borra nada —se
  /// vuelve al GPS y se puede volver a poner tocando el mapa— y el rojo
  /// prometía una consecuencia que no existe; encima era la única alarma de
  /// la pantalla de inicio. Mismo criterio que la X que quita la ruta activa
  /// en la barra de búsqueda.
  final bool actionDanger;
  final Color tint;

  /// El medallón lleva los puntos de espera en vez del icono: algo está en
  /// marcha y no hay nada que tocar.
  final bool trabajando;

  /// Aparece sin que nadie lo pida y tiene que decirse solo.
  ///
  /// Sin región viva VoiceOver no dice nada hasta que alguien pasa el dedo
  /// por encima, que es justo lo que no va a ocurrir cuando el mapa se
  /// queda congelado.
  final bool vivo;

  /// El rótulo como se dice, cuando escrito no se lee bien: los tres puntos
  /// de «Reconectando…» son de espera, no de frase, y leídos en voz alta
  /// suenan a que falta algo.
  final String? dicho;

  /// La píldora entera, dicha en una frase.
  ///
  /// En pantalla son tres bloques —el rótulo, la pista en gris y el
  /// botón— y sueltos se leerían como tres cosas sin relación.
  String get dicha {
    final partes = <String>[
      dicho ?? text,
      if (sub != null) sub!,
      if (actionLabel != null && onAction != null) actionLabel!,
    ];
    return partes.join('. ');
  }
}

/// La píldora flotante de estado del mapa: medallón con icono, rótulo, pista
/// y, si hay algo que hacer, su acción.
class PildoraEstado extends StatelessWidget {
  const PildoraEstado({super.key, required this.data});

  final PildoraDatos data;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      // La píldora entera es el botón: el rótulo no se toca por un lado y
      // la acción por otro, el toque es el mismo en toda la superficie.
      button: data.onAction != null,
      liveRegion: data.vivo,
      label: data.dicha,
      // `excludeSemantics` tapa el árbol de abajo, y con él la acción del
      // InkWell; sin este toque la píldora se anunciaría como botón y el
      // doble toque de VoiceOver no haría nada.
      onTap: data.onAction,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          onTap: data.onAction,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 380),
            padding: const EdgeInsets.fromLTRB(8, 7, 14, 7),
            // Sombra corta y filo fino: una sombra larga sobre el mapa hace
            // que la píldora flote como una nube; una corta la deja apoyada,
            // que es lo que es.
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: Border.all(color: AppColors.hairline),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryDeep.withValues(alpha: 0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: data.tint,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  // El glifo de 18 va en la variante accesible de su
                  // color: sobre el tinte de su propio medallón, el color
                  // de relleno se queda en 2,7-2,8:1 y la norma pide 3:1
                  // hasta para un icono.
                  child: data.trabajando
                      ? IndicadorCarga(size: 20, color: data.iconColor)
                      : Icon(data.icon, size: 18, color: data.iconColor),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data.text,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                        softWrap: true,
                        style: AppTextStyles.cuerpoFuerte,
                      ),
                      if (data.sub != null)
                        Text(
                          data.sub!,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: AppTextStyles.pie,
                        ),
                    ],
                  ),
                ),
                if (data.actionLabel != null && data.onAction != null) ...[
                  const SizedBox(width: 10),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: data.actionDanger
                          ? AppColors.surfaceMuted
                          // F4: primaryAccessible da 4.5:1 con texto blanco;
                          // primary a secas se queda en ~3.1:1.
                          : AppColors.primaryAccessible,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      border: data.actionDanger
                          ? Border.all(color: AppColors.hairline)
                          : null,
                    ),
                    child: Text(
                      data.actionLabel!,
                      style: AppTextStyles.etiqueta.copyWith(
                        color: data.actionDanger
                            ? AppColors.textSecondary
                            : Colors.white,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
