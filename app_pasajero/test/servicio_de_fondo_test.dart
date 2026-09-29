// El servicio de fondo se apaga solo si la app deja de dar señales
// (auditoría 2026-09, H1).
//
// El plugin (`flutter_background_service_android` 6.3.1) revive el
// servicio con su perro guardián cada vez que el sistema lo para sin un
// `stopService` explícito, también al quitar la app de recientes. El
// servicio renacido corre sin la app: sin socket y sin avisos, solo la
// notificación fija. Por eso el servicio espera las señales de vida de la
// app y, si dejan de llegar, se para él mismo con `stopSelf`, que es la
// parada explícita que el perro guardián respeta.
import 'dart:async';

import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_pasajero/services/background_keep_alive.dart';

class _ServicioFalso implements ServiceInstance {
  final _canales = <String, StreamController<Map<String, dynamic>?>>{};
  bool parado = false;

  StreamController<Map<String, dynamic>?> _canal(String metodo) =>
      _canales.putIfAbsent(metodo, StreamController.broadcast);

  /// Lo que la app le manda al servicio.
  void recibir(String metodo) => _canal(metodo).add(null);

  @override
  Stream<Map<String, dynamic>?> on(String method) => _canal(method).stream;

  @override
  void invoke(String method, [Map<String, dynamic>? args]) {}

  @override
  Future<void> stopSelf() async => parado = true;
}

void main() {
  testWidgets('sin señales de la app, el servicio se para solo',
      (tester) async {
    final servicio = _ServicioFalso();
    await atenderServicio(servicio);

    await tester.pump(const Duration(seconds: 70));
    expect(servicio.parado, isTrue);
    servicio.recibir('stopService');
    await tester.pump();
  });

  testWidgets('con señales cada 20 s sigue vivo', (tester) async {
    final servicio = _ServicioFalso();
    await atenderServicio(servicio);

    for (var i = 0; i < 9; i++) {
      await tester.pump(const Duration(seconds: 20));
      servicio.recibir('latido');
    }
    expect(servicio.parado, isFalse);
    servicio.recibir('stopService');
    await tester.pump();
    expect(servicio.parado, isTrue);
  });
}
