// En el paso «Mira los buses», la cámara se quedaba en el punto de espera:
// si el bus más cercano iba lejos, el trozo iluminado del mapa salía sin
// ningún bus y la guía pedía tocar uno que no se veía (dueño, 2026-10-16).
// Ahora lleva el mapa al bus más cercano, junto con el punto, y dice que se
// puede mover el mapa para buscar otro.
import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/map_tour_provider.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/map_view_state.dart';
import 'package:ya_viene_pasajero/features/map/presentation/widgets/map_tour_overlay.dart';

import 'helpers/mapa.dart';

/// El mapa tiene temporizadores vivos: `pumpAndSettle` no acabaría nunca.
Future<void> asentar(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('el paso de los buses lleva el mapa al bus más cercano',
      (tester) async {
    final mapa = await MapaDePrueba.montar(tester);
    // El segundo es el más cercano al punto de espera (10,990): a unos
    // 550 m; los otros, a 4,4 y 4,5 km.
    mapa.repo.foto([10.950, 10.985, 11.030]);
    await asentar(tester);
    final guia = mapa.container.read(mapGuideProvider.notifier);
    await tester.runAsync(() async {
      await guia.restart(hasLocation: true);
      await guia.moveTo(MapGuideStep.buses);
    });
    await asentar(tester);

    expect(mapa.container.read(enfoqueDeBusProvider),
        (busId: 'BUS-SQA221', routeId: rutaDePrueba.id));
    final vista = tester.widget<MapGuideOverlay>(find.byType(MapGuideOverlay));
    expect(vista.message, contains('más cercano'));
    expect(vista.message, contains('mueve el mapa'));

    await mapa.desmontar(tester);
  });
}
