import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../features/notifications/presentation/providers/distancia_aviso_provider.dart';

/// Lo que dice la actividad en vivo de un aviso armado: la pantalla
/// bloqueada y la Dynamic Island del iPhone (dueño, 2026-10-19). La misma
/// cifra que la hoja, la ruta y la barra de lo que falta.
///
/// La barra va de 3 km, la distancia más larga del aviso
/// ([distanciaAvisoMaxima]), a tu punto: el bus avanza igual en todas las
/// rutas, y de 3 km para allá espera al principio.
@immutable
class EstadoEnVivo {
  const EstadoEnVivo({
    required this.busId,
    required this.placa,
    required this.ruta,
    required this.distancia,
    required this.aviso,
    required this.avance,
    required this.avanceAviso,
  });

  final String busId;

  /// Placa del bus, derivada de su identificador cuando tiene prefijo BUS-.
  final String placa;

  /// El nombre de la ruta sin su código.
  final String? ruta;

  /// «1,5 km», como la hoja.
  final String distancia;

  /// «Te avisamos a 1,0 km», como bajo el botón del aviso.
  final String aviso;

  /// Lo que lleva el bus de la barra (0 a 3 km o más, 1 en tu punto).
  final double avance;

  /// Dónde va la marca del aviso en la misma barra.
  final double avanceAviso;

  /// Qué tanto de la barra lleva un bus a [metros] de tu punto: 0 a 3 km o
  /// más, 1 en tu punto.
  static double avanceDe(double metros) =>
      1 - (metros / distanciaAvisoMaxima).clamp(0.0, 1.0);

  Map<String, Object?> aMapa() => {
        'busId': busId,
        'placa': placa,
        'ruta': ruta,
        'distancia': distancia,
        'aviso': aviso,
        'avance': avance,
        'avanceAviso': avanceAviso,
      };
}

/// La actividad en vivo de los avisos (inyectable en tests).
abstract class ActividadEnVivo {
  /// Pone o pone al día la actividad del aviso de [EstadoEnVivo.busId].
  Future<void> mostrar(EstadoEnVivo estado);

  /// Quita la actividad de [busId]. Con [llego] se queda un rato diciendo
  /// que el bus está cerca; si no (aviso quitado), se va enseguida.
  Future<void> terminar(String busId, {required bool llego});
}

/// La de verdad: un canal con el `AppDelegate`, que la lleva a ActivityKit.
/// Solo en iOS (16.2 o más, lo decide el lado nativo). Falla blando: sin la
/// actividad, el aviso suena igual.
class ActividadEnVivoCanal implements ActividadEnVivo {
  const ActividadEnVivoCanal();

  static const _canal = MethodChannel('yaviene/actividad_en_vivo');

  bool get _activa => defaultTargetPlatform == TargetPlatform.iOS;

  @override
  Future<void> mostrar(EstadoEnVivo estado) =>
      _llamar('mostrar', estado.aMapa());

  @override
  Future<void> terminar(String busId, {required bool llego}) =>
      _llamar('terminar', {'busId': busId, 'llego': llego});

  Future<void> _llamar(String metodo, Map<String, Object?> datos) async {
    if (!_activa) return;
    try {
      await _canal.invokeMethod<void>(metodo, datos);
    } on MissingPluginException {
      // Sin el lado nativo (pruebas, o un iOS sin la extensión): nada.
    } catch (e) {
      debugPrint('actividad en vivo ($metodo) falló: $e');
    }
  }
}
