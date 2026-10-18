// En el paso del aviso, si el pasajero nunca guardó una distancia, tocar
// «Avisarme cuando esté cerca» abre la rueda en la tarjeta del bus. La guía
// se escondía mientras tanto y la pantalla entera quedaba encendida y
// tocable: se podía mover el mapa, cambiar de ruta o soltar el bus con la
// guía a medias (dueño, 2026-10-16). Ahora la guía sigue puesta y solo
// ilumina la tarjeta con la rueda y sus dos botones.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/map_tour_provider.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/tracking_providers.dart';
import 'package:ya_viene_pasajero/features/map/presentation/widgets/eta_bottom_sheet.dart';
import 'package:ya_viene_pasajero/features/map/presentation/widgets/map_tour_overlay.dart';

import 'helpers/mapa.dart';

/// El mapa tiene temporizadores vivos: `pumpAndSettle` no acabaría nunca.
Future<void> asentar(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('con la rueda abierta, la guía ilumina solo la rueda',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final mapa = await MapaDePrueba.montar(tester);
    // A unos 2,2 km del punto de espera: la rueda ofrece distancias.
    mapa.repo.foto([10.970]);
    await asentar(tester);
    mapa.container.read(selectedBusesProvider.notifier).toggleBus('BUS-SQA220');
    final guia = mapa.container.read(mapGuideProvider.notifier);
    await tester.runAsync(() async {
      await guia.restart(hasLocation: true, locationSettled: true);
      await guia.moveTo(MapGuideStep.alert);
    });
    await asentar(tester);
    expect(find.byType(MapGuideOverlay), findsOneWidget);

    await tester.tap(find.text('Avisarme cuando esté cerca'));
    await asentar(tester);

    expect(find.text('Guardar'), findsOneWidget, reason: 'la rueda se abrió');
    expect(find.byType(MapGuideOverlay), findsOneWidget,
        reason: 'la guía no se esconde con la rueda abierta');
    final guiaVista =
        tester.widget<MapGuideOverlay>(find.byType(MapGuideOverlay));
    final hueco = guiaVista.target;
    for (final boton in ['Guardar', 'Solo esta vez']) {
      expect(hueco.contains(tester.getCenter(find.text(boton))), isTrue,
          reason: '«$boton» queda dentro de lo iluminado');
    }
    expect(hueco.top,
        greaterThanOrEqualTo(tester.getTopLeft(find.byType(EtaBottomSheet)).dy),
        reason: 'el mapa queda bajo el velo: el hueco empieza en la hoja');
    final carta = tester.getRect(find.byKey(const ValueKey('guide_card')));
    expect(carta.overlaps(hueco.inflate(10)), isFalse,
        reason: 'la tarjeta de la guía no tapa la rueda');
    expect(guiaVista.primaryLabel, isNull,
        reason: 'se sigue con «Guardar», no con un botón de la guía');

    // Guardar arma el aviso y la guía vuelve a su tarjeta de siempre.
    await tester.tap(find.text('Guardar'));
    await asentar(tester);
    expect(find.text('Guardar'), findsNothing);
    expect(mapa.container.read(activeAlertsProvider), {'BUS-SQA220'});
    expect(find.byType(MapGuideOverlay), findsOneWidget);
    expect(
        tester
            .widget<MapGuideOverlay>(find.byType(MapGuideOverlay))
            .primaryLabel,
        isNotNull);

    await mapa.desmontar(tester);
  });
}
