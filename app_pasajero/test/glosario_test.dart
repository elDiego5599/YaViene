// T6.8 · Las palabras del pasajero son las del glosario.
//
// `ya_viene_core/lib/core/texto/glosario.json` es el glosario único (la
// web tiene la misma copia, atada por hash en `ya_viene_core/test`). Aquí se
// comprueba que lo que el pasajero lee —la distancia en la hoja, en el
// historial y en la notificación, y el título del aviso— dice lo que el
// glosario dice.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_pasajero/core/services/bus_notification_service.dart';
import 'package:ya_viene_pasajero/core/utils/distancia.dart';

const _canal = MethodChannel('dexterous.com/flutter/local_notifications');

final _glosario = jsonDecode(
  File('../ya_viene_core/lib/core/texto/glosario.json').readAsStringSync(),
) as Map<String, dynamic>;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  AndroidFlutterLocalNotificationsPlugin.registerWith();

  final distancia = _glosario['distancia'] as Map<String, dynamic>;
  final m = distancia['metros'] as String;
  final km = distancia['kilometros'] as String;
  final coma = distancia['separadorDecimal'] as String;

  test('la distancia sigue las reglas del glosario', () {
    // Menos de 1 km: metros enteros. Desde 1 km: un decimal con coma.
    // Desde 10 km: sin decimales.
    expect(distanciaAviso(430), '430 $m');
    expect(distanciaAviso(999), '999 $m');
    expect(distanciaAviso(1000), '1${coma}0 $km');
    expect(distanciaAviso(3400), '3${coma}4 $km');
    expect(distanciaAviso(14408), '14 $km');
    expect(kmLabel(9949), '9${coma}9 $km');
  });

  group('la notificación', () {
    late Map<String, Object?> mostrada;

    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_canal, (call) async {
        switch (call.method) {
          case 'areNotificationsEnabled':
            return true;
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
    });
    tearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_canal, null));

    Future<void> avisar(int metros) => BusNotificationService.notifyBusNear(
          busId: 'BUS-SQA223',
          routeName: 'Ruta 106',
          distanceMeters: metros,
        );

    test('el título es el aviso de la app: ruta y placa (regla 12)', () async {
      await avisar(430);
      final plantilla = (_glosario['aviso'] as Map)['app'] as String;
      expect(
        mostrada['title'],
        plantilla
            .replaceAll('{ruta}', 'Ruta 106')
            .replaceAll('{placa}', 'SQA223'),
      );
    });

    test('el cuerpo canta la distancia como el historial', () async {
      // El radio del aviso es ≤ 1000 m: justo en 1000, la notificación
      // decía «1000 m» y el historial de la misma alerta «1,0 km».
      for (final metros in [430, 1000]) {
        await avisar(metros);
        expect(mostrada['body'],
            'Está a ${distanciaAviso(metros)} de tu ubicación');
      }
    });
  });
}
