import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/map_tour_provider.dart';
import 'package:ya_viene_pasajero/features/map/presentation/widgets/map_tour_overlay.dart';
import 'package:ya_viene_pasajero/features/map/presentation/widgets/search_pill_bar.dart';

import 'helpers/mapa.dart';

Future<void> asentar(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  // El hueco se medía en la pantalla y se pintaba en la guía: con la pestaña
  // del mapa entrando de lado (desde Info, «Ver guía»), las dos cuentas se
  // separaban y el hueco caía corrido o fuera (dueño, 2026-10-27).
  testWidgets('con la pantalla corrida, el hueco sigue sobre su objetivo',
      (tester) async {
    const corrimiento = Offset(120, 0);
    final mapa = await MapaDePrueba.montar(tester, corrimiento: corrimiento);
    await asentar(tester);
    await tester.runAsync(() async {
      await mapa.container
          .read(mapGuideProvider.notifier)
          .restart(hasLocation: true);
    });
    await asentar(tester);

    final hueco = tester
        .widget<CustomPaint>(find.byKey(const ValueKey('guide_scrim')).last)
        .painter! as PintorHueco;
    final pill = tester.getRect(find.byType(SearchPillBar)).shift(-corrimiento);
    expect(hueco.hole.center.dx, closeTo(pill.center.dx, 0.5));
    expect(hueco.hole.center.dy, closeTo(pill.center.dy, 0.5));

    await mapa.desmontar(tester);
  });
}
