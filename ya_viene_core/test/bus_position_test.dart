import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_core/ya_viene_core.dart';

void main() {
  test('BusPosition accepts canonical ghost and epoch timestamp fields', () {
    final timestamp = DateTime(2026, 8, 4, 12).millisecondsSinceEpoch;
    final position = BusPosition.fromJson({
      'busId': 'B-042',
      'routeId': 'R-101',
      'lat': 10.99,
      'lon': -74.80,
      'heading': 90,
      'speedKmh': 30,
      'timestamp': timestamp,
      'isGhost': true,
      'sequence': 7,
    });

    expect(position.isGhostBus, isTrue);
    expect(position.timestamp.millisecondsSinceEpoch, timestamp);
    expect(position.sequence, 7);
    expect(position.toJson()['isGhost'], isTrue);
  });

  test('BusPosition rechaza el JSON sin identidad o sin coordenada', () {
    const base = {
      'busId': 'B-042',
      'routeId': 'R-101',
      'lat': 10.99,
      'lon': -74.80,
    };
    for (final falta in ['busId', 'routeId', 'lat', 'lon']) {
      final json = Map<String, dynamic>.from(base)..remove(falta);
      // Rellenar con ceros ponía el bus en (0, 0), en el golfo de Guinea.
      expect(() => BusPosition.fromJson(json), throwsFormatException,
          reason: 'sin $falta debería lanzar');
    }
    expect(
      () => BusPosition.fromJson(Map.of(base)..['lat'] = 91.0),
      throwsFormatException,
    );
    expect(
      () => BusPosition.fromJson(Map.of(base)..['busId'] = '  '),
      throwsFormatException,
    );
  });

  // El backend guarda NULL cuando el bus no manda rumbo. Rellenarlo con 0 lo
  // volvía el norte.
  test('BusPosition sin rumbo lo deja vacío, y el 0 sigue siendo el norte', () {
    const base = {
      'busId': 'B-042',
      'routeId': 'R-101',
      'lat': 10.99,
      'lon': -74.80,
    };
    Map<String, dynamic> con(Object? heading) => {...base, 'heading': heading};
    expect(BusPosition.fromJson(base).heading, isNull);
    expect(BusPosition.fromJson(con(null)).heading, isNull);
    expect(BusPosition.fromJson(con(0)).heading, 0);
  });

  test('BusPosition lee la captura del equipo y la conserva', () {
    final position = BusPosition.fromJson(const {
      'busId': 'B-042',
      'routeId': 'R-101',
      'lat': 10.99,
      'lon': -74.80,
      'capturedAt': 1754300000000,
    });
    expect(position.capturedAt, 1754300000000);
    expect(position.toJson()['capturedAt'], 1754300000000);
    expect(position.copyWith(lat: 11).capturedAt, 1754300000000);
  });

  // Los mensajes no llegan en orden: el socket reconecta, el REST vuelve
  // tarde, el respaldo va atrás. La captura del equipo es lo que los ordena.
  group('esMasNueva', () {
    bool masNueva(int? nueva, int? previa,
            {bool fantasmaNuevo = false, bool fantasmaPrevio = false}) =>
        esMasNueva(
          capturaNueva: nueva,
          capturaPrevia: previa,
          fantasmaNuevo: fantasmaNuevo,
          fantasmaPrevio: fantasmaPrevio,
        );

    test('una captura posterior reemplaza y una anterior no', () {
      expect(masNueva(2000, 1000), isTrue);
      expect(masNueva(1000, 2000), isFalse);
    });

    test('con la misma captura solo pasa si cambia el fantasma', () {
      expect(masNueva(1000, 1000), isFalse);
      expect(masNueva(1000, 1000, fantasmaNuevo: true), isTrue);
      expect(masNueva(1000, 1000, fantasmaPrevio: true), isTrue);
    });

    test('sin captura en alguna de las dos se acepta la nueva', () {
      expect(masNueva(null, 1000), isTrue);
      expect(masNueva(1000, null), isTrue);
      expect(masNueva(null, null), isTrue);
    });
  });
}
