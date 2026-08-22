import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/fleet_api.dart';
import '../../data/fleet_socket_service.dart';
import '../../domain/fleet_bus.dart';
import '../../domain/fleet_route.dart';

enum FleetConnection { connecting, connected, disconnected }

enum FleetStatusFilter { all, online, hidden, offline }

class FleetState {
  const FleetState({
    this.connection = FleetConnection.connecting,
    this.buses = const <String, FleetBus>{},
    this.routes = const <FleetRoute>[],
    this.error,
    this.updating = const <String>{},
    this.selectedBusId,
    this.routeFilter,
    this.statusFilter = FleetStatusFilter.all,
    this.sessionExpired = false,
  });

  final FleetConnection connection;
  final Map<String, FleetBus> buses;
  final List<FleetRoute> routes;
  final String? error;
  final Set<String> updating;
  final String? selectedBusId;
  final String? routeFilter;
  final FleetStatusFilter statusFilter;

  /// La sesión del admin expiró o fue revocada (401 en REST o kick del socket).
  final bool sessionExpired;

  FleetBus? get selectedBus {
    final id = selectedBusId;
    return id == null ? null : buses[id];
  }

  List<FleetBus> get fleetList {
    final list = buses.values.where((b) {
      final filter = routeFilter;
      if (filter != null && b.routeId != filter) return false;
      return switch (statusFilter) {
        FleetStatusFilter.all => true,
        FleetStatusFilter.online => b.online && !b.isGhost,
        FleetStatusFilter.hidden => !b.visible,
        FleetStatusFilter.offline => !b.online || b.isGhost,
      };
    }).toList()
      ..sort((a, b) => a.busId.compareTo(b.busId));
    return list;
  }

  List<FleetBus> get _routeScoped => routeFilter == null
      ? buses.values.toList()
      : buses.values.where((b) => b.routeId == routeFilter).toList();

  int get totalBuses => _routeScoped.length;
  int get onlineBuses => _routeScoped.where((b) => b.online && !b.isGhost).length;
  int get hiddenBuses => _routeScoped.where((b) => !b.visible).length;
  int get offlineBuses => _routeScoped.where((b) => !b.online || b.isGhost).length;

  String? routeName(String? routeId) {
    if (routeId == null) return null;
    for (final route in routes) {
      if (route.routeId == routeId) return route.name;
    }
    return 'Ruta $routeId';
  }

  FleetState copyWith({
    FleetConnection? connection,
    Map<String, FleetBus>? buses,
    List<FleetRoute>? routes,
    String? error,
    Set<String>? updating,
    String? Function()? selectedBusId,
    String? Function()? routeFilter,
    FleetStatusFilter? statusFilter,
    bool? sessionExpired,
    bool clearError = false,
  }) {
    return FleetState(
      connection: connection ?? this.connection,
      buses: buses ?? this.buses,
      routes: routes ?? this.routes,
      error: clearError ? null : error ?? this.error,
      updating: updating ?? this.updating,
      selectedBusId: selectedBusId != null ? selectedBusId() : this.selectedBusId,
      routeFilter: routeFilter != null ? routeFilter() : this.routeFilter,
      statusFilter: statusFilter ?? this.statusFilter,
      sessionExpired: sessionExpired ?? this.sessionExpired,
    );
  }
}

class FleetNotifier extends StateNotifier<FleetState> {
  FleetNotifier(this._ref) : super(const FleetState());

  final Ref _ref;
  final _api = FleetApi();
  FleetSocketService? _socket;
  final List<StreamSubscription> _subs = [];

  String? get _token => _ref.read(authProvider).session?.token;

  /// Sesión expirada/revocada: marca el estado para que el dashboard avise y
  /// cierre sesión, y detiene la reconexión del socket.
  bool _onSessionExpired(Object e) {
    if (e is! SessionExpiredException) return false;
    state = state.copyWith(
      sessionExpired: true,
      connection: FleetConnection.disconnected,
      error: null,
    );
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
    _socket?.dispose();
    _socket = null;
    return true;
  }

  void start() {
    final token = _token;
    if (token == null) return;
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
    _socket?.dispose();
    final socket = FleetSocketService(token: token);
    _socket = socket;
    _subs.add(socket.connectionStream.listen((connected) {
      state = state.copyWith(
        connection: connected ? FleetConnection.connected : FleetConnection.disconnected,
      );
    }));
    _subs.add(socket.sessionKickedStream.listen((_) {
      state = state.copyWith(
        sessionExpired: true,
        connection: FleetConnection.disconnected,
        error: null,
      );
      for (final s in _subs) {
        s.cancel();
      }
      _subs.clear();
      _socket?.dispose();
      _socket = null;
    }));
    _subs.add(socket.busBatchStream.listen((buses) {
      // Respeta el estado visible guardado en el backend: los buses que
      // quedaron habilitados/ocultos de la última sesión se ven igual.
      final map = <String, FleetBus>{
        for (final b in buses) b.busId: b,
      };
      state = state.copyWith(buses: map, clearError: true);
    }));
    _subs.add(socket.busPositionStream.listen((bus) {
      final previous = state.buses[bus.busId];
      debugPrint('[fleet] bus:position ${bus.busId} lat=${bus.lat} lon=${bus.lon}');
      state = state.copyWith(buses: {
        ...state.buses,
        bus.busId: bus.copyWith(
          online: true,
          visible: previous?.visible ?? bus.visible,
        ),
      });
    }));
    _subs.add(socket.busHiddenStream.listen((busId) {
      final previous = state.buses[busId];
      if (previous == null) return;
      state = state.copyWith(buses: {
        ...state.buses,
        busId: previous.copyWith(visible: false),
      });
    }));
    _subs.add(socket.busVisibleStream.listen((bus) {
      final previous = state.buses[bus.busId];
      if (previous == null) {
        // El evento trae la posición real del bus (sin los campos de
        // catálogo como online/visible): si hay posición, lo insertamos
        // visible con su posición; si no la hay, lo insertamos visible
        // sin posición (aparecerá gris hasta que publique).
        if (bus.lat != null && bus.lon != null) {
          state = state.copyWith(
            buses: {
              ...state.buses,
              bus.busId: bus.copyWith(visible: true, online: false),
            },
          );
        } else {
          state = state.copyWith(buses: {
            ...state.buses,
            bus.busId: FleetBus(
              busId: bus.busId,
              companyId: bus.companyId,
              visible: true,
              online: false,
            ),
          });
        }
        return;
      }
      state = state.copyWith(buses: {
        ...state.buses,
        bus.busId: previous.copyWith(
          visible: true,
          // La posición cruda del evento no trae `online` (sería false):
          // conservamos el estado real del bus para no marcarlo como "Sin señal".
          online: previous.online,
          lat: bus.lat,
          lon: bus.lon,
          heading: bus.heading,
          speedKmh: bus.speedKmh,
          capturedAt: bus.capturedAt,
          receivedAt: bus.receivedAt,
          sequence: bus.sequence,
          isGhost: bus.isGhost,
        ),
      });
    }));
    _subs.add(socket.busLeftStream.listen((busId) {
      final previous = state.buses[busId];
      if (previous == null) return;
      state = state.copyWith(buses: {
        ...state.buses,
        busId: previous.copyWith(online: false, clearPosition: true),
      });
    }));
    _subs.add(socket.busRemovedStream.listen((busId) {
      final remaining = {...state.buses}..remove(busId);
      state = state.copyWith(
        buses: remaining,
        selectedBusId: () => state.selectedBusId == busId ? null : state.selectedBusId,
      );
    }));
    socket.connect();
    refreshRoutes();
    // Fallback REST: pobla la lista de buses registrados aunque el socket
    // tarde o falle, y asegura que aparezcan los buses sin posición.
    refresh();
  }

  Future<void> refresh() async {
    final token = _token;
    if (token == null) return;
    try {
      final buses = await _api.fetchPositions(token);
      state = state.copyWith(
        buses: {for (final b in buses) b.busId: b},
        clearError: true,
      );
    } catch (e) {
      if (_onSessionExpired(e)) return;
      state = state.copyWith(error: 'No se pudo actualizar la flota.');
    }
  }

  Future<void> refreshRoutes() async {
    final token = _token;
    if (token == null) return;
    try {
      final routes = await _api.fetchRoutes(token);
      state = state.copyWith(
        routes: routes,
        routeFilter: () => state.routeFilter ?? (routes.isNotEmpty ? routes.first.routeId : null),
        clearError: true,
      );
    } catch (e) {
      if (_onSessionExpired(e)) return;
      // El catálogo es informativo; no bloquea la flota.
    }
  }

  void selectBus(String? busId) {
    state = state.copyWith(selectedBusId: () => busId);
  }

  /// Cierra el socket de flota y reinicia el estado (usado al cerrar sesión:
  /// sin esto el socket seguía vivo consumiendo datos con la sesión muerta).
  void stop() {
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
    _socket?.dispose();
    _socket = null;
    state = const FleetState(
      connection: FleetConnection.disconnected,
    );
  }

  /// Resetea la bandera de sesión expirada una vez el dashboard la mostró.
  void acknowledgeSessionExpired() {
    if (state.sessionExpired) {
      state = state.copyWith(sessionExpired: false);
    }
  }

  void setRouteFilter(String? routeId) {
    state = state.copyWith(routeFilter: () => routeId);
  }

  void setStatusFilter(FleetStatusFilter filter) {
    state = state.copyWith(statusFilter: filter);
  }

  Future<void> addRoute({required String name}) async {
    final token = _token;
    if (token == null) return;
    try {
      final route = await _api.createRoute(token, name: name);
      debugPrint('[fleet] ruta creada ${route.routeId}');
      state = state.copyWith(
        routes: [...state.routes, route],
        clearError: true,
      );
    } catch (e) {
      debugPrint('[fleet] crear ruta FALLÓ: $e');
      if (_onSessionExpired(e)) throw const SessionExpiredException();
      final message = e is DioException && e.response?.data is Map
          ? e.response!.data['error'] is Map
              ? (((e.response!.data as Map)['error'] as Map)['message']?.toString() ??
                  'No se pudo crear la ruta.')
              : 'No se pudo crear la ruta.'
          : 'No se pudo crear la ruta.';
      state = state.copyWith(error: message);
      throw Exception(message);
    }
  }

  Future<void> renameRoute(String routeId, {required String name}) async {
    final token = _token;
    if (token == null) return;
    try {
      final route = await _api.renameRoute(token, routeId, name: name);
      debugPrint('[fleet] ruta renombrada ${route.routeId} -> ${route.name}');
      state = state.copyWith(
        routes: [
          for (final r in state.routes) r.routeId == routeId ? route : r,
        ],
        clearError: true,
      );
      refreshRoutes();
    } catch (e) {
      debugPrint('[fleet] renombrar ruta FALLÓ: $e');
      if (_onSessionExpired(e)) throw const SessionExpiredException();
      final message = e is DioException && e.response?.data is Map
          ? e.response!.data['error'] is Map
              ? (((e.response!.data as Map)['error'] as Map)['message']?.toString() ??
                  'No se pudo renombrar la ruta.')
              : 'No se pudo renombrar la ruta.'
          : 'No se pudo renombrar la ruta.';
      state = state.copyWith(error: message);
      throw Exception(message);
    }
  }

  Future<void> removeRoute(String routeId) async {
    final token = _token;
    if (token == null) return;
    try {
      await _api.deleteRoute(token, routeId);
      debugPrint('[fleet] ruta eliminada $routeId');
      state = state.copyWith(
        routes: state.routes.where((r) => r.routeId != routeId).toList(),
        routeFilter: () => state.routeFilter == routeId ? null : state.routeFilter,
        clearError: true,
      );
      refreshRoutes();
      refresh();
    } catch (e) {
      debugPrint('[fleet] eliminar ruta FALLÓ: $e');
      if (_onSessionExpired(e)) throw const SessionExpiredException();
      state = state.copyWith(error: 'No se pudo eliminar la ruta.');
      rethrow;
    }
  }

  Future<void> toggleVisibility(String busId, bool visible) async {
    final token = _token;
    final previous = state.buses[busId];
    if (token == null || previous == null) return;
    state = state.copyWith(
      buses: {...state.buses, busId: previous.copyWith(visible: visible)},
      updating: {...state.updating, busId},
      clearError: true,
    );
    try {
      await _api.setVisibility(token, busId, visible);
      debugPrint('[fleet] toggle $busId -> visible=$visible OK');
    } catch (e) {
      debugPrint('[fleet] toggle $busId FALLÓ: $e');
      if (_onSessionExpired(e)) return;
      state = state.copyWith(
        buses: {...state.buses, busId: previous},
        error: visible ? 'No se pudo mostrar el bus $busId.' : 'No se pudo ocultar el bus $busId.',
      );
    } finally {
      state = state.copyWith(
        updating: {...state.updating}..remove(busId),
      );
    }
  }

  Future<void> setAllVisibility(bool visible) async {
    final token = _token;
    if (token == null) return;
    final previous = state.buses;
    state = state.copyWith(
      buses: {
        for (final entry in previous.entries) entry.key: entry.value.copyWith(visible: visible),
      },
      clearError: true,
    );
    try {
      final count = await _api.setAllVisibility(token, visible);
      debugPrint('[fleet] $count buses -> visible=$visible OK');
    } catch (e) {
      debugPrint('[fleet] visibilidad masiva FALLÓ: $e');
      if (_onSessionExpired(e)) return;
      state = state.copyWith(
        buses: previous,
        error: visible ? 'No se pudieron mostrar los buses.' : 'No se pudieron ocultar los buses.',
      );
    }
  }

  Future<void> addBus({required String placa, String? routeId, String? interno}) async {
    final token = _token;
    if (token == null) return;
    try {
      final bus = await _api.createBus(token, placa: placa, routeId: routeId, interno: interno);
      debugPrint('[fleet] bus creado ${bus.busId} placa=${bus.placa} ruta=${bus.routeId} interno=${bus.interno}');
      state = state.copyWith(
        buses: {...state.buses, bus.busId: bus},
        clearError: true,
      );
      refreshRoutes();
    } catch (e) {
      debugPrint('[fleet] crear bus FALLÓ: $e');
      if (_onSessionExpired(e)) throw const SessionExpiredException();
      state = state.copyWith(error: 'No se pudo crear el bus. Verifica la placa.');
      rethrow;
    }
  }

  Future<void> editBus(
    String busId, {
    String? placa,
    String? routeId,
    String? interno,
  }) async {
    final token = _token;
    if (token == null) return;
    try {
      final bus = await _api.updateBus(token, busId, placa: placa, routeId: routeId, interno: interno);
      debugPrint('[fleet] bus editado $busId placa=${bus.placa} ruta=${bus.routeId} interno=${bus.interno}');
      state = state.copyWith(
        buses: {...state.buses, bus.busId: bus},
        clearError: true,
      );
      refreshRoutes();
    } catch (e) {
      debugPrint('[fleet] editar bus FALLÓ: $e');
      if (_onSessionExpired(e)) throw const SessionExpiredException();
      state = state.copyWith(error: 'No se pudo guardar el bus.');
      rethrow;
    }
  }

  Future<void> removeBus(String busId) async {
    final token = _token;
    if (token == null) return;
    try {
      await _api.deleteBus(token, busId);
      debugPrint('[fleet] bus eliminado $busId');
      final remaining = {...state.buses}..remove(busId);
      state = state.copyWith(
        buses: remaining,
        selectedBusId: () => state.selectedBusId == busId ? null : state.selectedBusId,
        clearError: true,
      );
      refreshRoutes();
    } catch (e) {
      debugPrint('[fleet] eliminar bus FALLÓ: $e');
      if (_onSessionExpired(e)) throw const SessionExpiredException();
      state = state.copyWith(error: 'No se pudo eliminar el bus.');
      rethrow;
    }
  }

  Future<int> removeAllBuses() async {
    final token = _token;
    if (token == null) return 0;
    try {
      final count = await _api.deleteAllBuses(token);
      debugPrint('[fleet] debug: $count buses eliminados');
      state = state.copyWith(
        buses: const <String, FleetBus>{},
        selectedBusId: () => null,
        clearError: true,
      );
      refreshRoutes();
      return count;
    } catch (e) {
      debugPrint('[fleet] borrar todos FALLÓ: $e');
      if (_onSessionExpired(e)) throw const SessionExpiredException();
      state = state.copyWith(error: 'No se pudieron borrar los buses.');
      rethrow;
    }
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
    _socket?.dispose();
    super.dispose();
  }
}

final fleetProvider = StateNotifierProvider<FleetNotifier, FleetState>((ref) {
  return FleetNotifier(ref);
});
