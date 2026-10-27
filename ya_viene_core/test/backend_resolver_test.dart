// Pruebas de a qué backend decide hablarle la app en el arranque.
//
// Lo que se protege aquí es un fallo de demo, no un detalle de red: la URL del
// backend es constante de compilación, así que sin respaldo una APK ya
// repartida se queda muerta si el túnel de ngrok se cae, y la única salida es
// recompilar e instalar de nuevo.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_core/ya_viene_core.dart';

const principal = 'https://tunel.ngrok-free.dev';
const respaldo = 'https://ya-viene-backend.fly.dev';

/// Sonda de mentira: contesta que sí solo a las URLs de [vivas], y apunta a
/// quién se le preguntó y con cuánta espera.
({
  Future<bool> Function(String, Duration) sonda,
  List<String> preguntadas,
  List<Duration> esperas,
}) sondaFalsa(Set<String> vivas) {
  final preguntadas = <String>[];
  final esperas = <Duration>[];
  return (
    sonda: (String url, Duration espera) async {
      preguntadas.add(url);
      esperas.add(espera);
      return vivas.contains(url);
    },
    preguntadas: preguntadas,
    esperas: esperas,
  );
}

void main() {
  test('con la principal viva no se pregunta por el respaldo', () async {
    final f = sondaFalsa({principal, respaldo});
    final elegida = await BackendResolver.resolver(
      principal: principal,
      respaldo: respaldo,
      sonda: f.sonda,
    );
    expect(elegida, principal);
    // Importa que sea exactamente una: este camino es el 99 % de los
    // arranques, y cada pregunta de más es tiempo de pantalla en blanco.
    expect(f.preguntadas, [principal]);
  });

  test('con la principal caída se usa el respaldo', () async {
    final f = sondaFalsa({respaldo});
    final elegida = await BackendResolver.resolver(
      principal: principal,
      respaldo: respaldo,
      sonda: f.sonda,
    );
    expect(elegida, respaldo);
    // La principal se pregunta dos veces antes de rendirse.
    expect(f.preguntadas, [principal, principal, respaldo]);
  });

  test('una principal lenta la primera vez se reintenta antes del respaldo',
      () async {
    // Medido (2026-10-26): la primera petición a ngrok tras un rato quieto
    // tardó 3,3 s y la siguiente 1,8. Con una sola pregunta de 3 s la app se
    // iba a la flota simulada del respaldo, con ngrok vivo.
    final preguntadas = <String>[];
    final esperas = <Duration>[];
    var intentos = 0;
    final elegida = await BackendResolver.resolver(
      principal: principal,
      respaldo: respaldo,
      sonda: (url, espera) async {
        preguntadas.add(url);
        esperas.add(espera);
        return url == principal && ++intentos > 1;
      },
    );
    expect(elegida, principal);
    expect(preguntadas, [principal, principal]);
    expect(esperas.last, BackendResolver.esperaPrincipalReintento);
    expect(esperas.last, greaterThan(BackendResolver.esperaPrincipal));
  });

  test('si ninguna contesta se devuelve la principal', () async {
    // A propósito: así el mensaje de error que ve el usuario habla del sitio
    // que se configuró, y no de un respaldo que él no sabe que existe.
    final f = sondaFalsa({});
    final elegida = await BackendResolver.resolver(
      principal: principal,
      respaldo: respaldo,
      sonda: f.sonda,
    );
    expect(elegida, principal);
  });

  test('sin respaldo configurado no se pregunta nada', () async {
    final f = sondaFalsa({});
    final elegida = await BackendResolver.resolver(
      principal: principal,
      respaldo: '',
      sonda: f.sonda,
    );
    expect(elegida, principal);
    expect(f.preguntadas, isEmpty);
  });

  test('un respaldo igual a la principal no gasta una petición', () async {
    final f = sondaFalsa({});
    final elegida = await BackendResolver.resolver(
      principal: principal,
      respaldo: principal,
      sonda: f.sonda,
    );
    expect(elegida, principal);
    expect(f.preguntadas, isEmpty);
  });

  test('el respaldo espera más que la principal', () async {
    // La máquina de Fly duerme mientras no se usa y la primera petición la
    // levanta: medido, ese arranque en frío tarda unos 8 segundos, así que
    // con la espera corta de la principal el respaldo nunca llegaría a tiempo.
    final f = sondaFalsa({});
    await BackendResolver.resolver(
      principal: principal,
      respaldo: respaldo,
      sonda: f.sonda,
    );
    expect(f.esperas.first, BackendResolver.esperaPrincipal);
    expect(f.esperas.last, BackendResolver.esperaRespaldo);
    expect(f.esperas.last, greaterThan(f.esperas.first));
  });

  // `responde` contra un servidor de verdad en esta máquina: la sonda falsa
  // de arriba no mira el estado ni el cuerpo. Un túnel caído contesta con su
  // página de error, y un backend a medias con un 5xx: ninguno es «vivo».
  group('responde', () {
    late HttpServer servidor;
    late int estado;
    late String cuerpo;

    setUp(() async {
      servidor = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      servidor.listen((peticion) {
        peticion.response
          ..statusCode = estado
          ..write(cuerpo);
        peticion.response.close();
      });
    });
    tearDown(() => servidor.close(force: true));

    Future<bool> pregunta() => BackendResolver.responde(
        'http://127.0.0.1:${servidor.port}', const Duration(seconds: 5));

    test('un 200 con el JSON de salud es un backend vivo', () async {
      estado = 200;
      cuerpo = jsonEncode({'status': 'ok'});
      expect(await pregunta(), isTrue);
    });

    test('un 503, aunque traiga el JSON de salud, no', () async {
      estado = 503;
      cuerpo = jsonEncode({'status': 'ok'});
      expect(await pregunta(), isFalse);
    });

    test('un 200 que no dice ok, o que no es JSON, no', () async {
      estado = 200;
      cuerpo = jsonEncode({'status': 'degradado'});
      expect(await pregunta(), isFalse);
      cuerpo = '<html>ERR_NGROK_3200</html>';
      expect(await pregunta(), isFalse);
    });

    test('sin nadie escuchando, no', () async {
      final puerto = servidor.port;
      await servidor.close(force: true);
      expect(
          await BackendResolver.responde(
              'http://127.0.0.1:$puerto', const Duration(seconds: 5)),
          isFalse);
    });
  });
}
