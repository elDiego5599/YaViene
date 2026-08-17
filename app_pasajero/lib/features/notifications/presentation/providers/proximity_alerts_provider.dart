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

/// Firma del disparo de notificación (inyectable en tests).
typedef BusNearNotifier = Future<void> Function({
  required String busId,
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
  final _routeSubs = <String, ProviderSubscription<AsyncValue<List<BusPosition>>>>{};
  final _routePositions = <String, List<BusPosition>>{};

  static Future<void> _defaultNotify({
    required String busId,
    required int distanceMeters,
  }) =>
      BusNotificationService.notifyBusNear(
        busId: busId,
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
  Future<void> restore() async {
    await _ref.read(alertHistoryProvider.notifier).load();
    final entries = _ref.read(alertHistoryProvider);
    for (final e in entries) {
      if (e.sent || e.routeId.isEmpty) continue;
      if (_alertRoutes.containsKey(e.busId)) continue;
      _ref.read(activeAlertsProvider.notifier).toggleAlert(e.busId);
      armAlert(e.busId, e.routeId);
    }
  }

  /// Registra la ruta del bus al armar el aviso y suscribe posiciones de esa
  /// ruta: el aviso mide aunque la pantalla esté mostrando otra ruta.
  void armAlert(String busId, String routeId) {
    _alertRoutes[busId] = routeId;
    // Re-armado limpio: si este bus ya notificó su acercamiento antes (quedó
    // marcado en `state`), se borra esa marca para que pueda volver a sonar
    // en un nuevo acercamiento; si no, el aviso re-armado quedaba "muerto".
    state = {...state}..remove(busId);
    // Registro en el historial: la activación queda anotada (y es la fuente
    // de persistencia para re-armar al volver a abrir la app).
    _ref.read(alertHistoryProvider.notifier).upsert(
          busId,
          routeId: routeId,
          routeName: _ref.read(selectedRouteProvider)?.name,
        );
    // Ancla del aviso: si el usuario está con pin manual, el aviso se fija a
    // ESA ubicación. Aunque luego quite el pin (sin GPS la app queda sin
    // ubicación) o ponga otro pin, el aviso sigue midiendo desde donde se
    // armó. Con GPS activo la referencia queda null → se mide en vivo.
    final location = _ref.read(userLocationProvider);
    _alertRefs[busId] =
        location.mode == UserLocationMode.manual && location.hasPosition
            ? (location.lat!, location.lon!)
            : null;
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
      final routeId = _alertRoutes[busId] ?? _ref.read(selectedRouteProvider)?.id;
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
      for (final entry in fire.entries) {
        unawaited(_notify(
          busId: entry.key,
          distanceMeters: entry.value,
        ));
        // El aviso ya se envió: pasa a "enviado" en el historial, sale de la
        // lista de alertas activas (visible en la pantalla de
        // Notificaciones) y se libera la suscripción de su ruta.
        _ref.read(alertHistoryProvider.notifier).markSent(entry.key);
        _ref.read(activeAlertsProvider.notifier).toggleAlert(entry.key);
        disarmAlert(entry.key);
      }
      state = {...state, ...fire.keys}..removeAll(rearm);
    } else if (rearm.isNotEmpty) {
      state = {...state}..removeAll(rearm);
    }
  }
}

final proximityAlertsProvider =
    StateNotifierProvider<ProximityAlertsNotifier, Set<String>>((ref) {
  return ProximityAlertsNotifier(ref);
});
