import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_core/ya_viene_core.dart';

void main() {
  group('esUrlSegura', () {
    test('acepta https', () {
      expect(esUrlSegura('https://ya-viene-backend.fly.dev'), isTrue);
      expect(esUrlSegura('https://api.yaviene.co/api'), isTrue);
    });

    test('acepta http solo contra la propia máquina', () {
      expect(esUrlSegura('http://localhost:3000'), isTrue);
      expect(esUrlSegura('http://127.0.0.1:3000'), isTrue);
      expect(esUrlSegura('http://[::1]:3000'), isTrue);
    });

    test('rechaza http remoto: ahí viajan claves y tokens en claro', () {
      expect(esUrlSegura('http://ya-viene-backend.fly.dev'), isFalse);
      expect(esUrlSegura('http://192.168.1.40:3000'), isFalse);
      expect(esUrlSegura('ws://ya-viene-backend.fly.dev'), isFalse);
      expect(esUrlSegura('no es una url'), isFalse);
      // Riesgo: comparar el final del nombre. «evillocalhost» o
      // «mi.localhost» no son esta máquina: el tráfico sale a la red.
      expect(esUrlSegura('http://evillocalhost:3000'), isFalse);
      expect(esUrlSegura('http://mi.localhost:3000'), isFalse);
    });
  });
}
