import 'dart:convert';

import 'tarjeta.dart';

/// De dónde salió un saldo: la etiqueta «Simulación» depende de esto (D8).
enum OrigenSaldo { simulacion, operador }

/// Lo que responde una consulta de saldo. Ninguna variante lleva el número.
sealed class ConsultaSaldo {
  const ConsultaSaldo();
}

final class SaldoConsultado extends ConsultaSaldo {
  const SaldoConsultado({
    required this.valor,
    required this.consultado,
    required this.origen,
  });

  /// En pesos enteros: el peso no usa centavos en la práctica.
  final int valor;

  /// Cuándo lo dijo el proveedor. El saldo no se refresca solo: la pantalla
  /// dice la hora para que nadie lo tome por el de este instante.
  final DateTime consultado;

  final OrigenSaldo origen;

  @override
  bool operator ==(Object other) =>
      other is SaldoConsultado &&
      other.valor == valor &&
      other.consultado == consultado &&
      other.origen == origen;

  @override
  int get hashCode => Object.hash(valor, consultado, origen);

  @override
  String toString() => 'SaldoConsultado($valor, $consultado, ${origen.name})';
}

/// El teléfono no tiene red: se puede reintentar.
final class SaldoSinRed extends ConsultaSaldo {
  const SaldoSinRed();

  @override
  bool operator ==(Object other) => other is SaldoSinRed;

  @override
  int get hashCode => 1;
}

/// El proveedor no conoce esa tarjeta: casi siempre un número mal copiado.
final class TarjetaNoEncontrada extends ConsultaSaldo {
  const TarjetaNoEncontrada();

  @override
  bool operator ==(Object other) => other is TarjetaNoEncontrada;

  @override
  int get hashCode => 2;
}

/// El proveedor no contesta o falló: no es culpa del pasajero.
final class SaldoNoDisponible extends ConsultaSaldo {
  const SaldoNoDisponible();

  @override
  bool operator ==(Object other) => other is SaldoNoDisponible;

  @override
  int get hashCode => 3;
}

/// Quien sabe el saldo de una tarjeta: el operador del recaudo cuando haya
/// convenio, y mientras tanto [SaldoSimulado].
abstract interface class ProveedorSaldo {
  /// Mientras sea cierto, la pantalla lleva la etiqueta «Simulación».
  bool get simulado;

  /// Nunca lanza: todo fallo es una [ConsultaSaldo].
  Future<ConsultaSaldo> consultar(NumeroTarjeta numero);
}

/// Saldos de ejemplo, sin red ni servidor: no hay API pública del SIBUS
/// (D22). El mismo número da siempre el mismo saldo para que la demo no
/// cambie entre dos consultas, y dos números de prueba enseñan los fallos.
final class SaldoSimulado implements ProveedorSaldo {
  SaldoSimulado({
    required Future<bool> Function() hayRed,
    DateTime Function()? reloj,
    this.espera = const Duration(milliseconds: 700),
  })  : _hayRed = hayRed,
        _reloj = reloj ?? DateTime.now;

  final Future<bool> Function() _hayRed;
  final DateTime Function() _reloj;

  /// Lo que tarda en contestar, para que el estado «consultando» exista
  /// también en la demo, como existirá con un proveedor de verdad.
  final Duration espera;

  /// Números de prueba evidentes, para ver los dos fallos en la demo.
  static const pruebaNoEncontrada = '00000000';
  static const pruebaNoDisponible = '99999999';

  @override
  bool get simulado => true;

  @override
  Future<ConsultaSaldo> consultar(NumeroTarjeta numero) async {
    // Sin red, la simulación dice lo mismo que diría el proveedor real.
    if (!await _hayRed()) return const SaldoSinRed();
    await Future<void>.delayed(espera);
    return switch (numero.digitos) {
      pruebaNoEncontrada => const TarjetaNoEncontrada(),
      pruebaNoDisponible => const SaldoNoDisponible(),
      final digitos => SaldoConsultado(
          valor: _saldoDe(digitos),
          consultado: _reloj(),
          origen: OrigenSaldo.simulacion,
        ),
    };
  }

  /// De 0 a 100.000 pesos, de 100 en 100, fijo por número. Un hash propio y
  /// no `String.hashCode`, que Dart no promete igual entre ejecuciones.
  static int _saldoDe(String digitos) {
    var h = 0;
    for (final b in utf8.encode(digitos)) {
      h = (h * 31 + b) % 1000003;
    }
    return (h % 1001) * 100;
  }
}
