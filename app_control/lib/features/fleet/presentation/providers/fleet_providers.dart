import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:ya_viene_core/core/models/bus_position.dart' show esMasNueva;
// Solo el provider de la URL: el resto del paquete choca con el tema local.
import 'package:ya_viene_core/core/providers/app_providers.dart'
    show backendUrlProvider;

import '../../../auth/domain/auth_session.dart';
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
    this.flotaCargada = false,
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

  /// Ya llegó una foto entera de la flota (REST o lote del socket). Antes de
  /// eso una lista vacía no quiere decir «sin buses», sino «aún no sé».
  final bool flotaCargada;

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
    }).toList()..sort((a, b) => a.busId.compareTo(b.busId));
    return list;
  }

  List<FleetBus> get _routeScoped => routeFilter == null
      ? buses.values.toList()
      : buses.values.where((b) => b.routeId == routeFilter).toList();

  /// [fleetList] filtrada por lo que el operador escribe en el buscador del
  /// dashboard: placa, número de bus, interno o ruta. El conductor no: ya no
  /// se ve en el panel, y un resultado que no dice por qué salió confunde.
  List<FleetBus> buscar(String query) {
    if (query.isEmpty) return fleetList;
    final q = query.toLowerCase();
    return fleetList.where((b) {
      final nombreRuta = routeName(b.routeId) ?? '';
      return b.placa.toLowerCase().contains(q) ||
          b.busId.replaceFirst('BUS-', '').toLowerCase().contains(q) ||
          b.interno.toLowerCase().contains(q) ||
          (b.routeId?.toLowerCase().contains(q) ?? false) ||
          nombreRuta.toLowerCase().contains(q);
    }).toList();
  }

  int get totalBuses => _routeScoped.length;
  int get onlineBuses =>
      _routeScoped.where((b) => b.online && !b.isGhost).length;
  int get hiddenBuses => _routeScoped.where((b) => !b.visible).length;
  int get offlineBuses =>
      _routeScoped.where((b) => !b.online || b.isGhost).length;

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
    bool? flotaCargada,
    bool clearError = false,
  }) {
    return FleetState(
      connection: connection ?? this.connection,
      buses: buses ?? this.buses,
      routes: routes ?? this.routes,
      error: clearError ? null : error ?? this.error,
      updating: updating ?? this.updating,
      selectedBusId: selectedBusId != null
          ? selectedBusId()
          : this.selectedBusId,
      routeFilter: routeFilter != null ? routeFilter() : this.routeFilter,
      statusFilter: statusFilter ?? this.statusFilter,
      sessionExpired: sessionExpired ?? this.sessionExpired,
      flotaCargada: flotaCargada ?? this.flotaCargada,
    );
  }
}

class FleetNotifier extends StateNotifier<FleetState> {
  FleetNotifier(
    this._ref, {
    FleetApi? api,
    this.resincronizarCada = const Duration(seconds: 60),
  }) : _apiFija = api,
       super(const FleetState());

  final Ref _ref;
  final FleetApi? _apiFija;

  /// Cada cuánto el panel vuelve a pedir la flota por REST mientras está
  /// abierto. Es un parámetro para que las pruebas no esperen un minuto.
  final Duration resincronizarCada;
  FleetSocketService? _socket;
  final List<StreamSubscription> _subs = [];
  Timer? _recarga;

  /// El latido de la resincronización. El panel se enteraba de los cambios
  /// solo por el socket: un evento perdido —el socket cayó un segundo, el
  /// backend se reinició— dejaba la lista mintiendo hasta que el operador
  /// pulsaba «Recargar». La foto se funde con lo que ya hay (T2.5), así que
  /// una posición en vivo más nueva no retrocede por culpa del REST.
  Timer? _resync;

  /// Se lee en cada pedido y no una sola vez al crear el notifier: el
  /// backend puede cambiar con el panel abierto (al elegir antes del login).
  FleetApi get _api => _apiFija ?? _ref.read(fleetApiProvider);

  /// La sesión abierta. Su token es null en el navegador: ahí la sesión va
  /// en la cookie del panel y cada pedido sale sin `Authorization`.
  AuthSession? get _sesion => _ref.read(authProvider).session;

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
    _cerrarPorSesion();
    return true;
  }

  /// La bandera se queda puesta hasta `stop()` (cerrar sesión): es un
  /// hecho, no un aviso pendiente. Antes el dashboard la bajaba al mostrar
  /// la ventana y cada 401 que volvía después —flota y rutas salen juntas,
  /// más las acciones en vuelo— la volvía a subir y apilaba otra ventana
  /// encima: el dueño cerró cinco seguidas (2026-09-30).
  void _cerrarPorSesion() {
    if (state.sessionExpired) return;
    state = state.copyWith(
      sessionExpired: true,
      connection: FleetConnection.disconnected,
      error: null,
    );
    _recarga?.cancel();
    _resync?.cancel();
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
    _socket?.dispose();
    _socket = null;
  }

  void sesionRevocada() => _cerrarPorSesion();

  void start() {
    final sesion = _sesion;
    if (sesion == null) return;
    final token = sesion.token;
    // Una sesión nueva no viene expirada. Al cerrar sesión el dashboard para
    // la flota y luego sale, y esa salida llega aquí como revocación: la
    // marca quedaba puesta y, al volver a entrar, refresh y refreshRoutes no
    // pedían nada. El panel se quedaba sin rutas (dueño, 2026-10-27).
    if (state.sessionExpired) state = state.copyWith(sessionExpired: false);
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
    _socket?.dispose();
    final socket = _ref.read(fleetSocketFactoryProvider)(token);
    _socket = socket;
    _subs.add(
      socket.connectionStream.listen((connected) {
        state = state.copyWith(
          connection: connected
              ? FleetConnection.connected
              : FleetConnection.disconnected,
        );
      }),
    );
    _subs.add(socket.sessionKickedStream.listen((_) => _cerrarPorSesion()));
    _subs.add(
      socket.busBatchStream.listen((buses) {
        // Respeta el estado visible guardado en el backend: los buses que
        // quedaron habilitados/ocultos de la última sesión se ven igual. La
        // posición, solo si es más nueva que la que ya llegó en vivo.
        state = state.copyWith(
          buses: _fusionarFoto(buses),
          flotaCargada: true,
          clearError: true,
        );
      }),
    );
    _subs.add(
      socket.busPositionStream.listen((bus) {
        final previous = state.buses[bus.busId];
        // La misma regla que getFleetPositions en el backend (fleet_admin.ts):
        // en línea es haber reportado y no ser fantasma. Antes se marcaba
        // `true` siempre, y un evento fantasma dejaba el bus «En línea» hasta
        // que alguien pulsaba Recargar.
        final online = !bus.isGhost;
        if (previous == null) {
          // Un bus que el panel aún no conocía: lo dieron de alta en otro
          // panel, o el REST del arranque no ha vuelto. Entra con lo que trae
          // el evento y el catálogo (placa, interno, conductor) se pide aparte.
          state = state.copyWith(
            buses: {
              ...state.buses,
              bus.busId: bus.copyWith(online: online),
            },
          );
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
        state = state.copyWith(
          buses: {
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
          },
        );
      }),
    );
    _subs.add(
      socket.busHiddenStream.listen((busId) {
        final previous = state.buses[busId];
        if (previous == null) return;
        state = state.copyWith(
          buses: {...state.buses, busId: previous.copyWith(visible: false)},
        );
      }),
    );
    _subs.add(
      socket.busVisibleStream.listen((bus) {
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
            state = state.copyWith(
              buses: {
                ...state.buses,
                bus.busId: FleetBus(
                  busId: bus.busId,
                  companyId: bus.companyId,
                  visible: true,
                  online: false,
                ),
              },
            );
          }
          return;
        }
        if (!_masNueva(bus, previous)) {
          // Vuelve a verse, pero donde ya estaba: la posición del evento es
          // más vieja que la que llegó en vivo (T2.5).
          state = state.copyWith(
            buses: {
              ...state.buses,
              bus.busId: previous.copyWith(visible: true),
            },
          );
          return;
        }
        state = state.copyWith(
          buses: {
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
          },
        );
      }),
    );
    _subs.add(
      socket.busLeftStream.listen((busId) {
        final previous = state.buses[busId];
        if (previous == null) return;
        state = state.copyWith(
          buses: {
            ...state.buses,
            busId: previous.copyWith(online: false, clearPosition: true),
          },
        );
      }),
    );
    _subs.add(
      socket.busRemovedStream.listen((busId) {
        final remaining = {...state.buses}..remove(busId);
        state = state.copyWith(
          buses: remaining,
          selectedBusId: () =>
              state.selectedBusId == busId ? null : state.selectedBusId,
        );
      }),
    );
    socket.connect();
    refreshRoutes();
    // Fallback REST: pobla la lista de buses registrados aunque el socket
    // tarde o falle, y asegura que aparezcan los buses sin posición.
    refresh();
    _resync?.cancel();
    _resync = Timer.periodic(resincronizarCada, (_) {
      refresh();
      // Sin catálogo no hay filtro de ruta y el mapa mostraría toda la flota.
      if (state.routes.isEmpty) refreshRoutes();
    });
  }

  /// La ventana del panel vuelve al frente. Un panel en segundo plano puede
  /// haberse perdido eventos —el sistema duerme la conexión— y esperar hasta
  /// un minuto para enterarse sería justo cuando el operador está mirando.
  void alVolverAlFrente() {
    if (_socket == null) return;
    refresh();
    refreshRoutes();
  }

  Future<void> refresh() async {
    final sesion = _sesion;
    if (sesion == null || state.sessionExpired) return;
    final token = sesion.token;
    try {
      final buses = await _api.fetchPositions(token);
      state = state.copyWith(
        buses: _fusionarFoto(buses),
        flotaCargada: true,
        clearError: true,
      );
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
    for (final b in foto)
      b.busId: _conPosicionMasNueva(b, state.buses[b.busId]),
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
    final sesion = _sesion;
    if (sesion == null || state.sessionExpired) return;
    final token = sesion.token;
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
  /// en cuanto el operador toca una pestaña, manda su elección. Entre dos
  /// que empatan gana la que va antes en el catálogo.
  static String? _rutaDeArranque(List<FleetRoute> routes) => routes.isEmpty
      ? null
      : routes.reduce((a, b) => b.online > a.online ? b : a).routeId;

  void selectBus(String? busId) {
    state = state.copyWith(selectedBusId: () => busId);
  }

  /// Cierra el socket de flota y reinicia el estado (usado al cerrar sesión:
  /// sin esto el socket seguía vivo consumiendo datos con la sesión muerta).
  void stop() {
    _recarga?.cancel();
    _resync?.cancel();
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
    _socket?.dispose();
    _socket = null;
    state = const FleetState(connection: FleetConnection.disconnected);
  }

  void cambiarToken() {
    if (_socket == null) return;
    start();
  }

  void setRouteFilter(String? routeId) {
    state = state.copyWith(routeFilter: () => routeId);
  }

  void setStatusFilter(FleetStatusFilter filter) {
    state = state.copyWith(statusFilter: filter);
  }

  Future<void> addRoute({required String name}) async {
    final sesion = _sesion;
    if (sesion == null) return;
    final token = sesion.token;
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
                ? (((e.response!.data as Map)['error'] as Map)['message']
                          ?.toString() ??
                      'No se pudo crear la ruta.')
                : 'No se pudo crear la ruta.'
          : 'No se pudo crear la ruta.';
      state = state.copyWith(error: message);
      throw Exception(message);
    }
  }

  Future<void> renameRoute(String routeId, {required String name}) async {
    final sesion = _sesion;
    if (sesion == null) return;
    final token = sesion.token;
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
                ? (((e.response!.data as Map)['error'] as Map)['message']
                          ?.toString() ??
                      'No se pudo renombrar la ruta.')
                : 'No se pudo renombrar la ruta.'
          : 'No se pudo renombrar la ruta.';
      state = state.copyWith(error: message);
      throw Exception(message);
    }
  }

  Future<void> removeRoute(String routeId) async {
    final sesion = _sesion;
    if (sesion == null) return;
    final token = sesion.token;
    try {
      await _api.deleteRoute(token, routeId);
      debugPrint('[fleet] ruta eliminada $routeId');
      state = state.copyWith(
        routes: state.routes.where((r) => r.routeId != routeId).toList(),
        routeFilter: () =>
            state.routeFilter == routeId ? null : state.routeFilter,
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
    final sesion = _sesion;
    final previous = state.buses[busId];
    if (sesion == null || previous == null) return;
    final token = sesion.token;
    state = state.copyWith(
      buses: {
        ...state.buses,
        busId: previous.copyWith(visible: visible),
      },
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
        error: visible
            ? 'No se pudo mostrar el bus $busId.'
            : 'No se pudo ocultar el bus $busId.',
      );
    } finally {
      state = state.copyWith(updating: {...state.updating}..remove(busId));
    }
  }

  Future<void> setAllVisibility(bool visible) async {
    final sesion = _sesion;
    if (sesion == null) return;
    final token = sesion.token;
    final previous = state.buses;
    state = state.copyWith(
      buses: {
        for (final entry in previous.entries)
          entry.key: entry.value.copyWith(visible: visible),
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
        error: visible
            ? 'No se pudieron mostrar los buses.'
            : 'No se pudieron ocultar los buses.',
      );
    }
  }

  Future<void> addBus({
    required String placa,
    String? routeId,
    String? interno,
  }) async {
    final sesion = _sesion;
    if (sesion == null) return;
    final token = sesion.token;
    try {
      final bus = await _api.createBus(
        token,
        placa: placa,
        routeId: routeId,
        interno: interno,
      );
      debugPrint(
        '[fleet] bus creado ${bus.busId} placa=${bus.placa} ruta=${bus.routeId} interno=${bus.interno}',
      );
      state = state.copyWith(
        buses: {...state.buses, bus.busId: bus},
        clearError: true,
      );
      refreshRoutes();
    } catch (e) {
      debugPrint('[fleet] crear bus FALLÓ: $e');
      if (_onSessionExpired(e)) throw const SessionExpiredException();
      state = state.copyWith(
        error: 'No se pudo crear el bus. Verifica la placa.',
      );
      rethrow;
    }
  }

  Future<void> editBus(
    String busId, {
    String? placa,
    String? routeId,
    String? interno,
  }) async {
    final sesion = _sesion;
    if (sesion == null) return;
    final token = sesion.token;
    try {
      final bus = await _api.updateBus(
        token,
        busId,
        placa: placa,
        routeId: routeId,
        interno: interno,
      );
      debugPrint(
        '[fleet] bus editado $busId placa=${bus.placa} ruta=${bus.routeId} interno=${bus.interno}',
      );
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
    final sesion = _sesion;
    if (sesion == null) return;
    final token = sesion.token;
    try {
      await _api.deleteBus(token, busId);
      debugPrint('[fleet] bus eliminado $busId');
      final remaining = {...state.buses}..remove(busId);
      state = state.copyWith(
        buses: remaining,
        selectedBusId: () =>
            state.selectedBusId == busId ? null : state.selectedBusId,
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
    _resync?.cancel();
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
final fleetIoSocketFactoryProvider = Provider<FleetIoSocketFactory>(
  (ref) => io.io,
);

/// Cómo se abre el socket de la flota, contra el mismo backend que el REST.
/// Es una fábrica y no un servicio porque el notifier cierra el socket al
/// salir y abre uno nuevo, con otro token, al volver a entrar.
final fleetSocketFactoryProvider =
    Provider<FleetSocketService Function(String? token)>((ref) {
      final baseUrl = ref.watch(backendUrlProvider);
      final crearSocket = ref.watch(fleetIoSocketFactoryProvider);
      return (token) => FleetSocketService(
        baseUrl: baseUrl,
        token: token,
        crearSocket: crearSocket,
      );
    });

final fleetProvider = StateNotifierProvider<FleetNotifier, FleetState>((ref) {
  final notifier = FleetNotifier(ref);
  ref.listen<AuthState>(authProvider, (anterior, siguiente) {
    if (anterior?.session?.token != siguiente.session?.token &&
        siguiente.session != null) {
      notifier.cambiarToken();
    } else if (anterior?.session != null &&
        siguiente.session == null &&
        siguiente.status == AuthStatus.unauthenticated) {
      notifier.sesionRevocada();
    }
  });
  return notifier;
});
