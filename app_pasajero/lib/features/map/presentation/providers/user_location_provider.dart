import 'dart:async';

import 'package:flutter/foundation.dart';
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

  /// Permiso concedido pero no se pudo obtener la posición (sin señal o GPS
  /// apagado).
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
  static const _kManualLat = 'user_loc_manual_lat';
  static const _kManualLon = 'user_loc_manual_lon';

  /// Stream del GPS: mantiene el pin pegado al usuario mientras se mueve.
  StreamSubscription<Position>? _gpsSub;

  /// Memoización: si `initialize()` se invoca dos veces en serie (p. ej. por
  /// dos listeners del mapa), ambas comparten la misma corrida en vez de pedir
  /// el permiso dos veces a la vez.
  Future<void>? _initFuture;

  /// Pide el permiso de ubicación en el arranque (primera instalación) y, si
  /// ya estaba concedido, obtiene el GPS en silencio. Sin permiso, restaura
  /// el último pin manual guardado (si existe) para que el usuario reencuentre
  /// su punto de parada al instante; si no hay pin, queda el modo sin
  /// ubicación para que la hoja invite a tocar el mapa.
  Future<void> initialize() {
    return _initFuture ??=
        _doInitialize().whenComplete(() => _initFuture = null);
  }

  Future<void> _doInitialize() async {
    try {
      await _initializeOrThrow();
    } catch (e) {
      // El modo `unknown` no tiene píldora ni salida: es el estado de "aún
      // no sé", y quedarse ahí por una excepción de la plataforma deja al
      // usuario sin ubicación y sin nadie que le diga que puede poner el pin
      // a mano. Cualquier fallo aterriza en un modo que sí lo dice.
      debugPrint('initialize location error: $e');
      if (state.mode != UserLocationMode.unknown) return;
      try {
        if (await _restoreSavedPin()) return;
      } catch (_) {
        // Si lo que falló fue el propio almacén de preferencias, el pin
        // guardado tampoco se puede leer; queda el modo sin ubicación.
      }
      state = const UserLocationState(mode: UserLocationMode.denied);
    }
  }

  Future<void> _initializeOrThrow() async {
    final prefs = await SharedPreferences.getInstance();
    if (await _hasGpsPermission()) {
      await _locate();
      // El usuario permitió la ubicación pero el GPS no dio fijación (sin
      // señal, GPS apagado, indoor): en vez de quedarse "sin ubicación", se
      // recupera el último pin manual guardado, que es lo único que se
      // conserva entre arranques.
      if (state.mode == UserLocationMode.gpsFailed) {
        if (await _restoreSavedPin()) return;
      }
      return;
    }
    var status = await Permission.location.status;
    if (status.isRestricted || status.isPermanentlyDenied) {
      if (await _restoreSavedPin()) return;
      state = const UserLocationState(mode: UserLocationMode.permanentDenied);
      return;
    }
    final alreadyAsked = prefs.getBool(_kAsked) ?? false;
    if (alreadyAsked) {
      if (await _restoreSavedPin()) return;
      state = const UserLocationState(mode: UserLocationMode.denied);
      return;
    }
    status = await _requestLocation();
    await prefs.setBool(_kAsked, true);
    if (status.isGranted) {
      await _locate();
    } else {
      if (await _restoreSavedPin()) return;
      state = const UserLocationState(mode: UserLocationMode.denied);
    }
  }

  /// Un pin solo vale si es un punto real del planeta. `LatLng` de Google
  /// Maps recorta la latitud y da la vuelta a la longitud sin avisar, así que
  /// un valor fuera de rango se pintaba en un sitio mientras las distancias
  /// y los avisos se medían desde otro; y un NaN no se puede pintar.
  static bool _coordenadasValidas(double lat, double lon) =>
      lat.isFinite && lon.isFinite && lat.abs() <= 90 && lon.abs() <= 180;

  /// Restaura el pin manual guardado en el arranque anterior (si existe).
  ///
  /// Lo que hay en SharedPreferences no se da por bueno: si no es un punto
  /// válido se borra, y el arranque sigue como si no hubiera pin.
  Future<bool> _restoreSavedPin() async {
    final prefs = await SharedPreferences.getInstance();
    final lat = prefs.getDouble(_kManualLat);
    final lon = prefs.getDouble(_kManualLon);
    if (lat == null || lon == null) return false;
    if (!_coordenadasValidas(lat, lon)) {
      await prefs.remove(_kManualLat);
      await prefs.remove(_kManualLon);
      return false;
    }
    state = UserLocationState(
      mode: UserLocationMode.manual,
      lat: lat,
      lon: lon,
      updatedAt: DateTime.now(),
    );
    return true;
  }

  Future<bool> _hasGpsPermission() async {
    final status = await Permission.location.status;
    return status.isGranted;
  }

  /// Permiso pendiente en vuelo: `permission_handler` lanza PlatformException
  /// ("A request for permissions is already running") si se piden dos veces a
  /// la vez. Este futuro comparte una sola petición entre llamadas
  /// concurrentes.
  Future<PermissionStatus>? _pendingRequest;

  Future<PermissionStatus> _requestLocation() {
    return _pendingRequest ??= Permission.location
        .request()
        .whenComplete(() => _pendingRequest = null);
  }

  /// Pide permiso (si hace falta) y obtiene la posición una sola vez.
  Future<void> useGps() async {
    try {
      var status = await Permission.location.status;
      if (status.isPermanentlyDenied || status.isRestricted) {
        state = const UserLocationState(mode: UserLocationMode.permanentDenied);
        return;
      }
      if (!status.isGranted) {
        status = await _requestLocation();
        // Queda registrado que ya se preguntó: si el usuario niega aquí, el
        // mapa no debe volver a lanzar el diálogo de permiso (doble pregunta).
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_kAsked, true);
      }
      if (!status.isGranted) {
        state = const UserLocationState(mode: UserLocationMode.denied);
        return;
      }
      await _locate();
      // GPS no dio fijación: recuperar el pin guardado en vez de quedarse
      // colgado sin ubicación (igual que en el arranque).
      if (state.mode == UserLocationMode.gpsFailed) {
        if (await _restoreSavedPin()) return;
      }
    } catch (e) {
      // Nunca colgar un flujo (p. ej. el spinner del onboarding) por una
      // excepción de la plataforma: se queda sin ubicación con pin si existe.
      debugPrint('useGps error: $e');
      if (!await _restoreSavedPin()) {
        state = const UserLocationState(mode: UserLocationMode.denied);
      }
    }
  }

  /// Reanuda una sesión GPS que quedó sin stream al volver del segundo plano.
  /// No pide permiso ni cambia un pin manual: solo actúa si ya estábamos en
  /// modo GPS y el permiso sigue concedido.
  Future<void> resumeGpsIfNeeded() async {
    // Si el stream sigue vivo no reinicializarlo al volver de un diálogo del
    // sistema (p. ej. permiso de notificaciones): ese reset pondría el estado
    // en `locating` y haría parecer que se perdió la ubicación.
    if (state.mode != UserLocationMode.gps || _gpsSub != null) return;
    try {
      if (await _hasGpsPermission()) await _locate();
    } catch (e) {
      debugPrint('resume GPS error: $e');
    }
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
      // Si mientras esperábamos el GPS el usuario tocó el mapa para fijar su
      // pin manual, el GPS no debe sobrescribirlo.
      if (state.mode == UserLocationMode.manual) return;
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

  /// Pin manual: el usuario tocó el mapa. Se guarda para reencontrarlo en el
  /// próximo arranque cuando no hay permiso de GPS.
  void setManualPin(double lat, double lon) {
    if (!_coordenadasValidas(lat, lon)) return;
    _gpsSub?.cancel();
    _gpsSub = null;
    state = UserLocationState(
      mode: UserLocationMode.manual,
      lat: lat,
      lon: lon,
      updatedAt: DateTime.now(),
    );
    unawaited(_persistPin(lat, lon));
  }

  Future<void> _persistPin(double lat, double lon) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kManualLat, lat);
    await prefs.setDouble(_kManualLon, lon);
  }

  /// Quita el pin y vuelve al GPS si hay permiso. Con [resumeGps] en false
  /// (cierre de sesión) no se relanza la localización: la sesión terminó y
  /// dejar el GPS corriendo en el login filtraría ubicación sin usuario.
  Future<void> clearManualPin({bool resumeGps = true}) async {
    // Lo primero, antes de cualquier `await`: mientras se borraba el pin del
    // disco el stream del GPS seguía vivo, y una lectura que llegara en ese
    // hueco escribía una posición después del cierre de sesión. Si toca
    // volver al GPS, `_locate` abre una suscripción nueva.
    _gpsSub?.cancel();
    _gpsSub = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kManualLat);
    await prefs.remove(_kManualLon);
    if (!resumeGps) {
      state = const UserLocationState(mode: UserLocationMode.denied);
      return;
    }
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
