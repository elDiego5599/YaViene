import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:ya_viene_core/ya_viene_core.dart';

import '../../../core/app_info.dart';

/// Qué es lo que manda el pasajero.
enum TipoReporte { problema, sugerencia }

/// Lo que pasó con un reporte.
enum EnvioReporte {
  /// El servidor lo guardó: sale por correo aunque Gmail esté caído.
  recibido,

  /// Cinco en diez minutos desde este teléfono (429).
  muchos,

  /// El servidor no lo pudo guardar (cola llena, 503) o no conoce el buzón.
  noDisponible,

  /// Sin red o sin respuesta: se puede reintentar tal cual.
  sinRed,
}

/// El buzón de problemas y sugerencias (D14 del backend).
///
/// La app no manda el correo: le pasa el reporte al backend, que lo guarda
/// y lo envía al Gmail del equipo. Así la dirección del equipo no va dentro
/// de la APK y el pasajero no necesita una cuenta de correo en el teléfono.
/// Sin campo de contacto (Ley 1581): solo el tipo, el texto, la plataforma
/// y la versión de la app.
class Buzon {
  Buzon({required String Function() backend, http.Client? cliente})
      : _backend = backend,
        _cliente = cliente ?? http.Client();

  final String Function() _backend;
  final http.Client _cliente;

  /// Los topes del backend (`src/data/reportes.ts`): el contador del
  /// formulario no deja pasar de [maximo] y el botón no se enciende antes de
  /// [minimo].
  static const minimo = 3;
  static const maximo = 1000;

  static const _espera = Duration(seconds: 15);

  Future<EnvioReporte> enviar(TipoReporte tipo, String texto) async {
    try {
      final r = await _cliente
          .post(
            Uri.parse('${_backend()}/api/reportes'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'tipo': tipo.name,
              'texto': texto.trim(),
              if (_plataforma case final plataforma?) 'plataforma': plataforma,
              'version': kAppVersion,
            }),
          )
          .timeout(_espera);
      return switch (r.statusCode) {
        201 => EnvioReporte.recibido,
        429 => EnvioReporte.muchos,
        _ => EnvioReporte.noDisponible,
      };
    } catch (e) {
      debugPrint('buzón: no se pudo enviar: ${clasificarFallo(e).name}');
      return EnvioReporte.sinRed;
    }
  }

  static String? get _plataforma => kIsWeb
      ? null
      : switch (defaultTargetPlatform) {
          TargetPlatform.android => 'android',
          TargetPlatform.iOS => 'ios',
          _ => null,
        };
}

final buzonProvider = Provider<Buzon>(
  (ref) => Buzon(backend: () => ref.read(backendUrlProvider)),
);
