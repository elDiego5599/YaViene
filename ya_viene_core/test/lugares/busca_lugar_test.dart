import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_core/core/lugares/buscador_falso.dart';
import 'package:ya_viene_core/core/lugares/lugar.dart';
import 'package:ya_viene_core/core/lugares/recientes_de_lugares.dart';
import 'package:ya_viene_core/core/models/route_trajectory.dart';
import 'package:ya_viene_core/shared/widgets/busca_lugar.dart';

const _prado = Sugerencia(
  lugar: Lugar(
    punto: GeoPoint(lat: 11.0, lon: -74.8),
    origen: OrigenLugar.sitio,
    nombre: 'El Prado',
  ),
  tipo: TipoLugar.barrio,
  contexto: 'Barrio, Barranquilla',
);
const _portal = Sugerencia(
  lugar: Lugar(
    punto: GeoPoint(lat: 10.993, lon: -74.793),
    origen: OrigenLugar.sitio,
    nombre: 'Portal del Prado',
  ),
  tipo: TipoLugar.sitio,
  contexto: 'Centro comercial, Barranquilla',
);
const _uninorte = Sugerencia(
  lugar: Lugar(
    punto: GeoPoint(lat: 11.019, lon: -74.851),
    origen: OrigenLugar.sitio,
    nombre: 'Universidad del Norte',
  ),
  tipo: TipoLugar.sitio,
  contexto: 'Universidad, Puerto Colombia',
);

class _Prueba {
  _Prueba(this.buscador, {List<Sugerencia> recientes = const []})
      : almacen = AlmacenEnMemoria() {
    _sembrados = recientes;
  }

  final BuscadorFalso buscador;
  final AlmacenEnMemoria almacen;
  late final RecientesDeLugares recientes = RecientesDeLugares(almacen);
  late final List<Sugerencia> _sembrados;
  final elegidos = <Lugar>[];
  var ubicacion = 0, mapa = 0;

  Future<void> montar(
    WidgetTester tester, {
    bool conUbicacion = true,
    GeoPoint? sesgo,
  }) async {
    for (final s in _sembrados.reversed) {
      await recientes.guardar(s);
    }
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: BuscaLugar(
          buscador: buscador,
          recientes: recientes,
          sesgo: sesgo,
          alElegir: elegidos.add,
          alUsarUbicacion: conUbicacion ? () => ubicacion++ : null,
          alElegirEnMapa: () => mapa++,
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }
}

Future<void> _escribir(WidgetTester tester, String texto) async {
  await tester.enterText(find.byType(TextField), texto);
  await tester.pumpAndSettle();
}

void main() {
  group('sin escribir nada', () {
    testWidgets('ofrece tu ubicación y elegir en el mapa', (tester) async {
      final p = _Prueba(BuscadorFalso());
      await p.montar(tester);

      await tester.tap(find.text('Tu ubicación'));
      await tester.tap(find.text('Elegir en el mapa'));
      expect(p.ubicacion, 1);
      expect(p.mapa, 1);
    });

    testWidgets('sin quien pida la ubicación, no la ofrece', (tester) async {
      final p = _Prueba(BuscadorFalso());
      await p.montar(tester, conUbicacion: false);

      expect(find.text('Tu ubicación'), findsNothing);
      expect(find.text('Elegir en el mapa'), findsOneWidget);
    });

    testWidgets('sin recientes no hay sección de recientes', (tester) async {
      final p = _Prueba(BuscadorFalso());
      await p.montar(tester);

      expect(find.text('Recientes'), findsNothing);
    });

    testWidgets('muestra los recientes, el más nuevo primero', (tester) async {
      final p = _Prueba(BuscadorFalso(), recientes: [_portal, _prado]);
      await p.montar(tester);

      expect(find.text('Recientes'), findsOneWidget);
      final yPortal = tester.getTopLeft(find.text('Portal del Prado')).dy;
      final yPrado = tester.getTopLeft(find.text('El Prado')).dy;
      expect(yPortal, lessThan(yPrado));
      expect(find.text('Barrio, Barranquilla'), findsOneWidget);
    });

    testWidgets('tocar un reciente lo elige', (tester) async {
      final p = _Prueba(BuscadorFalso(), recientes: [_prado]);
      await p.montar(tester);

      await tester.tap(find.text('El Prado'));
      expect(p.elegidos, [_prado.lugar]);
    });

    testWidgets('un reciente se borra solo, y queda borrado en el teléfono',
        (tester) async {
      final p = _Prueba(BuscadorFalso(), recientes: [_portal, _prado]);
      await p.montar(tester);

      await tester.tap(find.bySemanticsLabel('Quitar El Prado de recientes'));
      await tester.pumpAndSettle();

      expect(find.text('El Prado'), findsNothing);
      expect(find.text('Portal del Prado'), findsOneWidget);
      expect(await p.recientes.lista(), [_portal]);
    });

    testWidgets('Borrar quita todos los recientes', (tester) async {
      final p = _Prueba(BuscadorFalso(), recientes: [_portal, _prado]);
      await p.montar(tester);

      await tester.tap(find.text('Borrar'));
      await tester.pumpAndSettle();

      expect(find.text('Recientes'), findsNothing);
      expect(await p.recientes.lista(), isEmpty);
      expect(p.almacen.texto, isNull);
    });
  });

  group('al escribir', () {
    testWidgets('muestra cada sugerencia con su nombre y su contexto',
        (tester) async {
      final p = _Prueba(BuscadorFalso(respuestas: {
        'prado': [_prado, _portal],
      }));
      await p.montar(tester);
      await _escribir(tester, 'prado');

      expect(find.text('El Prado'), findsOneWidget);
      expect(find.text('Barrio, Barranquilla'), findsOneWidget);
      expect(find.text('Portal del Prado'), findsOneWidget);
      expect(find.text('Centro comercial, Barranquilla'), findsOneWidget);
    });

    testWidgets('los recientes se van mientras hay texto', (tester) async {
      final p = _Prueba(
        BuscadorFalso(respuestas: {
          'uni': [_uninorte],
        }),
        recientes: [_prado],
      );
      await p.montar(tester);
      await _escribir(tester, 'uni');

      expect(find.text('Recientes'), findsNothing);
      expect(find.text('El Prado'), findsNothing);
    });

    testWidgets('busca con el sesgo que se le da', (tester) async {
      final falso = BuscadorFalso();
      const sesgo = GeoPoint(lat: 10.96, lon: -74.79);
      await _Prueba(falso).montar(tester, sesgo: sesgo);
      await _escribir(tester, 'prado');

      expect(falso.consultas.last, (consulta: 'prado', sesgo: sesgo));
    });

    testWidgets('elegir una sugerencia la devuelve y la guarda en recientes',
        (tester) async {
      final p = _Prueba(BuscadorFalso(respuestas: {
        'prado': [_prado, _portal],
      }));
      await p.montar(tester);
      await _escribir(tester, 'prado');
      await tester.tap(find.text('Portal del Prado'));
      await tester.pumpAndSettle();

      expect(p.elegidos, [_portal.lugar]);
      expect(await p.recientes.lista(), [_portal]);
    });

    testWidgets('dice de dónde salen los datos bajo los resultados',
        (tester) async {
      final p = _Prueba(BuscadorFalso(
        respuestas: {
          'prado': [_prado],
        },
        atribucion: '© Colaboradores de OpenStreetMap (ODbL 1.0)',
      ));
      await p.montar(tester);
      await _escribir(tester, 'prado');

      expect(
        find.text('© Colaboradores de OpenStreetMap (ODbL 1.0)'),
        findsOneWidget,
      );
    });

    testWidgets('sin resultados lo dice y deja elegir en el mapa',
        (tester) async {
      final p = _Prueba(BuscadorFalso());
      await p.montar(tester);
      await _escribir(tester, 'zzz');

      expect(find.text('No encontramos ese lugar'), findsOneWidget);
      await tester.tap(find.text('Elegir en el mapa'));
      expect(p.mapa, 1);
    });

    testWidgets('borrar el texto vuelve a lo de antes', (tester) async {
      final p = _Prueba(
        BuscadorFalso(respuestas: {
          'uni': [_uninorte],
        }),
        recientes: [_prado],
      );
      await p.montar(tester);
      await _escribir(tester, 'uni');
      await tester.tap(find.bySemanticsLabel('Borrar lo escrito'));
      await tester.pumpAndSettle();

      expect(find.text('Universidad del Norte'), findsNothing);
      expect(find.text('El Prado'), findsOneWidget);
    });

    testWidgets('una respuesta vieja que llega tarde no pisa la nueva',
        (tester) async {
      final lento = _BuscadorPorConsulta({
        'pra': (const Duration(milliseconds: 600), [_portal]),
        'prado': (Duration.zero, [_prado]),
      });
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: BuscaLugar(
            buscador: lento,
            recientes: RecientesDeLugares(AlmacenEnMemoria()),
            alElegir: (_) {},
          ),
        ),
      ));
      await tester.enterText(find.byType(TextField), 'pra');
      await tester.pump(const Duration(milliseconds: 200));
      await tester.enterText(find.byType(TextField), 'prado');
      await tester.pumpAndSettle();

      expect(find.text('El Prado'), findsOneWidget);
      expect(find.text('Portal del Prado'), findsNothing);
    });
  });

  group('cuando falla', () {
    testWidgets('sin conexión lo dice así, y reintentar vuelve a buscar',
        (tester) async {
      final falso = BuscadorFalso(error: const SocketException('sin red'));
      await _Prueba(falso).montar(tester);
      await _escribir(tester, 'prado');

      expect(find.text('Sin conexión'), findsOneWidget);
      final antes = falso.consultas.length;
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(falso.consultas.length, antes + 1);
    });

    testWidgets('otro error dice que no se pudo buscar', (tester) async {
      final falso = BuscadorFalso(error: StateError('índice roto'));
      await _Prueba(falso).montar(tester);
      await _escribir(tester, 'prado');

      expect(find.text('No pudimos buscar'), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);
      expect(find.text('Sin conexión'), findsNothing);
    });
  });

  testWidgets('con movimiento reducido todo llega sin animar', (tester) async {
    final p = _Prueba(
      BuscadorFalso(respuestas: {
        'prado': [_prado],
      }),
    );
    await tester.pumpWidget(MediaQuery(
      data: const MediaQueryData(disableAnimations: true),
      child: MaterialApp(
        home: Scaffold(
          body: BuscaLugar(
            buscador: p.buscador,
            recientes: p.recientes,
            alElegir: p.elegidos.add,
          ),
        ),
      ),
    ));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'prado');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump();
    expect(find.text('El Prado'), findsOneWidget);
    // Sin fundido a medias: lo nuevo llega entero en el mismo cuadro.
    final opacidades = tester
        .widgetList<FadeTransition>(find.ancestor(
          of: find.text('El Prado'),
          matching: find.byType(FadeTransition),
        ))
        .map((f) => f.opacity.value);
    expect(opacidades, everyElement(1.0));
  });
}

/// Un buscador que tarda distinto según la consulta, para cruzar respuestas.
class _BuscadorPorConsulta extends BuscadorFalso {
  _BuscadorPorConsulta(this.tabla);

  final Map<String, (Duration, List<Sugerencia>)> tabla;

  @override
  Future<List<Sugerencia>> buscar(
    String consulta, {
    int maximo = 8,
    GeoPoint? sesgo,
  }) async {
    final (demora, lista) =
        tabla[consulta] ?? (Duration.zero, const <Sugerencia>[]);
    await Future<void>.delayed(demora);
    return lista;
  }
}
