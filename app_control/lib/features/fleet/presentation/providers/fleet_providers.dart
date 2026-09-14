import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:ya_viene_core/core/models/bus_position.dart' show esMasNueva;
import 'package:ya_viene_core/core/network/backend_supervisor.dart';
// Solo el provider de la URL: el resto del paquete choca con el tema local.
import 'package:ya_viene_core/core/providers/app_providers.dart'
    show backendUrlProvider;

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

  /// [fleetList] filtrada por lo que el operador escribe en el buscador del
  /// dashboard: placa, número de bus, interno, ruta o conductor.
  List<FleetBus> buscar(String query) {
    if (query.isEmpty) return fleetList;
    final q = query.toLowerCase();
    return fleetList.where((b) {
      final nombreRuta = routeName(b.routeId) ?? '';
      return b.placa.toLowerCase().contains(q) ||
          b.busId.replaceFirst('BUS-', '').toLowerCase().contains(q) ||
          b.interno.toLowerCase().contains(q) ||
          (b.routeId?.toLowerCase().contains(q) ?? false) ||
          nombreRuta.toLowerCase().contains(q) ||
          (b.driverName?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

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
  FleetNotifier(this._ref, {FleetApi? api, this._supervisor})
      : _apiFija = api,
        super(const FleetState());

  final Ref _ref;
  final FleetApi? _apiFija;
  final BackendSupervisor? _supervisor;
  FleetSocketService? _socket;
  final List<StreamSubscription> _subs = [];
  Timer? _recarga;

  /// Se lee en cada pedido y no una sola vez al crear el notifier: el
  /// backend puede cambiar con el panel abierto (`BackendSupervisor`).
  FleetApi get _api => _apiFija ?? _ref.read(fleetApiProvider);

  String? get _token => _ref.read(authProvider).session?.token;

  /// Pide la flota por REST una sola vez aunque aparezcan varios buses
  /// nuevos seguidos: el primero arma el temporizador y los que llegan dentro
  /// del mismo segundo ya van incluidos en esa recarga.
  void _programarRecarga() {
    if (_recarga?.isActive ?? false) return;
    _recarga = Timer(const Duration(seconds: 1), () {
      refresh();
    });
  }

  /// Sesión expirada/revocada: marca el estado para que el dashboard avise y
  /// cierre sesión, y detiene la reconexión del socket.
  bool _onSessionExpired(Object e) {
    if (e is! SessionExpiredException) return false;
    state = state.copyWith(
      sessionExpired: true,
      connection: FleetConnection.disconnected,
      error: null,
    );
    _supervisor?.detener();
    _recarga?.cancel();
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
    final socket = _ref.read(fleetSocketFactoryProvider)(token);
    _socket = socket;
    _subs.add(socket.connectionStream.listen((connected) {
      // Si el socket no vuelve en 30 s, el supervisor pregunta si el
      // principal sigue vivo o toca pasar al respaldo.
      if (connected) {
        _supervisor?.conexionRecuperada();
      } else {
        _supervisor?.conexionPerdida();
      }
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
      _supervisor?.detener();
      for (final s in _subs) {
        s.cancel();
      }
      _subs.clear();
      _socket?.dispose();
      _socket = null;
    }));
    _subs.add(socket.busBatchStream.listen((buses) {
      // Respeta el estado visible guardado en el backend: los buses que
      // quedaron habilitados/ocultos de la última sesión se ven igual. La
      // posición, solo si es más nueva que la que ya llegó en vivo.
      state = state.copyWith(buses: _fusionarFoto(buses), clearError: true);
    }));
    _subs.add(socket.busPositionStream.listen((bus) {
      final previous = state.buses[bus.busId];
      debugPrint('[fleet] bus:position ${bus.busId} lat=${bus.lat} lon=${bus.lon}');
      // La misma regla que getFleetPositions en el backend (fleet_admin.ts):
      // en línea es haber reportado y no ser fantasma. Antes se marcaba
      // `true` siempre, y un evento fantasma dejaba el bus «En línea» hasta
      // que alguien pulsaba Recargar.
      final online = !bus.isGhost;
      if (previous == null) {
        // Un bus que el panel aún no conocía: lo dieron de alta en otro
        // panel, o el REST del arranque no ha vuelto. Entra con lo que trae
        // el evento y el catálogo (placa, interno, conductor) se pide aparte.
        state = state.copyWith(buses: {
          ...state.buses,
          bus.busId: bus.copyWith(online: online),
        });
        _programarRecarga();
        return;
      }
      // Una posición más vieja que la que ya tiene el bus llega tarde (el
      // socket reconectó, el respaldo va atrás): se descarta (T2.5).
      if (!_masNueva(bus, previous)) return;
      // El evento es la posición y nada más: no trae placa, interno ni
      // conductor, y `FleetBus.fromJson` los deja vacíos. Partir de él los
      // borraba en cada posición —la lista caía al busId y la búsqueda por
      // placa dejaba de encontrar—. Se parte del bus que ya estaba y solo se
      // pisa lo que el evento sí trae, como en `bus:visible`.
      state = state.copyWith(buses: {
        ...state.buses,
        bus.busId: previous.copyWith(
          online: online,
          // Como en el backend: la ruta de la posición manda sobre la del
          // catálogo. Si el evento no trae ruta, se queda la que había.
          routeId: bus.routeId,
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
      if (!_masNueva(bus, previous)) {
        // Vuelve a verse, pero donde ya estaba: la posición del evento es
        // más vieja que la que llegó en vivo (T2.5).
        state = state.copyWith(buses: {
          ...state.buses,
          bus.busId: previous.copyWith(visible: true),
        });
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
      state = state.copyWith(buses: _fusionarFoto(buses), clearError: true);
    } catch (e) {
      if (_onSessionExpired(e)) return;
      state = state.copyWith(error: 'No se pudo actualizar la flota.');
    }
  }

  /// La regla de core (`esMasNueva`) entre dos estados de un mismo bus.
  static bool _masNueva(FleetBus nuevo, FleetBus previo) => esMasNueva(
        capturaNueva: nuevo.capturedAt,
        capturaPrevia: previo.capturedAt,
        fantasmaNuevo: nuevo.isGhost,
        fantasmaPrevio: previo.isGhost,
      );

  /// Junta una foto completa de la flota (REST o `fleet:batch`) con lo que el
  /// panel ya tiene. La foto manda en qué buses hay y en su catálogo (placa,
  /// interno, conductor, visible); la posición de cada bus, solo si es más
  /// nueva que la que ya llegó en vivo. El REST pudo salir antes de ese
  /// evento y volver después, y reemplazar el mapa entero retrocedía el bus
  /// (T2.5).
  Map<String, FleetBus> _fusionarFoto(List<FleetBus> foto) => {
        for (final b in foto) b.busId: _conPosicionMasNueva(b, state.buses[b.busId]),
      };

  static FleetBus _conPosicionMasNueva(FleetBus foto, FleetBus? previo) {
    if (previo == null || _masNueva(foto, previo)) return foto;
    return foto.copyWith(
      online: previo.online,
      routeId: previo.routeId,
      lat: previo.lat,
      lon: previo.lon,
      heading: previo.heading,
      speedKmh: previo.speedKmh,
      capturedAt: previo.capturedAt,
      receivedAt: previo.receivedAt,
      sequence: previo.sequence,
      isGhost: previo.isGhost,
    );
  }

  Future<void> refreshRoutes() async {
    final token = _token;
    if (token == null) return;
    try {
      final routes = await _api.fetchRoutes(token);
      state = state.copyWith(
        routes: routes,
        routeFilter: () => state.routeFilter ?? _rutaDeArranque(routes),
        clearError: true,
      );
    } catch (e) {
      if (_onSessionExpired(e)) return;
      // El catálogo es informativo; no bloquea la flota.
    }
  }

  /// Con qué ruta se abre el panel. Era la primera del catálogo, que en la
  /// práctica es la del número más bajo y casi nunca la que tiene buses
  /// andando: el panel arrancaba en una ruta vacía y parecía que la empresa
  /// no tuviera flota. Se abre en la que más buses estén reportando; si
  /// ninguna reporta, en la primera, como antes. Solo decide el arranque:
  /// en cuanto el operador toca una pestaña, manda su elección.
  static String? _rutaDeArranque(List<FleetRoute> routes) {
    if (routes.isEmpty) return null;
    final conBuses = routes.where((r) => r.online > 0).toList()
      ..sort((a, b) => b.online.compareTo(a.online));
    return conBuses.isEmpty ? routes.first.routeId : conBuses.first.routeId;
  }

  void selectBus(String? busId) {
    state = state.copyWith(selectedBusId: () => busId);
  }

  /// Cierra el socket de flota y reinicia el estado (usado al cerrar sesión:
  /// sin esto el socket seguía vivo consumiendo datos con la sesión muerta).
  void stop() {
    _supervisor?.detener();
    _recarga?.cancel();
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

  /// El backend cambió con el panel abierto (el supervisor pasó al
  /// respaldo): cierra el socket y abre otro contra el backend nuevo, que se
  /// suscribe a la flota al conectar, y vuelve a pedir flota y rutas por
  /// REST. El filtro de ruta y el bus elegido se quedan. Si el panel no está
  /// abierto no hace nada: el próximo `start()` ya usa el backend nuevo.
  void cambiarBackend() {
    if (_socket == null) return;
    start();
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

  @override
  void dispose() {
    _recarga?.cancel();
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
    _socket?.dispose();
    super.dispose();
  }
}

/// La flota por REST, contra el backend actual: el que resolvió el arranque
/// o el respaldo si el túnel se cayó con el panel abierto.
final fleetApiProvider = Provider<FleetApi>(
  (ref) => FleetApi(baseUrl: ref.watch(backendUrlProvider)),
);

/// Con qué se abre cada socket de `socket_io_client`. Es `io.io`; las
/// pruebas lo cambian para simular el túnel y el respaldo.
final fleetIoSocketFactoryProvider =
    Provider<FleetIoSocketFactory>((ref) => io.io);

/// Cómo se abre el socket de la flota, contra el mismo backend que el REST.
/// Es una fábrica y no un servicio porque el notifier cierra el socket al
/// salir y abre uno nuevo, con otro token, al volver a entrar.
final fleetSocketFactoryProvider =
    Provider<FleetSocketService Function(String token)>((ref) {
  final baseUrl = ref.watch(backendUrlProvider);
  final crearSocket = ref.watch(fleetIoSocketFactoryProvider);
  return (token) => FleetSocketService(
        baseUrl: baseUrl,
        token: token,
        crearSocket: crearSocket,
      );
});

final fleetProvider = StateNotifierProvider<FleetNotifier, FleetState>((ref) {
  // Si el socket pasa 30 s sin conexión, el supervisor vuelve a elegir
  // backend. Si elige otro, el panel se muda sin cerrar la sesión.
  final supervisor = BackendSupervisor(
    reResolver: ref.read(backendUrlProvider.notifier).reResolver,
  );
  final notifier = FleetNotifier(ref, supervisor: supervisor);
  // Se escucha la fábrica del socket y no la URL: quien escucha la URL se
  // entera antes de que se rehagan los providers que dependen de ella, y
  // leería la fábrica y la API del backend anterior.
  ref.listen(fleetSocketFactoryProvider, (_, _) => notifier.cambiarBackend());
  ref.onDispose(supervisor.dispose);
  return notifier;
});
