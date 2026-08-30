import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  test('clearManualPin borra el pin guardado', () async {
    SharedPreferences.setMockInitialValues({
      _kManualLat: 10.9512,
      _kManualLon: -74.79145,
    });
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
    await notifier.clearManualPin();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getDouble(_kManualLat), isNull);
    expect(prefs.getDouble(_kManualLon), isNull);
    expect(notifier.state.mode, UserLocationMode.denied);
  });
}
