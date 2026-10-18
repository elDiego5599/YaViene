// La pantalla del mapa montada entera, sin red ni GPS ni plugins.
//
// El socket es un repositorio de mentira al que la prueba le empuja fotos
// de posiciones; la ubicación la mueve la prueba; el aviso «suena» sin
// tocar el plugin de notificaciones y el servicio de fondo anota lo que se
// le pide en vez de arrancar nada. El permiso de notificaciones se da sin
// preguntar: el plugin no contesta en las pruebas.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import 'package:ya_viene_pasajero/features/map/domain/repositories/realtime_repository.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/alert_toggle_provider.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/realtime_providers.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/user_location_provider.dart';
import 'package:ya_viene_pasajero/features/map/presentation/screens/map_screen.dart';
import 'package:ya_viene_pasajero/features/notifications/presentation/providers/proximity_alerts_provider.dart';
import 'package:ya_viene_pasajero/services/background_keep_alive.dart';

const rutaDePrueba = RouteInfo(id: 'R-106', name: 'Ruta 106', companyId: 'E');

/// Punto de espera de las pruebas.
const puntoDeEspera = (10.990, -74.800);

class RepoDePrueba implements RealtimeRepository {
  final lotes = StreamController<Map<String, dynamic>>.broadcast();
  final _nada = StreamController<Map<String, dynamic>>.broadcast();
  final _conexion = StreamController<ConnectionStatus>.broadcast();

  /// Empuja una foto de la ruta con un bus por cada latitud.
  void foto(List<double> latitudes) => lotes.add({
        'routeId': rutaDePrueba.id,
        'buses': [
          for (var i = 0; i < latitudes.length; i++)
            {
              'busId': 'BUS-SQA22$i',
              'routeId': rutaDePrueba.id,
              'lat': latitudes[i],
              'lon': puntoDeEspera.$2,
              'speedKmh': 30,
              'timestamp': DateTime.now().toIso8601String(),
            },
        ],
      });

  @override
  ConnectionStatus? get lastConnectionState => ConnectionStatus.connected;
  @override
  Stream<ConnectionStatus> get connectionStateStream => _conexion.stream;
  @override
  Stream<Map<String, dynamic>> get busPositionStream => _nada.stream;
  @override
  Stream<Map<String, dynamic>> get batchPositionStream => lotes.stream;
  @override
  Stream<Map<String, dynamic>> get busLeftStream => _nada.stream;
  @override
  Stream<Map<String, dynamic>> get busHiddenStream => _nada.stream;
  @override
  Stream<Map<String, dynamic>> get busVisibleStream => _nada.stream;
  @override
  Stream<Map<String, dynamic>> get busRemovedStream => _nada.stream;
  @override
  bool get isConnected => true;
  @override
  void connect() {}
  @override
  void disconnect() {}
  @override
  void dispose() {}
  @override
  void subscribeToRoute(String routeId) {}
  @override
  void unsubscribeFromRoute(String routeId) {}
}

/// La ubicación la pone la prueba: arranca con el pin en [puntoDeEspera].
class UbicacionDePrueba extends UserLocationNotifier {
  @override
  Future<void> initialize() async => state = UserLocationState(
        mode: UserLocationMode.manual,
        lat: puntoDeEspera.$1,
        lon: puntoDeEspera.$2,
      );

  /// Una lectura nueva del GPS.
  void leerGps(double lat, double lon) => state = UserLocationState(
        mode: UserLocationMode.gps,
        lat: lat,
        lon: lon,
        updatedAt: DateTime.now(),
      );
}

/// Anota lo que la app le pide al servicio de fondo.
class ServicioDePrueba implements ServicioDeFondo {
  final pedidos = <String>[];
  int latidos = 0;

  @override
  Future<void> encender() async => pedidos.add('encender');

  @override
  Future<void> apagar() async => pedidos.add('apagar');

  @override
  Future<void> latido() async => latidos++;
}

class MapaDePrueba {
  MapaDePrueba._(this.container, this.repo, this.servicio, this.avisados);

  final ProviderContainer container;
  final RepoDePrueba repo;
  final ServicioDePrueba servicio;

  /// Buses cuyo aviso «sonó».
  final List<String> avisados;

  UbicacionDePrueba get ubicacion =>
      container.read(userLocationProvider.notifier) as UbicacionDePrueba;

  /// Monta la pantalla con [rutaDePrueba] elegida y deja pasar el arranque.
  ///
  /// Sin [bienvenida], el teléfono ya la contestó con «Ir a la app»: la
  /// ventana no tapa el mapa en las pruebas que no van de ella.
  static Future<MapaDePrueba> montar(
    WidgetTester tester, {
    bool bienvenida = false,
  }) async {
    SharedPreferences.setMockInitialValues({
      'onboarding_seen': true,
      if (!bienvenida) ...{
        'map_guide_version': 2,
        'map_guide_status': 'skipped',
      },
    });
    final repo = RepoDePrueba();
    final servicio = ServicioDePrueba();
    final avisados = <String>[];
    final container = ProviderContainer(overrides: [
      backendUrlProvider.overrideWith(() => BackendUrl.fija('http://x')),
      realtimeServiceProvider.overrideWithValue(repo),
      userLocationProvider.overrideWith((ref) => UbicacionDePrueba()),
      servicioDeFondoProvider.overrideWithValue(servicio),
      alertToggleProvider.overrideWith(
        (ref) =>
            AlertToggleController(ref, requestPermission: () async => true),
      ),
      proximityAlertsProvider.overrideWith(
        (ref) => ProximityAlertsNotifier(
          ref,
          notify: ({
            required String busId,
            String? routeName,
            String? routeId,
            required int distanceMeters,
          }) async {
            avisados.add(busId);
            return true;
          },
          permiso: () async => true,
        ),
      ),
    ]);
    container.read(selectedRouteProvider.notifier).select(rutaDePrueba);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: MapScreen()),
    ));
    await tester.pump(const Duration(milliseconds: 50));
    return MapaDePrueba._(container, repo, servicio, avisados);
  }

  /// Desmonta y deja que venzan los temporizadores de la pantalla.
  Future<void> desmontar(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    container.read(proximityAlertsProvider.notifier).stop();
    await tester.pump(const Duration(seconds: 10));
    container.dispose();
  }
}
