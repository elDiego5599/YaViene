import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import '../../../../core/services/bus_notification_service.dart';
import '../../../map/presentation/providers/tracking_providers.dart';
import '../../../map/presentation/providers/user_location_provider.dart';
import '../../../map/presentation/utils/geo.dart';

/// Radio en el que se dispara el aviso (m).
const int alertRadiusMeters = 500;

/// Distancia a la que se "rearma" el aviso de un bus para poder volver a
/// notificar si el bus se aleja y regresa (histéresis).
const int alertReArmMeters = 750;

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

  /// Fuerza una verificación (útil en tests).
  Future<void> check() => _check();

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _check() async {
    final alerts = _ref.read(activeAlertsProvider);
    if (alerts.isEmpty) {
      if (state.isNotEmpty) state = {};
      return;
    }
    final route = _ref.read(selectedRouteProvider);
    final location = _ref.read(userLocationProvider);
    if (route == null || !location.hasPosition) return;

    final positions =
        _ref.read(busPositionsSourceProvider(route.id)).value ?? const <BusPosition>[];
    final byId = {for (final p in positions) p.busId: p};

    final rearm = <String>{};
    final fire = <String>{};
    for (final busId in alerts) {
      final pos = byId[busId];
      // Sin posición (o sin señal): no hay nada que medir todavía.
      if (pos == null || pos.isGhostBus) continue;
      final distance = haversineMeters(location.lat!, location.lon!, pos.lat, pos.lon);
      if (state.contains(busId)) {
        if (distance > alertReArmMeters) rearm.add(busId);
      } else if (distance <= alertRadiusMeters) {
        fire.add(busId);
      }
    }

    if (fire.isNotEmpty) {
      for (final busId in fire) {
        final pos = byId[busId]!;
        final distance =
            haversineMeters(location.lat!, location.lon!, pos.lat, pos.lon);
        unawaited(_notify(
          busId: busId,
          distanceMeters: distance.round(),
        ));
      }
      state = {...state, ...fire}..removeAll(rearm);
    } else if (rearm.isNotEmpty) {
      state = {...state}..removeAll(rearm);
    }
  }
}

final proximityAlertsProvider =
    StateNotifierProvider<ProximityAlertsNotifier, Set<String>>((ref) {
  return ProximityAlertsNotifier(ref);
});
