// La distancia de los avisos la elige la persona (dueño, 2026-10-06): una
// rueda de 500 m a 3 km, de 100 en 100, y «Guardar» la deja para los avisos
// que vienen.
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ya_viene_pasajero/features/notifications/presentation/providers/distancia_aviso_provider.dart';

void main() {
  test('la rueda va de 500 m a 3 km, de 100 en 100', () {
    expect(distanciasDeAviso, hasLength(26));
    expect(distanciasDeAviso.first, 500);
    expect(distanciasDeAviso.last, 3000);
    expect(distanciasDeAviso[5], 1000);
    expect(distanciasDeAviso, contains(distanciaAvisoInicial));
  });

  test('sin nada guardado no hay distancia: se pregunta', () async {
    SharedPreferences.setMockInitialValues({});
    final n = DistanciaAvisoNotifier();
    await n.load();
    expect(n.state, isNull);
  });

  test('«Guardar» la deja en el teléfono para la próxima vez', () async {
    SharedPreferences.setMockInitialValues({});
    await DistanciaAvisoNotifier().guardar(1800);

    final otra = DistanciaAvisoNotifier();
    await otra.load();
    expect(otra.state, 1800);
  });

  test('lo guardado fuera de 500–3000 m o con otro tipo no se cree', () async {
    for (final roto in <Object>[400, 3100, '1500', 1500.0, true]) {
      SharedPreferences.setMockInitialValues({'distancia_aviso_m': roto});
      final n = DistanciaAvisoNotifier();
      await n.load();
      expect(n.state, isNull, reason: 'guardado: $roto');
    }
  });

  test('no se guarda una distancia que la rueda no ofrece', () async {
    SharedPreferences.setMockInitialValues({});
    final n = DistanciaAvisoNotifier();
    expect(() => n.guardar(499), throwsArgumentError);
    expect(() => n.guardar(3001), throwsArgumentError);
    expect(n.state, isNull);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey('distancia_aviso_m'), isFalse);
  });

  // Un aviso suena cuando el bus está a su distancia o menos, y uno que
  // sonaría en segundos no sirve (y un salto del GPS lo dispara ya mismo):
  // la rueda deja 200 m de margen (dueño, 2026-10-07: «el bus ya va a
  // 2,4 km y aún puedo poner 2,6 km»). Con el bus a 2,6 km, hasta 2,4.
  test('la mayor distancia a 200 m o más del bus', () {
    expect(margenAvisoMetros, 200);
    for (final (metros, hasta) in <(double?, int?)>[
      (null, null),
      (3200, null),
      (3199, 2900),
      (2600, 2400),
      (2650, 2400),
      (834, 600),
      (800, 600),
      (700, 500),
      (650, 500),
      (120, 500),
    ]) {
      expect(distanciaAvisoHasta(metros), hasta, reason: 'bus a $metros m');
    }
  });
}
