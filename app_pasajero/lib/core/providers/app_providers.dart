/// =============================================================================
/// PROVIDERS BASE (Riverpod) — CAPA DE DATOS SIMULADA PARA MVP 0
///
/// Estos providers simulan la entrada de datos en tiempo real.
/// Cuando se integre el WebSocket real, SOLO se modifica la implementación
/// interna de estos providers. La UI nunca sabrá la diferencia.
///
/// Patrón de aislamiento:
///   WebSocket/MQTT → Repository → Provider → Widget (solo se redibuja lo
///   que consume el dato que cambió, no toda la pantalla).
/// =============================================================================

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/bus_position.dart';
import '../models/route_info.dart';
import '../models/company.dart';

// =============================================================================
// PROVIDER 1: Tick de Tiempo Real (Canario de Rendimiento)
// Emite un contador cada segundo. Permite verificar en ProfileMode que
// la UI NO parpadea completa con cada tick — solo el widget que lo consuma.
// =============================================================================

/// StreamProvider que emite un [int] (contador) cada segundo.
/// VERIFICACIÓN: Envolve el widget que muestre este valor en un
/// [Consumer] aislado y usa Flutter DevTools para confirmar que
/// solo ese widget se redibuja.
final realtimeTickProvider = StreamProvider.autoDispose<int>((ref) async* {
  int tick = 0;
  while (true) {
    await Future.delayed(const Duration(seconds: 1));
    yield tick++;
  }
});

// =============================================================================
// PROVIDER 2: Posiciones de Buses (Simulado — reemplazar con WebSocket)
// =============================================================================

/// StreamProvider que emite una lista de [BusPosition] simulando el movimiento
/// de 3 buses en un corredor de prueba cada 2 segundos.
/// Reemplazar el Stream por la conexión real a Socket.io en el MVP 1.
final busPositionsProvider =
    StreamProvider.autoDispose.family<List<BusPosition>, String>(
  (ref, routeId) async* {
    // Posiciones base del corredor de prueba (ruta ficticia en Barranquilla)
    double baseLat = 11.0041;
    double baseLon = -74.8070;

    yield _generateDummyPositions(routeId, baseLat, baseLon, tick: 0);

    int tick = 0;
    await for (final _ in Stream.periodic(const Duration(seconds: 2))) {
      tick++;
      baseLat += 0.0001 * tick; // Simula movimiento hacia el norte
      yield _generateDummyPositions(routeId, baseLat, baseLon, tick: tick);
    }
  },
);

List<BusPosition> _generateDummyPositions(
  String routeId,
  double baseLat,
  double baseLon, {
  required int tick,
}) {
  return [
    BusPosition(
      busId: 'B-001',
      routeId: routeId,
      lat: baseLat,
      lon: baseLon,
      heading: 45,
      speedKmh: 35,
      timestamp: DateTime.now(),
      isGhostBus: false,
    ),
    BusPosition(
      busId: 'B-002',
      routeId: routeId,
      lat: baseLat + 0.005,
      lon: baseLon + 0.003,
      heading: 48,
      speedKmh: 28,
      timestamp: DateTime.now().subtract(const Duration(seconds: 95)),
      isGhostBus: true, // Simula bus sin señal hace más de 90 segundos
    ),
    BusPosition(
      busId: 'B-003',
      routeId: routeId,
      lat: baseLat + 0.012,
      lon: baseLon + 0.007,
      heading: 52,
      speedKmh: 42,
      timestamp: DateTime.now(),
      isGhostBus: false,
    ),
  ];
}

// =============================================================================
// PROVIDER 3: Catálogos de Empresa y Ruta (Simulado — reemplazar con HTTP)
// =============================================================================

/// FutureProvider con la lista de empresas transportadoras.
/// Simula una llamada HTTP al backend con 500ms de latencia artificial.
final companiesProvider = FutureProvider<List<Company>>((ref) async {
  await Future.delayed(const Duration(milliseconds: 500));
  return [
    const Company(id: '1', name: 'Coolitoral S.A.'),
    const Company(id: '2', name: 'Metrocaribe Ltda.'),
    const Company(id: '3', name: 'Transcaribe S.A.S.'),
  ];
});

/// StateNotifierProvider para la empresa seleccionada actualmente.
final selectedCompanyProvider =
    StateNotifierProvider<SelectedCompanyNotifier, Company?>(
  (ref) => SelectedCompanyNotifier(),
);

class SelectedCompanyNotifier extends StateNotifier<Company?> {
  SelectedCompanyNotifier() : super(null);

  void select(Company company) => state = company;
  void clear() => state = null;
}

// ---

/// FutureProvider.family que carga las rutas de una empresa específica.
final routesByCompanyProvider =
    FutureProvider.autoDispose.family<List<RouteInfo>, String>(
  (ref, companyId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    // Datos simulados filtrados por empresa
    final allRoutes = {
      '1': [
        const RouteInfo(id: '101', name: 'Ruta 1 - Centro/Soledad', companyId: '1'),
        const RouteInfo(id: '102', name: 'Ruta 2 - Murillo/Terminal', companyId: '1'),
      ],
      '2': [
        const RouteInfo(id: '201', name: 'Ruta 5 - Riomar/Abello', companyId: '2'),
      ],
      '3': [
        const RouteInfo(id: '301', name: 'Troncal - Portal/Caribe', companyId: '3'),
      ],
    };
    return allRoutes[companyId] ?? [];
  },
);

/// StateNotifierProvider para la ruta seleccionada.
final selectedRouteProvider =
    StateNotifierProvider<SelectedRouteNotifier, RouteInfo?>(
  (ref) => SelectedRouteNotifier(),
);

class SelectedRouteNotifier extends StateNotifier<RouteInfo?> {
  SelectedRouteNotifier() : super(null);

  void select(RouteInfo route) => state = route;
  void clear() => state = null;
}

// ---

/// Enum para el sentido de la ruta.
enum RouteSentido { ida, vuelta }

/// StateProvider simple para el sentido seleccionado.
final selectedSentidoProvider = StateProvider<RouteSentido>(
  (ref) => RouteSentido.ida, // Por defecto: Ida
);

// =============================================================================
// PROVIDER 4: Estado de la Alerta de Proximidad
// =============================================================================

/// StateProvider que maneja si el pasajero tiene activa la alerta de
/// "Avísame cuando el bus esté cerca". Booleano simple por ahora.
final proximityAlertProvider = StateProvider<bool>((ref) => false);
