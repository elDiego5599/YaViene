import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_pasajero/features/map/presentation/utils/map_constants.dart';
import 'package:ya_viene_pasajero/features/map/presentation/widgets/halo_painter.dart';
import 'package:ya_viene_pasajero/features/map/presentation/widgets/map_bus_animator.dart';
import 'package:ya_viene_pasajero/features/map/presentation/widgets/map_markers.dart';
import 'package:ya_viene_pasajero/features/map/presentation/widgets/map_pin_utils.dart';
import 'package:ya_viene_pasajero/features/map/presentation/widgets/map_placeholders.dart';

void main() {
  group('map_markers', () {
    test('createPinMarker devuelve bytes no vacíos', () async {
      final bytes = await createPinMarker();
      expect(bytes, isA<Uint8List>());
      expect(bytes.length, greaterThan(100));
    });

    test('createFlatTransitMarker activo y fantasma devuelven bytes', () async {
      final active = await createFlatTransitMarker(
        const Color(0xFF14274E),
        isGhost: false,
      );
      final ghost = await createFlatTransitMarker(
        const Color(0xFF94A3B8),
        isGhost: true,
      );
      expect(active.length, greaterThan(100));
      expect(ghost.length, greaterThan(100));
      expect(active, isNot(equals(ghost)));
    });
  });

  group('map_bus_animator', () {
    test('BusMotion dura 1 segundo', () {
      final start = DateTime(2024, 1, 1, 12, 0, 0);
      final m = BusMotion(
        fromLat: 0,
        fromLon: 0,
        fromHeading: 0,
        toLat: 1,
        toLon: 1,
        toHeading: 90,
        start: start,
      );
      expect(m.isFinished(start), isFalse);
      expect(
          m.isFinished(
            start.add(const Duration(milliseconds: 999)),
          ),
          isFalse);
      expect(
          m.isFinished(
            start.add(const Duration(milliseconds: 1000)),
          ),
          isTrue);
      expect(
          m.isFinished(
            start.add(const Duration(seconds: 2)),
          ),
          isTrue);
    });

    test('displayOf interpola lineal y heading por arco corto', () {
      final start = DateTime(2024, 1, 1, 12, 0, 0);
      final m = BusMotion(
        fromLat: 10,
        fromLon: 20,
        fromHeading: 350,
        toLat: 20,
        toLon: 40,
        toHeading: 10,
        start: start,
      );
      // t=0
      final at0 = displayOf(m, start);
      expect(at0.$1, closeTo(10, 0.01));
      expect(at0.$2, closeTo(20, 0.01));
      expect(at0.$3, closeTo(350, 0.01));
      // t=0.5 -> heading 350 -> 10 por arco corto (20 grados, +10 desde 350)
      final atHalf = displayOf(m, start.add(const Duration(milliseconds: 500)));
      expect(atHalf.$1, closeTo(15, 0.01));
      expect(atHalf.$2, closeTo(30, 0.01));
      expect(atHalf.$3, closeTo(0, 0.01));
      // t=1
      final at1 = displayOf(m, start.add(const Duration(milliseconds: 1000)));
      expect(at1.$1, closeTo(20, 0.01));
      expect(at1.$2, closeTo(40, 0.01));
      expect(at1.$3, closeTo(10, 0.01));
    });
  });

  group('halo_painter', () {
    test('shouldRepaint detecta cambios', () {
      const a = HaloPainter(center: Offset(10, 10), phase: 0.5);
      const b = HaloPainter(center: Offset(10, 10), phase: 0.5);
      const c = HaloPainter(center: Offset(20, 10), phase: 0.5);
      const d = HaloPainter(center: Offset(10, 10), phase: 0.8);
      expect(a.shouldRepaint(b), isFalse);
      expect(a.shouldRepaint(c), isTrue);
      expect(a.shouldRepaint(d), isTrue);
    });

    testWidgets('HaloPainter pinta sin crashear', (tester) async {
      await tester.pumpWidget(
        const CustomPaint(
          size: Size(100, 100),
          painter: HaloPainter(center: Offset(50, 50), phase: 0.5),
        ),
      );
      expect(find.byType(CustomPaint), findsOneWidget);
    });
  });

  group('map_pin_utils', () {
    test('radiusCircleFeature genera polígono cerrado de 49 puntos', () {
      final feature = radiusCircleFeature(11.0041, -74.8070, 2000);
      expect(feature['type'], 'Feature');
      final geom = feature['geometry'] as Map;
      expect(geom['type'], 'Polygon');
      final coords = (geom['coordinates'] as List).first as List;
      expect(coords.length, 49); // 48 pasos + cierre
      expect(coords.first, equals(coords.last));
    });
  });

  group('map_placeholders', () {
    testWidgets('MapStylePlaceholder visible muestra texto', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MapStylePlaceholder(
              layersReady: false,
              placeholderShown: true,
              onFadeEnd: _noop,
            ),
          ),
        ),
      );
      expect(find.text('Preparando tu mapa…'), findsOneWidget);
    });

    testWidgets('MapStylePlaceholder invisible no muestra texto',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MapStylePlaceholder(
              layersReady: true,
              placeholderShown: false,
              onFadeEnd: _noop,
            ),
          ),
        ),
      );
      expect(find.text('Preparando tu mapa…'), findsNothing);
    });

    testWidgets('MapStyleFailedBanner oculto es SizedBox', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Stack(children: [
              MapStyleFailedBanner(
                styleFailed: false,
                onRetry: _noop,
              ),
            ]),
          ),
        ),
      );
      expect(find.text('Reintentar'), findsNothing);
    });

    testWidgets('MapStyleFailedBanner visible muestra botón', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(children: [
              MapStyleFailedBanner(
                styleFailed: true,
                onRetry: () => tapped = true,
              ),
            ]),
          ),
        ),
      );
      expect(find.text('No se pudo cargar el mapa'), findsOneWidget);
      await tester.tap(find.text('Reintentar'));
      expect(tapped, isTrue);
    });
  });

  group('map_constants', () {
    test('constantes tienen valores esperados', () {
      expect(MapConstants.busHitRadius, 32.0);
      expect(MapConstants.guideBusRectSize, 76.0);
      expect(MapConstants.guideBottomInset, 310.0);
    });
  });
}

void _noop() {}
