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
    required this.routeId,
    required this.companyId,
    required this.placa,
    required this.ruta,
    required this.distancia,
    required this.aviso,
    required this.avance,
    required this.avanceAviso,
    this.llego = false,
  });

  final String busId;

  /// Ruta que se abre al tocar la actividad en vivo.
  final String routeId;

  /// Empresa que identifica sin ambigüedad la ruta al abrir el aviso.
  final String? companyId;

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

  /// El bus ya entró al radio del aviso: la actividad dice que está cerca.
  /// No espera a la notificación, que es local y puede tardar con la app
  /// suspendida (dueño, 2026-10-29).
  final bool llego;

  /// Qué tanto de la barra lleva un bus a [metros] de tu punto: 0 a 3 km o
  /// más, 1 en tu punto.
  static double avanceDe(double metros) =>
      1 - (metros / distanciaAvisoMaxima).clamp(0.0, 1.0);

  Map<String, Object?> aMapa() => {
        'busId': busId,
        'routeId': routeId,
        'companyId': companyId,
        'placa': placa,
        'ruta': ruta,
        'distancia': distancia,
        'aviso': aviso,
        'avance': avance,
        'avanceAviso': avanceAviso,
        'llego': llego,
      };
}

/// La actividad en vivo de los avisos (inyectable en tests).
abstract class ActividadEnVivo {
  /// Pone o pone al día la actividad del aviso de [EstadoEnVivo.busId].
  /// `true` si quedó viva. iOS no deja pedirla con la app atrás (pantalla
  /// bloqueada), y en Android o iOS viejo no hay: entonces `false`.
  Future<bool> mostrar(EstadoEnVivo estado);

  /// Quita la actividad de [busId]. Con [llego] se queda un rato diciendo
  /// que el bus está cerca; si no (aviso quitado), se va enseguida.
  Future<void> terminar(String busId, {required bool llego});

  /// El bus llegó: la actividad de [busId] da el aviso con su sonido y se
  /// queda un rato diciendo que está cerca. `false` si no hay ninguna viva
  /// (iOS viejo, apagadas en Ajustes, Android): entonces suena el banner.
  Future<bool> sonar(String busId);
}

/// La de verdad: un canal con el `AppDelegate`, que la lleva a ActivityKit.
/// Solo en iOS (16.2 o más, lo decide el lado nativo). Falla blando: sin la
/// actividad, el aviso suena igual.
class ActividadEnVivoCanal implements ActividadEnVivo {
  const ActividadEnVivoCanal();

  static const _canal = MethodChannel('yaviene/actividad_en_vivo');

  bool get _activa => defaultTargetPlatform == TargetPlatform.iOS;

  @override
  Future<bool> mostrar(EstadoEnVivo estado) async =>
      await _llamar<bool>('mostrar', estado.aMapa()) ?? false;

  @override
  Future<void> terminar(String busId, {required bool llego}) =>
      _llamar<void>('terminar', {'busId': busId, 'llego': llego});

  @override
  Future<bool> sonar(String busId) async =>
      await _llamar<bool>('sonar', {'busId': busId}) ?? false;

  Future<T?> _llamar<T>(String metodo, Map<String, Object?> datos) async {
    if (!_activa) return null;
    try {
      return await _canal.invokeMethod<T>(metodo, datos);
    } on MissingPluginException {
      // Sin el lado nativo (pruebas, o un iOS sin la extensión): nada.
    } catch (e) {
      debugPrint('actividad en vivo ($metodo) falló: $e');
    }
    return null;
  }
}
