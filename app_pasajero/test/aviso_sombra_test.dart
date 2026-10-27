import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_pasajero/core/widgets/aviso.dart';

/// El cuadrito de «Deshacer» en Avisos llevaba debajo una franja de sombra
/// cortada en seco (dueño, 2026-10-27: «una sombra/iluminación abajo que se
/// ve rara»). El `SnackBar` recorta su contenido por defecto y la sombra de
/// la tarjeta, que baja más allá de ella, quedaba partida en una raya.
void main() {
  testWidgets('el SnackBar no recorta la sombra de la tarjeta', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => mostrarAviso(context, 'Aviso borrado',
                accion: ('Deshacer', (_) {})),
            child: const Text('borrar'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('borrar'));
    await tester.pumpAndSettle();
    expect(
        tester.widget<SnackBar>(find.byType(SnackBar)).clipBehavior, Clip.none);
    // La sombra no baja más de lo que cabe en el margen de abajo (16).
    final tarjeta =
        tester.widget<Container>(find.byKey(const ValueKey('aviso_tarjeta')));
    final sombras = (tarjeta.decoration! as BoxDecoration).boxShadow!;
    for (final s in sombras) {
      expect(
          s.offset.dy + s.blurRadius + s.spreadRadius, lessThanOrEqualTo(16));
    }
  });
}
