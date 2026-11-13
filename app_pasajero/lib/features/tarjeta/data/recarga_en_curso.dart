import 'package:shared_preferences/shared_preferences.dart';

import '../domain/recarga.dart';

/// La recarga que el pasajero tiene abierta en el canal del proveedor. Solo
/// guarda la referencia opaca y la hora (nunca el número de la tarjeta), y
/// solo una: se sigue una recarga a la vez, como se sigue un bus a la vez.
/// Es lo que permite decir que un enlace de regreso es de esta app y no de
/// otro lado: sin referencia en curso, el enlace se ignora.
class RecargaEnCurso {
  RecargaEnCurso(this._prefs, {DateTime Function()? reloj})
      : _reloj = reloj ?? DateTime.now;

  final SharedPreferences _prefs;
  final DateTime Function() _reloj;

  static const llave = 'recarga_en_curso_referencia';
  static const llaveHora = 'recarga_en_curso_inicio';

  /// Pasado este rato el enlace de regreso ya no vale: una referencia vieja
  /// no se puede repetir semanas después.
  static const vigencia = Duration(minutes: 30);

  ReferenciaRecarga? leer() {
    final inicio = _prefs.getInt(llaveHora);
    final referencia = ReferenciaRecarga.leer(_prefs.getString(llave));
    if (inicio == null || referencia == null) {
      return null;
    }
    final edad =
        _reloj().difference(DateTime.fromMillisecondsSinceEpoch(inicio));
    return edad.isNegative || edad > vigencia ? null : referencia;
  }

  Future<void> guardar(ReferenciaRecarga referencia) async {
    await _prefs.setString(llave, referencia.valor);
    await _prefs.setInt(llaveHora, _reloj().millisecondsSinceEpoch);
  }

  Future<void> olvidar() async {
    await _prefs.remove(llave);
    await _prefs.remove(llaveHora);
  }
}
