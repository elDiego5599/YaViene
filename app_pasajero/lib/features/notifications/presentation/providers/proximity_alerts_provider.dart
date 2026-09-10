import 'dart:async';

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

/// Vigila el bus con alerta activa (selección única) y dispara una notificación
/// local cuando entra al radio de [alertRadiusMeters] de la ubicación
/// del usuario (GPS o pin). Cada bus notifica por separado y solo una vez por
/// acercamiento.
class ProximityAlertsNotifier extends StateNotifier<Set<String>> {
  ProximityAlertsNotifier(this._ref, {BusNearNotifier? notify})
      : _notify = notify ?? _defaultNotify,
        super({});

  final Ref _ref;
  final BusNearNotifier _notify;
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
  String? _monitoringUserId;

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

  /// Detiene el timer periódico (al cerrar sesión). Idempotente; [start] lo
  /// relanza.
  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Fuerza una verificación (útil en tests).
  Future<void> check() => _check();

  /// Re-arma los avisos activos persistidos (al reabrir la app o al volver a
  /// iniciar sesión). Idempotente: un aviso ya armado en memoria no se
  /// duplica. Las entradas "enviadas" no se re-arman.
  Future<void> restore({String? userId}) async {
    if (_monitoringUserId != userId) {
      pauseMonitoring();
      _ref.read(activeAlertsProvider.notifier).clear();
      _monitoringUserId = userId;
    }
    _monitoringPaused = true;
    try {
      await _ref.read(alertHistoryProvider.notifier).load(userId: userId);
      final entries = _ref.read(alertHistoryProvider);
      for (final e in entries) {
        if (e.sent || e.routeId.isEmpty) continue;
        final active = _ref.read(activeAlertsProvider.notifier);
        final wasMonitoring = _alertRoutes[e.busId] == e.routeId &&
            _routeSubs.containsKey(e.routeId);
        if (!active.activateAlert(e.busId)) continue;
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
      }
    } finally {
      _monitoringPaused = false;
    }
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
    _monitoringUserId = null;
    state = {};
    _alertRoutes.clear();
    _alertRefs.clear();
    for (final sub in _routeSubs.values) {
      sub.close();
    }
    _routeSubs.clear();
    _routePositions.clear();
  }

  /// Cierra el seguimiento en memoria al cerrar sesión, pero conserva los
  /// avisos activos y su historial para que [restore] los reactive al volver.
  void pauseMonitoring() {
    _monitoringPaused = true;
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

  Future<void> _check() async {
    if (_monitoringPaused) return;
    final alerts = _ref.read(activeAlertsProvider);
    if (alerts.isEmpty) {
      if (state.isNotEmpty) state = {};
      return;
    }
    final location = _ref.read(userLocationProvider);
    // Referencia por defecto: la ubicación actual (GPS o pin). Un aviso armado
    // con pin manual usa SU snapshot (_alertRefs) aunque la ubicación actual
    // haya desaparecido (pin quitado) o haya cambiado (pin nuevo): por eso ya
    // no se sale temprano cuando no hay posición en vivo.
    final liveRef =
        location.hasPosition ? (location.lat!, location.lon!) : null;

    final rearm = <String>{};
    final fire = <String, int>{};
    for (final busId in alerts) {
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
        if (!mostrado) continue;
        enviados.add(entry.key);
        // El aviso ya se envió: pasa a "enviado" en el historial, sale de la
        // lista de alertas activas (visible en la pantalla de
        // Notificaciones) y se libera la suscripción de su ruta.
        _ref.read(alertHistoryProvider.notifier).markSent(entry.key);
        _ref.read(activeAlertsProvider.notifier).deactivateAlert(entry.key);
        disarmAlert(entry.key);
      }
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
