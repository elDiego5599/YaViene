import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ya_viene_core/ya_viene_core.dart' show GeoPoint;
import 'package:ya_viene_pasajero/features/map/presentation/providers/user_location_provider.dart';

const _kManualLat = 'user_loc_manual_lat';
const _kManualLon = 'user_loc_manual_lon';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('setManualPin persiste las coordenadas para el próximo arranque',
      () async {
    final notifier = UserLocationNotifier();

    notifier.setManualPin(10.9512, -74.79145);
    await Future<void>.delayed(Duration.zero);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getDouble(_kManualLat), 10.9512);
    expect(prefs.getDouble(_kManualLon), -74.79145);
    expect(notifier.state.isManual, isTrue);
  });

  test('initialize sin permiso de GPS restaura el pin guardado', () async {
    SharedPreferences.setMockInitialValues({
      _kManualLat: 10.9512,
      _kManualLon: -74.79145,
      'user_loc_asked': true,
    });
    // permiso denegado: la app entra por la rama de restauración del pin
    // (sin tocar geolocator).
    const channel = MethodChannel('flutter.baseflow.com/permissions/methods');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'checkPermissionStatus') return 0; // denied
      if (call.method == 'shouldShowRequestPermissionRationale') return false;
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    final notifier = UserLocationNotifier();
    await notifier.initialize();

    expect(notifier.state.mode, UserLocationMode.manual);
    expect(notifier.state.lat, 10.9512);
    expect(notifier.state.lon, -74.79145);
  });

  test('initialize con permiso de GPS también restaura el pin guardado',
      () async {
    // El dueño, 2026-10-02: «se guarda el ultimo pin q el usuario coloco
    // antes de cerrar la app». Con el GPS concedido el arranque iba al GPS y
    // el pin marcado a mano se perdía; ahora manda el pin hasta «Quitar».
    SharedPreferences.setMockInitialValues({
      _kManualLat: 10.9512,
      _kManualLon: -74.79145,
      'user_loc_asked': true,
    });
    const permisos = MethodChannel('flutter.baseflow.com/permissions/methods');
    const gps = MethodChannel('flutter.baseflow.com/geolocator');
    final llamadasGps = <String>[];
    final mensajero =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    mensajero.setMockMethodCallHandler(permisos, (call) async {
      if (call.method == 'checkPermissionStatus') return 1; // granted
      return null;
    });
    mensajero.setMockMethodCallHandler(gps, (call) async {
      llamadasGps.add(call.method);
      return null;
    });
    addTearDown(() {
      mensajero.setMockMethodCallHandler(permisos, null);
      mensajero.setMockMethodCallHandler(gps, null);
    });

    final notifier = UserLocationNotifier();
    await notifier.initialize();

    expect(notifier.state.mode, UserLocationMode.manual);
    expect(notifier.state.lat, 10.9512);
    expect(notifier.state.lon, -74.79145);
    expect(llamadasGps, isEmpty);
  });

  test('initialize sin permiso y sin pin guardado queda en modo denegado',
      () async {
    SharedPreferences.setMockInitialValues({'user_loc_asked': true});
    const channel = MethodChannel('flutter.baseflow.com/permissions/methods');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'checkPermissionStatus') return 0; // denied
      if (call.method == 'shouldShowRequestPermissionRationale') return false;
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    final notifier = UserLocationNotifier();
    await notifier.initialize();

    expect(notifier.state.mode, UserLocationMode.denied);
    expect(notifier.state.hasPosition, isFalse);
  });

  test('un pin guardado que no es un punto válido se descarta y se borra',
      () async {
    const channel = MethodChannel('flutter.baseflow.com/permissions/methods');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'checkPermissionStatus') return 0; // denied
      if (call.method == 'shouldShowRequestPermissionRationale') return false;
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    for (final (lat, lon) in [
      (95.0, -74.79145),
      (10.9512, 200.0),
      (double.nan, -74.79145),
      (10.9512, double.infinity),
    ]) {
      SharedPreferences.setMockInitialValues({
        _kManualLat: lat,
        _kManualLon: lon,
        'user_loc_asked': true,
      });

      final notifier = UserLocationNotifier();
      await notifier.initialize();

      expect(notifier.state.mode, UserLocationMode.denied,
          reason: '($lat, $lon) no debe restaurarse');
      expect(notifier.state.hasPosition, isFalse);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getDouble(_kManualLat), isNull);
      expect(prefs.getDouble(_kManualLon), isNull);
    }
  });

  test('setManualPin ignora un punto imposible y no lo guarda', () async {
    final notifier = UserLocationNotifier();

    notifier.setManualPin(double.nan, -74.79145);
    notifier.setManualPin(10.9512, -181);
    await Future<void>.delayed(Duration.zero);

    expect(notifier.state.mode, UserLocationMode.unknown);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getDouble(_kManualLat), isNull);
    expect(prefs.getDouble(_kManualLon), isNull);
  });

  // El dueño, 2026-10-07: «Quitar» quita el pin para que ponga otro; el GPS
  // es aparte («Usar GPS»). Antes, con el permiso concedido, «Quitar» volvía
  // solo al GPS y el usuario no veía cómo marcar otro punto.
  for (final (nombre, permiso) in [('con permiso', 1), ('sin permiso', 0)]) {
    test('clearManualPin $nombre borra el pin y deja el mapa sin punto',
        () async {
      SharedPreferences.setMockInitialValues({
        _kManualLat: 10.9512,
        _kManualLon: -74.79145,
        'user_loc_asked': true,
      });
      const permisos =
          MethodChannel('flutter.baseflow.com/permissions/methods');
      const gps = MethodChannel('flutter.baseflow.com/geolocator');
      final llamadasGps = <String>[];
      final mensajero =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      mensajero.setMockMethodCallHandler(permisos, (call) async {
        if (call.method == 'checkPermissionStatus') return permiso;
        if (call.method == 'shouldShowRequestPermissionRationale') {
          return false;
        }
        return null;
      });
      mensajero.setMockMethodCallHandler(gps, (call) async {
        llamadasGps.add(call.method);
        return null;
      });
      addTearDown(() {
        mensajero.setMockMethodCallHandler(permisos, null);
        mensajero.setMockMethodCallHandler(gps, null);
      });

      final notifier = UserLocationNotifier();
      addTearDown(notifier.dispose);
      await notifier.initialize();
      expect(notifier.state.mode, UserLocationMode.manual);

      await notifier.clearManualPin();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getDouble(_kManualLat), isNull);
      expect(prefs.getDouble(_kManualLon), isNull);
      expect(notifier.state.mode, UserLocationMode.sinPunto);
      expect(notifier.state.hasPosition, isFalse);
      expect(llamadasGps, isEmpty, reason: 'Quitar no prende el GPS');

      // Y al volver a la app no se prende solo.
      await notifier.resumeGpsIfNeeded();
      expect(notifier.state.mode, UserLocationMode.sinPunto);
      expect(llamadasGps, isEmpty);
    });
  }

  group('permiso denegado para siempre y concedido más tarde (T5.6)', () {
    const permisos = MethodChannel('flutter.baseflow.com/permissions/methods');
    const gps = MethodChannel('flutter.baseflow.com/geolocator');
    late int estado; // índice de PermissionStatus: 1 concedido, 4 para siempre

    setUp(() {
      final mensajero =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      mensajero.setMockMethodCallHandler(permisos, (call) async {
        if (call.method == 'checkPermissionStatus') return estado;
        if (call.method == 'shouldShowRequestPermissionRationale') {
          return false;
        }
        return null;
      });
      mensajero.setMockMethodCallHandler(gps, (call) async {
        if (call.method == 'isLocationServiceEnabled') return true;
        if (call.method == 'getCurrentPosition') {
          return {
            'latitude': 10.9512,
            'longitude': -74.79145,
            'timestamp': 0,
            'accuracy': 5.0,
            'altitude': 0.0,
            'altitude_accuracy': 0.0,
            'heading': 0.0,
            'heading_accuracy': 0.0,
            'speed': 0.0,
            'speed_accuracy': 0.0,
          };
        }
        return null;
      });
      addTearDown(() {
        mensajero.setMockMethodCallHandler(permisos, null);
        mensajero.setMockMethodCallHandler(gps, null);
      });
    });

    test('denegado para siempre y sin pin: queda bloqueado, sin preguntar',
        () async {
      estado = 4;
      final notifier = UserLocationNotifier();
      await notifier.initialize();
      expect(notifier.state.mode, UserLocationMode.permanentDenied);
    });

    for (final (nombre, inicial) in [
      ('bloqueado en Ajustes', 4),
      ('denegado', 0),
    ]) {
      test('$nombre, concedido en Ajustes: al volver ubica solo', () async {
        // La píldora manda a Ajustes; el usuario lo concede allá y vuelve.
        // Sin esto la app seguía diciendo «bloqueada» y la píldora volvía a
        // mandar a Ajustes: un círculo sin salida.
        SharedPreferences.setMockInitialValues({'user_loc_asked': true});
        estado = inicial;
        final notifier = UserLocationNotifier();
        addTearDown(notifier.dispose);
        await notifier.initialize();
        expect(notifier.state.hasPosition, isFalse);

        estado = 1;
        await notifier.resumeGpsIfNeeded();

        expect(notifier.state.mode, UserLocationMode.gps);
        expect(notifier.state.lat, 10.9512);
      });
    }

    test('al volver sin conceder nada no se mueve ni pregunta', () async {
      SharedPreferences.setMockInitialValues({'user_loc_asked': true});
      estado = 4;
      final notifier = UserLocationNotifier();
      await notifier.initialize();
      await notifier.resumeGpsIfNeeded();
      expect(notifier.state.mode, UserLocationMode.permanentDenied);
    });

    test('con pin manual, conceder más tarde no se lo quita', () async {
      SharedPreferences.setMockInitialValues({
        _kManualLat: 10.9,
        _kManualLon: -74.8,
        'user_loc_asked': true,
      });
      estado = 0;
      final notifier = UserLocationNotifier();
      await notifier.initialize();
      expect(notifier.state.isManual, isTrue);

      estado = 1;
      await notifier.resumeGpsIfNeeded();
      expect(notifier.state.isManual, isTrue);
      expect(notifier.state.lat, 10.9);
    });
  });
  // El pin salta a la ruta que se sigue; el ancla es donde lo puso la
  // persona. Cada ruta nueva lo lleva a ella desde el ancla, no desde el
  // salto anterior: de la A a la B y de vuelta a la A, el pin vuelve a su
  // sitio en vez de irse corriendo (dueño, 2026-11-06).
  group('ancla del pin', () {
    test('sin ancla aparte, el ancla es el pin', () {
      final notifier = UserLocationNotifier()..setManualPin(10.95, -74.79);
      expect(notifier.state.ancla, const GeoPoint(lat: 10.95, lon: -74.79));
    });

    test('el pin en la ruta guarda el ancla y la persiste', () async {
      final notifier = UserLocationNotifier()
        ..setManualPin(10.951, -74.791,
            ancla: const GeoPoint(lat: 10.95, lon: -74.79));
      await Future<void>.delayed(Duration.zero);

      expect(notifier.state.lat, 10.951);
      expect(notifier.state.ancla, const GeoPoint(lat: 10.95, lon: -74.79));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getDouble('user_loc_ancla_lat'), 10.95);
      expect(prefs.getDouble('user_loc_ancla_lon'), -74.79);
    });

    test('el arranque trae el ancla; sin ella guardada, el pin', () async {
      const permisos =
          MethodChannel('flutter.baseflow.com/permissions/methods');
      final mensajero =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      mensajero.setMockMethodCallHandler(permisos, (call) async => 0);
      addTearDown(() => mensajero.setMockMethodCallHandler(permisos, null));

      SharedPreferences.setMockInitialValues({
        _kManualLat: 10.951,
        _kManualLon: -74.791,
        'user_loc_ancla_lat': 10.95,
        'user_loc_ancla_lon': -74.79,
        'user_loc_asked': true,
      });
      final conAncla = UserLocationNotifier();
      await conAncla.initialize();
      expect(conAncla.state.ancla, const GeoPoint(lat: 10.95, lon: -74.79));

      SharedPreferences.setMockInitialValues({
        _kManualLat: 10.951,
        _kManualLon: -74.791,
        'user_loc_asked': true,
      });
      final deAntes = UserLocationNotifier();
      await deAntes.initialize();
      expect(deAntes.state.ancla, const GeoPoint(lat: 10.951, lon: -74.791));
    });

    test('un ancla guardada que no es un punto real vale como el pin',
        () async {
      const permisos =
          MethodChannel('flutter.baseflow.com/permissions/methods');
      final mensajero =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      mensajero.setMockMethodCallHandler(permisos, (call) async => 0);
      addTearDown(() => mensajero.setMockMethodCallHandler(permisos, null));
      SharedPreferences.setMockInitialValues({
        _kManualLat: 10.951,
        _kManualLon: -74.791,
        'user_loc_ancla_lat': double.nan,
        'user_loc_ancla_lon': -74.79,
        'user_loc_asked': true,
      });
      final notifier = UserLocationNotifier();
      await notifier.initialize();
      expect(notifier.state.ancla, const GeoPoint(lat: 10.951, lon: -74.791));
    });

    test('Quitar borra el ancla', () async {
      final notifier = UserLocationNotifier()
        ..setManualPin(10.951, -74.791,
            ancla: const GeoPoint(lat: 10.95, lon: -74.79));
      await Future<void>.delayed(Duration.zero);
      await notifier.clearManualPin();

      expect(notifier.state.ancla, isNull);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getDouble('user_loc_ancla_lat'), isNull);
      expect(prefs.getDouble('user_loc_ancla_lon'), isNull);
    });
  });
}
