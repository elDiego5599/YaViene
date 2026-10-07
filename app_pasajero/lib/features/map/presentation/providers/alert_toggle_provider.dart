import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ya_viene_core/ya_viene_core.dart';

import '../../../../core/services/bus_notification_service.dart';
import '../../../notifications/presentation/providers/alert_history_provider.dart';
import '../../../notifications/presentation/providers/distancia_aviso_provider.dart';
import '../../../notifications/presentation/providers/proximity_alerts_provider.dart';
import '../utils/geo.dart';
import '../widgets/alert_guards.dart' as guards;
import 'route_reach_provider.dart';
import 'tracking_providers.dart';
import 'user_location_provider.dart';

/// Pide el permiso de notificaciones (inyectable en tests).
typedef NotificationPermissionRequester = Future<bool> Function();

/// Le pregunta a la persona a qué distancia quiere el aviso (la rueda).
/// [hasta] es la mayor que puede ofrecer —la de más que el bus ya pasó
/// sonaría ya mismo—, o `null` si cualquiera sirve. `null` si cerró sin
/// elegir; [guardar] si la quiere para los que vienen.
typedef ElegirDistancia = Future<({int metros, bool guardar})?> Function(
    int? hasta);

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

  /// Cerró la rueda de la distancia sin elegir: no se arma nada.
  cancelled,
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
      outcome != AlertToggleOutcome.permissionDenied &&
      outcome != AlertToggleOutcome.cancelled;
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

  /// Activa o desactiva el aviso de [busId]. Para activarlo hace falta una
  /// distancia: la guardada o, si no hay, la que conteste [elegirDistancia].
  Future<AlertToggleResult> toggle(
    String busId, {
    required ElegirDistancia elegirDistancia,
  }) async {
    final notifier = _ref.read(activeAlertsProvider.notifier);
    final wasActive = _ref.read(activeAlertsProvider).contains(busId);
    late final int radio;
    if (!wasActive) {
      // Sin posición (GPS negado y sin pin) el aviso nunca podría medir ni
      // dispararse: mejor explicarlo antes de armar una alerta muerta.
      final routeDistance = await _routeDistanceToUser();
      final guardada = _ref.read(distanciaAvisoProvider);
      // Antes de abrir la rueda se dice lo que ninguna opción arreglaría:
      // preguntar para luego decir que no se puede sería hacerle perder el
      // tiempo. «Ya está cerca» se mide con la mínima aunque haya una
      // guardada mayor: con el bus a 800 m y 1 km guardado, el de 500 m
      // todavía sirve.
      var message = _validar(
        busId,
        routeDistance,
        radioCercaM: distanciaAvisoMinima,
        radioRutaM: guardada ?? distanciaAvisoMaxima,
      );
      if (message != null) {
        return AlertToggleResult(AlertToggleOutcome.rejected, message: message);
      }
      final hasta = distanciaAvisoHasta(_distanceToBus(_busById(busId)));
      if (guardada != null && (hasta == null || guardada <= hasta)) {
        radio = guardada;
      } else {
        // Sin guardada, o con una que el bus ya pasó: la rueda, solo con
        // las que todavía no ha pasado.
        final elegida = await elegirDistancia(hasta);
        if (elegida == null) {
          return const AlertToggleResult(AlertToggleOutcome.cancelled);
        }
        radio = elegida.metros;
        if (elegida.guardar) {
          await _ref.read(distanciaAvisoProvider.notifier).guardar(radio);
        }
        // La rueda tardó lo que la persona quiso: el bus se movió.
        message = _validar(busId, routeDistance,
            radioCercaM: radio, radioRutaM: radio);
        if (message != null) {
          return AlertToggleResult(AlertToggleOutcome.rejected,
              message: message);
        }
      }
      if (!await _requestPermission()) {
        return const AlertToggleResult(AlertToggleOutcome.permissionDenied);
      }
    }

    final routeId = _ref.read(selectedRouteProvider)?.id;
    if (wasActive) {
      notifier.deactivateAlert(busId);
      _ref.read(proximityAlertsProvider.notifier).disarmAlert(busId);
      // Y fuera del historial. Un aviso activo nunca notificó —al notificar
      // se marca y se desactiva solo—, así que quitarlo aquí no borra nada
      // que haya pasado: borra la intención que se acaba de retirar. Sin
      // esto el registro se quedaba en la pantalla de Notificaciones como un
      // aviso vivo que ya no mide nada, y al reabrir la app `restore` lo
      // volvía a armar, resucitando el aviso que el pasajero había quitado.
      // Es lo mismo que ya hacía la propia pantalla de Notificaciones al
      // desactivar desde allí.
      _ref.read(alertHistoryProvider.notifier).remove(busId);
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
      _ref
          .read(proximityAlertsProvider.notifier)
          .armAlert(busId, routeId, radioM: radio);
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

  String? _validar(
    String busId,
    double? routeDistance, {
    required int radioCercaM,
    required int radioRutaM,
  }) {
    final bus = _busById(busId);
    return guards.validateAlertActivation(
      hasPosition: _ref.read(userLocationProvider).hasPosition,
      bus: bus,
      busDistanceMeters: _distanceToBus(bus),
      activeAlertsCount: _ref.read(activeAlertsProvider).length,
      routeDistanceMeters: routeDistance,
      radioCercaM: radioCercaM,
      radioRutaM: radioRutaM,
    );
  }

  /// Lo más que se acerca el recorrido de la ruta abierta al punto del
  /// usuario, o null si no se sabe (sin ruta, sin ubicación, sin geometría).
  ///
  /// Si el recorrido todavía está cargando se le espera un momento. Sin esa
  /// espera, un toque rápido nada más abrir la app leería null —"no se
  /// sabe"—, y como no saber deja pasar, se armaría justo el aviso imposible
  /// que esta regla existe para evitar. La espera está topada y cualquier
  /// fallo cae en null: ante la duda se sigue dejando armar.
  Future<double?> _routeDistanceToUser() async {
    final route = _ref.read(selectedRouteProvider);
    if (route == null) return null;
    if (_ref.read(routeTrajectoryProvider(route.id)).isLoading) {
      try {
        await _ref
            .read(routeTrajectoryProvider(route.id).future)
            .timeout(const Duration(milliseconds: 600));
      } catch (_) {
        // Sin geometría no se sabe, y no saber no bloquea.
      }
    }
    return _ref.read(routeDistanceToUserProvider(route.id));
  }

  /// El texto del límite no depende de la ruta ni de la ubicación: se pide
  /// con las demás reglas ya en verde para quedarse solo con la del límite.
  String _limitMessage() => guards.validateAlertActivation(
        hasPosition: true,
        bus: null,
        busDistanceMeters: null,
        activeAlertsCount: 2,
        radioCercaM: distanciaAvisoInicial,
        radioRutaM: distanciaAvisoInicial,
      )!;
}

final alertToggleProvider = Provider<AlertToggleController>(
  (ref) => AlertToggleController(ref),
);
