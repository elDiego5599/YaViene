import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_pasajero/features/mas/presentation/fondo_ilustrado.dart';
import 'package:ya_viene_pasajero/features/splash/presentation/widgets/escena_arranque.dart';
import 'package:ya_viene_pasajero/features/splash/presentation/widgets/fondo_matizado.dart';

/// El fondo de Info (dueño, 2026-10-18): las ilustraciones de Barranquilla
/// chicas, regadas sin orden y con pocos buses, atenuadas sobre el
/// matizado del arranque. Solo arriba, detrás de la marca, y se apagan
/// hacia las tarjetas: en toda la pantalla hacían ruido (revisión externa,
/// 2026-10-18). Quieto.
void main() {
  const pantalla = Size(390, 844);

  testWidgets('siete dibujos, solo buses de empresas de la app',
      (tester) async {
    expect(Motivo.values, hasLength(7));
    // Un bus de una empresa que no está en la app promete lo que no hay.
    final buses = Motivo.values.where((m) => m.name.startsWith('bus'));
    expect(buses, {Motivo.busSobusa, Motivo.busCoolitoral});
    final cuenta = <Motivo, int>{};
    var dentro = 0;
    for (final c in FondoIlustrado.celdas(pantalla)) {
      if ((Offset.zero & pantalla).contains(c.centro)) {
        dentro++;
        cuenta[c.motivo] = (cuenta[c.motivo] ?? 0) + 1;
      }
    }
    expect(cuenta.keys.toSet(), Motivo.values.toSet());
    expect(dentro, inInclusiveRange(12, 24));
    final deBus = buses.map((m) => cuenta[m]!).reduce((a, b) => a + b);
    expect(deBus, lessThanOrEqualTo(dentro ~/ 4), reason: '$deBus/$dentro');
  });

  testWidgets('solo arriba: ninguno cae debajo de la franja', (tester) async {
    for (final c in FondoIlustrado.celdas(pantalla)) {
      expect(c.centro.dy, lessThanOrEqualTo(FondoIlustrado.franja),
          reason: '${c.centro}');
    }
  });

  testWidgets('se apaga hacia abajo, del todo al pie de la franja',
      (tester) async {
    await tester
        .pumpWidget(const MaterialApp(home: FondoIlustrado(child: SizedBox())));
    final mascara = tester.widget<ShaderMask>(find.byType(ShaderMask));
    expect(mascara.blendMode, BlendMode.dstIn);
    final dibujo = find.byType(Image).first;
    expect(find.ancestor(of: dibujo, matching: find.byType(ShaderMask)),
        findsOneWidget);
    final degradado = FondoIlustrado.desvanecido(const Size(390, 844));
    expect(degradado.colors.first.a, 1);
    expect(degradado.colors.last.a, 0);
    expect(degradado.stops!.last * 844, closeTo(FondoIlustrado.franja, 0.5));
  });

  testWidgets('chicos, regados sin orden y sin huecos', (tester) async {
    final celdas = FondoIlustrado.celdas(pantalla);
    const r = FondoIlustrado.separacion;
    for (final c in celdas) {
      expect(c.lado, inInclusiveRange(40, 62), reason: '${c.lado}');
    }
    // Con aire: ninguno pegado a otro.
    for (final a in celdas) {
      for (final b in celdas) {
        if (identical(a, b)) continue;
        expect((a.centro - b.centro).distance, greaterThanOrEqualTo(r));
      }
    }
    // Pero sin calvas: cualquier punto tiene un dibujo a poco más de [r]
    // (lo que mide la rejilla de donde se sacan).
    for (var y = 0.0; y <= FondoIlustrado.franja; y += 10) {
      for (var x = 0.0; x <= pantalla.width; x += 10) {
        final p = Offset(x, y);
        final cerca = celdas
            .map((c) => (c.centro - p).distance)
            .reduce((a, b) => a < b ? a : b);
        expect(cerca, lessThan(r * 1.1), reason: '$p');
      }
    }
    // «Todo con el mismo orden no cuadra»: no van en hileras. Si fueran
    // en filas, muchos compartirían altura; regados, no pasan de tres (en
    // pantalla: la orilla de la rejilla, por fuera, sí es una fila).
    final porAltura = <double, int>{};
    for (final c in celdas.where((c) => c.centro.dy >= 0)) {
      porAltura[c.centro.dy] = (porAltura[c.centro.dy] ?? 0) + 1;
    }
    expect(porAltura.values.every((n) => n <= 3), isTrue, reason: '$porAltura');
  });

  testWidgets('dos vecinos nunca repiten dibujo', (tester) async {
    final celdas = FondoIlustrado.celdas(pantalla);
    var pares = 0;
    for (final a in celdas) {
      for (final b in celdas) {
        final d = (a.centro - b.centro).distance;
        if (identical(a, b) || d > FondoIlustrado.separacion * 1.5) continue;
        pares++;
        expect(a.motivo, isNot(b.motivo), reason: '${a.centro} ${b.centro}');
      }
    }
    expect(pares, greaterThan(20));
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

  // «Atenúa un poco las imágenes en la pantalla de Info» (dueño,
  // 2026-10-18), y sin los puntitos ni las estrellitas de los huecos: con
  // los dibujos de fondo, sobraban.
  testWidgets('los dibujos, atenuados y sin relleno entre ellos',
      (tester) async {
    await tester
        .pumpWidget(const MaterialApp(home: FondoIlustrado(child: SizedBox())));
    final pintores = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((c) => c.painter)
        .whereType<CustomPainter>()
        .map((p) => p.runtimeType)
        .toSet();
    expect(pintores, {PintorMatizado, PintorVentana});
    final dibujos = [
      ...find.byType(Image).evaluate(),
      ...find
          .byWidgetPredicate(
              (w) => w is CustomPaint && w.painter is PintorVentana)
          .evaluate(),
    ];
    expect(dibujos, isNotEmpty);
    for (final e in dibujos) {
      final velo = e.findAncestorWidgetOfExactType<Opacity>();
      expect(velo, isNotNull);
      // «Quedó demasiado opaca, nada visualmente atractiva» (dueño,
      // 2026-10-18): al 40 % se perdían; vivos, sin pelearle a las tarjetas.
      expect(velo!.opacity, inInclusiveRange(0.65, 0.8));
    }
  });

  // «La Ventana al Mundo se ve súper oscura, cero colorida» (dueño,
  // 2026-10-18): chica, las juntas del arranque taparían los colores.
  testWidgets('la Ventana al Mundo chica conserva sus colores', (tester) async {
    for (final alto in [60.0, 290.0]) {
      final w = (alto * PintorVentana.aspecto).round(), h = alto.round();
      late ByteData datos;
      await tester.runAsync(() async {
        final grabadora = ui.PictureRecorder();
        PintorVentana(1)
            .paint(Canvas(grabadora), Size(w.toDouble(), h.toDouble()));
        final imagen = await grabadora.endRecording().toImage(w, h);
        datos = (await imagen.toByteData(format: ui.ImageByteFormat.rawRgba))!;
      });
      var visibles = 0, oscuros = 0;
      for (var i = 0; i < w * h; i++) {
        if (datos.getUint8(i * 4 + 3) < 200) continue;
        visibles++;
        final r = datos.getUint8(i * 4),
            g = datos.getUint8(i * 4 + 1),
            b = datos.getUint8(i * 4 + 2);
        if (0.2126 * r + 0.7152 * g + 0.0722 * b < 70) oscuros++;
      }
      expect(oscuros / visibles, lessThan(0.12), reason: 'alto $alto');
    }
  });

  testWidgets('quieto: no pide cuadros ni se repinta', (tester) async {
    await tester
        .pumpWidget(const MaterialApp(home: FondoIlustrado(child: SizedBox())));
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(
        const PintorMatizado().shouldRepaint(const PintorMatizado()), isFalse);
  });
}
