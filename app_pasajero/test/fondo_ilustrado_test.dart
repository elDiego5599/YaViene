import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_pasajero/features/mas/presentation/fondo_ilustrado.dart';
import 'package:ya_viene_pasajero/features/splash/presentation/widgets/escena_arranque.dart';
import 'package:ya_viene_pasajero/features/splash/presentation/widgets/fondo_matizado.dart';

/// El fondo de Info (dueño, 2026-10-18): las ilustraciones de Barranquilla
/// «mucho más pequeñas, en toda la pantalla, con más buses diferentes y más
/// de cada cosa», como un papel de dibujos, sobre el matizado del arranque
/// y con relleno de puntitos, estrellitas y espirales entre ellas. Quieto.
void main() {
  const pantalla = Size(390, 844);

  testWidgets('nueve dibujos, los cuatro buses, y todos en un teléfono',
      (tester) async {
    expect(Motivo.values, hasLength(9));
    expect(Motivo.values.where((m) => m.name.startsWith('bus')), hasLength(4));
    final cuenta = <Motivo, int>{};
    for (final c in FondoIlustrado.celdas(pantalla)) {
      if ((Offset.zero & pantalla).contains(c.centro)) {
        cuenta[c.motivo] = (cuenta[c.motivo] ?? 0) + 1;
      }
    }
    expect(cuenta.keys.toSet(), Motivo.values.toSet());
    // «Más de cada cosa»: ninguno sale solo una o dos veces.
    for (final MapEntry(:key, :value) in cuenta.entries) {
      expect(value, greaterThanOrEqualTo(6), reason: '$key $value');
    }
  });

  testWidgets('chicos y por toda la pantalla, sin huecos', (tester) async {
    final celdas = FondoIlustrado.celdas(pantalla);
    for (final c in celdas) {
      expect(c.lado, inInclusiveRange(40, 62), reason: '${c.lado}');
    }
    // Cualquier punto de la pantalla tiene un dibujo cerca.
    for (var y = 0.0; y <= pantalla.height; y += 10) {
      for (var x = 0.0; x <= pantalla.width; x += 10) {
        final p = Offset(x, y);
        final cerca = celdas
            .map((c) => (c.centro - p).distance)
            .reduce((a, b) => a < b ? a : b);
        expect(cerca, lessThan(FondoIlustrado.celda * 0.75), reason: '$p');
      }
    }
  });

  testWidgets('dos vecinos nunca repiten dibujo', (tester) async {
    final celdas = FondoIlustrado.celdas(pantalla);
    var pares = 0;
    for (final a in celdas) {
      for (final b in celdas) {
        final d = (a.centro - b.centro).distance;
        if (d == 0 || d > FondoIlustrado.celda * 1.3) continue;
        pares++;
        expect(a.motivo, isNot(b.motivo), reason: '${a.centro} ${b.centro}');
      }
    }
    expect(pares, greaterThan(200));
  });

  testWidgets('las fotos existen, livianas y nítidas al tamaño en que van',
      (tester) async {
    var bytes = 0;
    for (final m in Motivo.values) {
      if (m.asset == null) continue;
      final archivo = File(m.asset!);
      expect(archivo.existsSync(), isTrue, reason: m.asset);
      bytes += archivo.lengthSync();
      late ui.Image imagen;
      await tester.runAsync(() async {
        final codec = await ui.instantiateImageCodec(archivo.readAsBytesSync());
        imagen = (await codec.getNextFrame()).image;
      });
      // El lado más largo alcanza para el dibujo más grande a @3x, y no
      // trae píxeles de más.
      final largo = imagen.width > imagen.height ? imagen.width : imagen.height;
      expect(largo, inInclusiveRange(170, 200), reason: m.asset);
    }
    expect(bytes, lessThan(110 * 1024), reason: '$bytes bytes');
  });

  // «Usa la misma Ventana al Mundo que en la pantalla de carga» (dueño,
  // 2026-10-18).
  testWidgets('la Ventana al Mundo es la del arranque, ya armada',
      (tester) async {
    expect(Motivo.ventana.asset, isNull);
    await tester
        .pumpWidget(const MaterialApp(home: FondoIlustrado(child: SizedBox())));
    final torres = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((c) => c.painter)
        .whereType<PintorVentana>()
        .toList();
    expect(torres, isNotEmpty);
    expect(torres.every((p) => p.avance == 1), isTrue);
  });

  testWidgets('sobre el matizado, sin anunciarse al lector de pantalla',
      (tester) async {
    await tester
        .pumpWidget(const MaterialApp(home: FondoIlustrado(child: SizedBox())));
    expect(
        find.byWidgetPredicate(
            (w) => w is CustomPaint && w.painter is PintorMatizado),
        findsOneWidget);
    final imagenes = tester.widgetList<Image>(find.byType(Image)).toList();
    expect(imagenes, isNotEmpty);
    expect(imagenes.every((i) => i.excludeFromSemantics), isTrue);
  });

  testWidgets('el relleno: puntitos, estrellitas y espirales de colores',
      (tester) async {
    expect(Relleno.values.map((r) => r.name).toSet(),
        containsAll(['punto', 'estrella', 'espiral']));
    final rellenos = PintorRelleno.piezas(pantalla);
    expect(rellenos.length,
        greaterThan(FondoIlustrado.celdas(pantalla).length ~/ 2));
    expect(rellenos.map((r) => r.tipo).toSet(), Relleno.values.toSet());
    // Pinta de verdad: hay color donde antes era transparente.
    final ancho = pantalla.width.toInt(), alto = pantalla.height.toInt();
    late ByteData datos;
    await tester.runAsync(() async {
      final grabadora = ui.PictureRecorder();
      const PintorRelleno().paint(Canvas(grabadora), pantalla);
      final imagen = await grabadora.endRecording().toImage(ancho, alto);
      datos = (await imagen.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    });
    var pintados = 0;
    for (var i = 0; i < ancho * alto; i++) {
      if (datos.getUint8(i * 4 + 3) > 0) pintados++;
    }
    expect(pintados, greaterThan(ancho * alto ~/ 100));
    // Y chico: no le quita sitio a los dibujos.
    expect(pintados, lessThan(ancho * alto ~/ 12));
  });

  testWidgets('quieto: no pide cuadros ni se repinta', (tester) async {
    await tester
        .pumpWidget(const MaterialApp(home: FondoIlustrado(child: SizedBox())));
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(const PintorRelleno().shouldRepaint(const PintorRelleno()), isFalse);
  });
}
