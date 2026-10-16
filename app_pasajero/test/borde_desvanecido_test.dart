import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_pasajero/core/widgets/borde_desvanecido.dart';

/// Lo que sube al desplazarse se disuelve bajo el título en vez de cortarse
/// en seco contra él (dueño, 2026-10-16: «como en la foto»), como el borde
/// de desplazamiento de iOS: sin vidrio, solo un fundido corto.
void main() {
  testWidgets('arriba se funde y debajo queda entero', (tester) async {
    final marco = GlobalKey();
    await tester.pumpWidget(Center(
      child: RepaintBoundary(
        key: marco,
        child: const SizedBox(
          width: 100,
          height: 100,
          child: ColoredBox(
            color: Colors.white,
            child: BordeDesvanecido(child: ColoredBox(color: Colors.black)),
          ),
        ),
      ),
    ));

    final caja =
        marco.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    late List<int> fila0, filaMedio, filaAbajo;
    await tester.runAsync(() async {
      final imagen = await caja.toImage();
      final datos =
          (await imagen.toByteData(format: ui.ImageByteFormat.rawRgba))!;
      int rojo(int y) => datos.getUint8((y * 100 + 50) * 4);
      fila0 = [rojo(0)];
      filaMedio = [rojo((BordeDesvanecido.alto / 2).floor())];
      filaAbajo = [rojo(BordeDesvanecido.alto.ceil() + 1), rojo(99)];
    });

    // Contra el blanco del fondo: el filo de arriba casi no se ve, a media
    // franja va a medias y pasada la franja es negro entero.
    expect(fila0.single, greaterThan(230));
    expect(filaMedio.single, inInclusiveRange(60, 200));
    expect(filaAbajo, everyElement(0));
  });
}
