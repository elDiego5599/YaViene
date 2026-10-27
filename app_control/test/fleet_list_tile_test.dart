// La fila de un bus en la lista del panel.
//
// La fila llevaba, además de la placa, un chip con la ruta y un segundo
// renglón con el conductor. El chip no cabía casi nunca: en 1440 ni se
// pintaba y en 1600 salía cortado («Vivero Pa…»), y el nombre del
// conductor de la flota de ejemplo («Conductor 3001») no le decía nada al
// operador. El dueño pidió quitar los dos: la fila es la placa y su estado,
// y la ruta ya la dice la pestaña elegida arriba. El nombre ya ni llega:
// el backend dejó de mandarlo (no hay app de conductor, 2026-10-27).
//
// Estas pruebas miden con la tipografía de verdad. Con Ahem, la de cajas
// que usa `flutter test` si no se le da otra, cada letra es un cuadrado y
// los anchos no se parecen a los de la app, y aquí lo que se prueba es
// justo si las cosas caben. Cargarla en este archivo no toca las demás
// pruebas: cada archivo corre en su propio aislado.
//
// Y miden en macOS y en Windows, que es donde corre el panel. Sin decirlo,
// `flutter test` se hace pasar por Android, y allá el lápiz mide 40 de
// ancho en vez de los 33 del escritorio: el hueco de la placa saldría 7 más
// angosto que el de verdad y las cuentas de aquí no probarían la app.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_control/core/theme/app_theme.dart';
import 'package:ya_viene_control/features/fleet/domain/fleet_bus.dart';
import 'package:ya_viene_control/features/fleet/presentation/widgets/fleet_list_tile.dart';

Future<void> _cargarFuentes() async {
  final manifiesto =
      json.decode(await rootBundle.loadString('FontManifest.json'))
          as List<dynamic>;

  for (final entrada in manifiesto.cast<Map<String, dynamic>>()) {
    final cargador = FontLoader(entrada['family'] as String);
    final fuentes = (entrada['fonts'] as List).cast<Map<String, dynamic>>();
    for (final fuente in fuentes) {
      cargador.addFont(rootBundle.load(fuente['asset'] as String));
    }
    await cargador.load();
  }
}

/// El ancho de una fila para una ventana de tanto. El panel arranca
/// maximizado (`windowManager.maximize()` en `main.dart`), así que lo normal
/// es que el ancho lo ponga la pantalla, pero la cuenta vale también para
/// una ventana achicada a mano: la lista es siempre un cuarto
/// (`flex: 1` contra el `flex: 3` del mapa, sin puntos de quiebre). A la
/// lista le toca un cuarto de lo que dejan los 16 de cada lado y los 12
/// entre lista y mapa, y a la fila eso menos el borde de la lista (1 y 1) y
/// el relleno de su `ListView` (12 y 12).
double _fila(double pantalla) => (pantalla - 16 * 2 - 12) / 4 - 2 - 24;

/// 1280 es un portátil de 1920 con Windows al 150 % o una MacBook vieja, 1440
/// una MacBook Air y 1600 el tamaño con que se abre la ventana antes de
/// maximizarla.
final _anchos = [_fila(1280), _fila(1440), _fila(1600)];

/// La más ancha y la más angosta de las placas del tablero de ejemplo.
const _placas = ['WNP659', 'KJT704'];

/// La placa más ancha que puede haber: tres letras y tres números, las más
/// anchas de la tipografía, con el guion que llevan las placas de antes.
const _placaMasAncha = 'WWW000';

const _rutaCorta = 'Tcherassi';
const _rutaLarga = 'Vivero Paraíso';

Future<void> _montar(
  WidgetTester tester, {
  required double ancho,
  required String placa,
  String? ruta,
  bool enTerminal = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      // La fila vive en un `ListView`, que le da el ancho de la lista y
      // ningún límite de alto. Encerrada en una caja de alto fijo se
      // estiraría hasta llenarla y las medidas no serían las de la app.
      home: Scaffold(
        body: ListView(
          children: [
            Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: ancho,
                child: FleetListTile(
                  bus: FleetBus(
                    busId: placa,
                    companyId: 'empresa',
                    placa: placa,
                    visible: true,
                    online: false,
                    isGhost: true,
                    enTerminal: enTerminal,
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
          ],
        ),
      ),
    ),
  );
}

/// El panel solo se instala en escritorio (`app_control` es macOS y
/// Windows), y ahí el lápiz y el interruptor miden lo mismo en las dos.
const _escritorio = TargetPlatformVariant(<TargetPlatform>{
  TargetPlatform.macOS,
  TargetPlatform.windows,
});

RenderParagraph _parrafo(WidgetTester tester, String texto) =>
    tester.renderObject<RenderParagraph>(find.text(texto));

/// Lo que se le perdona a una medida al compararla con otra. Cuando la placa
/// se achica justo hasta llenar el hueco, su ícono termina en
/// 157,00000000000003 y el lápiz empieza en 157: no se montan, es la coma
/// flotante.
const _holgura = 0.01;

/// Si el texto se pintó entero o lo cortaron los puntos suspensivos.
bool _entero(RenderParagraph parrafo) =>
    parrafo.size.width + _holgura >=
    parrafo.getMaxIntrinsicWidth(double.infinity);

void main() {
  setUpAll(_cargarFuentes);

  testWidgets('marca En terminal aparte del estado Oculto manual', (
    tester,
  ) async {
    await _montar(
      tester,
      ancho: _fila(1440),
      placa: 'WNP659',
      enTerminal: true,
    );
    expect(find.text('En terminal'), findsOneWidget);
    final semantic = tester.getSemantics(
      find.bySemanticsLabel('Placa WNP659, Inactivo, En terminal'),
    );
    expect(semantic.label, contains('En terminal'));
  });

  for (final ancho in _anchos) {
    for (final placa in _placas) {
      testWidgets(
        'a ${ancho.toStringAsFixed(0)} con $placa la fila es la placa y su '
        'estado, sin ruta ni conductor',
        (tester) async {
          await _montar(tester, ancho: ancho, placa: placa, ruta: _rutaLarga);

          expect(tester.takeException(), isNull, reason: 'la fila se desborda');
          expect(
            _entero(_parrafo(tester, placa)),
            isTrue,
            reason: 'la placa se cortó',
          );
          expect(
            find.text(_rutaLarga),
            findsNothing,
            reason: 'volvió el chip de la ruta',
          );

          final icono = tester.getRect(find.byIcon(Icons.pause_circle_outline));
          final lapiz = tester.getRect(find.byType(IconButton));
          expect(
            icono.right,
            lessThanOrEqualTo(lapiz.left + _holgura),
            reason: 'el ícono de estado quedó encima del lápiz',
          );
        },
        variant: _escritorio,
      );
    }
  }

  // Con la ventana maximizada la placa nunca se achica, ni la más ancha
  // posible en la pantalla más chica.
  for (final ruta in [_rutaLarga, null]) {
    testWidgets('a 1280 la placa más ancha va a su tamaño, '
        'con ${ruta ?? 'ninguna ruta'}', (tester) async {
      await _montar(
        tester,
        ancho: _fila(1280),
        placa: _placaMasAncha,
        ruta: ruta,
      );

      expect(tester.takeException(), isNull, reason: 'la fila se desborda');
      final placa = _parrafo(tester, _placaMasAncha);
      expect(_entero(placa), isTrue, reason: 'la placa se cortó');
      expect(
        tester.getRect(find.text(_placaMasAncha)).width,
        closeTo(placa.size.width, _holgura),
        reason: 'la placa se achicó teniendo sitio',
      );
    }, variant: _escritorio);
  }

  // Achicando la ventana a mano se llega a un ancho en que ni la placa sola
  // cabe: ahí se achica lo justo, entera y sin salirse de la fila.
  for (final ruta in [_rutaCorta, null]) {
    testWidgets(
      'con la ventana en 1200 la placa más ancha se achica sin salirse, '
      'con ${ruta ?? 'ninguna ruta'}',
      (tester) async {
        await _montar(
          tester,
          ancho: _fila(1200),
          placa: _placaMasAncha,
          ruta: ruta,
        );

        expect(tester.takeException(), isNull, reason: 'la fila se desborda');
        final placa = _parrafo(tester, _placaMasAncha);
        expect(_entero(placa), isTrue, reason: 'la placa se cortó');
        expect(
          tester.getRect(find.text(_placaMasAncha)).width,
          lessThan(placa.size.width),
        );
        final icono = tester.getRect(find.byIcon(Icons.pause_circle_outline));
        final lapiz = tester.getRect(find.byType(IconButton));
        expect(
          icono.right,
          lessThanOrEqualTo(lapiz.left + _holgura),
          reason: 'el ícono de estado quedó encima del lápiz',
        );
      },
      variant: _escritorio,
    );
  }
}
