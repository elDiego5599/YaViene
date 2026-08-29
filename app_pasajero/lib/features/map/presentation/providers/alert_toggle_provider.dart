import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ya_viene_core/ya_viene_core.dart';

import '../../../../core/services/bus_notification_service.dart';
import '../../../notifications/presentation/providers/proximity_alerts_provider.dart';
import '../utils/geo.dart';
import '../widgets/alert_guards.dart' as guards;
import 'route_reach_provider.dart';
import 'tracking_providers.dart';
import 'user_location_provider.dart';

/// Pide el permiso de notificaciones (inyectable en tests).
typedef NotificationPermissionRequester = Future<bool> Function();

/// Resultado de intentar activar/desactivar un aviso. El widget solo traduce
/// esto a háptico y snackbar: toda la regla de negocio vive aquí.
enum AlertToggleOutcome {
  /// Quedó armado y midiendo.
  activated,

  /// Se desactivó (estaba activo).
  deactivated,

  /// Una regla lo rechazó (sin ubicación, bus fantasma, ya cerca, límite).
  /// [AlertToggleResult.message] trae el texto para el usuario.
  rejected,

  /// El usuario no concedió el permiso de notificaciones.
  permissionDenied,

  /// Carrera: dos taps concurrentes y el segundo no alcanzó cupo. Mismo
  /// texto de límite que [rejected].
  limitReached,

  /// Estado imposible defendido: aviso activado sin ruta seleccionada; se
  /// deshace solo. No debería ocurrir nunca.
  noRoute,
}

class AlertToggleResult {
  const AlertToggleResult(this.outcome, {this.message});

  final AlertToggleOutcome outcome;

  /// Texto para snackbar cuando [AlertToggleOutcome.rejected] o
  /// [AlertToggleOutcome.limitReached].
  final String? message;

  /// El háptico dispara cuando la intención se aceptó a trámite (igual que
  /// antes: tras validar y tras permiso, incluso si la carrera quitó el cupo).
  bool get needsHaptic =>
      outcome != AlertToggleOutcome.rejected &&
      outcome != AlertToggleOutcome.permissionDenied;
}

/// Orquestación de activar/desactivar un aviso, fuera del widget: pide
/// permiso en contexto, valida las reglas (alert_guards.dart), arma el aviso
/// con su ruta y cierra la carrera de dos taps con la comprobación atómica.
/// Inyectable completo en tests: sin UI, sin permisos reales, sin snackbar.
class AlertToggleController {
  AlertToggleController(
    this._ref, {
    NotificationPermissionRequester? requestPermission,
  }) : _requestPermission =
            requestPermission ?? BusNotificationService.requestPermission;

  final Ref _ref;
  final NotificationPermissionRequester _requestPermission;

  Future<AlertToggleResult> toggle(String busId) async {
    final notifier = _ref.read(activeAlertsProvider.notifier);
    final wasActive = _ref.read(activeAlertsProvider).contains(busId);
    if (!wasActive) {
      // Sin posición (GPS negado y sin pin) el aviso nunca podría medir ni
      // dispararse: mejor explicarlo antes de armar una alerta muerta.
      final bus = _busById(busId);
      final message = guards.validateAlertActivation(
        hasPosition: _ref.read(userLocationProvider).hasPosition,
        bus: bus,
        busAlreadyNear: _busAlreadyNear(bus),
        activeAlertsCount: _ref.read(activeAlertsProvider).length,
        routeDistanceMeters: _routeDistanceToUser(),
      );
      if (message != null) {
        return AlertToggleResult(AlertToggleOutcome.rejected, message: message);
      }
      if (!await _requestPermission()) {
        return const AlertToggleResult(AlertToggleOutcome.permissionDenied);
      }
    }

    final routeId = _ref.read(selectedRouteProvider)?.id;
    if (wasActive) {
      notifier.deactivateAlert(busId);
      _ref.read(proximityAlertsProvider.notifier).disarmAlert(busId);
      return const AlertToggleResult(AlertToggleOutcome.deactivated);
    }

    // La validación ocurre antes del await del permiso. Esta comprobación
    // atómica evita que dos taps concurrentes armen un tercer aviso mientras
    // la solicitud de permiso está en vuelo.
    if (!notifier.activateAlert(busId)) {
      return AlertToggleResult(
        AlertToggleOutcome.limitReached,
        message: _limitMessage(),
      );
    }
    if (routeId != null) {
      // Quedó armado: se registra la ruta para que el aviso mida aunque se
      // cambie de ruta en pantalla.
      _ref.read(proximityAlertsProvider.notifier).armAlert(busId, routeId);
      return const AlertToggleResult(AlertToggleOutcome.activated);
    }
    // Defensa contra un estado imposible: nunca dejes un aviso activo sin
    // ruta ni suscripción de posiciones.
    notifier.deactivateAlert(busId);
    return const AlertToggleResult(AlertToggleOutcome.noRoute);
  }

  BusPosition? _busById(String busId) {
    final route = _ref.read(selectedRouteProvider);
    if (route == null) return null;
    final positions = _ref.read(busPositionsSourceProvider(route.id)).value;
    if (positions == null) return null;
    for (final p in positions) {
      if (p.busId == busId) return p;
    }
    return null;
  }

  double? _distanceToBus(BusPosition? bus) {
    if (bus == null) return null;
    final location = _ref.read(userLocationProvider);
    if (!location.hasPosition) return null;
    return haversineMeters(location.lat!, location.lon!, bus.lat, bus.lon);
  }

  bool _busAlreadyNear(BusPosition? bus) {
    final distance = _distanceToBus(bus);
    return distance != null && distance <= alertRadiusMeters;
  }

  /// Lo más que se acerca el recorrido de la ruta abierta al punto del
  /// usuario, o null si no se sabe (sin ruta, sin ubicación, sin geometría).
  double? _routeDistanceToUser() {
    final route = _ref.read(selectedRouteProvider);
    if (route == null) return null;
    return _ref.read(routeDistanceToUserProvider(route.id));
  }

  /// El texto del límite no depende de la ruta ni de la ubicación: se pide
  /// con las demás reglas ya en verde para quedarse solo con la del límite.
  String _limitMessage() => guards.validateAlertActivation(
        hasPosition: true,
        bus: null,
        busAlreadyNear: false,
        activeAlertsCount: 2,
      )!;
}

final alertToggleProvider = Provider<AlertToggleController>(
  (ref) => AlertToggleController(ref),
);
