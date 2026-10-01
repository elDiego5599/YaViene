// La leyenda del mapa del panel (YV-29).
//
// Tenía tres renglones para cuatro situaciones: «Inactivo» no aparecía, y
// «Sin señal» llevaba el mismo gris que «Ocultos», así que la leyenda no
// servía para lo único que tiene que servir —decir qué es cada bus del
// mapa—. Y sus cifras se solapaban: un bus oculto y sin señal se contaba en
// dos renglones, de modo que sumarlos daba más buses de los que había.
//
// El plan pedía cerrar esto con una foto de referencia (golden). No se hace
// así: `app_control` no tiene el andamiaje de goldens que sí tiene el
// pasajero, y las fotos del pasajero acaban de declararse prueba local
// porque cada máquina las dibuja distinto. Una prueba de widget afirma lo
// mismo —cuatro renglones, cuatro íconos, cuatro colores, las cifras— y
// además corre en la CI, que es donde una foto no correría.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_control/core/theme/app_theme.dart';
import 'package:ya_viene_control/features/fleet/presentation/bus_estado.dart';
import 'package:ya_viene_control/features/fleet/presentation/widgets/control_map.dart';

Future<void> _montar(WidgetTester tester, Map<BusEstado, int> conteo) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        backgroundColor: AppColors.bg,
        body: Center(child: FleetLegend(conteo: conteo)),
      ),
    ),
  );
}

const _conteo = <BusEstado, int>{
  BusEstado.enLinea: 7,
  BusEstado.inactivo: 2,
  BusEstado.sinSenal: 3,
  BusEstado.oculto: 0,
};

void main() {
  testWidgets('la leyenda nombra las cuatro situaciones, no tres', (
    tester,
  ) async {
    await _montar(tester, _conteo);

    for (final estado in BusEstado.values) {
      expect(
        find.text(estado.rotulo),
        findsOneWidget,
        reason: 'falta el renglón de ${estado.rotulo}',
      );
    }
  });

  testWidgets('cada renglón trae su ícono, y ninguno repite', (tester) async {
    await _montar(tester, _conteo);

    final iconos = <IconData>{};
    for (final estado in BusEstado.values) {
      expect(
        find.byIcon(estado.icono),
        findsOneWidget,
        reason: '${estado.rotulo} no muestra su ícono',
      );
      iconos.add(estado.icono);
    }
    expect(iconos.length, BusEstado.values.length);
  });

  testWidgets('cada ícono va del color de su estado, y ninguno repite', (
    tester,
  ) async {
    await _montar(tester, _conteo);

    final colores = <Color>{};
    for (final estado in BusEstado.values) {
      final icono = tester.widget<Icon>(find.byIcon(estado.icono));
      expect(icono.color, estado.color, reason: 'color de ${estado.rotulo}');
      colores.add(estado.color);
    }
    expect(colores.length, BusEstado.values.length);
  });

  testWidgets('el ícono se anuncia con el nombre del estado', (tester) async {
    await _montar(tester, _conteo);

    for (final estado in BusEstado.values) {
      final icono = tester.widget<Icon>(find.byIcon(estado.icono));
      expect(icono.semanticLabel, estado.rotulo);
    }
  });

  testWidgets('cada renglón muestra su cifra', (tester) async {
    await _montar(tester, _conteo);

    for (final entrada in _conteo.entries) {
      expect(
        find.text('${entrada.value}'),
        findsOneWidget,
        reason: 'cifra de ${entrada.key.rotulo}',
      );
    }
  });

  testWidgets('un estado en cero se queda a la vista, en cero', (tester) async {
    await _montar(tester, _conteo);

    // Que no haya buses ocultos es información: el renglón desaparecido haría
    // dudar de si el panel dejó de contarlos.
    expect(find.text('Oculto'), findsOneWidget);
    expect(find.text('0'), findsOneWidget);
  });

  testWidgets('sin datos de un estado, ese renglón cuenta cero', (
    tester,
  ) async {
    await _montar(tester, const {BusEstado.enLinea: 4});

    expect(find.text('Sin señal'), findsOneWidget);
    // Tres ceros: inactivo, sin señal y oculto.
    expect(find.text('0'), findsNWidgets(3));
    expect(tester.takeException(), isNull);
  });
}
