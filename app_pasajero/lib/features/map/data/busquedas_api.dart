import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:ya_viene_core/core/geo/celda_busqueda.dart';

typedef RegistrarBusquedaRuta = Future<void> Function({
  required String routeId,
  required double? lat,
  required double? lng,
});

/// Se inyecta desde el arranque para que contextos sin backend configurado
/// (como las pruebas de widgets) no intenten acceder a la red.
final registrarBusquedaRutaProvider = Provider<RegistrarBusquedaRuta>(
  (ref) => ({required routeId, required lat, required lng}) async {},
);

/// Implementación de producción: resuelve la URL al invocarse, no al elegir
/// la ruta; el envío es accesorio y el API descarta fallos de red.
RegistrarBusquedaRuta crearRegistradorBusqueda(
  String Function() backendUrl, {
  http.Client? client,
}) =>
    ({required routeId, required lat, required lng}) async {
      await registrarBusqueda(
        backendUrl: backendUrl(),
        routeId: routeId,
        lat: lat,
        lng: lng,
        client: client,
      );
    };

/// Registro de mejor esfuerzo al elegir la ruta. No reintenta ni propaga
/// errores: registrar una búsqueda nunca forma parte de abrir el mapa.
Future<void> registrarBusqueda({
  required String backendUrl,
  required String routeId,
  required double? lat,
  required double? lng,
  http.Client? client,
}) async {
  try {
    final celda =
        lat == null || lng == null ? null : centroCeldaBusqueda(lat, lng);
    final uri = Uri.parse('$backendUrl/api/busquedas');
    const headers = {'Content-Type': 'application/json'};
    final body = jsonEncode({
      'routeId': routeId,
      if (celda != null) 'celda': {'lat': celda.lat, 'lng': celda.lng},
    });
    final request = client == null
        ? http.post(uri, headers: headers, body: body)
        : client.post(uri, headers: headers, body: body);
    await request.timeout(const Duration(seconds: 2));
  } catch (_) {
    // Evento efímero, sin cola ni reintentos por decisión del producto.
  }
}
