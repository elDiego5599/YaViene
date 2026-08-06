import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/fleet_api.dart';
import '../../data/fleet_socket_service.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/fleet_bus.dart';
import '../../domain/fleet_route.dart';

enum FleetConnection { connecting, connected, disconnected }

class FleetState {
  const FleetState({
    this.connection = FleetConnection.connecting,
    this.buses = const <String, FleetBus>{},
    this.routes = const <FleetRoute>[],
    this.error,
    this.updating = const <String>{},
    this.selectedBusId,
    this.routeFilter,
  });

  final FleetConnection connection;
  final Map<String, FleetBus> buses;
  final List<FleetRoute> routes;
  final String? error;
  final Set<String> updating;
  final String? selectedBusId;
  final String? routeFilter;

  FleetBus? get selectedBus {
    final id = selectedBusId;
    return id == null ? null : buses[id];
  }

  List<FleetBus> get fleetList {
    final list = buses.values.where((b) {
      final filter = routeFilter;
      return filter == null || b.routeId == filter;
    }).toList()
      ..sort((a, b) => a.busId.compareTo(b.busId));
    return list;
  }

  int get totalBuses => buses.length;
  int get onlineBuses => buses.values.where((b) => b.online).length;
  int get hiddenBuses => buses.values.where((b) => !b.visible).length;
  int get offlineBuses => buses.values.where((b) => !b.online).length;

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
    );
  }
}

class FleetNotifier extends StateNotifier<FleetState> {
  FleetNotifier(this._ref) : super(const FleetState());

  final Ref _ref;
  FleetSocketService? _socket;

  String? get _token => _ref.read(authProvider).session?.token;

  void start() {
    final token = _token;
    if (token == null) return;
    _socket?.dispose();
    final socket = FleetSocketService(token: token);
    _socket = socket;
    socket.connectionStream.listen((connected) {
      state = state.copyWith(
        connection: connected ? FleetConnection.connected : FleetConnection.disconnected,
      );
    });
    socket.busBatchStream.listen((buses) {
      final map = <String, FleetBus>{for (final b in buses) b.busId: b};
      state = state.copyWith(buses: map, clearError: true);
    });
    socket.busPositionStream.listen((bus) {
      final previous = state.buses[bus.busId];
      state = state.copyWith(buses: {
        ...state.buses,
        bus.busId: bus.copyWith(
          online: true,
          visible: previous?.visible ?? bus.visible,
        ),
      });
    });
    socket.busHiddenStream.listen((busId) {
      final previous = state.buses[busId];
      if (previous == null) return;
      state = state.copyWith(buses: {
        ...state.buses,
        busId: previous.copyWith(visible: false),
      });
    });
    socket.busVisibleStream.listen((bus) {
      final previous = state.buses[bus.busId];
      state = state.copyWith(buses: {
        ...state.buses,
        bus.busId: bus.copyWith(
          visible: true,
          online: previous?.online ?? true,
        ),
      });
    });
    socket.busLeftStream.listen((busId) {
      final previous = state.buses[busId];
      if (previous == null) return;
      state = state.copyWith(buses: {
        ...state.buses,
        busId: previous.copyWith(online: false, clearPosition: true),
      });
    });
    socket.busRemovedStream.listen((busId) {
      final remaining = {...state.buses}..remove(busId);
      state = state.copyWith(
        buses: remaining,
        selectedBusId: () => state.selectedBusId == busId ? null : state.selectedBusId,
      );
    });
    socket.connect();
    refreshRoutes();
  }

  Future<void> refresh() async {
    final token = _token;
    if (token == null) return;
    try {
      final buses = await FleetApi().fetchPositions(token);
      state = state.copyWith(
        buses: {for (final b in buses) b.busId: b},
        clearError: true,
      );
    } catch (_) {
      state = state.copyWith(error: 'No se pudo actualizar la flota.');
    }
  }

  Future<void> refreshRoutes() async {
    final token = _token;
    if (token == null) return;
    try {
      final routes = await FleetApi().fetchRoutes(token);
      state = state.copyWith(routes: routes, clearError: true);
    } catch (_) {
      // El catálogo es informativo; no bloquea la flota.
    }
  }

  void selectBus(String? busId) {
    state = state.copyWith(selectedBusId: () => busId);
  }

  void setRouteFilter(String? routeId) {
    state = state.copyWith(routeFilter: () => routeId);
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
      await FleetApi().setVisibility(token, busId, visible);
      debugPrint('[fleet] toggle $busId -> visible=$visible OK');
    } catch (e) {
      debugPrint('[fleet] toggle $busId FALLÓ: $e');
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

  Future<void> addBus({required String placa, String? routeId}) async {
    final token = _token;
    if (token == null) return;
    try {
      final bus = await FleetApi().createBus(token, placa: placa, routeId: routeId);
      debugPrint('[fleet] bus creado ${bus.busId} placa=${bus.placa} ruta=${bus.routeId}');
      state = state.copyWith(
        buses: {...state.buses, bus.busId: bus},
        clearError: true,
      );
      refreshRoutes();
    } catch (e) {
      debugPrint('[fleet] crear bus FALLÓ: $e');
      state = state.copyWith(error: 'No se pudo crear el bus. Verifica la placa.');
      rethrow;
    }
  }

  Future<void> editBus(
    String busId, {
    String? placa,
    String? routeId,
  }) async {
    final token = _token;
    if (token == null) return;
    try {
      final bus = await FleetApi().updateBus(token, busId, placa: placa, routeId: routeId);
      debugPrint('[fleet] bus editado $busId placa=${bus.placa} ruta=${bus.routeId}');
      state = state.copyWith(
        buses: {...state.buses, bus.busId: bus},
        clearError: true,
      );
      refreshRoutes();
    } catch (e) {
      debugPrint('[fleet] editar bus FALLÓ: $e');
      state = state.copyWith(error: 'No se pudo guardar el bus.');
      rethrow;
    }
  }

  Future<void> removeBus(String busId) async {
    final token = _token;
    if (token == null) return;
    try {
      await FleetApi().deleteBus(token, busId);
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
      state = state.copyWith(error: 'No se pudo eliminar el bus.');
      rethrow;
    }
  }

  @override
  void dispose() {
    _socket?.dispose();
    super.dispose();
  }
}

final fleetProvider = StateNotifierProvider<FleetNotifier, FleetState>((ref) {
  return FleetNotifier(ref);
});
