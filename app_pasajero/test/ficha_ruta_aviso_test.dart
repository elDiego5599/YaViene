// La ruta va en el ícono del aviso (dueño, 2026-10-19): «que en el icono
// salga es la ruta tipo B18 C16». Android la lleva como ícono grande; iOS
// no deja cambiar el ícono de la app y la lleva como imagen adjunta.
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_pasajero/core/services/bus_notification_service.dart';
import 'package:ya_viene_pasajero/core/utils/bus_labels.dart';

const _canal = MethodChannel('dexterous.com/flutter/local_notifications');

const _png = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('el código es el primer pedazo del nombre: B18, C16, A1', () {
    expect(codigoRuta('B18 Tcherassi'), 'B18');
    expect(codigoRuta(' c16 Calle 72 Uninorte'), 'C16');
    expect(codigoRuta('A1 Silencio Universidades'), 'A1');
    // Un nombre sin código no se inventa uno.
    expect(codigoRuta('Ruta 106'), isNull);
    expect(codigoRuta('Calle 72'), isNull);
    expect(codigoRuta(''), isNull);
    expect(codigoRuta(null), isNull);
    // Al lado de la ficha va el nombre sin el código.
    expect(nombreSinCodigo('C16 Calle 72 Uninorte'), 'Calle 72 Uninorte');
    expect(nombreSinCodigo(' B18  Tcherassi'), 'Tcherassi');
    expect(nombreSinCodigo('Ruta 106'), 'Ruta 106');
    expect(nombreSinCodigo('C16'), 'C16');
    expect(nombreSinCodigo(null), isNull);
  });

  late Map<String, Object?> mostrada;

  void instalar() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_canal, (call) async {
      switch (call.method) {
        case 'areNotificationsEnabled':
          return true;
        case 'checkPermissions':
          return <String, Object?>{
            'isEnabled': true,
            'isSoundEnabled': true,
            'isAlertEnabled': true,
            'isBadgeEnabled': true,
            'isProvisionalEnabled': false,
            'isCriticalEnabled': false,
          };
        case 'getNotificationChannels':
          return [
            <String, Object?>{
              'id': 'bus_alerts',
              'name': 'Alertas de buses',
              'description': null,
              'groupId': null,
              'showBadge': true,
              'importance': 4,
              'bypassDnd': false,
              'playSound': true,
              'enableLights': false,
              'enableVibration': true,
              'vibrationPattern': null,
              'ledColor': 0,
              'audioAttributesUsage': 5,
            },
          ];
        case 'show':
          mostrada = Map<String, Object?>.from(call.arguments as Map);
      }
      return null;
    });
  }

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_canal, null);
  });

  test('Android: la ficha de la ruta es el ícono grande', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    instalar();
    expect(
      await BusNotificationService.notifyBusNear(
          busId: 'BUS-SQA223', routeName: 'B18 Tcherassi'),
      isTrue,
    );
    final android = mostrada['platformSpecifics'] as Map;
    final icono = android['largeIcon'];
    expect(icono, isA<Uint8List>());
    expect((icono as Uint8List).sublist(0, 8), _png);
  });

  test('iOS: la ficha va adjunta como imagen', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    IOSFlutterLocalNotificationsPlugin.registerWith();
    instalar();
    expect(
      await BusNotificationService.notifyBusNear(
          busId: 'BUS-SQA223', routeName: 'C16 Calle 72 Uninorte'),
      isTrue,
    );
    final ios = mostrada['platformSpecifics'] as Map;
    final adjuntos = ios['attachments'] as List;
    expect(adjuntos, hasLength(1));
    final archivo = File((adjuntos.single as Map)['filePath'] as String);
    expect(archivo.readAsBytesSync().sublist(0, 8), _png);
  });

  test('sin código de ruta el aviso sale igual, sin ficha', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    instalar();
    expect(
      await BusNotificationService.notifyBusNear(
          busId: 'BUS-SQA223', routeName: 'Ruta 106'),
      isTrue,
    );
    expect((mostrada['platformSpecifics'] as Map)['largeIcon'], isNull);
  });
}
