// AUD29-26 · Retirar un aviso antes de iniciar el servicio no hace ruido.
//
// Sin `init()`, el plugin de notificaciones no tiene su estado y `cancel`
// lanza; el `catch` lo dejaba en el log en cada arranque y tapaba los
// errores de verdad. Va en su propio archivo porque el servicio es estático:
// otra prueba que lo inicie antes lo dejaría iniciado para esta.
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_pasajero/core/services/bus_notification_service.dart';

const _canal = MethodChannel('dexterous.com/flutter/local_notifications');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  AndroidFlutterLocalNotificationsPlugin.registerWith();

  test('sin iniciar, retirar no llega al plugin ni escribe en el log',
      () async {
    final llamadas = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_canal, (call) async {
      llamadas.add(call.method);
      return null;
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_canal, null));
    final log = <String?>[];
    final antes = debugPrint;
    debugPrint = (mensaje, {wrapWidth}) => log.add(mensaje);
    addTearDown(() => debugPrint = antes);

    await BusNotificationService.retirar('BUS-SQA223');

    expect(llamadas, isEmpty);
    expect(log, isEmpty);
  });
}
