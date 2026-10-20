import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/map_guide_copy.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/map_tour_provider.dart';

void main() {
  group('isMapGuideStep', () {
    test('solo ubica los pasos del mapa', () {
      expect(isMapGuideStep(MapGuideStep.location), isTrue);
      expect(isMapGuideStep(MapGuideStep.search), isTrue);
      expect(isMapGuideStep(MapGuideStep.buses), isTrue);
      expect(isMapGuideStep(MapGuideStep.distance), isTrue);
      expect(isMapGuideStep(MapGuideStep.alert), isTrue);
      expect(isMapGuideStep(MapGuideStep.background), isTrue);
      expect(isMapGuideStep(MapGuideStep.company), isFalse);
      expect(isMapGuideStep(MapGuideStep.route), isFalse);
      expect(isMapGuideStep(MapGuideStep.launchBuses), isFalse);
      expect(isMapGuideStep(null), isFalse);
    });
  });

  group('guideCopyFor', () {
    test('alert con aviso ya activo', () {
      final copy = guideCopyFor(
        MapGuideStep.alert,
        hasActiveAlert: true,
        limitReached: false,
        isBlocked: false,
      );
      expect(copy.title, 'Aviso ya activado');
      expect(copy.primaryLabel, 'Continuar');
    });

    test('alert cuando ya sigue un bus', () {
      final copy = guideCopyFor(
        MapGuideStep.alert,
        hasActiveAlert: false,
        limitReached: true,
        isBlocked: false,
      );
      expect(copy.title, 'Ya sigues un bus');
      expect(copy.message,
          'Quita su aviso o espera a que suene para seguir otro.');
      expect(copy.primaryLabel, 'Continuar');
    });

    test('alert bloqueado por señal', () {
      final copy = guideCopyFor(
        MapGuideStep.alert,
        hasActiveAlert: false,
        limitReached: false,
        isBlocked: true,
      );
      expect(copy.title, 'Elige otro bus');
      expect(copy.primaryLabel, 'Elegir otro bus');
    });

    test('alert normal usa copia base', () {
      final copy = guideCopyFor(
        MapGuideStep.alert,
        hasActiveAlert: false,
        limitReached: false,
        isBlocked: false,
      );
      expect(copy.title, 'Activa el aviso');
    });

    test('otros pasos ignoran flags', () {
      final copy = guideCopyFor(
        MapGuideStep.buses,
        hasActiveAlert: true,
        limitReached: true,
        isBlocked: true,
      );
      expect(copy.title, 'Mira los buses');
    });
  });

  group('mapGuideCopy base', () {
    test('todos los pasos tienen titulo e icono', () {
      for (final step in MapGuideStep.values) {
        final copy = mapGuideCopy(step);
        expect(copy.title, isNotEmpty);
        expect(copy.message, isNotEmpty);
      }
    });
  });

  // En iPhone el aviso solo suena con la app abierta: no hay
  // `UIBackgroundModes` ni push. El último paso decía «Ya Viene seguirá
  // pendiente del bus» en todas partes, y quien le hacía caso en un iPhone
  // cambiaba de app y perdía el bus (auditoría 2026-09, H3).
  group('el paso de segundo plano según el teléfono', () {
    tearDown(() => debugDefaultTargetPlatformOverride = null);

    test('en iPhone pide dejar la app abierta', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final copy = mapGuideCopy(MapGuideStep.background);
      expect(copy.title, 'Deja Ya Viene abierta');
      expect(copy.message, contains('solo suena con Ya Viene abierta'));
      expect(copy.message, isNot(contains('seguirá pendiente')));
      expect(copy.message, isNot(contains('cambiar de aplicación')));
    });

    test('en Android no cambia', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final copy = mapGuideCopy(MapGuideStep.background);
      expect(copy.title, 'Sigue con lo tuyo');
      expect(
        copy.message,
        'Puedes cambiar de aplicación y hacer otra cosa: Ya Viene seguirá '
        'pendiente del bus. Lo único que lo corta es cerrar la app del todo.',
      );
    });
  });
}
