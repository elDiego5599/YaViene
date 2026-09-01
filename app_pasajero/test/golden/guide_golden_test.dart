import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_pasajero/features/map/presentation/widgets/'
    'map_tour_overlay.dart';

import 'golden_harness.dart';

/// La guía: el velo con el hueco iluminado y su tarjeta de texto.
///
/// El recorte (`saveLayer` + `BlendMode.clear` + desenfoque + degradado) es
/// de lo mejor que tiene la app y está en la lista de congelados. Estas
/// fotos existen para cazar el día en que alguien lo rompa sin querer.
void main() {
  Future<void> montar(
    WidgetTester tester, {
    required Rect objetivo,
    required String titulo,
    required String mensaje,
    required IconData icono,
    required int paso,
    String? etiquetaPrimaria,
    bool conAtras = false,
  }) async {
    await tester.pumpWidget(marcoGolden(
      Stack(
        children: [
          // Un fondo con algo debajo: si el velo fuera opaco, el hueco no
          // se distinguiría del resto en la foto.
          const Positioned.fill(child: ColoredBox(color: Color(0xFFE8E6E1))),
          Positioned.fromRect(
            rect: objetivo,
            child: const DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.all(Radius.circular(20)),
              ),
            ),
          ),
          MapGuideOverlay(
            target: objetivo,
            title: titulo,
            message: mensaje,
            icon: icono,
            stepIndex: paso,
            stepCount: 8,
            primaryLabel: etiquetaPrimaria,
            onPrimary: etiquetaPrimaria == null ? null : () {},
            onBack: conAtras ? () {} : null,
            onSkip: () {},
          ),
        ],
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  testWidgets('guía · hueco arriba, tarjeta debajo', (tester) async {
    fijarPantalla(tester);
    await montar(
      tester,
      objetivo: const Rect.fromLTWH(16, 60, 358, 60),
      titulo: 'Elige tu ruta',
      mensaje: 'Toca aquí para buscar la empresa y la ruta que esperas.',
      icono: Icons.search_rounded,
      paso: 2,
    );
    await coincideConOro(tester, 'guia_arriba');
  });

  testWidgets('guía · hueco abajo, tarjeta encima', (tester) async {
    fijarPantalla(tester);
    await montar(
      tester,
      objetivo: const Rect.fromLTWH(16, 620, 358, 160),
      titulo: 'Avísame cuando esté cerca',
      mensaje: 'Te llega una notificación cuando el bus esté a 1 km.',
      icono: Icons.notifications_active_rounded,
      paso: 6,
      etiquetaPrimaria: 'Entendido',
      conAtras: true,
    );
    await coincideConOro(tester, 'guia_abajo');
  });
}
