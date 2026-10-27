import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

/// Controla la ubicación que mantiene activa la app con la pantalla
/// bloqueada mientras queda al menos un aviso armado.
abstract interface class ServicioMantenerVivo {
  Future<void> iniciar();

  Future<void> detener();
}

/// Pide al lado nativo (`MantenerVivo` en `ActividadEnVivo.swift`) su propio
/// CLLocationManager con actualizaciones en segundo plano. No usa el stream
/// de geolocator: en iOS es uno solo para toda la app y, si el mapa lo abrió
/// antes (sin segundo plano), pedirlo otra vez devuelve ese mismo, sin
/// `allowsBackgroundLocationUpdates`, e iOS suspende la app con el aviso
/// armado.
class MantenerVivoIos implements ServicioMantenerVivo {
  MantenerVivoIos({
    bool Function()? esIos,
    Future<LocationPermission> Function()? permiso,
  })  : _esIos = esIos ?? _ios,
        _permiso = permiso ?? Geolocator.checkPermission;

  static const _canal = MethodChannel('yaviene/mantener_vivo');

  final bool Function() _esIos;
  final Future<LocationPermission> Function() _permiso;
  bool _activo = false;
  bool _solicitado = false;
  Future<void>? _inicioPendiente;

  static bool _ios() => Platform.isIOS;

  @override
  Future<void> iniciar() async {
    _solicitado = true;
    if (!_esIos() || _activo) return;
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
    final permiso = await _permiso();
    if (!_solicitado ||
        (permiso != LocationPermission.whileInUse &&
            permiso != LocationPermission.always)) {
      return;
    }
    await _canal.invokeMethod<void>('iniciar');
    _activo = true;
  }

  @override
  Future<void> detener() async {
    _solicitado = false;
    final pendiente = _inicioPendiente;
    if (pendiente != null) await pendiente;
    if (!_activo) return;
    _activo = false;
    await _canal.invokeMethod<void>('detener');
  }
}
