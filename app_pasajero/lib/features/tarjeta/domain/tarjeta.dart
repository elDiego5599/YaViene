/// El número de la tarjeta SIBUS del pasajero (D22 del backend).
///
/// Es un dato personal: con él se pueden atar viajes a una persona. Por eso
/// vive solo en el teléfono (Llavero o Keystore, `TarjetaGuardada`), nunca
/// va al backend y este tipo no lo suelta en `toString`, logs ni errores:
/// quien quiera los dígitos tiene que pedir [digitos] a propósito.
///
/// El formato real del número no es público (sibusoficial.ambq.gov.co no lo
/// da y no hay API conocida), así que no se inventa uno: solo dígitos, con
/// un largo acotado por [minimo] y [maximo]. Cuando el AMB o el operador lo
/// confirmen, se ajusta aquí y en sus pruebas.
final class NumeroTarjeta {
  const NumeroTarjeta._(this.digitos);

  /// Lo bastante corto para no aceptar un número cualquiera, lo bastante
  /// largo para un número de tarjeta sin contacto (los de 16 o 19 caben).
  static const minimo = 8;
  static const maximo = 20;

  /// Solo para guardarlo y para el proveedor del saldo.
  final String digitos;

  /// Lee lo que escribió el pasajero: quita los espacios con que se agrupa
  /// y acepta solo 0 a 9 (ni guiones ni dígitos de otros alfabetos).
  static LecturaNumero leer(String texto) {
    // Tope antes de recorrer: una entrada enorme no se procesa entera.
    if (texto.length > maximo * 4) {
      return const NumeroInvalido(FalloNumero.muyLargo);
    }
    final limpio = texto.replaceAll(' ', '');
    if (limpio.isEmpty) return const NumeroInvalido(FalloNumero.vacio);
    if (!_soloDigitos.hasMatch(limpio)) {
      return const NumeroInvalido(FalloNumero.soloDigitos);
    }
    if (limpio.length < minimo) {
      return const NumeroInvalido(FalloNumero.muyCorto);
    }
    if (limpio.length > maximo) {
      return const NumeroInvalido(FalloNumero.muyLargo);
    }
    return NumeroValido(NumeroTarjeta._(limpio));
  }

  static final _soloDigitos = RegExp(r'^[0-9]+$');

  String get ultimos4 => digitos.substring(digitos.length - 4);

  /// Lo único que sale en pantalla.
  String get enmascarado => '•••• $ultimos4';

  @override
  String toString() => 'NumeroTarjeta(oculto)';

  @override
  bool operator ==(Object other) =>
      other is NumeroTarjeta && other.digitos == digitos;

  @override
  int get hashCode => digitos.hashCode;
}

/// Por qué no sirve lo que se escribió.
enum FalloNumero { vacio, soloDigitos, muyCorto, muyLargo }

sealed class LecturaNumero {
  const LecturaNumero();
}

final class NumeroValido extends LecturaNumero {
  const NumeroValido(this.numero);
  final NumeroTarjeta numero;

  @override
  String toString() => 'NumeroValido(oculto)';
}

final class NumeroInvalido extends LecturaNumero {
  const NumeroInvalido(this.fallo);
  final FalloNumero fallo;

  @override
  bool operator ==(Object other) =>
      other is NumeroInvalido && other.fallo == fallo;

  @override
  int get hashCode => fallo.hashCode;

  @override
  String toString() => 'NumeroInvalido(${fallo.name})';
}
