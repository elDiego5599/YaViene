import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_core/ya_viene_core.dart';

// Marca «fecha de ahora» en el ayudante `json`: null ya significa «sin fecha».
const Object _ahora = Object();

void main() {
  // Lo que llega por la red, con fecha de ahora salvo que la prueba diga
  // otra: la fecha es parte de lo que se valida.
  Map<String, dynamic> json(
          {Object? timestamp = _ahora, bool isGhost = false}) =>
      {
        'busId': 'B-042',
        'routeId': 'R-101',
        'lat': 10.99,
        'lon': -74.80,
        'timestamp': identical(timestamp, _ahora)
            ? DateTime.now().toUtc().toIso8601String()
            : timestamp,
        'isGhost': isGhost,
      };

  String hace(Duration d) =>
      DateTime.now().subtract(d).toUtc().toIso8601String();

  test('tryParse lee una posición completa con sus campos', () {
    final cuando = DateTime.now().subtract(const Duration(seconds: 3));
    final position = BusPosition.tryParse({
      ...json(timestamp: cuando.toIso8601String()),
      'heading': 90,
      'speedKmh': 30,
      'sentido': 'venida',
      'sequence': 7,
      'capturedAt': 1754300000000,
    });

    expect(position, isNotNull);
    expect(position!.timestamp, cuando);
    expect(position.heading, 90);
    expect(position.speedKmh, 30);
    expect(position.sentido, 'venida');
    expect(position.sequence, 7);
    expect(position.capturedAt, 1754300000000);
    expect(position.toJson()['capturedAt'], 1754300000000);
    expect(position.copyWith(lat: 11).capturedAt, 1754300000000);
  });

  test('tryParse rechaza el JSON sin identidad o sin coordenada', () {
    for (final falta in ['busId', 'routeId', 'lat', 'lon']) {
      // Rellenar con ceros ponía el bus en (0, 0), en el golfo de Guinea.
      expect(BusPosition.tryParse(json()..remove(falta)), isNull,
          reason: 'sin $falta no hay posición');
    }
    expect(BusPosition.tryParse(json()..['lat'] = 91.0), isNull);
    expect(BusPosition.tryParse(json()..['busId'] = '  '), isNull);
    // Un tipo equivocado no tumba a quien escucha: devuelve null.
    expect(BusPosition.tryParse(json()..['lat'] = '10.99'), isNull);
    expect(BusPosition.tryParse(json()..['busId'] = 42), isNull);
  });

  // Antes una fecha que faltaba o no se entendía se volvía «ahora», y el bus
  // salía como recién reportado.
  test('tryParse sin fecha, o con una que no se entiende, no da posición', () {
    expect(BusPosition.tryParse(json(timestamp: null)), isNull);
    expect(BusPosition.tryParse(json(timestamp: 'ayer')), isNull);
    expect(BusPosition.tryParse(json(timestamp: 1757500000000)), isNull);
  });

  test('tryParse: una fecha del futuro, pasada la holgura del reloj, no pasa',
      () {
    final futuro = DateTime.now().add(const Duration(minutes: 30));
    expect(BusPosition.tryParse(json(timestamp: futuro.toIso8601String())),
        isNull);
    final pocoAdelantado = DateTime.now().add(const Duration(minutes: 2));
    expect(
      BusPosition.tryParse(json(timestamp: pocoAdelantado.toIso8601String())),
      isNotNull,
      reason: 'un reloj un par de minutos corrido no deja la app sin buses',
    );
  });

  test('tryParse: en vivo tiene tope de edad; sin señal no, porque se enseña',
      () {
    expect(
        BusPosition.tryParse(json(timestamp: hace(const Duration(hours: 2)))),
        isNull);
    expect(
        BusPosition.tryParse(json(timestamp: hace(const Duration(minutes: 6)))),
        isNotNull,
        reason: 'recién pasado el plazo del servidor, dentro de la holgura');
    final fantasma = BusPosition.tryParse(
      json(timestamp: hace(const Duration(hours: 2)), isGhost: true),
    );
    expect(fantasma, isNotNull);
    expect(fantasma!.isGhostBus, isTrue);
    expect(fantasma.toJson()['isGhost'], isTrue);
  });

  // El backend guarda NULL cuando el bus no manda rumbo. Rellenarlo con 0 lo
  // volvía el norte.
  test('tryParse sin rumbo lo deja vacío, y el 0 sigue siendo el norte', () {
    expect(BusPosition.tryParse(json())!.heading, isNull);
    expect(BusPosition.tryParse(json()..['heading'] = null)!.heading, isNull);
    expect(BusPosition.tryParse(json()..['heading'] = 0)!.heading, 0);
  });

  // Un rumbo o una velocidad que no son números de verdad giran el icono a
  // ninguna parte y rompen la distancia: la posición entera no vale.
  test('tryParse rechaza rumbo y velocidad no finitos', () {
    for (final raro in [double.nan, double.infinity, double.negativeInfinity]) {
      expect(BusPosition.tryParse(json()..['heading'] = raro), isNull,
          reason: 'heading $raro');
      expect(BusPosition.tryParse(json()..['speedKmh'] = raro), isNull,
          reason: 'speedKmh $raro');
    }
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
