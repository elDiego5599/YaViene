// Con la guía en marcha, el menú lateral se abría: con el botón (el paso de
// la búsqueda ilumina la barra entera, botón del menú incluido) y
// arrastrando desde el borde izquierdo, que el velo de la guía no tapa
// porque el gesto del Scaffold va encima del cuerpo. El menú encima de la
// guía la deja a medias y sin salida (dueño, 2026-10-05).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/map_tour_provider.dart';
import 'package:ya_viene_pasajero/features/map/presentation/widgets/search_pill_bar.dart';

import 'helpers/mapa.dart';

/// El mapa tiene temporizadores vivos: `pumpAndSettle` no acabaría nunca.
Future<void> asentar(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

bool menuAbierto(WidgetTester tester) =>
    tester.state<ScaffoldState>(find.byType(Scaffold).first).isDrawerOpen;

void main() {
  Future<MapaDePrueba> enLaGuia(WidgetTester tester) async {
    final mapa = await MapaDePrueba.montar(tester, bienvenida: true);
    await asentar(tester);
    await tester.tap(find.text('Ver la guía'));
    await asentar(tester);
    expect(mapa.container.read(mapGuideProvider).step, MapGuideStep.search);
    return mapa;
  }

  testWidgets('en la guía, el botón del menú no lo abre', (tester) async {
    final mapa = await enLaGuia(tester);

    await tester.tap(find.bySemanticsLabel('Abrir menú'), warnIfMissed: false);
    await asentar(tester);
    expect(menuAbierto(tester), isFalse);

    await mapa.desmontar(tester);
  });

  testWidgets('en la guía, arrastrar desde el borde no abre el menú',
      (tester) async {
    final mapa = await enLaGuia(tester);

    final alto = tester.view.physicalSize.height / tester.view.devicePixelRatio;
    await tester.dragFrom(Offset(2, alto / 2), const Offset(300, 0));
    await asentar(tester);
    expect(menuAbierto(tester), isFalse);

    await mapa.desmontar(tester);
  });

  testWidgets('sin guía, el botón del menú sí lo abre', (tester) async {
    final mapa = await MapaDePrueba.montar(tester);
    await asentar(tester);

    await tester.tap(find.bySemanticsLabel('Abrir menú'));
    await asentar(tester);
    expect(menuAbierto(tester), isTrue);

    await mapa.desmontar(tester);
  });

  // El velo tapa hoy el botón; si un paso lo destapara, el botón mismo no
  // abre el menú mientras la guía siga.
  testWidgets('el botón del menú no abre nada con la guía activa',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final guia = MapGuideNotifier();
    await guia.initialize(
      hasLocation: true,
      locationSettled: true,
      hasRoute: false,
      hasSelectedBus: false,
      hasActiveAlert: false,
    );
    await guia.empezar();
    final container = ProviderContainer(
        overrides: [mapGuideProvider.overrideWith((ref) => guia)]);
    addTearDown(container.dispose);
    container.listen(selectedRouteProvider, (_, __) {});
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        home: Scaffold(
          drawer: Drawer(),
          body: Align(alignment: Alignment.topCenter, child: SearchPillBar()),
        ),
      ),
    ));

    await tester.tap(find.bySemanticsLabel('Abrir menú'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(menuAbierto(tester), isFalse);
  });
}
