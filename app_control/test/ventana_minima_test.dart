// El panel en una pestaña del navegador más chica que la ventana mínima.
//
// En el escritorio `window_manager` no deja achicar la ventana bajo
// 1200×700 (`ventanaMinima`). En el navegador la ventana es la pestaña y
// nadie la detiene: el tablero, medido de 1600 a 1200
// (panel_angosto_test.dart), se desbordaba. Bajo `ventanaMinimaWeb` el
// tablero se sigue armando a ese mínimo, recortado y sin perder lo que
// tenía, y encima va una ventana propia que pide agrandar la pestaña.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_control/core/theme/app_theme.dart';
import 'package:ya_viene_control/core/widgets/ventana.dart';
import 'package:ya_viene_control/core/widgets/ventana_minima.dart';

const _titulo = 'La ventana es muy pequeña';

/// Un tablero de mentira que cuenta sus toques y guarda estado propio.
class _Tablero extends StatefulWidget {
  const _Tablero();

  @override
  State<_Tablero> createState() => _TableroState();
}

class _TableroState extends State<_Tablero> {
  int toques = 0;

  @override
  Widget build(BuildContext context) => GestureDetector(
    key: const ValueKey('tablero'),
    behavior: HitTestBehavior.opaque,
    onTap: () => setState(() => toques++),
    child: const SizedBox.expand(),
  );
}

Future<void> _montar(
  WidgetTester tester,
  Size tamano, {
  bool web = true,
}) async {
  await tester.binding.setSurfaceSize(tamano);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: VentanaMinima(web: web, child: const _Tablero()),
    ),
  );
  await tester.pump();
}

Size _tamanoTablero(WidgetTester tester) =>
    tester.getSize(find.byKey(const ValueKey('tablero')));

void main() {
  testWidgets('en el mínimo de la pestaña el tablero va solo', (tester) async {
    await _montar(tester, ventanaMinimaWeb);

    expect(find.text(_titulo), findsNothing);
    expect(_tamanoTablero(tester), ventanaMinimaWeb);
  });

  // El portátil más común en las empresas: 768 − 40 de la barra de tareas
  // − ~85 de Chrome. Ahí el panel tiene que abrir sin aviso.
  testWidgets('en un portátil de 1366×768 (pestaña de 1366×643) no hay '
      'aviso', (tester) async {
    await _montar(tester, const Size(1366, 643));

    expect(find.text(_titulo), findsNothing);
    expect(_tamanoTablero(tester), const Size(1366, 643));
  });

  testWidgets('el aviso dice el mínimo que de verdad se pide', (tester) async {
    await _montar(tester, const Size(1000, 800));

    final w = ventanaMinimaWeb.width.toInt();
    final h = ventanaMinimaWeb.height.toInt();
    expect(find.textContaining('al menos $w × $h '), findsOneWidget);
  });

  for (final tamano in const [
    Size(1000, 800),
    Size(1400, 560),
    Size(375, 667),
  ]) {
    testWidgets('a ${tamano.width.toInt()}×${tamano.height.toInt()} pide '
        'agrandar sin desbordar el tablero', (tester) async {
      await _montar(tester, tamano);

      expect(find.byType(Ventana), findsOneWidget);
      expect(find.text(_titulo), findsOneWidget);
      // El tablero no se aprieta: se arma a lo mínimo que cuida y se recorta.
      expect(
        _tamanoTablero(tester),
        Size(
          math.max(tamano.width, ventanaMinimaWeb.width),
          math.max(tamano.height, ventanaMinimaWeb.height),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('con el aviso puesto el tablero no recibe toques', (
    tester,
  ) async {
    await _montar(tester, const Size(1000, 600));

    await tester.tapAt(const Offset(20, 20));
    await tester.pump();

    final estado = tester.state<_TableroState>(find.byType(_Tablero));
    expect(estado.toques, 0);
  });

  testWidgets(
    'al agrandar, el aviso se va y el tablero sigue siendo el mismo',
    (tester) async {
      await _montar(tester, const Size(1000, 600));
      final antes = tester.state<_TableroState>(find.byType(_Tablero));

      await tester.binding.setSurfaceSize(const Size(1400, 800));
      await tester.pump();

      expect(find.text(_titulo), findsNothing);
      // El mismo State: el socket y lo elegido en el tablero no se rehacen
      // cada vez que la pestaña cruza el mínimo.
      expect(tester.state<_TableroState>(find.byType(_Tablero)), same(antes));
      await tester.tap(find.byKey(const ValueKey('tablero')));
      expect(antes.toques, 1);
    },
  );

  testWidgets('en el escritorio no hay aviso: ahí manda window_manager', (
    tester,
  ) async {
    await _montar(tester, const Size(1000, 600), web: false);

    expect(find.text(_titulo), findsNothing);
    expect(_tamanoTablero(tester), const Size(1000, 600));
  });
}
