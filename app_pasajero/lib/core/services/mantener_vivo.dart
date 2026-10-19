import 'dart:async';
import 'dart:io';

import 'package:geolocator/geolocator.dart';

/// Controla el stream de ubicación que mantiene activa la app con la pantalla
/// bloqueada mientras queda al menos un aviso armado.
abstract interface class ServicioMantenerVivo {
  Future<void> iniciar();

  Future<void> detener();
}

class MantenerVivoGeolocator implements ServicioMantenerVivo {
  MantenerVivoGeolocator({bool Function()? esIos}) : _esIos = esIos ?? _ios;

  final bool Function() _esIos;
  StreamSubscription<Position>? _suscripcion;
  bool _solicitado = false;
  Future<void>? _inicioPendiente;

  static bool _ios() => Platform.isIOS;

  @override
  Future<void> iniciar() async {
    _solicitado = true;
    if (!_esIos() || _suscripcion != null) return;
    final pendiente = _inicioPendiente;
    if (pendiente != null) return pendiente;
    final inicio = _iniciarSiPermitido();
    _inicioPendiente = inicio;
    try {
      await inicio;
    } finally {
      if (identical(_inicioPendiente, inicio)) _inicioPendiente = null;
    }
  }

  Future<void> _iniciarSiPermitido() async {
    // Revisar el permiso existente nunca abre un diálogo ni solicita Always.
    final permiso = await Geolocator.checkPermission();
    if (!_solicitado ||
        (permiso != LocationPermission.whileInUse &&
            permiso != LocationPermission.always)) {
      return;
    }
    final ajustes = AppleSettings(
      accuracy: LocationAccuracy.reduced,
      distanceFilter: 100,
      allowBackgroundLocationUpdates: true,
      showBackgroundLocationIndicator: true,
      pauseLocationUpdatesAutomatically: false,
      activityType: ActivityType.otherNavigation,
    );
    // Las posiciones se ignoran: este stream existe solo para que iOS no
    // suspenda la app con la pantalla bloqueada mientras hay avisos armados.
    _suscripcion = Geolocator.getPositionStream(
      locationSettings: ajustes,
    ).listen((_) {}, onError: (Object error, StackTrace stack) {});
  }

  @override
  Future<void> detener() async {
    _solicitado = false;
    final pendiente = _inicioPendiente;
    if (pendiente != null) await pendiente;
    await _suscripcion?.cancel();
    _suscripcion = null;
  }
}
