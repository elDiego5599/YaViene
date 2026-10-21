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
    late List<Object?> retiradas;

    setUp(() {
      retiradas = [];
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
          case 'cancel':
            retiradas.add((call.arguments as Map)['id']);
        }
        return null;
      });
    });
    tearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_canal, null));

    Future<void> avisar() => BusNotificationService.notifyBusNear(
          busId: 'BUS-SQA223',
          routeName: 'Ruta 106',
        );

    test('el aviso dice solo la ruta, sin placa ni distancia (regla 12)',
        () async {
      // El dueño lo pidió así al probarlo en un Android (2026-10-02): una
      // línea, «Tu bus de la ruta X está cerca de ti». La placa y los metros
      // siguen en la hoja y en el historial.
      await avisar();
      final plantilla = (_glosario['aviso'] as Map)['app'] as String;
      expect(mostrada['title'], plantilla.replaceAll('{ruta}', 'Ruta 106'));
      expect(mostrada['body'], isNull);
    });

    test('sin nombre de ruta, usa su id; sin ninguno, no inventa', () async {
      await BusNotificationService.notifyBusNear(
        busId: 'BUS-SQA223',
        routeId: 'r106',
        companyId: 'coolitoral',
      );
      expect(mostrada['title'], 'Tu bus de la ruta r106 está cerca de ti');
      // Lleva el bus y su ruta: tocarlo abre el mapa en ese bus.
      expect(
          BusNotificationService.leerCarga(mostrada['payload'] as String?),
          const AvisoTocado(
            busId: 'BUS-SQA223',
            routeId: 'r106',
            companyId: 'coolitoral',
          ));
      await BusNotificationService.notifyBusNear(
        busId: 'BUS-SQA223',
      );
      expect(mostrada['title'], 'Tu bus está cerca de ti');
    });

    test('la misma notificación no suena dos veces; retirarla la quita',
        () async {
      // El servidor vigila aunque la app esté viva (D13): el push y el
      // barrido local pueden llegar juntos y ser la misma notificación.
      await avisar();
      final android = mostrada['platformSpecifics'] as Map;
      expect(android['onlyAlertOnce'], isTrue);
      final id = mostrada['id'];

      await BusNotificationService.retirar('BUS-SQA223');
      expect(retiradas, [id]);
    });
  });
}
