// El proveedor simulado habla con una pasarela de mentira (D23, D8). En la
// prueba la pasarela es un HttpServer en el lazo local: así se ve que la app
// le pregunta a ella el estado y que no se fía de nada más.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_pasajero/features/tarjeta/data/recarga_simulada.dart';
import 'package:ya_viene_pasajero/features/tarjeta/domain/recarga.dart';
import 'package:ya_viene_pasajero/features/tarjeta/domain/tarjeta.dart';

NumeroTarjeta _tarjeta() =>
    (NumeroTarjeta.leer('12345678') as NumeroValido).numero;

/// Pasarela falsa: guarda referencias y contesta lo que el test le ponga.
class _Pasarela {
  late final HttpServer servidor;
  final referencias = <String, Map<String, Object?>>{};
  final cuerposRecibidos = <String>[];
  final rutasPedidas = <String>[];
  int? forzarEstado;
  String? forzarCuerpo;

  Future<void> iniciar() async {
    servidor = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    servidor.listen((peticion) async {
      rutasPedidas.add('${peticion.method} ${peticion.uri}');
      final cuerpo = await utf8.decoder.bind(peticion).join();
      cuerposRecibidos.add(cuerpo);
      final r = peticion.response;
      if (forzarEstado != null) {
        r.statusCode = forzarEstado!;
        r.write(forzarCuerpo ?? '');
        return r.close();
      }
      final partes = peticion.uri.pathSegments;
      if (peticion.method == 'POST' && partes.join('/') == 'recargas') {
        final ref = (jsonDecode(cuerpo) as Map)['referencia'] as String;
        referencias[ref] = {'estado': 'pendiente'};
        r.statusCode = 201;
      } else if (peticion.method == 'GET' &&
          partes.length == 2 &&
          partes.first == 'recargas') {
        final dato = referencias[partes.last];
        if (dato == null) {
          r.statusCode = 404;
        } else {
          r.headers.contentType = ContentType.json;
          r.write(forzarCuerpo ?? jsonEncode(dato));
        }
      } else {
        r.statusCode = 404;
      }
      await r.close();
    });
  }

  Uri get base => Uri.parse('http://127.0.0.1:${servidor.port}');
  Future<void> cerrar() => servidor.close(force: true);
}

void main() {
  late _Pasarela pasarela;
  var hayRed = true;
  late RecargaSimulada proveedor;

  setUp(() async {
    hayRed = true;
    pasarela = _Pasarela();
    await pasarela.iniciar();
    proveedor = RecargaSimulada(
      base: pasarela.base,
      hayRed: () async => hayRed,
      espera: Duration.zero,
      limite: const Duration(seconds: 2),
    );
  });
  tearDown(() => pasarela.cerrar());

  test('es una simulación y su página es la de la pasarela', () {
    expect(proveedor.simulado, isTrue);
    expect(
        proveedor.paginas.permite(pasarela.base.resolve('/pagar/x')), isTrue);
    expect(
      proveedor.paginas.permite(Uri.parse('http://127.0.0.1:1/pagar/x')),
      isFalse,
      reason: 'otro puerto no es la pasarela',
    );
    expect(
      proveedor.paginas.permite(Uri.parse('https://127.0.0.1/pagar/x')),
      isFalse,
    );
  });

  group('iniciar', () {
    test('crea una referencia opaca que la pasarela conoce', () async {
      final inicio = await proveedor.iniciar(_tarjeta());
      final lista = inicio as RecargaLista;
      expect(pasarela.referencias.keys, [lista.referencia.valor]);
      expect(lista.pagina.path, '/pagar/${lista.referencia.valor}');
    });

    test('la pasarela y la URL nunca ven el número de la tarjeta', () async {
      final lista = await proveedor.iniciar(_tarjeta()) as RecargaLista;
      expect(lista.pagina.toString(), isNot(contains('12345678')));
      expect(pasarela.cuerposRecibidos.join(), isNot(contains('12345678')));
      expect(pasarela.rutasPedidas.join(), isNot(contains('12345678')));
    });

    test('cada recarga tiene su propia referencia', () async {
      final a = await proveedor.iniciar(_tarjeta()) as RecargaLista;
      final b = await proveedor.iniciar(_tarjeta()) as RecargaLista;
      expect(a.referencia, isNot(b.referencia));
    });

    test('sin red: InicioSinRed y no toca la pasarela', () async {
      hayRed = false;
      expect(await proveedor.iniciar(_tarjeta()), isA<InicioSinRed>());
      expect(pasarela.rutasPedidas, isEmpty);
    });

    test('la pasarela falla: no disponible', () async {
      pasarela.forzarEstado = 503;
      expect(await proveedor.iniciar(_tarjeta()), isA<InicioNoDisponible>());
    });

    test('la pasarela caída: no disponible', () async {
      await pasarela.cerrar();
      expect(await proveedor.iniciar(_tarjeta()), isA<InicioNoDisponible>());
    });
  });

  group('consultar: manda lo que dice la pasarela', () {
    Future<ReferenciaRecarga> nueva() async =>
        (await proveedor.iniciar(_tarjeta()) as RecargaLista).referencia;

    test('recién creada: pendiente', () async {
      expect(
          await proveedor.consultar(await nueva()), const RecargaPendiente());
    });

    test('aprobada con su valor', () async {
      final ref = await nueva();
      pasarela.referencias[ref.valor] = {'estado': 'aprobada', 'valor': 20000};
      expect(
        await proveedor.consultar(ref),
        const RecargaAprobada(valor: 20000),
      );
    });

    test('rechazada', () async {
      final ref = await nueva();
      pasarela.referencias[ref.valor] = {'estado': 'rechazada'};
      expect(await proveedor.consultar(ref), const RecargaRechazada());
    });

    test('referencia que la pasarela no conoce: desconocida', () async {
      final ajena = ReferenciaRecarga.leer('nunca-creada-1234567')!;
      expect(await proveedor.consultar(ajena), const RecargaDesconocida());
    });

    test('sin red: sin red, sin tocar la pasarela', () async {
      final ref = await nueva();
      pasarela.rutasPedidas.clear();
      hayRed = false;
      expect(await proveedor.consultar(ref), const RecargaSinRed());
      expect(pasarela.rutasPedidas, isEmpty);
    });

    test('lo ilegible se queda en pendiente, nunca en aprobada', () async {
      final ref = await nueva();
      for (final raro in [
        '',
        'no es json',
        '[]',
        '{"estado":"APROBADA!!"}',
        '{"estado":"aprobada;DROP"}',
        '{"estado":42}',
        '{}',
        '{"estado":"rechazada","valor":"mucho"}',
        '{"estado":"x"${' ' * 70000}}',
      ]) {
        pasarela.forzarCuerpo = raro;
        final r = await proveedor.consultar(ref);
        expect(
          r,
          anyOf(const RecargaPendiente(), const RecargaRechazada()),
          reason: raro.length > 100 ? 'cuerpo enorme' : raro,
        );
        expect(r, isNot(isA<RecargaAprobada>()), reason: '$raro');
      }
    });

    test('un valor absurdo no se enseña', () async {
      final ref = await nueva();
      for (final valor in [-1, 0, 99999999, 1.5, null]) {
        pasarela.referencias[ref.valor] = {
          'estado': 'aprobada',
          'valor': valor
        };
        expect(await proveedor.consultar(ref), const RecargaAprobada());
      }
    });

    test('error 500 o pasarela caída: pendiente', () async {
      final ref = await nueva();
      pasarela.forzarEstado = 500;
      expect(await proveedor.consultar(ref), const RecargaPendiente());
      pasarela.forzarEstado = null;
      await pasarela.cerrar();
      expect(await proveedor.consultar(ref), const RecargaPendiente());
    });
  });
}
