import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_pasajero/config.dart';

void main() {
  group('AppConfig del pasajero en release', () {
    test('sin BACKEND_URL el arranque dice qué falta', () {
      expect(
        () => AppConfig.backendUrlPara('', release: true),
        throwsA(isA<StateError>()),
      );
    });

    test('rechaza http remoto: mandaría en claro el token y el punto', () {
      expect(
        () =>
            AppConfig.backendUrlPara('http://192.168.1.40:3000', release: true),
        throwsA(isA<StateError>()),
      );
      expect(
        AppConfig.backendUrlPara('https://occupy-shed-squatter.ngrok-free.dev',
            release: true),
        'https://occupy-shed-squatter.ngrok-free.dev',
      );
    });

    test('un respaldo inseguro no se usa', () {
      expect(
        AppConfig.respaldoPara('http://ya-viene-backend.fly.dev',
            release: true),
        '',
      );
      expect(
        AppConfig.respaldoPara('https://ya-viene-backend.fly.dev',
            release: true),
        'https://ya-viene-backend.fly.dev',
      );
    });

    test('en desarrollo vale localhost y http', () {
      expect(AppConfig.backendUrlPara('', release: false),
          'http://localhost:3000');
      expect(AppConfig.respaldoPara('http://192.168.1.40:3000', release: false),
          'http://192.168.1.40:3000');
    });
  });
}
