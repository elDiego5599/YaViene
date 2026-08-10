import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum UserLocationMode {
  /// Sin estado inicial todavía (no se ha inicializado).
  unknown,

  /// El usuario negó el permiso de ubicación → tocar el mapa es la opción.
  denied,

  /// Permiso bloqueado de forma permanente → hay que ir a Ajustes.
  permanentDenied,

  /// Permiso concedido pero no se pudo obtener la posición (sin señal o GPS apagado).
  gpsFailed,

  /// Pidiendo posición al GPS.
  locating,

  /// Centro del usuario = GPS real.
  gps,

  /// Centro del usuario = pin manual tocado en el mapa.
  manual,
}

class UserLocationState {
  const UserLocationState({
    this.mode = UserLocationMode.unknown,
    this.lat,
    this.lon,
    this.updatedAt,
  });

  final UserLocationMode mode;
  final double? lat;
  final double? lon;
  final DateTime? updatedAt;

  bool get hasPosition => lat != null && lon != null;
  bool get isManual => mode == UserLocationMode.manual;
}

class UserLocationNotifier extends StateNotifier<UserLocationState> {
  UserLocationNotifier() : super(const UserLocationState());

  static const _kAsked = 'user_loc_asked';

  /// Stream del GPS: mantiene el pin pegado al usuario mientras se mueve.
  StreamSubscription<Position>? _gpsSub;

  /// Pide el permiso de ubicación en el arranque (primera instalación) y, si
  /// ya estaba concedido, obtiene el GPS en silencio. No se restaura ningún
  /// pin guardado: cada arranque parte sin ubicación y la hoja invita a
  /// tocar el mapa (o el GPS la resuelve). Si el permiso ya se negó antes,
  /// no vuelve a mostrar el diálogo del sistema: queda el modo "denegado"
  /// para que el mapa le diga que toque donde está.
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    if (await _hasGpsPermission()) {
      await _locate();
      return;
    }
    var status = await Permission.location.status;
    if (status.isRestricted || status.isPermanentlyDenied) {
      state = const UserLocationState(mode: UserLocationMode.permanentDenied);
      return;
    }
    final alreadyAsked = prefs.getBool(_kAsked) ?? false;
    if (alreadyAsked) {
      state = const UserLocationState(mode: UserLocationMode.denied);
      return;
    }
    status = await Permission.location.request();
    await prefs.setBool(_kAsked, true);
    if (status.isGranted) {
      await _locate();
    } else {
      state = const UserLocationState(mode: UserLocationMode.denied);
    }
  }

  Future<bool> _hasGpsPermission() async {
    final status = await Permission.location.status;
    return status.isGranted;
  }

  /// Pide permiso (si hace falta) y obtiene la posición una sola vez.
  Future<void> useGps() async {
    var status = await Permission.location.status;
    if (status.isPermanentlyDenied || status.isRestricted) {
      state = const UserLocationState(mode: UserLocationMode.permanentDenied);
      return;
    }
    if (!status.isGranted) {
      status = await Permission.location.request();
    }
    if (!status.isGranted) {
      state = const UserLocationState(mode: UserLocationMode.denied);
      return;
    }
    await _locate();
  }

  Future<void> _locate() async {
    state = const UserLocationState(mode: UserLocationMode.locating);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        state = const UserLocationState(mode: UserLocationMode.gpsFailed);
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 15),
        ),
      );
      state = UserLocationState(
        mode: UserLocationMode.gps,
        lat: position.latitude,
        lon: position.longitude,
        updatedAt: DateTime.now(),
      );
      _startGpsStream();
    } catch (_) {
      state = const UserLocationState(mode: UserLocationMode.gpsFailed);
    }
  }

  /// Sigue al usuario en movimiento: actualiza el pin con cada movimiento
  /// relevante (filtro de 8 m; el sistema limita la frecuencia).
  /// En segundo plano el sistema puede pausar el stream (permiso "solo al
  /// usar la app"); al volver al frente se reanuda solo.
  void _startGpsStream() {
    _gpsSub?.cancel();
    _gpsSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        distanceFilter: 8,
      ),
    ).listen(
      (position) {
        if (state.mode == UserLocationMode.manual) return;
        state = UserLocationState(
          mode: UserLocationMode.gps,
          lat: position.latitude,
          lon: position.longitude,
          updatedAt: DateTime.now(),
        );
      },
      onError: (Object _) {
        // GPS apagado o restringido en segundo plano: el pin conserva la
        // última posición conocida; el próximo _locate() reinicia el stream.
        _gpsSub?.cancel();
        _gpsSub = null;
      },
    );
  }

  /// Pin manual: el usuario tocó el mapa.
  void setManualPin(double lat, double lon) {
    _gpsSub?.cancel();
    _gpsSub = null;
    state = UserLocationState(
      mode: UserLocationMode.manual,
      lat: lat,
      lon: lon,
      updatedAt: DateTime.now(),
    );
  }

  /// Quita el pin y vuelve al GPS si hay permiso.
  Future<void> clearManualPin() async {
    if (await _hasGpsPermission()) {
      await _locate();
    } else {
      state = const UserLocationState(mode: UserLocationMode.denied);
    }
  }

  @override
  void dispose() {
    _gpsSub?.cancel();
    _gpsSub = null;
    super.dispose();
  }
}

final userLocationProvider =
    StateNotifierProvider<UserLocationNotifier, UserLocationState>(
        (ref) => UserLocationNotifier());
