import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/bus_parsing.dart';

Map<String, dynamic> _json({Object? timestamp, bool isGhost = false}) => {
      'busId': 'BUS-ABC123',
      'routeId': 'R-101',
      'lat': 10.98,
      'lon': -74.78,
      'timestamp': timestamp,
      'isGhost': isGhost,
    };

String _hace(Duration d) =>
    DateTime.now().subtract(d).toUtc().toIso8601String();

void main() {
  test('una posición reciente pasa con su propia fecha', () {
    final cuando = DateTime.now().subtract(const Duration(seconds: 3));
    final pos = safeBusPosition(_json(timestamp: cuando.toIso8601String()));
    expect(pos, isNotNull);
    expect(pos!.timestamp, cuando);
  });

  // Antes una fecha que faltaba o no se entendía se volvía «ahora», y el bus
  // salía como recién reportado.
  test('sin fecha, o con una que no se entiende, no hay posición', () {
    expect(safeBusPosition(_json()), isNull);
    expect(safeBusPosition(_json(timestamp: 'ayer')), isNull);
    expect(safeBusPosition(_json(timestamp: 1757500000000)), isNull);
  });

  test('una fecha del futuro, pasada la holgura del reloj, no pasa', () {
    final futuro = DateTime.now().add(const Duration(minutes: 30));
    expect(safeBusPosition(_json(timestamp: futuro.toIso8601String())), isNull);
    final pocoAdelantado = DateTime.now().add(const Duration(minutes: 2));
    expect(
      safeBusPosition(_json(timestamp: pocoAdelantado.toIso8601String())),
      isNotNull,
      reason: 'un reloj un par de minutos corrido no deja la app sin buses',
    );
  });

  test('en vivo tiene tope de edad; sin señal no, porque su edad se enseña',
      () {
    expect(safeBusPosition(_json(timestamp: _hace(const Duration(hours: 2)))),
        isNull);
    expect(safeBusPosition(_json(timestamp: _hace(const Duration(minutes: 6)))),
        isNotNull,
        reason: 'recién pasado el plazo del servidor, dentro de la holgura');
    final fantasma = safeBusPosition(
      _json(timestamp: _hace(const Duration(hours: 2)), isGhost: true),
    );
    expect(fantasma, isNotNull);
    expect(fantasma!.isGhostBus, isTrue);
  });
}
