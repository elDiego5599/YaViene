import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:ya_viene_pasajero/core/services/mantener_vivo.dart';

// El stream de geolocator en iOS es uno solo para toda la app: si el mapa lo
// abrió antes (filtro de 8 m, sin segundo plano), pedirlo otra vez devolvía
// ese mismo, sin `allowsBackgroundLocationUpdates`, e iOS suspendía la app
// con el aviso armado (sin notificación ni actividad en vivo, 2026-10-26).
// Por eso el aviso pide al lado nativo su propio CLLocationManager.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const canal = MethodChannel('yaviene/mantener_vivo');
  late List<String> llamadas;

  setUp(() {
    llamadas = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(canal, (llamada) async {
      llamadas.add(llamada.method);
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(canal, null);
  });

  MantenerVivoIos servicio({
    bool ios = true,
    LocationPermission permiso = LocationPermission.whileInUse,
  }) =>
      MantenerVivoIos(esIos: () => ios, permiso: () async => permiso);

  test('con permiso pide al lado nativo su propio gestor y lo suelta',
      () async {
    final s = servicio();
    await s.iniciar();
    await s.iniciar();
    await s.detener();
    expect(llamadas, ['iniciar', 'detener']);
  });

  test('sin permiso de ubicación no pide nada', () async {
    await servicio(permiso: LocationPermission.denied).iniciar();
    expect(llamadas, isEmpty);
  });

  test('fuera de iOS no pide nada', () async {
    await servicio(ios: false).iniciar();
    expect(llamadas, isEmpty);
  });

  test('detener mientras arranca no deja el gestor prendido', () async {
    final s = servicio();
    final inicio = s.iniciar();
    await s.detener();
    await inicio;
    expect(llamadas.where((m) => m == 'iniciar').length,
        llamadas.where((m) => m == 'detener').length);
  });
}
