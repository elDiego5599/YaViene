// Recarga de la tarjeta SIBUS (D23). Ya Viene no cobra ni toca dinero: abre
// el canal del operador con una referencia opaca y, al volver, le pregunta
// al proveedor qué pasó. Estas pruebas son las de abuso: el enlace de
// regreso es entrada hostil y solo manda lo que dice el proveedor.
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ya_viene_pasajero/features/tarjeta/data/recarga_en_curso.dart';
import 'package:ya_viene_pasajero/features/tarjeta/data/servicio_recarga.dart';
import 'package:ya_viene_pasajero/features/tarjeta/domain/recarga.dart';
import 'package:ya_viene_pasajero/features/tarjeta/domain/tarjeta.dart';

const _refA = 'AbCdEfGhIjKlMnOp1234';
const _refB = 'ZyXwVuTsRqPoNmLk9876';

ReferenciaRecarga _ref(String s) => ReferenciaRecarga.leer(s)!;

NumeroTarjeta _tarjeta() =>
    (NumeroTarjeta.leer('12345678') as NumeroValido).numero;

class _Proveedor implements ProveedorRecarga {
  _Proveedor({
    Uri? pagina,
    this.estado = const RecargaPendiente(),
    this.inicio,
    this.paginas = const PaginasDePago(hosts: {'pagos.operador.co'}),
  }) : pagina = pagina ?? Uri.parse('https://pagos.operador.co/pagar/$_refA');

  Uri pagina;
  ConsultaRecarga estado;
  InicioRecarga? inicio;
  final consultadas = <ReferenciaRecarga>[];

  @override
  final PaginasDePago paginas;

  @override
  bool get simulado => true;

  @override
  Future<InicioRecarga> iniciar(NumeroTarjeta numero) async =>
      inicio ?? RecargaLista(referencia: _ref(_refA), pagina: pagina);

  @override
  Future<ConsultaRecarga> consultar(ReferenciaRecarga referencia) async {
    consultadas.add(referencia);
    return estado;
  }
}

class _Banco {
  _Banco({DateTime? ahora}) : ahora = ahora ?? DateTime(2026, 11, 13, 10);
  DateTime ahora;
  final abiertas = <Uri>[];
  final registro = <String>[];
  bool abre = true;
}

Future<(ServicioRecarga, _Proveedor, _Banco, SharedPreferences)> _armar({
  _Proveedor? proveedor,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final banco = _Banco();
  final p = proveedor ?? _Proveedor();
  final servicio = ServicioRecarga(
    proveedor: p,
    enCurso: RecargaEnCurso(prefs, reloj: () => banco.ahora),
    abrir: (url) async {
      banco.abiertas.add(url);
      return banco.abre;
    },
    registrar: banco.registro.add,
  );
  return (servicio, p, banco, prefs);
}

void main() {
  group('ReferenciaRecarga', () {
    test('acepta una referencia opaca de 16 a 64 caracteres seguros', () {
      expect(ReferenciaRecarga.leer(_refA), isNotNull);
      expect(ReferenciaRecarga.leer('a' * 16), isNotNull);
      expect(ReferenciaRecarga.leer('a_-' * 21 + 'a'), isNotNull); // 64
    });

    test('rechaza lo que no tiene la forma', () {
      for (final mala in [
        null,
        '',
        'corta',
        'a' * 15,
        'a' * 65,
        '../../etc/passwd/xxxx',
        'con espacio 1234567890',
        'tildeátilde1234567',
        'nul\u0000nul12345678901',
        'a=b&c=d1234567890123',
        '12345678\n12345678',
      ]) {
        expect(ReferenciaRecarga.leer(mala), isNull, reason: '$mala');
      }
    });

    test('no se deja imprimir entera', () {
      final r = _ref(_refA);
      expect('$r', isNot(contains(_refA)));
      expect('$r', contains(_refA.substring(0, 4)));
    });
  });

  group('enlace de regreso: basura', () {
    test('solo yaviene://recarga con una referencia válida pasa', () {
      expect(
        referenciaDeEnlace('yaviene://recarga?referencia=$_refA&estado=ok'),
        _ref(_refA),
      );
    });

    test('ignora todo lo que no es el enlace de recarga', () {
      for (final basura in [
        '',
        'basura',
        'yaviene://recarga',
        'yaviene://recarga?referencia=',
        'yaviene://recarga?referencia=corta',
        'yaviene://recarga?estado=aprobada',
        'yaviene://aviso?referencia=$_refA',
        'yaviene://recarga.malo.com?referencia=$_refA',
        'yaviene://malo@recarga?referencia=$_refA',
        'yaviene://recarga:99?referencia=$_refA',
        'yaviene://recarga/otra?referencia=$_refA',
        'yaviene://recarga?referencia=$_refA&referencia=$_refB',
        'https://recarga/?referencia=$_refA',
        'otro://recarga?referencia=$_refA',
        'YAVIENE://RECARGA?referencia=$_refA' 'x' * 600,
        'yaviene://recarga?referencia=%00%00%00%00%00%00%00%00%00%00%00%00%00%00%00%00',
        'yaviene://recarga?referencia=<script>alert(1)</script>',
        '::: no es un uri :::',
      ]) {
        expect(referenciaDeEnlace(basura), isNull, reason: basura);
      }
    });

    test('el estado del enlace no se lee: no existe en el resultado', () {
      // Que `estado=aprobada` no llegue a ningún sitio es parte del tipo:
      // el parser devuelve solo la referencia.
      expect(
        referenciaDeEnlace(
            'yaviene://recarga?referencia=$_refA&estado=aprobada'),
        isA<ReferenciaRecarga>(),
      );
    });
  });

  group('regreso al servicio', () {
    test('enlace con basura no consulta nada', () async {
      final (s, p, _, _) = await _armar();
      await s.iniciar(_tarjeta());
      expect(await s.alVolver('yaviene://recarga?referencia=!!'), isNull);
      expect(p.consultadas, isEmpty);
    });

    test('referencia ajena: se ignora y no se consulta', () async {
      final (s, p, _, _) = await _armar();
      await s.iniciar(_tarjeta());
      expect(
        await s.alVolver('yaviene://recarga?referencia=$_refB&estado=aprobada'),
        isNull,
      );
      expect(p.consultadas, isEmpty);
    });

    test('enlace válido sin recarga en curso se ignora', () async {
      final (s, p, _, _) = await _armar();
      expect(
        await s.alVolver('yaviene://recarga?referencia=$_refA&estado=aprobada'),
        isNull,
      );
      expect(p.consultadas, isEmpty);
    });

    test('el enlace repetido no vale dos veces', () async {
      final (s, p, _, _) = await _armar();
      p.estado = const RecargaAprobada(valor: 10000);
      await s.iniciar(_tarjeta());
      const enlace = 'yaviene://recarga?referencia=$_refA&estado=aprobada';
      expect(await s.alVolver(enlace), const RecargaAprobada(valor: 10000));
      expect(await s.alVolver(enlace), isNull);
      expect(p.consultadas, hasLength(1));
    });

    test('el enlace dice aprobada y el proveedor rechazada: manda el proveedor',
        () async {
      final (s, p, _, _) = await _armar();
      p.estado = const RecargaRechazada();
      await s.iniciar(_tarjeta());
      expect(
        await s.alVolver('yaviene://recarga?referencia=$_refA&estado=aprobada'),
        const RecargaRechazada(),
      );
    });

    test('sin red al volver: sigue pendiente y se puede reintentar', () async {
      final (s, p, _, _) = await _armar();
      p.estado = const RecargaSinRed();
      await s.iniciar(_tarjeta());
      const enlace = 'yaviene://recarga?referencia=$_refA';
      expect(await s.alVolver(enlace), const RecargaSinRed());
      p.estado = const RecargaAprobada(valor: 5000);
      expect(await s.reanudar(), const RecargaAprobada(valor: 5000));
      expect(await s.reanudar(), isNull);
    });

    test('mientras el proveedor no contesta, se queda en Pendiente', () async {
      final (s, p, _, _) = await _armar();
      p.estado = const RecargaPendiente();
      await s.iniciar(_tarjeta());
      const enlace = 'yaviene://recarga?referencia=$_refA&estado=aprobada';
      expect(await s.alVolver(enlace), const RecargaPendiente());
      expect(await s.alVolver(enlace), const RecargaPendiente());
    });

    test('el proveedor no la conoce: desconocida y se cierra', () async {
      final (s, p, _, _) = await _armar();
      p.estado = const RecargaDesconocida();
      await s.iniciar(_tarjeta());
      expect(
        await s.alVolver('yaviene://recarga?referencia=$_refA'),
        const RecargaDesconocida(),
      );
      expect(await s.reanudar(), isNull);
    });

    test('una recarga vieja ya no vale', () async {
      final (s, p, banco, _) = await _armar();
      await s.iniciar(_tarjeta());
      banco.ahora = banco.ahora.add(const Duration(hours: 2));
      expect(await s.alVolver('yaviene://recarga?referencia=$_refA'), isNull);
      expect(p.consultadas, isEmpty);
    });

    test('iniciar otra recarga reemplaza la anterior', () async {
      final (s, p, _, _) = await _armar();
      await s.iniciar(_tarjeta());
      p.inicio = RecargaLista(
        referencia: _ref(_refB),
        pagina: Uri.parse('https://pagos.operador.co/pagar/$_refB'),
      );
      await s.iniciar(_tarjeta());
      expect(await s.alVolver('yaviene://recarga?referencia=$_refA'), isNull);
      expect(
        await s.alVolver('yaviene://recarga?referencia=$_refB'),
        const RecargaPendiente(),
      );
    });

    test('quitar la tarjeta olvida la recarga en curso', () async {
      final (s, _, _, _) = await _armar();
      await s.iniciar(_tarjeta());
      await s.olvidar();
      expect(await s.alVolver('yaviene://recarga?referencia=$_refA'), isNull);
      expect(await s.reanudar(), isNull);
    });
  });

  group('salida: solo páginas permitidas, sin el número', () {
    test('abre la página del proveedor y queda Pendiente', () async {
      final (s, _, banco, _) = await _armar();
      expect(await s.iniciar(_tarjeta()), const RecargaPendiente());
      expect(banco.abiertas.single.host, 'pagos.operador.co');
    });

    test('un dominio que no está en la lista no se abre', () async {
      for (final mala in [
        'https://malo.example/pagar/$_refA',
        'http://pagos.operador.co/pagar/$_refA',
        'https://pagos.operador.co.malo.example/pagar/$_refA',
        'https://pagos.operador.co@malo.example/pagar/$_refA',
        'https://malo.example/@pagos.operador.co/pagar/$_refA',
        'javascript:alert(1)',
        'yaviene://recarga?referencia=$_refA',
        'file:///etc/passwd',
      ]) {
        final (s, _, banco, _) = await _armar(
          proveedor: _Proveedor(pagina: Uri.parse(mala)),
        );
        expect(await s.iniciar(_tarjeta()), const RecargaNoAbierta(),
            reason: mala);
        expect(banco.abiertas, isEmpty, reason: mala);
        expect(await s.reanudar(), isNull, reason: mala);
      }
    });

    test('si la página lleva el número de la tarjeta, no se abre', () async {
      final (s, _, banco, _) = await _armar(
        proveedor: _Proveedor(
          pagina: Uri.parse('https://pagos.operador.co/pagar?tarjeta=12345678'),
        ),
      );
      expect(await s.iniciar(_tarjeta()), const RecargaNoAbierta());
      expect(banco.abiertas, isEmpty);
    });

    test('sin red al iniciar: no se abre nada ni se guarda', () async {
      final (s, _, banco, prefs) = await _armar(
        proveedor: _Proveedor(inicio: const InicioSinRed()),
      );
      expect(await s.iniciar(_tarjeta()), const RecargaSinRed());
      expect(banco.abiertas, isEmpty);
      expect(prefs.getKeys(), isEmpty);
    });

    test('si el sistema no la abre, no queda nada pendiente', () async {
      final (s, _, banco, _) = await _armar();
      banco.abre = false;
      expect(await s.iniciar(_tarjeta()), const RecargaNoAbierta());
      expect(await s.reanudar(), isNull);
    });
  });

  group('lo que se guarda y lo que se escribe', () {
    test('en disco solo hay la referencia y la hora, nunca el número',
        () async {
      final (s, _, _, prefs) = await _armar();
      await s.iniciar(_tarjeta());
      final todo = [
        for (final k in prefs.getKeys()) '$k=${prefs.get(k)}',
      ].join('|');
      expect(todo, isNot(contains('12345678')));
      expect(todo, contains(_refA));
    });

    test('el registro nunca lleva la referencia entera ni el número', () async {
      final (s, p, banco, _) = await _armar();
      p.estado = const RecargaAprobada(valor: 1000);
      await s.iniciar(_tarjeta());
      await s.alVolver('yaviene://recarga?referencia=$_refA&estado=aprobada');
      await s.alVolver('yaviene://recarga?referencia=$_refB');
      await s.alVolver('basura-$_refA');
      expect(banco.registro, isNotEmpty);
      for (final linea in banco.registro) {
        expect(linea, isNot(contains(_refA)), reason: linea);
        expect(linea, isNot(contains(_refB)), reason: linea);
        expect(linea, isNot(contains('12345678')), reason: linea);
      }
    });
  });
}
