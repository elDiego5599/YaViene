import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'ventana.dart';

/// Lo más chica que se deja la ventana. 1200 de ancho es lo más angosto que
/// se cuida (panel_angosto_test.dart): la lista es un cuarto de la ventana y
/// por debajo la placa se encogía hasta no leerse —a 1024, unos 8 px—. 700
/// de alto es lo que deja un portátil de 1366×768 con la barra de tareas de
/// Windows y el título de la ventana, así que la ventana cabe en cualquier
/// pantalla en que el panel se lee (estilo_panel_test.dart).
const ventanaMinima = Size(1200, 700);

/// El tablero en una pestaña del navegador, que nadie detiene bajo
/// [ventanaMinima] como hace `window_manager` en el escritorio.
///
/// Por debajo, el tablero se sigue armando a lo mínimo que cuida, recortado
/// arriba a la izquierda y sin recibir toques, teclas ni lector de
/// pantalla; encima va el velo de [mostrarVentana] con una [Ventana] que
/// pide agrandar. No se cambia el tablero por el aviso: el árbol es el
/// mismo de los dos lados del mínimo, así que el socket y lo elegido no se
/// rehacen cada vez que la pestaña lo cruza (ventana_minima_test.dart).
class VentanaMinima extends StatelessWidget {
  const VentanaMinima({super.key, required this.child, this.web = kIsWeb});

  final Widget child;

  /// En el escritorio la ventana ya no baja del mínimo: no hay aviso.
  final bool web;

  @override
  Widget build(BuildContext context) {
    if (!web) return child;
    return LayoutBuilder(
      builder: (context, espacio) {
        final ancho = espacio.maxWidth < ventanaMinima.width
            ? ventanaMinima.width
            : espacio.maxWidth;
        final alto = espacio.maxHeight < ventanaMinima.height
            ? ventanaMinima.height
            : espacio.maxHeight;
        final chica = ancho > espacio.maxWidth || alto > espacio.maxHeight;
        return Stack(
          children: [
            Positioned.fill(
              child: ExcludeFocus(
                excluding: chica,
                child: ExcludeSemantics(
                  excluding: chica,
                  child: AbsorbPointer(
                    absorbing: chica,
                    child: ClipRect(
                      child: OverflowBox(
                        alignment: Alignment.topLeft,
                        minWidth: ancho,
                        maxWidth: ancho,
                        minHeight: alto,
                        maxHeight: alto,
                        child: child,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (chica) ...[
              ModalBarrier(
                dismissible: false,
                color: AppColors.navyRaised.withValues(alpha: 0.62),
              ),
              const SafeArea(
                child: Ventana(
                  icono: Icons.open_in_full,
                  titulo: 'La ventana es muy pequeña',
                  mensaje:
                      'El tablero necesita al menos 1200 × 700 para que la '
                      'lista y el mapa quepan enteros. Agranda la ventana '
                      'del navegador o aleja el zoom.',
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
