import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:ya_viene_core/ya_viene_core.dart';

/// Por qué falló una carga, dicho en las tres clases que el pasajero
/// distingue: sin conexión, servidor lento y servidor con problemas.
///
/// Antes todo era `Exception('Error al cargar datos (502)')` y la app decía
/// lo mismo con el wifi apagado que con el túnel sin backend detrás
/// (dueño, 2026-09-30).
void main() {
  group('clasificarFallo', () {
    test('sin red: el socket no llega a abrirse', () {
      expect(
        clasificarFallo(const SocketException('Failed host lookup')),
        FalloRed.sinConexion,
      );
      // Así lo envuelve `package:http` en iOS y Android.
      expect(
        clasificarFallo(http.ClientException('Connection failed')),
        FalloRed.sinConexion,
      );
    });

    test('un wifi con portal cautivo corta el TLS: tampoco hay salida', () {
      expect(
        clasificarFallo(const HandshakeException('portal')),
        FalloRed.sinConexion,
      );
    });

    test('nadie contesta a tiempo: lento', () {
      expect(clasificarFallo(TimeoutException('8 s')), FalloRed.lento);
    });

    test('contesta mal: problema del servidor', () {
      expect(clasificarFallo(const RespuestaFallida(502)), FalloRed.servidor);
      expect(
        clasificarFallo(const FormatException('<html>')),
        FalloRed.servidor,
      );
      expect(clasificarFallo(StateError('otro')), FalloRed.servidor);
    });
  });

  group('companiesProvider falla con su causa', () {
    Future<Object> errorDe(String url) async {
      final container = ProviderContainer(overrides: [
        backendUrlProvider.overrideWith(() => BackendUrl.fija(url)),
      ]);
      addTearDown(container.dispose);
      final sub = container.listen(companiesProvider, (_, __) {});
      addTearDown(sub.close);
      try {
        await container.read(companiesProvider.future);
      } catch (e) {
        return e;
      }
      fail('la carga debía fallar');
    }

    Future<String> servidor(int estado, String cuerpo) async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen((req) {
        req.response
          ..statusCode = estado
          ..write(cuerpo)
          ..close();
      });
      return 'http://127.0.0.1:${server.port}';
    }

    test('el túnel sin backend detrás (502) es del servidor', () async {
      final e = await errorDe(await servidor(502, 'ERR_NGROK_8012'));
      expect(e, isA<RespuestaFallida>());
      expect((e as RespuestaFallida).estado, 502);
      expect(clasificarFallo(e), FalloRed.servidor);
    });

    test('una página en vez de la lista es del servidor', () async {
      final e = await errorDe(await servidor(200, '<html>aviso</html>'));
      expect(clasificarFallo(e), FalloRed.servidor);
    });

    test('nadie escuchando en el puerto es falta de conexión', () async {
      // Se abre y se cierra un puerto para tener uno libre seguro.
      final libre = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final puerto = libre.port;
      await libre.close();
      final e = await errorDe('http://127.0.0.1:$puerto');
      expect(clasificarFallo(e), FalloRed.sinConexion);
    });
  });
}
