import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import 'package:ya_viene_pasajero/core/router/app_router.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/map_tour_provider.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/tracking_providers.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/user_location_provider.dart';
import 'package:ya_viene_pasajero/features/map/presentation/widgets/eta_bottom_sheet.dart';

/// La puerta al planificador vive en la hoja de abajo, no en la columna de
/// píldoras del mapa (dueño, 2026-11-14: ahí se amontonaban hasta cuatro), y
/// solo cuando ya hay pin: sin él, la hoja pide primero tocar el mapa.
class _Ubicacion extends UserLocationNotifier {
  _Ubicacion(UserLocationState inicial) {
    state = inicial;
  }
}

class _Guia extends MapGuideNotifier {
  _Guia() {
    state = const MapGuideState(step: MapGuideStep.search, initialized: true);
  }
}

Future<void> _montar(WidgetTester tester, UserLocationState ubicacion,
    {bool conGuia = false}) async {
  SharedPreferences.setMockInitialValues({});
  final router = GoRouter(routes: [
    GoRoute(
      path: '/',
      builder: (_, __) =>
          const Scaffold(body: Stack(children: [EtaBottomSheet()])),
    ),
    GoRoute(
      path: AppRoutes.viaje,
      builder: (_, __) => const Text('el planificador'),
    ),
  ]);
  addTearDown(router.dispose);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      userLocationProvider.overrideWith((ref) => _Ubicacion(ubicacion)),
      if (conGuia) mapGuideProvider.overrideWith((ref) => _Guia()),
      busPositionsSourceProvider.overrideWith(
        (ref, routeId) => Stream.value(const <BusPosition>[]),
      ),
    ],
    child: MaterialApp.router(routerConfig: router),
  ));
  await tester.pumpAndSettle();
}

const _conPin = UserLocationState(
  mode: UserLocationMode.manual,
  lat: 10.98,
  lon: -74.80,
);

void main() {
  testWidgets('sin pin la hoja no ofrece planear', (tester) async {
    await _montar(tester, const UserLocationState());
    expect(find.byKey(const ValueKey('empty-no-position')), findsOneWidget);
    expect(find.byKey(const ValueKey('entrada-viaje')), findsNothing);
  });

  testWidgets(
      'con el pin puesto, la hoja pregunta a dónde va y abre el '
      'planificador', (tester) async {
    await _montar(tester, _conPin);
    expect(find.byKey(const ValueKey('empty-no-route')), findsOneWidget);
    expect(find.text('¿A dónde vas?'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('entrada-viaje')));
    await tester.pumpAndSettle();
    expect(find.text('el planificador'), findsOneWidget);
  });

  testWidgets('se anuncia como un solo botón con su nombre', (tester) async {
    final semantica = tester.ensureSemantics();
    await _montar(tester, _conPin);
    expect(
      tester.getSemantics(find.byKey(const ValueKey('entrada-viaje'))),
      isSemantics(
        isButton: true,
        hasTapAction: true,
        label: '¿A dónde vas?\nTe decimos qué buses tomar',
      ),
    );
    semantica.dispose();
  });

  // La guía enseña el mapa y cuenta con su hueco: una fila de más en la hoja
  // se lo comía en un iPhone SE con la letra grande.
  testWidgets('durante la guía la hoja no ofrece planear', (tester) async {
    await _montar(tester, _conPin, conGuia: true);
    expect(find.byKey(const ValueKey('empty-no-route')), findsOneWidget);
    expect(find.byKey(const ValueKey('entrada-viaje')), findsNothing);
  });
}
