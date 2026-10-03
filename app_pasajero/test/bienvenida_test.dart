// La primera vez que se abre el mapa, la app saluda y deja escoger entre la
// guía y la app sin más. Antes la guía arrancaba sola, sin que nadie
// recibiera al usuario (dueño, 2026-10-02).
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ya_viene_pasajero/core/widgets/dialogo.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/map_tour_provider.dart';

import 'helpers/mapa.dart';

/// El mapa tiene temporizadores vivos: `pumpAndSettle` no acabaría nunca.
Future<void> asentar(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  Future<MapaDePrueba> abrir(WidgetTester tester) async {
    final mapa = await MapaDePrueba.montar(tester, bienvenida: true);
    await asentar(tester);
    return mapa;
  }

  testWidgets('saluda una vez, encima del mapa y sin la guía detrás',
      (tester) async {
    final mapa = await abrir(tester);

    expect(find.byType(Dialogo), findsOneWidget);
    expect(find.text('Te damos la bienvenida'), findsOneWidget);
    expect(find.text('Ver la guía'), findsOneWidget);
    expect(find.text('Ir a la app'), findsOneWidget);
    expect(mapa.container.read(mapGuideProvider).step, isNull);

    // Otra lectura del GPS vuelve a mirar la guía: no abre otra ventana.
    mapa.ubicacion.leerGps(puntoDeEspera.$1, puntoDeEspera.$2);
    await asentar(tester);
    expect(find.byType(Dialogo), findsOneWidget);

    await mapa.desmontar(tester);
  });

  testWidgets('«Ver la guía» arranca la guía', (tester) async {
    final mapa = await abrir(tester);

    await tester.tap(find.text('Ver la guía'));
    await asentar(tester);

    expect(find.byType(Dialogo), findsNothing);
    // La ubicación ya está: la guía empieza en la búsqueda.
    expect(mapa.container.read(mapGuideProvider).step, MapGuideStep.search);

    await mapa.desmontar(tester);
  });

  testWidgets('«Ir a la app» la cierra y no vuelve', (tester) async {
    final mapa = await abrir(tester);

    await tester.tap(find.text('Ir a la app'));
    await asentar(tester);

    expect(find.byType(Dialogo), findsNothing);
    final guia = mapa.container.read(mapGuideProvider);
    expect(guia.step, isNull);
    expect(guia.skipped, isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('map_guide_status'), 'skipped');

    await mapa.desmontar(tester);
  });

  testWidgets('tocar fuera cuenta como «Ir a la app»', (tester) async {
    final mapa = await abrir(tester);

    await tester.tapAt(const Offset(4, 4));
    await asentar(tester);

    expect(find.byType(Dialogo), findsNothing);
    expect(mapa.container.read(mapGuideProvider).skipped, isTrue);

    await mapa.desmontar(tester);
  });
}
