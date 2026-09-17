// La fila de un bus en la lista del panel.
//
// Con una ruta de nombre largo («Vivero Paraíso») la fila no cabía: el chip
// de la ruta no cedía nada, la placa quedaba en un hueco más angosto que
// ella misma y su ícono de estado se pintaba encima del chip. En una
// ventana de 1440 pasaba con cualquier ruta.
//
// Estas pruebas miden con la tipografía de verdad. Con Ahem, la de cajas
// que usa `flutter test` si no se le da otra, cada letra es un cuadrado y
// los anchos no se parecen a los de la app, y aquí lo que se prueba es
// justo si las cosas caben. Cargarla en este archivo no toca las demás
// pruebas: cada archivo corre en su propio aislado.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_control/core/theme/app_theme.dart';
import 'package:ya_viene_control/features/fleet/domain/fleet_bus.dart';
import 'package:ya_viene_control/features/fleet/presentation/widgets/fleet_list_tile.dart';

Future<void> _cargarFuentes() async {
  final manifiesto = json.decode(
    await rootBundle.loadString('FontManifest.json'),
  ) as List<dynamic>;

  for (final entrada in manifiesto.cast<Map<String, dynamic>>()) {
    final cargador = FontLoader(entrada['family'] as String);
    final fuentes = (entrada['fonts'] as List).cast<Map<String, dynamic>>();
    for (final fuente in fuentes) {
      cargador.addFont(rootBundle.load(fuente['asset'] as String));
    }
    await cargador.load();
  }
}

/// El ancho de una fila con la ventana maximizada. El panel arranca así
/// (`windowManager.maximize()` en `main.dart`), de modo que el ancho lo pone
/// la pantalla: a la lista le toca un cuarto de lo que dejan los 16 de cada
/// lado y los 12 entre lista y mapa, y a la fila eso menos el borde de la
/// lista (1 y 1) y el relleno de su `ListView` (12 y 12).
double _fila(double pantalla) => (pantalla - 16 * 2 - 12) / 4 - 2 - 24;

/// 1280 es un portátil de 1920 con Windows al 150 % o una MacBook vieja, 1440
/// una MacBook Air y 1600 el tamaño con que se abre la ventana antes de
/// maximizarla.
final _anchos = [_fila(1280), _fila(1440), _fila(1600)];

/// La más ancha y la más angosta de las placas del tablero de ejemplo.
const _placas = ['WNP-659', 'KJT-704'];

/// La placa más ancha que puede haber: tres letras y tres números, las más
/// anchas de la tipografía, con el guion que llevan las placas de antes.
const _placaMasAncha = 'WWW-000';

const _rutaCorta = 'Tcherassi';
const _rutaLarga = 'Vivero Paraíso';

Future<void> _montar(
  WidgetTester tester, {
  required double ancho,
  required String placa,
  String? ruta,
  String? conductor,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: ancho,
            child: FleetListTile(
              bus: FleetBus(
                busId: placa,
                companyId: 'empresa',
                placa: placa,
                driverName: conductor,
                visible: true,
                online: false,
                isGhost: true,
              ),
              selected: false,
              updating: false,
              routeName: ruta,
              onTap: () {},
              onToggle: (_) {},
              onEdit: () {},
            ),
          ),
        ),
      ),
    ),
  );
}

RenderParagraph _parrafo(WidgetTester tester, String texto) =>
    tester.renderObject<RenderParagraph>(find.text(texto));

/// Si el texto se pintó entero o lo cortaron los puntos suspensivos.
bool _entero(RenderParagraph parrafo) =>
    parrafo.size.width + 0.01 >= parrafo.getMaxIntrinsicWidth(double.infinity);

void main() {
  setUpAll(_cargarFuentes);

  for (final ancho in _anchos) {
    for (final ruta in [_rutaCorta, _rutaLarga, null]) {
      for (final placa in _placas) {
        testWidgets(
            'a ${ancho.toStringAsFixed(0)} con ${ruta ?? 'ninguna ruta'} '
            'y $placa nada se monta', (tester) async {
          await _montar(tester, ancho: ancho, placa: placa, ruta: ruta);

          expect(tester.takeException(), isNull, reason: 'la fila se desborda');
          expect(
            _entero(_parrafo(tester, placa)),
            isTrue,
            reason: 'la placa se cortó',
          );

          final icono = tester.getRect(find.byIcon(Icons.pause_circle_outline));
          final lapiz = tester.getRect(find.byType(IconButton));
          final chip = find.text(ruta ?? '');
          if (ruta != null && chip.evaluate().isNotEmpty) {
            final caja = tester.getRect(
              find.ancestor(of: chip, matching: find.byType(Container)).first,
            );
            expect(icono.right, lessThanOrEqualTo(caja.left),
                reason: 'el ícono de estado quedó encima del chip');
            expect(caja.right, lessThanOrEqualTo(lapiz.left),
                reason: 'el chip quedó encima del lápiz');
          } else {
            expect(icono.right, lessThanOrEqualTo(lapiz.left),
                reason: 'el ícono de estado quedó encima del lápiz');
          }
        });
      }
    }
  }

  testWidgets('con una ruta larga se corta el nombre de la ruta, no la placa',
      (tester) async {
    await _montar(tester, ancho: _fila(1600), placa: 'WNP-659', ruta: _rutaLarga);

    expect(tester.takeException(), isNull);
    expect(_entero(_parrafo(tester, 'WNP-659')), isTrue);
    expect(_entero(_parrafo(tester, _rutaLarga)), isFalse);
  });

  testWidgets('con espacio de sobra la ruta se lee entera', (tester) async {
    await _montar(tester, ancho: _fila(1600), placa: 'WNP-659', ruta: _rutaCorta);

    expect(_entero(_parrafo(tester, _rutaCorta)), isTrue);
  });

  // A 1440 a la placa angosta le sobraría para «Tche…», pero a la ancha no:
  // o todas las filas llevan chip o ninguna, y la lista no se ve salteada.
  for (final placa in _placas) {
    testWidgets('a 1440 no hay chip de ruta, tampoco con $placa',
        (tester) async {
      await _montar(tester, ancho: _fila(1440), placa: placa, ruta: _rutaCorta);

      expect(tester.takeException(), isNull);
      expect(find.text(_rutaCorta), findsNothing);
    });
  }

  // 1536 es una pantalla de 1920 con Windows al 125 %.
  testWidgets('desde 1536 el chip vuelve, aunque sea cortado', (tester) async {
    await _montar(tester, ancho: _fila(1536), placa: 'WNP-659', ruta: _rutaLarga);

    expect(tester.takeException(), isNull);
    expect(find.text(_rutaLarga), findsOneWidget);
  });

  // A 1280 la placa más ancha no cabe a su tamaño ni sin chip: se achica lo
  // justo, entera y sin salirse de la fila.
  for (final ruta in [_rutaCorta, null]) {
    testWidgets(
        'a 1280 la placa más ancha se achica sin salirse, '
        'con ${ruta ?? 'ninguna ruta'}', (tester) async {
      await _montar(tester, ancho: _fila(1280), placa: _placaMasAncha, ruta: ruta);

      expect(tester.takeException(), isNull, reason: 'la fila se desborda');
      final placa = _parrafo(tester, _placaMasAncha);
      expect(_entero(placa), isTrue, reason: 'la placa se cortó');
      expect(tester.getRect(find.text(_placaMasAncha)).width,
          lessThan(placa.size.width));
      final icono = tester.getRect(find.byIcon(Icons.pause_circle_outline));
      final lapiz = tester.getRect(find.byType(IconButton));
      expect(icono.right, lessThanOrEqualTo(lapiz.left),
          reason: 'el ícono de estado quedó encima del lápiz');
    });
  }

  testWidgets('con espacio la placa más ancha va a su tamaño', (tester) async {
    await _montar(tester, ancho: _fila(1600), placa: _placaMasAncha, ruta: _rutaLarga);

    expect(tester.takeException(), isNull);
    final placa = _parrafo(tester, _placaMasAncha);
    expect(tester.getRect(find.text(_placaMasAncha)).width,
        closeTo(placa.size.width, 0.01));
    expect(find.text(_rutaLarga), findsOneWidget);
  });

  testWidgets('un conductor de nombre largo no empuja la fila', (tester) async {
    await _montar(
      tester,
      ancho: _fila(1440),
      placa: 'KJT-704',
      ruta: _rutaCorta,
      conductor: 'María Fernanda Villalobos Castañeda',
    );

    expect(tester.takeException(), isNull);
    final nombre = _parrafo(tester, 'María Fernanda Villalobos Castañeda');
    expect(_entero(nombre), isFalse);
    expect(nombre.size.height, lessThan(20), reason: 'va en un solo renglón');
  });
}
