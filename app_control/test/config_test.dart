import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_control/config.dart';

void main() {
  group('AppConfig.esSegura', () {
    test('acepta https', () {
      expect(AppConfig.esSegura('https://ya-viene-backend.fly.dev'), isTrue);
      expect(AppConfig.esSegura('https://api.yaviene.co/api'), isTrue);
    });

    test('acepta http solo contra la propia máquina', () {
      expect(AppConfig.esSegura('http://localhost:3000'), isTrue);
      expect(AppConfig.esSegura('http://127.0.0.1:3000'), isTrue);
    });

    test('rechaza http remoto: ahí viaja la clave del panel en claro', () {
      expect(AppConfig.esSegura('http://ya-viene-backend.fly.dev'), isFalse);
      expect(AppConfig.esSegura('http://192.168.1.40:3000'), isFalse);
      expect(AppConfig.esSegura('ws://ya-viene-backend.fly.dev'), isFalse);
      expect(AppConfig.esSegura('no es una url'), isFalse);
      // Riesgo: comparar el final del nombre. «evillocalhost» o
      // «mi.localhost» no son esta máquina: el tráfico sale a la red.
      expect(AppConfig.esSegura('http://evillocalhost:3000'), isFalse);
      expect(AppConfig.esSegura('http://mi.localhost:3000'), isFalse);
    });
  });
}
