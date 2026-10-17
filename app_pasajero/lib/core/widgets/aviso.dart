import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:ya_viene_core/ya_viene_core.dart';

/// El aviso corto de abajo: lo que la app dice sin preguntar nada —«ya
/// tienes 2 avisos activos», «el bus ya está cerca»—.
///
/// Antes era el `SnackBar` de fábrica con el tema encima: una barra tinta
/// que se leía como un mensaje del sistema, no de la app (dueño,
/// 2026-09-28). Ahora es una tarjeta de la familia del [Dialogo]: el mismo
/// blanco con su filo y su sombra, el mismo cuadro de icono, el mismo texto.
/// Del `SnackBar` se queda lo que funciona bien: la cola (un aviso espera a
/// que se vaya el anterior), la voz (se lee en cuanto aparece) y el gesto
/// de apartarlo con el dedo.
///
/// [accion] es el botón de texto de la derecha («Deshacer»): al pulsarlo
/// la tarjeta se va y la acción recibe un contexto que sigue vivo aunque la
/// pantalla que la armó ya se haya cerrado, para poder avisar otra cosa.
class AvisoTarjeta extends StatelessWidget {
  const AvisoTarjeta({
    super.key,
    required this.mensaje,
    required this.icono,
    this.accion,
  });

  final String mensaje;
  final IconData icono;
  final (String, void Function(BuildContext))? accion;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('aviso_tarjeta'),
      // 14 por dentro: el aire de las tarjetas del selector. Arriba y abajo
      // lo mismo, para que una línea sola quede centrada con el icono.
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.hairline),
        boxShadow: AppShadows.floating,
      ),
      child: Row(
        children: [
          // El cuadro de icono del Dialogo a su tamaño de la guía (38): aquí
          // va al lado del texto, como en la tarjeta de la guía, no encima.
          // Ámbar: es un «todavía no», no un error ni una confirmación; el
          // ámbar legible pasa 4.5:1 sobre su propio tinte al 12 %.
          ExcludeSemantics(
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.warningAccessible.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(icono, color: AppColors.warningAccessible, size: 22),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              mensaje,
              style: AppTextStyles.cuerpo.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ),
          if (accion case (final texto, final alPulsar))
            // Verde legible y con la letra de los botones del [Dialogo]: es
            // la acción que arregla, no un aviso más. 48 de alto para el dedo.
            TextButton(
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                alPulsar(context);
              },
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primaryAccessible,
                minimumSize: const Size(48, 48),
                textStyle: AppTextStyles.boton,
              ),
              child: Text(texto),
            ),
        ],
      ),
    );
  }
}

/// Cuánto se queda un aviso: lo que tarda en leerse, con suelo y techo.
///
/// 60 ms por letra es leer a unas 17 letras por segundo, el ritmo de una
/// lectura tranquila en el teléfono; los 2 s de base son lo que tarda el ojo
/// en ir hasta abajo. El suelo de 4 s es el del `SnackBar` de Material, y el
/// techo de 10 s evita que el aviso largo («esta ruta no pasa cerca…») se
/// quede tapando el botón. Con el lector de pantalla no se va solo: Material
/// ya lo retiene mientras la navegación accesible esté puesta.
Duration duracionDeAviso(String mensaje) => Duration(
      milliseconds: (2000 + mensaje.length * 60).clamp(4000, 10000),
    );

/// Muestra una [AvisoTarjeta] abajo, sobre el `ScaffoldMessenger` del
/// contexto. Quita el que hubiera: dos avisos seguidos del mismo botón
/// responden al último toque, no hacen cola.
void mostrarAviso(
  BuildContext context,
  String mensaje, {
  IconData icono = Icons.info_outline_rounded,
  (String, void Function(BuildContext))? accion,
}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        // Transparente y sin sombra propia: el `SnackBar` solo presta la
        // cola, la voz y el gesto; lo que se ve es la tarjeta.
        backgroundColor: Colors.transparent,
        elevation: 0,
        padding: EdgeInsets.zero,
        behavior: SnackBarBehavior.floating,
        // 16 a los lados y abajo: el margen de las píldoras del mapa. Y,
        // dentro de las pestañas, lo que la barra de abajo le suma al
        // relleno de la pantalla sobre la barra de inicio, que el
        // `SnackBar` no cuenta: si no, el aviso y su «Deshacer» salían bajo
        // la barra (dueño, 2026-10-16).
        margin: EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.md +
              math.max(
                  0,
                  MediaQuery.paddingOf(context).bottom -
                      MediaQuery.viewPaddingOf(context).bottom),
        ),
        duration: duracionDeAviso(mensaje),
        content: AvisoTarjeta(mensaje: mensaje, icono: icono, accion: accion),
      ),
    );
}
