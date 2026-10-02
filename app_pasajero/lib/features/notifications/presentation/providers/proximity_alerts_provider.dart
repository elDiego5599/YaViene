import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import '../../../../core/services/bus_notification_service.dart';
import '../../../map/presentation/providers/tracking_providers.dart';
import '../../../map/presentation/providers/user_location_provider.dart';
import '../../../map/presentation/utils/geo.dart';
import 'alert_history_provider.dart';

/// Radio en el que se dispara el aviso (m).
const int alertRadiusMeters = 1000;

/// Distancia a la que se "rearma" el aviso de un bus para poder volver a
/// notificar si el bus se aleja y regresa (histéresis). Debe ser MAYOR al
/// radio de alerta: si fuera menor, un bus entre rearm y radio (p. ej. a
/// 900 m) dispararía otra vez al instante cada vez que se re-arma el aviso.
const int alertReArmMeters = 1500;

/// Firma del disparo de notificación (inyectable en tests). Devuelve si el
/// aviso llegó a mostrarse: un aviso que no se mostró no se da por enviado.
typedef BusNearNotifier = Future<bool> Function({
  required String busId,
  String? routeName,
  String? routeId,
  required int distanceMeters,
});

/// Si el teléfono puede enseñar un aviso ahora (inyectable en tests).
typedef PermisoDeAvisos = Future<bool> Function();

/// Hay avisos armados que no pueden sonar porque las notificaciones de la
/// app están apagadas. Lo pone el barrido cuando un aviso no se pudo
/// mostrar y lo lee la hoja del mapa para decirlo (auditoría 2026-09, H2).
final avisosSinPermisoProvider = StateProvider<bool>((ref) => false);

/// Vigila el bus con alerta activa (selección única) y dispara una notificación
/// local cuando entra al radio de [alertRadiusMeters] de la ubicación
/// del usuario (GPS o pin). Cada bus notifica por separado y solo una vez por
/// acercamiento.
class ProximityAlertsNotifier extends StateNotifier<Set<String>> {
  ProximityAlertsNotifier(
    this._ref, {
    BusNearNotifier? notify,
    PermisoDeAvisos? permiso,
    DateTime Function()? ahora,
  })  : _notify = notify ?? _defaultNotify,
        _permiso = permiso ?? BusNotificationService.puedeAvisar,
        _ahora = ahora ?? DateTime.now,
        super({}) {
    _ref.listen<UserLocationState>(userLocationProvider, _alMoverUbicacion);
  }

  final Ref _ref;
  final BusNearNotifier _notify;
  final PermisoDeAvisos _permiso;

  /// Reloj con el que se decide si un aviso venció (inyectable en tests:
  /// esperar tres horas de verdad no es una prueba).
  final DateTime Function() _ahora;
  Timer? _timer;

  /// Ruta a la que pertenece cada bus con aviso armado. Necesaria para que el
  /// aviso siga midiendo aunque el usuario esté viendo otra ruta.
  final _alertRoutes = <String, String>{};

  /// Referencia geográfica de cada aviso armado con pin manual (snapshot de
  /// la ubicación al armarse). `null` = se mide en vivo contra la ubicación
  /// actual (GPS activo, o todavía sin ubicación al armar).
  final _alertRefs = <String, (double, double)?>{};

  /// Suscripciones de posiciones por ruta armada: solo se mantienen mientras
  /// haya avisos activos en esa ruta.
  final _routeSubs =
      <String, ProviderSubscription<AsyncValue<List<BusPosition>>>>{};
  final _routePositions = <String, List<BusPosition>>{};
  bool _monitoringPaused = false;

  static Future<bool> _defaultNotify({
    required String busId,
    String? routeName,
    String? routeId,
    required int distanceMeters,
  }) =>
      BusNotificationService.notifyBusNear(
        busId: busId,
        routeName: routeName,
        routeId: routeId,
        distanceMeters: distanceMeters,
      );

  /// BusIds que ya notificaron su acercamiento (armados): no vuelven a
  /// notificar hasta que se alejen más de [alertReArmMeters].

  void start() {
    if (_timer != null) return;
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _check());
  }

  /// Detiene el timer periódico. Idempotente; [start] lo relanza.
  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Fuerza una verificación (útil en tests).
  Future<void> check() => _check();

  /// Re-arma los avisos activos persistidos (al reabrir la app o al volver
  /// al mapa). Idempotente: un aviso ya armado en memoria no se duplica. Las
  /// entradas "enviadas" no se re-arman.
  Future<void> restore() async {
    _monitoringPaused = true;
    try {
      await _ref.read(alertHistoryProvider.notifier).load();
      final entries = _ref.read(alertHistoryProvider);
      for (final e in entries) {
        if (!e.sent) rearmar(e);
      }
    } finally {
      _monitoringPaused = false;
    }
    // Al abrir la app con avisos armados se mira si pueden sonar: el
    // permiso se pudo quitar en Ajustes mientras la app estaba cerrada.
    if (_ref.read(activeAlertsProvider).isNotEmpty) {
      _anotarPermiso(await _preguntarPermiso());
    }
  }

  /// Vuelve a armar un aviso que está en el historial, con su ancla de
  /// entonces. Lo usan [restore] y el «Deshacer» de la pantalla de avisos.
  /// `false` si no cabe: ya hay 2 activos.
  bool rearmar(AlertHistoryEntry e) {
    if (e.routeId.isEmpty) return false;
    final wasMonitoring =
        _alertRoutes[e.busId] == e.routeId && _routeSubs.containsKey(e.routeId);
    if (!_ref.read(activeAlertsProvider.notifier).activateAlert(e.busId)) {
      return false;
    }
    if (!wasMonitoring) {
      // Ancla guardada, no la ubicación de ahora: re-armar leyendo la
      // posición actual mudaba el aviso al pin nuevo (o lo dejaba en
      // vivo si el GPS todavía no había respondido).
      _armMonitoring(
        e.busId,
        e.routeId,
        recordHistory: false,
        ancla: e.refLat != null && e.refLon != null
            ? (e.refLat!, e.refLon!)
            : null,
      );
    }
    return true;
  }

  /// Pregunta al sistema; `null` si no contesta (sin plugin, o un error del
  /// canal): no saber no cambia lo que la hoja ya dice.
  Future<bool?> _preguntarPermiso() async {
    try {
      return await _permiso();
    } catch (e) {
      debugPrint('no se pudo leer el permiso de notificaciones: $e');
      return null;
    }
  }

  void _anotarPermiso(bool? concedido) {
    if (!mounted || concedido == null) return;
    _ref.read(avisosSinPermisoProvider.notifier).state = !concedido;
  }

  /// Registra la ruta del bus al armar el aviso y suscribe posiciones de esa
  /// ruta: el aviso mide aunque la pantalla esté mostrando otra ruta.
  void armAlert(String busId, String routeId) {
    _armMonitoring(
      busId,
      routeId,
      recordHistory: true,
      ancla: _anclaActual(),
    );
  }

  /// Punto de espera al que se fija un aviso nuevo: el pin manual de ahora.
  /// Con GPS activo queda `null` → el aviso mide en vivo, porque ahí el punto
  /// de espera es el usuario, que se mueve con él.
  (double, double)? _anclaActual() {
    final location = _ref.read(userLocationProvider);
    return location.mode == UserLocationMode.manual && location.hasPosition
        ? (location.lat!, location.lon!)
        : null;
  }

  /// Un aviso armado con GPS no tiene ancla: mide desde la persona, que se
  /// mueve con él. Pero al poner o arrastrar el pin, «en vivo» pasaba a ser
  /// el pin y el aviso se mudaba con él (lo vio el dueño, 2026-09-28). Al
  /// pasar de GPS a pin, esos avisos se quedan donde estaba el GPS. Solo en
  /// ese paso: GPS → «ubicando» es el mismo GPS volviendo a leer.
  void _alMoverUbicacion(UserLocationState? antes, UserLocationState ahora) {
    if (antes == null ||
        antes.mode != UserLocationMode.gps ||
        !antes.hasPosition ||
        ahora.mode != UserLocationMode.manual) {
      return;
    }
    final donde = (antes.lat!, antes.lon!);
    final historial = _ref.read(alertHistoryProvider.notifier);
    for (final busId in _alertRoutes.keys) {
      if (_alertRefs[busId] != null) continue;
      _alertRefs[busId] = donde;
      historial.fijarAncla(busId, donde.$1, donde.$2);
    }
  }

  /// Ancla de un aviso armado, para que la pantalla mida la distancia desde
  /// el mismo punto desde el que mide el aviso.
  (double, double)? anchorFor(String busId) => _alertRefs[busId];

  void _armMonitoring(
    String busId,
    String routeId, {
    required bool recordHistory,
    required (double, double)? ancla,
  }) {
    _monitoringPaused = false;
    _alertRoutes[busId] = routeId;
    // Re-armado limpio: si este bus ya notificó su acercamiento antes (quedó
    // marcado en `state`), se borra esa marca para que pueda volver a sonar
    // en un nuevo acercamiento; si no, el aviso re-armado quedaba "muerto".
    state = {...state}..remove(busId);
    // Registro en el historial: la activación queda anotada (y es la fuente
    // de persistencia para re-armar al volver a abrir la app).
    if (recordHistory) {
      _ref.read(alertHistoryProvider.notifier).upsert(
            busId,
            routeId: routeId,
            routeName: _ref.read(selectedRouteProvider)?.name,
            refLat: ancla?.$1,
            refLon: ancla?.$2,
          );
    }
    // Ancla del aviso: el punto de espera con el que se armó. Aunque luego se
    // quite el pin (sin GPS la app queda sin ubicación) o se ponga otro pin
    // para armar otro bus, este aviso sigue midiendo desde donde se armó.
    _alertRefs[busId] = ancla;
    _routeSubs.putIfAbsent(routeId, () {
      return _ref.listen<AsyncValue<List<BusPosition>>>(
        busPositionsSourceProvider(routeId),
        (previous, next) {
          _routePositions[routeId] = next.value ?? const [];
        },
        fireImmediately: true,
      );
    });
  }

  /// Olvida la ruta del bus; si era el último aviso de esa ruta, se cierra la
  /// suscripción (se desuscribe del socket).
  void disarmAlert(String busId) {
    _alertRefs.remove(busId);
    final routeId = _alertRoutes.remove(busId);
    if (routeId == null) return;
    if (!_alertRoutes.containsValue(routeId)) {
      _routeSubs.remove(routeId)?.close();
      _routePositions.remove(routeId);
    }
  }

  /// Limpia el registro de avisos disparados/rearmados.
  void clear() {
    _monitoringPaused = false;
    state = {};
    _alertRoutes.clear();
    _alertRefs.clear();
    for (final sub in _routeSubs.values) {
      sub.close();
    }
    _routeSubs.clear();
    _routePositions.clear();
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final sub in _routeSubs.values) {
      sub.close();
    }
    _routeSubs.clear();
    _alertRefs.clear();
    super.dispose();
  }

  /// Retira los avisos que pasaron su [vidaDeUnAviso] sin sonar: el caso
  /// típico es un bus que se fue al patio, donde lo ocultan, y no volvió.
  /// Se van igual que uno desactivado a mano: fuera de los activos, sin
  /// suscripción y fuera del historial.
  void _vencer(Set<String> alerts) {
    final ahora = _ahora();
    for (final e in _ref.read(alertHistoryProvider)) {
      if (!alerts.contains(e.busId) || !avisoVencido(e, ahora)) continue;
      _ref.read(activeAlertsProvider.notifier).deactivateAlert(e.busId);
      disarmAlert(e.busId);
      _ref.read(alertHistoryProvider.notifier).remove(e.busId);
      if (state.contains(e.busId)) state = {...state}..remove(e.busId);
    }
  }

  /// Hay un barrido en curso. `Timer.periodic` dispara cada 5 s sin esperar
  /// a que el anterior termine, y el barrido espera a que cada notificación
  /// se muestre: el primer aviso en iOS se queda esperando a que la persona
  /// conteste el permiso, y ese rato puede durar varios ticks. El tick
  /// siguiente veía el mismo bus dentro del radio, todavía sin marcar, y lo
  /// avisaba otra vez. Mientras uno corre, los que llegan se saltan; el
  /// siguiente tick libre vuelve a medir con datos frescos.
  bool _checkInFlight = false;

  Future<void> _check() async {
    if (_checkInFlight) return;
    _checkInFlight = true;
    try {
      await _checkOnce();
    } finally {
      _checkInFlight = false;
    }
  }

  Future<void> _checkOnce() async {
    if (_monitoringPaused) return;
    final alerts = _ref.read(activeAlertsProvider);
    if (alerts.isEmpty) {
      if (state.isNotEmpty) state = {};
      return;
    }
    _vencer(alerts);
    final location = _ref.read(userLocationProvider);
    // Referencia por defecto: la ubicación actual (GPS o pin). Un aviso armado
    // con pin manual usa SU snapshot (_alertRefs) aunque la ubicación actual
    // haya desaparecido (pin quitado) o haya cambiado (pin nuevo): por eso ya
    // no se sale temprano cuando no hay posición en vivo.
    final liveRef =
        location.hasPosition ? (location.lat!, location.lon!) : null;

    final rearm = <String>{};
    final fire = <String, int>{};
    for (final busId in _ref.read(activeAlertsProvider)) {
      // Preferir la ruta registrada o la del historial. El último fallback
      // conserva compatibilidad con un aviso efímero armado por un consumidor
      // antiguo que solo marcó activeAlerts; durante logout está bloqueado por
      // `_monitoringPaused`, así que no puede medir otra ruta por accidente.
      var routeId = _alertRoutes[busId];
      if (routeId == null) {
        for (final entry in _ref.read(alertHistoryProvider)) {
          if (entry.busId == busId && !entry.sent && entry.routeId.isNotEmpty) {
            routeId = entry.routeId;
            break;
          }
        }
      }
      routeId ??= _ref.read(selectedRouteProvider)?.id;
      if (routeId == null) continue;
      final positions = _routePositions[routeId] ??
          _ref.read(busPositionsSourceProvider(routeId)).value ??
          const <BusPosition>[];
      // Sin posición (o sin señal): no hay nada que medir todavía.
      BusPosition? pos;
      for (final p in positions) {
        if (p.busId == busId) {
          pos = p;
          break;
        }
      }
      if (pos == null || pos.isGhostBus) continue;
      final ref = _alertRefs[busId] ?? liveRef;
      if (ref == null) continue;
      final distance = haversineMeters(ref.$1, ref.$2, pos.lat, pos.lon);
      if (state.contains(busId)) {
        if (distance > alertReArmMeters) rearm.add(busId);
      } else if (distance <= alertRadiusMeters) {
        fire[busId] = distance.round();
      }
    }

    if (fire.isNotEmpty) {
      // Sólo los que de verdad se mostraron. El resto se queda como está
      // —armado, activo y sin marcar— y el barrido de dentro de cinco
      // segundos lo vuelve a intentar mientras el bus siga dentro del radio.
      final enviados = <String>{};
      var fallidos = 0;
      for (final entry in fire.entries) {
        // Nombre de ruta y placa del bus para el texto de la notificación.
        String? routeName;
        for (final e in _ref.read(alertHistoryProvider)) {
          if (e.busId == entry.key) {
            routeName = e.routeName;
            break;
          }
        }
        final mostrado = await _notify(
          busId: entry.key,
          routeName: routeName,
          routeId: _alertRoutes[entry.key],
          distanceMeters: entry.value,
        );
        if (!mounted) return;
        if (!mostrado) {
          fallidos++;
          continue;
        }
        enviados.add(entry.key);
        // El aviso ya se envió: pasa a "enviado" en el historial, sale de la
        // lista de alertas activas (visible en la pantalla de
        // Notificaciones) y se libera la suscripción de su ruta.
        _ref.read(alertHistoryProvider.notifier).markSent(entry.key);
        _ref.read(activeAlertsProvider.notifier).deactivateAlert(entry.key);
        disarmAlert(entry.key);
      }
      // Uno que sonó prueba que hay permiso. Si ninguno sonó se pregunta,
      // para que la hoja diga por qué el aviso no llega.
      if (enviados.isNotEmpty) {
        _anotarPermiso(true);
      } else if (fallidos > 0) {
        _anotarPermiso(await _preguntarPermiso());
      }
      if (!mounted) return;
      if (enviados.isNotEmpty) {
        state = {...state, ...enviados}..removeAll(rearm);
      } else if (rearm.isNotEmpty) {
        state = {...state}..removeAll(rearm);
      }
    } else if (rearm.isNotEmpty) {
      state = {...state}..removeAll(rearm);
    }
  }
}

final proximityAlertsProvider =
    StateNotifierProvider<ProximityAlertsNotifier, Set<String>>((ref) {
  return ProximityAlertsNotifier(ref);
});
