// Con la guía en marcha, el menú lateral se abría: con el botón (el paso de
// la búsqueda ilumina la barra entera, botón del menú incluido) y
// arrastrando desde el borde izquierdo, que el velo de la guía no tapa
// porque el gesto del Scaffold va encima del cuerpo. El menú encima de la
// guía la deja a medias y sin salida (dueño, 2026-10-05).
//
// Desde el 2026-10-16 el menú no existe: lo suyo vive en la barra de abajo,
// que se aparta durante la guía (`pildora_navegacion_test.dart`). Aquí
// queda que el mapa no traiga ningún cajón que la guía pueda dejar abrir.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/map_tour_provider.dart';

import 'helpers/mapa.dart';

/// El mapa tiene temporizadores vivos: `pumpAndSettle` no acabaría nunca.
Future<void> asentar(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('el mapa ya no trae menú lateral ni su botón', (tester) async {
    final mapa = await MapaDePrueba.montar(tester);
    await asentar(tester);

    expect(find.bySemanticsLabel('Abrir menú'), findsNothing);
    expect(tester.widget<Scaffold>(find.byType(Scaffold).first).drawer, isNull);

    await mapa.desmontar(tester);
  });

  testWidgets('en la guía, arrastrar desde el borde no abre nada',
      (tester) async {
    final mapa = await MapaDePrueba.montar(tester, bienvenida: true);
    await asentar(tester);
    await tester.tap(find.text('Ver la guía'));
    await asentar(tester);
    expect(mapa.container.read(mapGuideProvider).step, MapGuideStep.search);

    final alto = tester.view.physicalSize.height / tester.view.devicePixelRatio;
    await tester.dragFrom(Offset(2, alto / 2), const Offset(300, 0));
    await asentar(tester);
    expect(find.byType(Drawer), findsNothing);
    expect(mapa.container.read(mapGuideProvider).step, MapGuideStep.search);

    await mapa.desmontar(tester);
  });
}
