import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/tarjeta.dart';

/// Dónde vive el número de la tarjeta: el Llavero de iOS o el Keystore de
/// Android, nunca SharedPreferences (ver `PrefsKeys`) ni el backend (D22).
class TarjetaGuardada {
  TarjetaGuardada({required FlutterSecureStorage almacen, required this.prefs})
      : _almacen = almacen;

  final FlutterSecureStorage _almacen;
  final SharedPreferences prefs;

  static const llave = 'tarjeta_sibus';

  /// iOS conserva el Llavero al desinstalar la app y SharedPreferences no:
  /// si falta esta marca, la app es nueva en el teléfono y lo que quede en el
  /// Llavero es de una instalación anterior, que el pasajero ya dejó.
  static const marcaInstalacion = 'tarjeta_instalacion_vista';

  /// Solo en este teléfono y tras el primer desbloqueo: ni copia de iCloud
  /// ni Llavero sincronizado entre aparatos.
  static const opcionesDelSistema = FlutterSecureStorage(
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
      synchronizable: false,
    ),
  );

  Future<NumeroTarjeta?> leer() async {
    await _olvidarInstalacionAnterior();
    final String? guardado;
    try {
      guardado = await _almacen.read(key: llave);
    } on PlatformException {
      // Un Llavero que no se deja leer (p. ej. antes del primer desbloqueo)
      // no borra nada: la pantalla pide el número y guardarlo lo reemplaza.
      return null;
    }
    if (guardado == null) return null;
    switch (NumeroTarjeta.leer(guardado)) {
      case NumeroValido(:final numero):
        return numero;
      case NumeroInvalido():
        // Algo que no es un número válido no se enseña ni se manda: se borra.
        await quitar();
        return null;
    }
  }

  Future<void> guardar(NumeroTarjeta numero) async {
    await _olvidarInstalacionAnterior();
    await _almacen.write(key: llave, value: numero.digitos);
  }

  Future<void> quitar() => _almacen.delete(key: llave);

  Future<void> _olvidarInstalacionAnterior() async {
    if (prefs.getBool(marcaInstalacion) ?? false) return;
    await quitar();
    await prefs.setBool(marcaInstalacion, true);
  }
}
