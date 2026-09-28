import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_pasajero/features/map/presentation/widgets/search_pill_bar.dart';

/// El degradado del destello de «Ruta activa» (search_pill_bar.dart).
void main() {
  test('la franja entra y sale por fuera, y en todo punto se lee (F4)', () {
    double contraste(Color c) => 1.05 / (c.computeLuminance() + 0.05);
    for (var i = 0; i <= 20; i++) {
      final g = EtiquetaRutaActiva.pasada(i / 20);
      for (final c in g.colors) {
        expect(contraste(c), greaterThanOrEqualTo(4.5), reason: '$c');
      }
      expect(g.stops!.every((s) => s >= 0 && s <= 1), isTrue);
    }
    // En los extremos no hay luz dentro del texto: todo es tinta.
    final inicio = EtiquetaRutaActiva.pasada(0).stops!;
    final fin = EtiquetaRutaActiva.pasada(1).stops!;
    expect(inicio.last, 0);
    expect(fin.first, 1);
    // A mitad, la franja está dentro.
    final medio = EtiquetaRutaActiva.pasada(0.5).stops!;
    expect(medio[1], closeTo(0.5, 0.01));
  });

  test('la luz se nota: la franja brilla al menos el triple que la tinta', () {
    // El dueño (2026-09-27) no la veía: con tinta #065F46 y pico #038750 la
    // franja brillaba 2,1 veces la tinta y en 12 px se leía quieta. El pico
    // no puede subir más sin bajar de 4,5:1, así que la que baja es la
    // tinta.
    final tinta = EtiquetaRutaActiva.tinta.computeLuminance();
    final pico = EtiquetaRutaActiva.destello.computeLuminance();
    expect(pico / tinta, greaterThanOrEqualTo(3));
  });

  test('vuelve pronto: una pasada con su descanso cabe en 3 s', () {
    // Con 6 s entre luces el ojo la daba por quieta.
    expect(
      EtiquetaRutaActiva.pasadaDura + EtiquetaRutaActiva.pausa,
      lessThanOrEqualTo(const Duration(seconds: 3)),
    );
  });
}
