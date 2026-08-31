import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_pasajero/features/map/presentation/utils/camera_fit.dart';

/// El encuadre al elegir ruta.
///
/// El recorrido completo no sirve como caja: las seis rutas del catálogo
/// miden ~16 x 11 km y su centro cae unos 5 km al sur del centro de
/// Barranquilla, así que enmarcarlo sacaba la cámara de la ciudad.
void main() {
  group('liveViewportBounds', () {
    test('sin puntos no hay caja: la cámara no se mueve', () {
      expect(liveViewportBounds(const []), isNull);
    });

    test('un solo bus se abre hasta el lado mínimo, centrado en él', () {
      final caja = liveViewportBounds(const [(lat: 11.0041, lon: -74.8070)])!;

      expect(caja.maxLat - caja.minLat, closeTo(minFitSpanDeg, 1e-9));
      expect(caja.maxLon - caja.minLon, closeTo(minFitSpanDeg, 1e-9));
      expect((caja.minLat + caja.maxLat) / 2, closeTo(11.0041, 1e-9));
      expect((caja.minLon + caja.maxLon) / 2, closeTo(-74.8070, 1e-9));
    });

    test('dos buses separados caben los dos, sin achicar la caja', () {
      final caja = liveViewportBounds(const [
        (lat: 10.98, lon: -74.83),
        (lat: 11.03, lon: -74.78),
      ])!;

      expect(caja.minLat, closeTo(10.98, 1e-9));
      expect(caja.maxLat, closeTo(11.03, 1e-9));
      expect(caja.minLon, closeTo(-74.83, 1e-9));
      expect(caja.maxLon, closeTo(-74.78, 1e-9));
    });

    test('el punto de espera entra en la caja aunque el bus esté lejos', () {
      const espera = (lat: 11.0100, lon: -74.8100);
      final caja = liveViewportBounds(const [
        (lat: 10.9500, lon: -74.7800),
        espera,
      ])!;

      expect(caja.minLat, lessThanOrEqualTo(espera.lat));
      expect(caja.maxLat, greaterThanOrEqualTo(espera.lat));
      expect(caja.minLon, lessThanOrEqualTo(espera.lon));
      expect(caja.maxLon, greaterThanOrEqualTo(espera.lon));
    });

    test('dos buses casi pegados no llevan la cámara a zoom de calle', () {
      final caja = liveViewportBounds(const [
        (lat: 11.0041, lon: -74.8070),
        (lat: 11.0043, lon: -74.8072),
      ])!;

      expect(caja.maxLat - caja.minLat, closeTo(minFitSpanDeg, 1e-9));
      expect(caja.maxLon - caja.minLon, closeTo(minFitSpanDeg, 1e-9));
    });

    test('el lado largo manda: no se recorta al mínimo', () {
      final caja = liveViewportBounds(const [
        (lat: 10.95, lon: -74.8070),
        (lat: 11.05, lon: -74.8072),
      ])!;

      expect(caja.maxLat - caja.minLat, closeTo(0.10, 1e-9));
      expect(caja.maxLon - caja.minLon, closeTo(minFitSpanDeg, 1e-9));
    });
  });
}
