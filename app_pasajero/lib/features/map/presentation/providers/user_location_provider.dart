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

  static const _kMode = 'user_loc_mode';
  static const _kLat = 'user_loc_lat';
  static const _kLon = 'user_loc_lon';

  /// Pide el permiso de ubicación en el arranque (primera instalación) y, si
  /// ya estaba concedido, obtiene el GPS en silencio. Si hay un pin manual
  /// guardado, lo usa sin pedir nada.
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final mode = prefs.getString(_kMode);
    final lat = prefs.getDouble(_kLat);
    final lon = prefs.getDouble(_kLon);
    if (mode == 'manual' && lat != null && lon != null) {
      state = UserLocationState(
        mode: UserLocationMode.manual,
        lat: lat,
        lon: lon,
        updatedAt: DateTime.now(),
      );
      return;
    }
    if (await _hasGpsPermission()) {
      await _locate();
      return;
    }
    var status = await Permission.location.status;
    if (status.isRestricted || status.isPermanentlyDenied) {
      state = const UserLocationState(mode: UserLocationMode.permanentDenied);
      return;
    }
    status = await Permission.location.request();
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
      await _persist('gps', position.latitude, position.longitude);
      state = UserLocationState(
        mode: UserLocationMode.gps,
        lat: position.latitude,
        lon: position.longitude,
        updatedAt: DateTime.now(),
      );
    } catch (_) {
      state = const UserLocationState(mode: UserLocationMode.gpsFailed);
    }
  }

  /// Pin manual: el usuario tocó el mapa.
  void setManualPin(double lat, double lon) {
    _persist('manual', lat, lon);
    state = UserLocationState(
      mode: UserLocationMode.manual,
      lat: lat,
      lon: lon,
      updatedAt: DateTime.now(),
    );
  }

  /// Quita el pin y vuelve al GPS si hay permiso.
  Future<void> clearManualPin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kMode);
    await prefs.remove(_kLat);
    await prefs.remove(_kLon);
    if (await _hasGpsPermission()) {
      await _locate();
    } else {
      state = const UserLocationState(mode: UserLocationMode.denied);
    }
  }

  Future<void> _persist(String mode, double lat, double lon) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kMode, mode);
    await prefs.setDouble(_kLat, lat);
    await prefs.setDouble(_kLon, lon);
  }
}

final userLocationProvider =
    StateNotifierProvider<UserLocationNotifier, UserLocationState>(
        (ref) => UserLocationNotifier());
