// La pantalla del mapa no se reconstruye entera con cada foto de posiciones
// ni con cada lectura del GPS (auditoría 2026-09, H5).
//
// `MapScreen.build` miraba las posiciones de la ruta y la ubicación enteras
// para armar la etiqueta y las acciones del mapa para el lector de
// pantalla. Las fotos llegan hasta cada 200 ms y el GPS con cada 8 m, y
// cada una rehacía el Scaffold con la cabecera, la hoja, la guía y el
// `MapWidget`. Ahora eso vive en un envoltorio propio que mira solo lo que
// dice (con `select`), y la pantalla ni se entera.
//
// Se cuentan las veces que el framework reconstruye el elemento de
// `MapScreen` con `debugOnRebuildDirtyWidget`, el gancho que Flutter llama
// en cada reconstrucción.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import 'package:ya_viene_pasajero/features/map/presentation/screens/map_screen.dart';
import 'package:ya_viene_pasajero/features/map/presentation/widgets/map_widget.dart';

import 'helpers/mapa.dart';

void main() {
  testWidgets(
      'fotos de posiciones y lecturas del GPS no reconstruyen la '
      'pantalla', (tester) async {
    final semantica = tester.ensureSemantics();
    final mapa = await MapaDePrueba.montar(tester);
    mapa.repo.foto([10.95, 10.94]);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.bySemanticsLabel(RegExp('^Mapa con 2 buses de Ruta 106')),
        findsOneWidget);

    var reconstrucciones = 0;
    debugOnRebuildDirtyWidget = (element, _) {
      if (element.widget is MapScreen) reconstrucciones++;
    };
    try {
      final mapaNativo = tester.widget<MapWidget>(find.byType(MapWidget));

      // Veinte fotos: los buses avanzan 100 m cada vez.
      for (var i = 1; i <= 20; i++) {
        mapa.repo.foto([10.95 + i * 0.0009, 10.94 + i * 0.0009]);
        await tester.pump(const Duration(milliseconds: 250));
      }
      expect(reconstrucciones, 0, reason: 'fotos de posiciones');

      // Veinte lecturas del GPS: la persona camina 10 m cada vez.
      for (var i = 1; i <= 20; i++) {
        mapa.ubicacion.leerGps(
          puntoDeEspera.$1 + i * 0.00009,
          puntoDeEspera.$2,
        );
        await tester.pump(const Duration(milliseconds: 250));
      }
      expect(reconstrucciones, 0, reason: 'lecturas del GPS');

      // El mapa nativo es el mismo objeto: nadie lo rehízo.
      expect(
        identical(mapaNativo, tester.widget<MapWidget>(find.byType(MapWidget))),
        isTrue,
      );

      // Lo que el lector de pantalla oye sí se entera: un bus más en la
      // foto cambia la etiqueta del mapa.
      mapa.repo.foto([10.96, 10.95, 10.93]);
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.bySemanticsLabel(RegExp('^Mapa con 3 buses de Ruta 106')),
          findsOneWidget);
      expect(reconstrucciones, 0);

      // Control: lo que la pantalla sí pinta la reconstruye. Sin esto un
      // contador roto pasaría en verde.
      mapa.container.read(selectedRouteProvider.notifier).select(
            const RouteInfo(id: 'R-107', name: 'Ruta 107', companyId: 'E'),
          );
      await tester.pump(const Duration(milliseconds: 250));
      expect(reconstrucciones, greaterThan(0));
    } finally {
      debugOnRebuildDirtyWidget = null;
    }
    await mapa.desmontar(tester);
    semantica.dispose();
  });
}
