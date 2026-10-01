import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_pasajero/features/map/presentation/utils/map_constants.dart';

/// Grados de latitud a kilómetros (constante: los meridianos no se estrechan).
const double _kmPorGradoLat = 110.574;

/// Grados de longitud a kilómetros a la altura de Barranquilla, donde un
/// grado mide menos que en el ecuador por el coseno de la latitud.
double _kmPorGradoLon(double lat) => 111.320 * math.cos(lat * math.pi / 180.0);

void main() {
  const altoKm =
      (MapConstants.areaNorteLat - MapConstants.areaSurLat) * _kmPorGradoLat;
  const centroLat = (MapConstants.areaNorteLat + MapConstants.areaSurLat) / 2;
  final anchoKm = (MapConstants.areaEsteLon - MapConstants.areaOesteLon) *
      _kmPorGradoLon(centroLat);

  test('el área del mapa es un cuadrado de verdad', () {
    // «Cuadrado» en grados sería un rectángulo en el suelo: aquí un grado de
    // longitud mide 109,3 km y uno de latitud 110,6. Si el cuadrado no lo es
    // en kilómetros, el dedo topa con el borde antes por un lado que por el
    // otro y el mapa se siente torcido sin que se vea por qué.
    expect((anchoKm - altoKm).abs() / altoKm, lessThan(0.02),
        reason: 'el área mide $anchoKm × $altoKm km');
  });

  test('el área cubre Malambo, Soledad, Eduardo Santos y el norte', () {
    // Los cuatro extremos que pidió el área servida. Si mañana alguien
    // aprieta el cuadrado para ahorrar teselas, esto dice qué se quedó fuera.
    const sitios = <String, (double, double)>{
      'Malambo': (10.859, -74.774),
      'Soledad': (10.918, -74.765),
      'Eduardo Santos (La Playa)': (10.928, -74.829),
      'La Playa, norte de Barranquilla': (11.020, -74.800),
      'ciénaga de Mallorquín': (11.040, -74.850),
      'Bocas de Ceniza': (11.108, -74.851),
    };
    sitios.forEach((nombre, punto) {
      expect(punto.$1,
          inInclusiveRange(MapConstants.areaSurLat, MapConstants.areaNorteLat),
          reason: '$nombre se queda fuera del mapa');
      expect(punto.$2,
          inInclusiveRange(MapConstants.areaOesteLon, MapConstants.areaEsteLon),
          reason: '$nombre se queda fuera del mapa');
    });
  });

  test('a zoom mínimo la pantalla cabe dentro del área', () {
    // Android sujeta el centro de la cámara e iOS sujeta lo que se ve. Solo
    // coinciden si en el plano más lejano la pantalla entera cabe en el
    // cuadrado; si no, iOS bloquea el zoom antes que Android y el mismo gesto
    // hace cosas distintas en cada teléfono.
    //
    // Se mide contra un teléfono alto (956 pt, el Pro Max), que es el caso
    // que más pide. Web Mercator: el mundo mide 512·2^zoom px de lado y un
    // píxel abarca menos latitud cuanto más al norte.
    const altoPantallaPt = 956.0;
    final mundoPx = 512 * math.pow(2, MapConstants.zoomMinimo);
    final latVisible =
        altoPantallaPt * 360 / mundoPx / math.cos(centroLat * math.pi / 180.0);

    expect(latVisible,
        lessThanOrEqualTo(MapConstants.areaNorteLat - MapConstants.areaSurLat),
        reason: 'la pantalla ve ${latVisible.toStringAsFixed(3)}° de latitud '
            'y el área solo tiene '
            '${(MapConstants.areaNorteLat - MapConstants.areaSurLat)}°');
  });

  test('a zoom mínimo queda sitio para arrastrar el mapa', () {
    // Que la pantalla quepa no basta: si cabe justa, la cámara se mueve dos
    // kilómetros y se para, y el mapa se siente clavado —fue exactamente el
    // problema del cuadrado de 28 km, donde el norte de la ciudad quedaba
    // detrás de una pared invisible. Se pide margen de verdad: al menos diez
    // kilómetros de recorrido del centro en el plano más lejano, en el
    // teléfono alto, que es el que menos margen deja.
    const altoPantallaPt = 956.0;
    final mundoPx = 512 * math.pow(2, MapConstants.zoomMinimo);
    final latVisible =
        altoPantallaPt * 360 / mundoPx / math.cos(centroLat * math.pi / 180.0);
    final margenKm =
        (MapConstants.areaNorteLat - MapConstants.areaSurLat - latVisible) *
            _kmPorGradoLat;

    expect(margenKm, greaterThanOrEqualTo(10.0),
        reason: 'solo se puede arrastrar ${margenKm.toStringAsFixed(1)} km '
            'de norte a sur');
  });

  test('a zoom mínimo se ven las seis rutas de lado a lado', () {
    // El otro lado del mismo compromiso: si el zoom mínimo se sube para que
    // quepa un cuadrado más pequeño, la pantalla —que es estrecha— deja de
    // abarcar el ancho de las rutas y ya no se pueden ver enteras.
    const anchoPantallaPt = 402.0;
    const anchoRutasGrados = 74.873370 - 74.773128;
    final mundoPx = 512 * math.pow(2, MapConstants.zoomMinimo);
    final lonVisible = anchoPantallaPt * 360 / mundoPx;

    expect(lonVisible, greaterThanOrEqualTo(anchoRutasGrados),
        reason: 'la pantalla ve ${lonVisible.toStringAsFixed(3)}° de longitud '
            'y las rutas ocupan $anchoRutasGrados°');
  });
}
