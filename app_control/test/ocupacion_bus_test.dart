// La ocupación aproximada del bus seleccionado, en su ficha, como en la
// tarjeta del bus del pasajero (dueño, 2026-10-27): de ejemplo, sube y baja
// por tramos de la ruta.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_control/features/fleet/domain/fleet_bus.dart';
import 'package:ya_viene_control/features/fleet/presentation/widgets/ocupacion_bus.dart';
import 'package:ya_viene_core/ya_viene_core.dart';

void main() {
  final hora = DateTime(2026, 10, 27, 7, 15);
  FleetBus bus({double? lat = 10.98, String? routeId = 'R-001'}) => FleetBus(
    busId: 'BUS-SQA220',
    companyId: 'sobusa',
    visible: true,
    routeId: routeId,
    lat: lat,
    lon: -74.79,
    heading: 90,
    online: true,
    capturedAt: hora.millisecondsSinceEpoch,
  );
  // Una calle recta de este a oeste, de unos 2,2 km.
  SeguidorRuta seguidor() => SeguidorRuta(
    RutaMedible.de(const [
      GeoPoint(lat: 10.98, lon: -74.80),
      GeoPoint(lat: 10.98, lon: -74.78),
    ])!,
  );

  test('la del tramo donde va el bus, como en el pasajero', () {
    expect(
      ocupacionDeFlota(seguidor(), bus()),
      ocupacionSimulada(
        busId: 'BUS-SQA220',
        routeId: 'R-001',
        tramo: 0.5,
        hora: hora,
      ),
    );
  });

  test('sin ruta, sin posición o fuera de la ruta, no se dice', () {
    expect(ocupacionDeFlota(null, bus()), isNull);
    expect(ocupacionDeFlota(seguidor(), bus(lat: null)), isNull);
    expect(ocupacionDeFlota(seguidor(), bus(routeId: null)), isNull);
    expect(ocupacionDeFlota(seguidor(), bus(lat: 10.99)), isNull);
  });

  testWidgets('dice el porcentaje, con su pista en la escala de calor', (
    tester,
  ) async {
    final semantica = tester.ensureSemantics();
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: OcupacionBus(porcentaje: 62))),
    );
    await tester.pumpAndSettle();
    expect(find.text('OCUPACIÓN APROX.'), findsOneWidget);
    expect(find.text('62 %'), findsOneWidget);
    expect(find.bySemanticsLabel('Ocupación aproximada: 62 %'), findsOneWidget);
    final pista = tester.getSize(find.byKey(const ValueKey('ocupacion-pista')));
    final relleno = tester.getSize(
      find.byKey(const ValueKey('ocupacion-relleno')),
    );
    expect(pista.height, 6);
    expect(relleno.width / pista.width, closeTo(0.62, 0.01));
    semantica.dispose();
  });
}
