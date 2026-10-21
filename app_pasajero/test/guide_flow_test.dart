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

  // Con el aviso activo, iOS mantiene la ubicación y muestra la actividad en
  // vivo en la pantalla bloqueada. Cerrar la app del todo corta la
  // actualización.
  group('el paso de segundo plano según el teléfono', () {
    tearDown(() => debugDefaultTargetPlatformOverride = null);

    test('en iPhone explica la distancia en pantalla bloqueada', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final copy = mapGuideCopy(MapGuideStep.background);
      expect(copy.title, 'Puedes bloquear el teléfono');
      expect(
        copy.message,
        contains('distancia en la pantalla bloqueada'),
      );
      expect(copy.message, contains('cierras la app del todo'));
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
