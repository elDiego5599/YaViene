import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/map_tour_provider.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/tracking_providers.dart';
import 'package:ya_viene_pasajero/features/map/presentation/widgets/cabecera_flotante.dart';
import 'package:ya_viene_pasajero/features/map/presentation/widgets/eta_bottom_sheet.dart';
import 'package:ya_viene_pasajero/features/map/presentation/widgets/map_recenter_button.dart';
import 'package:ya_viene_pasajero/features/map/presentation/widgets/map_tour_overlay.dart';
import 'package:ya_viene_pasajero/features/map/presentation/widgets/rueda_distancia.dart';
import 'package:ya_viene_pasajero/features/map/presentation/widgets/search_pill_bar.dart';

import 'helpers/fuentes.dart';
import 'helpers/mapa.dart';

/// Las áreas iluminadas de la guía, paso por paso, en tres teléfonos y con
/// la letra normal y grande (dueño, 2026-10-18: «hay algunas que no se ven
/// bien, otras que incluyen cosas extras»).
///
/// En cada paso: la carta no pisa el hueco ni se sale de la zona segura, lo
/// que el paso enseña está dentro del hueco, lo que no enseña está fuera, y
/// la carta no tapa la hoja que explica. Con las fuentes de verdad: con la
/// de las pruebas la carta mide más que en el teléfono.
typedef Telefono = ({String nombre, Size tam, double arriba, double abajo});

const telefonos = <Telefono>[
  (nombre: 'iPhone 15', tam: Size(390, 844), arriba: 47, abajo: 34),
  (nombre: 'iPhone SE', tam: Size(375, 667), arriba: 20, abajo: 0),
  (nombre: 'iPhone 15 Pro Max', tam: Size(430, 932), arriba: 59, abajo: 34),
];

Future<void> asentar(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> ponerTelefono(
    WidgetTester tester, Telefono t, double letra) async {
  tester.view.physicalSize = t.tam * 3;
  tester.view.devicePixelRatio = 3;
  final relleno = FakeViewPadding(top: t.arriba * 3, bottom: t.abajo * 3);
  tester.view.padding = relleno;
  tester.view.viewPadding = relleno;
  tester.platformDispatcher.textScaleFactorTestValue = letra;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

PintorHueco pintor(WidgetTester tester) => tester
    .widget<CustomPaint>(find.byKey(const ValueKey('guide_scrim')).last)
    .painter! as PintorHueco;

Rect carta(WidgetTester tester) =>
    tester.getRect(find.byKey(const ValueKey('guide_card')).last);

/// La cara blanca de la hoja de abajo (sin el botón de recentrar).
Rect hoja(WidgetTester tester) => tester.getRect(find.descendant(
      of: find.byType(EtaBottomSheet),
      matching: find.byWidgetPredicate((w) =>
          w is DecoratedBox &&
          w.decoration is ShapeDecoration &&
          w.key is GlobalKey),
    ));

bool contiene(Rect fuera, Rect dentro) =>
    fuera.inflate(0.5).contains(dentro.topLeft) &&
    fuera.inflate(0.5).contains(dentro.bottomRight);

void comun(WidgetTester tester, Telefono t, String paso) {
  final hueco = pintor(tester).hole;
  final c = carta(tester);
  expect(c.overlaps(hueco), isFalse,
      reason: '$paso: la carta $c pisa el hueco $hueco');
  expect(c.top, greaterThanOrEqualTo(t.arriba + 8 - 0.5),
      reason: '$paso: la carta se mete bajo la isla');
  expect(c.bottom,
      lessThanOrEqualTo(t.tam.height - (t.abajo - 16).clamp(12, 99) + 0.5),
      reason: '$paso: la carta baja hasta la barra de inicio');
  expect(hueco.height, greaterThanOrEqualTo(48), reason: paso);
}

void main() {
  setUpAll(cargarFuentes);

  for (final t in telefonos) {
    for (final letra in [1.0, 1.35]) {
      testWidgets('los huecos del mapa en ${t.nombre} con letra ×$letra',
          (tester) async {
        await ponerTelefono(tester, t, letra);
        final mapa = await MapaDePrueba.montar(tester);
        mapa.repo.foto([10.970]);
        await asentar(tester);
        final guia = mapa.container.read(mapGuideProvider.notifier);
        Future<void> ir(MapGuideStep paso) async {
          await tester.runAsync(() async => guia.moveTo(paso));
          await asentar(tester);
        }

        // Ubicación: el mapa libre entre la cabecera y la hoja.
        await tester.runAsync(() async {
          await guia.restart(hasLocation: false, locationSettled: true);
        });
        await asentar(tester);
        comun(tester, t, 'ubicación');
        var hueco = pintor(tester).hole;
        final pill = tester.getRect(find.byType(SearchPillBar));
        final chip = tester.getRect(find.byType(CabeceraFlotante));
        expect(hueco.top, greaterThan(pill.bottom), reason: 'ubicación');
        expect(hueco.top, greaterThan(chip.bottom), reason: 'ubicación');
        expect(hueco.bottom, lessThanOrEqualTo(hoja(tester).top + 0.5),
            reason: 'ubicación: el hueco se mete en la hoja');
        expect(hueco.height, greaterThan(t.tam.height * 0.25),
            reason: 'ubicación: queda poco mapa');

        // Búsqueda: la píldora entera, con su forma.
        await ir(MapGuideStep.search);
        comun(tester, t, 'búsqueda');
        hueco = pintor(tester).hole;
        expect(
            contiene(
                hueco, tester.getRect(find.byKey(const ValueKey('pill-logo')))),
            isTrue,
            reason: 'búsqueda: el logo queda fuera');
        expect(
            contiene(hueco,
                tester.getRect(find.byKey(const ValueKey('pill-quitar-ruta')))),
            isTrue,
            reason: 'búsqueda: la punta derecha queda fuera');
        expect(pintor(tester).radio, hueco.shortestSide / 2,
            reason: 'búsqueda: la píldora no es píldora');

        // Buses: el mapa libre, sin la hoja ni el botón de recentrar.
        await ir(MapGuideStep.buses);
        comun(tester, t, 'buses');
        hueco = pintor(tester).hole;
        expect(hueco.top, greaterThan(chip.bottom), reason: 'buses');
        final boton = tester.getRect(find.byType(MapRecenterButton));
        expect(hueco.bottom, lessThanOrEqualTo(boton.top - 12 + 0.5),
            reason: 'buses: el botón de recentrar queda partido');
        expect(hueco.bottom, lessThanOrEqualTo(hoja(tester).top + 0.5),
            reason: 'buses: el hueco se mete en la hoja');

        // Distancia: el número, y la carta fuera de la hoja.
        mapa.container
            .read(selectedBusesProvider.notifier)
            .toggleBus('BUS-SQA220');
        await ir(MapGuideStep.distance);
        comun(tester, t, 'distancia');
        expect(contiene(pintor(tester).hole, pintorObjetivo(tester)), isTrue,
            reason: 'distancia: el número queda fuera');
        cartaSobreLaHoja(tester, t, 'distancia');

        // Aviso: el botón, como píldora.
        await ir(MapGuideStep.alert);
        comun(tester, t, 'aviso');
        hueco = pintor(tester).hole;
        expect(
            contiene(
                hueco, tester.getRect(find.text('Avisarme cuando esté cerca'))),
            isTrue,
            reason: 'aviso: el botón queda fuera');
        expect(pintor(tester).radio, hueco.shortestSide / 2,
            reason: 'aviso: el botón no es píldora');
        cartaSobreLaHoja(tester, t, 'aviso');

        // La rueda: la pregunta, la rueda y sus dos botones.
        await tester.tap(find.text('Avisarme cuando esté cerca'));
        await asentar(tester);
        comun(tester, t, 'rueda');
        hueco = pintor(tester).hole;
        for (final f in [
          find.byType(RuedaDistancia),
          find.text('Guardar'),
          find.text('Solo esta vez'),
        ]) {
          expect(contiene(hueco, tester.getRect(f)), isTrue,
              reason: 'rueda: $f queda fuera de $hueco');
        }
        expect(pintor(tester).radio, AppRadius.card, reason: 'rueda');

        // Cierre: la carta al centro, dentro de la zona segura.
        await tester.tap(find.text('Guardar'));
        await asentar(tester);
        // Con el aviso armado la guía vuelve a su carta, ahora con botón.
        comun(tester, t, 'aviso armado');
        cartaSobreLaHoja(tester, t, 'aviso armado');
        await tester.tap(find.byKey(const ValueKey('guide_primary')));
        await asentar(tester);
        expect(mapa.container.read(mapGuideProvider).step,
            MapGuideStep.background);
        final c = carta(tester);
        expect(c.top, greaterThanOrEqualTo(t.arriba));
        expect(c.bottom, lessThanOrEqualTo(t.tam.height - t.abajo));
        await mapa.desmontar(tester);
      });

      testWidgets('el aviso trabado en ${t.nombre} con letra ×$letra',
          (tester) async {
        await ponerTelefono(tester, t, letra);
        final mapa = await MapaDePrueba.montar(tester);
        // A 110 m del pin: más cerca de lo que deja la rueda.
        mapa.repo.foto([10.989]);
        await asentar(tester);
        final guia = mapa.container.read(mapGuideProvider.notifier);
        mapa.container
            .read(selectedBusesProvider.notifier)
            .toggleBus('BUS-SQA220');
        await tester.runAsync(() async {
          await guia.restart(hasLocation: true, locationSettled: true);
          await guia.moveTo(MapGuideStep.alert);
        });
        await asentar(tester);
        expect(find.byKey(const ValueKey('guide_primary')), findsOneWidget);
        comun(tester, t, 'aviso trabado');
        cartaSobreLaHoja(tester, t, 'aviso trabado');
        await mapa.desmontar(tester);
      });
    }
  }
}

/// El objetivo que la pantalla le pasó a la guía.
Rect pintorObjetivo(WidgetTester tester) =>
    tester.widget<MapGuideOverlay>(find.byType(MapGuideOverlay).last).target;

/// Si cabe, la carta queda entera encima de la hoja; si no, el hueco se
/// recortó por debajo de ella.
void cartaSobreLaHoja(WidgetTester tester, Telefono t, String paso) {
  final c = carta(tester);
  final h = hoja(tester);
  final cabe = c.height + 12 <= h.top - (t.arriba + 8);
  if (cabe) {
    expect(c.bottom, lessThanOrEqualTo(h.top - 12 + 0.5),
        reason: '$paso: la carta tapa la hoja');
  } else {
    expect(pintor(tester).hole.top, greaterThanOrEqualTo(c.bottom + 12 - 0.5),
        reason: '$paso: la carta tapa el hueco');
  }
}
