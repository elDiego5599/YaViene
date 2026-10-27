// La ocupación aproximada de la tarjeta del bus: de ejemplo, sube y baja
// por tramos a lo largo de la ruta (dueño, 2026-10-27).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import 'package:ya_viene_pasajero/features/map/presentation/widgets/ocupacion_bus.dart';

void main() {
  final hora = DateTime(2026, 10, 27, 7, 15);
  BusPosition bus(double lon) => BusPosition(
        busId: 'BUS-SQA220',
        routeId: 'R-001',
        lat: 10.98,
        lon: lon,
        heading: 90,
        speedKmh: 20,
        timestamp: hora,
        isGhostBus: false,
      );
  // Una calle recta de este a oeste, de unos 2,2 km.
  SeguidorRuta seguidor() => SeguidorRuta(RutaMedible.de(const [
        GeoPoint(lat: 10.98, lon: -74.80),
        GeoPoint(lat: 10.98, lon: -74.78),
      ])!);

  test('la del tramo donde va el bus, a la hora de su posición', () {
    expect(
      ocupacionEnRuta(seguidor(), bus(-74.79)),
      ocupacionSimulada(
          busId: 'BUS-SQA220', routeId: 'R-001', tramo: 0.5, hora: hora),
    );
  });

  test('sin ruta, o con el bus fuera de ella, no se dice', () {
    expect(ocupacionEnRuta(null, bus(-74.79)), isNull);
    expect(
        ocupacionEnRuta(
            seguidor(),
            BusPosition(
              busId: 'BUS-SQA220',
              routeId: 'R-001',
              lat: 10.99,
              lon: -74.79,
              heading: 90,
              speedKmh: 20,
              timestamp: hora,
              isGhostBus: false,
            )),
        isNull);
  });

  testWidgets('dice el porcentaje aproximado, con su barra', (tester) async {
    final semantica = tester.ensureSemantics();
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: OcupacionBus(porcentaje: 62)),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Ocupación aprox.'), findsOneWidget);
    expect(find.text('62 %'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Ocupación aproximada, 62 por ciento'),
      findsOneWidget,
    );
    final relleno =
        tester.getSize(find.byKey(const ValueKey('ocupacion-relleno')));
    final pista = tester.getSize(find.byKey(const ValueKey('ocupacion-pista')));
    expect(relleno.width, closeTo(pista.width * 0.62, 0.5));
    expect(pista.height, 6);
    semantica.dispose();
  });
}
