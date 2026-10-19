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

  group('waitingPointBounds', () {
    test('la caja queda centrada en el punto de espera', () {
      final caja = waitingPointBounds(11.0041, -74.8070);

      expect((caja.minLat + caja.maxLat) / 2, closeTo(11.0041, 1e-9));
      expect((caja.minLon + caja.maxLon) / 2, closeTo(-74.8070, 1e-9));
    });

    test('mide el lado mínimo, no un punto', () {
      final caja = waitingPointBounds(11.0041, -74.8070);

      expect(caja.maxLat - caja.minLat, closeTo(minFitSpanDeg, 1e-9));
      expect(caja.maxLon - caja.minLon, closeTo(minFitSpanDeg, 1e-9));
    });

    test('un bus lejano ya no arrastra el encuadre', () {
      // El caso que motivó el cambio: con un bus al otro extremo de la ruta,
      // enmarcar "todo lo vivo" abría la caja a media ciudad.
      final viva = liveViewportBounds(const [
        (lat: 11.0041, lon: -74.8070),
        (lat: 10.90, lon: -74.90),
      ])!;
      final delPunto = waitingPointBounds(11.0041, -74.8070);

      expect(viva.maxLat - viva.minLat, greaterThan(0.10));
      expect(delPunto.maxLat - delPunto.minLat, closeTo(minFitSpanDeg, 1e-9));
    });
  });

  group('avisoBounds', () {
    const bus = (lat: 11.0, lon: -74.80);
    const espera = (lat: 11.03, lon: -74.77);

    test('enmarca el bus del aviso y el punto de espera juntos', () {
      final caja = avisoBounds(
        rutaDelAviso: 'r106',
        rutaEnMapa: 'r106',
        bus: bus,
        espera: espera,
      )!;
      expect(caja.minLat, 11.0);
      expect(caja.maxLat, 11.03);
      expect(caja.minLon, -74.80);
      expect(caja.maxLon, -74.77);
    });

    test('sin punto de espera, el bus solo al lado mínimo', () {
      final caja = avisoBounds(
        rutaDelAviso: 'r106',
        rutaEnMapa: 'r106',
        bus: bus,
      )!;
      expect(caja.maxLat - caja.minLat, closeTo(minFitSpanDeg, 1e-9));
      expect((caja.minLat + caja.maxLat) / 2, closeTo(11.0, 1e-9));
    });

    test('espera mientras el mapa siga en otra ruta o el bus no llegue', () {
      expect(
        avisoBounds(rutaDelAviso: 'r106', rutaEnMapa: 'c11', bus: bus),
        isNull,
      );
      expect(
        avisoBounds(rutaDelAviso: 'r106', rutaEnMapa: null, bus: bus),
        isNull,
      );
      expect(
        avisoBounds(
            rutaDelAviso: 'r106',
            rutaEnMapa: 'r106',
            bus: null,
            espera: espera),
        isNull,
      );
    });
  });

  // Al tocar un bus la cámara va hasta él con resorte, como en Mapas de
  // iOS (dueño, 2026-10-19).
  group('puntoDelViaje', () {
    const desde = (lat: 11.0, lon: -74.8);
    const hasta = (lat: 11.01, lon: -74.79);

    test('arranca donde estaba y acaba en el bus', () {
      final inicio = puntoDelViaje(desde, hasta, Duration.zero);
      expect(inicio.lat, desde.lat);
      expect(inicio.lon, desde.lon);
      final fin = puntoDelViaje(desde, hasta, kViajeCamara);
      expect(fin.lat, hasta.lat);
      expect(fin.lon, hasta.lon);
      final despues = puntoDelViaje(desde, hasta, kViajeCamara * 2);
      expect(despues.lat, hasta.lat);
    });

    test('con resorte: arranca quieta, nunca se pasa del bus', () {
      final ms = kViajeCamara.inMilliseconds;
      var antes = desde.lat;
      for (var t = 0; t <= ms; t += 16) {
        final p = puntoDelViaje(desde, hasta, Duration(milliseconds: t));
        expect(p.lat, greaterThanOrEqualTo(antes - 1e-12));
        expect(p.lat, lessThanOrEqualTo(hasta.lat + 1e-12));
        antes = p.lat;
      }
      // Un resorte va más rápido que la recta en la primera mitad.
      final mitad =
          puntoDelViaje(desde, hasta, Duration(milliseconds: ms ~/ 2));
      expect(
          (mitad.lat - desde.lat) / (hasta.lat - desde.lat), greaterThan(0.6));
    });
  });
}
