// La hoja dice cuándo la app habla con el respaldo (T2.3).
//
// Con D1 = espejo de la demo, el respaldo sirve una flota simulada a
// propósito, y quien mira el mapa tiene que poder saberlo. Lo dice una línea
// discreta, aparte de lo que diga cada estado: el «Toca un bus en el mapa» se
// queda exactamente como está.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import 'package:ya_viene_pasajero/core/utils/color_ruta.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/tracking_providers.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/user_location_provider.dart';
import 'package:ya_viene_pasajero/features/map/presentation/widgets/eta_bottom_sheet.dart';
import 'package:ya_viene_pasajero/features/map/presentation/widgets/sena_tocar_bus.dart';

const double _lat = 6.2442;
const double _lon = -75.5812;

class _UbicacionDePrueba extends UserLocationNotifier {
  _UbicacionDePrueba() {
    state = const UserLocationState(
      mode: UserLocationMode.manual,
      lat: _lat,
      lon: _lon,
    );
  }
}

final _bus = BusPosition(
  busId: 'A-1',
  routeId: 'R1',
  lat: _lat + 0.007645,
  lon: _lon,
  heading: 0,
  speedKmh: 30,
  timestamp: DateTime(2026, 1, 1, 8),
  isGhostBus: false,
);

/// La hoja sobre una ruta con un bus y ninguno elegido: el estado «Toca un
/// bus en el mapa».
Future<void> _montar(
  WidgetTester tester, {
  required bool enRespaldo,
  String ruta = 'Ruta 1',
}) async {
  final container = ProviderContainer(overrides: [
    userLocationProvider.overrideWith((ref) => _UbicacionDePrueba()),
    busPositionsSourceProvider.overrideWith(
      (ref, routeId) => Stream.value([_bus]),
    ),
    routeTrajectoryProvider.overrideWith(
      (ref, routeId) => RouteTrajectory(
        routeId: routeId,
        routeName: 'Ruta 1',
        points: const [
          GeoPoint(lat: _lat, lon: _lon - 0.05),
          GeoPoint(lat: _lat, lon: _lon + 0.05),
        ],
      ),
    ),
  ]);
  addTearDown(container.dispose);
  container.read(selectedRouteProvider.notifier).select(
        RouteInfo(id: 'R1', name: ruta, companyId: 'C1'),
      );
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Scaffold(body: EtaBottomSheet(enRespaldo: enRespaldo)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('en el túnel la hoja no dice nada del respaldo', (tester) async {
    await _montar(tester, enRespaldo: false);

    expect(find.text('Toca un bus en el mapa'), findsOneWidget);
    expect(find.text('Conectado al respaldo'), findsNothing);
  });

  testWidgets(
      'en el respaldo una línea lo dice, y «Toca un bus en el mapa» sigue '
      'igual', (tester) async {
    final vacio = find.byKey(const ValueKey('empty-pick-bus'));
    await _montar(tester, enRespaldo: false);
    final medidaSinLinea = tester.getSize(vacio);

    await tester.pumpWidget(const SizedBox());
    await _montar(tester, enRespaldo: true);

    expect(find.text('Conectado al respaldo'), findsOneWidget);
    expect(vacio, findsOneWidget);
    // La línea va aparte: el estado vacío no la contiene y mide lo mismo.
    expect(
      find.descendant(of: vacio, matching: find.text('Conectado al respaldo')),
      findsNothing,
    );
    expect(
      find.descendant(of: vacio, matching: find.text('Toca un bus en el mapa')),
      findsOneWidget,
    );
    expect(tester.getSize(vacio), medidaSinLinea);
  });

  testWidgets('con la hoja plegada la línea sigue a la vista', (tester) async {
    await _montar(tester, enRespaldo: true);

    await tester.tap(find.byKey(const ValueKey('sheet-handle')));
    await tester.pumpAndSettle();

    // Plegada se va lo que dice el estado, no la línea: los buses del mapa
    // siguen siendo los del respaldo.
    expect(find.text('Toca un bus en el mapa').hitTestable(), findsNothing);
    expect(find.text('Conectado al respaldo').hitTestable(), findsOneWidget);
  });

  testWidgets('«Toca un bus en el mapa» lleva el bus del mapa, no la mano',
      (tester) async {
    // El dueño (2026-09-27): la mano de Material «no me gusta nada». El
    // dibujo es el mismo bus que se toca en el mapa.
    await _montar(tester, enRespaldo: false);
    final vacio = find.byKey(const ValueKey('empty-pick-bus'));
    expect(
      find.descendant(
          of: vacio, matching: find.byIcon(Icons.touch_app_outlined)),
      findsNothing,
    );
    expect(
      find.descendant(
          of: vacio, matching: find.byKey(const ValueKey('sena-tocar-bus'))),
      findsOneWidget,
    );
  });

  testWidgets('la seña dibuja el bus en el color de su ruta', (tester) async {
    // El bus de la seña es el del mapa, y el del mapa va en el color de su
    // ruta (`colorRuta`, dueño, 2026-10-19).
    await _montar(tester, enRespaldo: false, ruta: 'C16 Calle 72');
    final sena = tester.widget<SenaTocarBus>(find.byType(SenaTocarBus));
    expect(sena.color, coloresRuta['C16']);
  });
}
