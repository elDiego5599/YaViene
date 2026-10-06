// Lo que el panel entiende de las respuestas del servidor al entrar y al
// comprobar la sesión. Contra un servidor de verdad en el puerto local: un
// doble de Dio diría lo que uno espera oír, no lo que el servidor manda.
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_control/features/auth/data/auth_api.dart';

void main() {
  late HttpServer servidor;
  var estado = HttpStatus.ok;
  Object? cuerpo;

  setUp(() async {
    estado = HttpStatus.ok;
    cuerpo = const <String, Object>{};
    servidor = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    servidor.listen((req) async {
      req.response.statusCode = estado;
      if (cuerpo != null) {
        req.response.headers.contentType = ContentType.json;
        req.response.write(jsonEncode(cuerpo));
      }
      await req.response.close();
    });
  });

  tearDown(() => servidor.close(force: true));

  AuthApi api() => AuthApi(baseUrl: 'http://127.0.0.1:${servidor.port}');

  group('validateSession', () {
    test('con 200 la sesión sigue viva', () async {
      expect(await api().validateSession('t-1'), isTrue);
    });

    // Riesgo: dar por buena cualquier respuesta 2xx. Un 204 de un proxy
    // delante del backend no dice que el token sirva.
    test('un 2xx que no es 200 no la da por buena', () async {
      estado = HttpStatus.noContent;
      cuerpo = null;

      expect(await api().validateSession('t-1'), isFalse);
    });

    // Un token vencido no es un fallo de red: pide la clave, no reintenta.
    test('un 401 es sesión vencida, sin lanzar', () async {
      estado = HttpStatus.unauthorized;

      expect(await api().validateSession('t-1'), isFalse);
    });

    test('un 500 lanza: no se sabe si la sesión sirve', () async {
      estado = HttpStatus.internalServerError;

      await expectLater(
        api().validateSession('t-1'),
        throwsA(isA<DioException>()),
      );
    });
  });

  group('login', () {
    test('un fallo con mensaje del servidor muestra ese mensaje', () async {
      estado = HttpStatus.serviceUnavailable;
      cuerpo = {
        'error': {'message': 'El servidor está en mantenimiento.'},
      };

      await expectLater(
        api().login('admin', 'clave'),
        throwsA(
          isA<AuthApiException>().having(
            (e) => e.message,
            'mensaje',
            'El servidor está en mantenimiento.',
          ),
        ),
      );
    });

    test('sin mensaje del servidor dice el código', () async {
      estado = HttpStatus.serviceUnavailable;
      cuerpo = {
        'error': {'code': 'X'},
      };

      await expectLater(
        api().login('admin', 'clave'),
        throwsA(
          isA<AuthApiException>().having(
            (e) => e.message,
            'mensaje',
            'El servidor respondió algo inesperado (503).',
          ),
        ),
      );
    });
  });
}
