import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../domain/recarga.dart';
import '../domain/tarjeta.dart';

/// Proveedor de recarga de mentira (D23, D8): habla con una pasarela
/// simulada (`tool/pasarela_simulada.py` en el desarrollo, un servidor local
/// en las pruebas) que hace de página de pago del operador. Hace lo que haría
/// el real: pide una referencia, manda al pasajero a la página y, al volver,
/// pregunta el estado. Al operador no le manda el número de la tarjeta: en la
/// simulación no hace falta, y así tampoco puede filtrarlo.
final class RecargaSimulada implements ProveedorRecarga {
  RecargaSimulada({
    required this.base,
    required Future<bool> Function() hayRed,
    http.Client? cliente,
    this.espera = const Duration(milliseconds: 600),
    this.limite = const Duration(seconds: 6),
    Random? azar,
  })  : _hayRed = hayRed,
        _cliente = cliente ?? http.Client(),
        _azar = azar ?? Random.secure(),
        paginas = PaginasDePago(
          hosts: {base.host.toLowerCase()},
          esquemas: {base.scheme},
          puertos: {base.port},
        );

  /// Dónde corre la pasarela, p. ej. `http://localhost:8099`.
  final Uri base;
  final Future<bool> Function() _hayRed;
  final http.Client _cliente;
  final Random _azar;

  /// Lo que tarda en contestar, para que el estado «consultando» exista
  /// también en la demo.
  final Duration espera;
  final Duration limite;

  /// Una respuesta más grande que esto no es de la pasarela.
  static const _tope = 16 * 1024;

  /// Una recarga simulada no pasa de un millón de pesos.
  static const _valorMaximo = 1000000;

  @override
  final PaginasDePago paginas;

  @override
  bool get simulado => true;

  @override
  Future<InicioRecarga> iniciar(NumeroTarjeta numero) async {
    if (!await _hayRed()) return const InicioSinRed();
    await Future<void>.delayed(espera);
    final referencia = ReferenciaRecarga.leer(_nuevaReferencia())!;
    try {
      final r = await _cliente
          .post(
            base.resolve('/recargas'),
            headers: {'content-type': 'application/json'},
            body: jsonEncode({'referencia': referencia.valor}),
          )
          .timeout(limite);
      if (r.statusCode != 201) return const InicioNoDisponible();
    } on Object {
      return const InicioNoDisponible();
    }
    return RecargaLista(
      referencia: referencia,
      pagina: base.resolve('/pagar/${referencia.valor}'),
    );
  }

  @override
  Future<ConsultaRecarga> consultar(ReferenciaRecarga referencia) async {
    if (!await _hayRed()) return const RecargaSinRed();
    await Future<void>.delayed(espera);
    try {
      final r = await _cliente
          .get(base.resolve('/recargas/${referencia.valor}'))
          .timeout(limite);
      if (r.statusCode == 404) return const RecargaDesconocida();
      if (r.statusCode != 200 || r.bodyBytes.length > _tope) {
        return const RecargaPendiente();
      }
      return _leer(utf8.decode(r.bodyBytes, allowMalformed: true));
    } on Object {
      // Mientras el proveedor no contesta, ni se acredita ni se niega.
      return const RecargaPendiente();
    }
  }

  /// Solo dos palabras valen; cualquier otra cosa es «sigue pendiente».
  static ConsultaRecarga _leer(String cuerpo) {
    final Object? json;
    try {
      json = jsonDecode(cuerpo);
    } on FormatException {
      return const RecargaPendiente();
    }
    if (json is! Map) return const RecargaPendiente();
    return switch (json['estado']) {
      'aprobada' => RecargaAprobada(valor: _valor(json['valor'])),
      'rechazada' => const RecargaRechazada(),
      _ => const RecargaPendiente(),
    };
  }

  static int? _valor(Object? v) =>
      v is int && v > 0 && v <= _valorMaximo ? v : null;

  String _nuevaReferencia() => base64UrlEncode(
        List<int>.generate(24, (_) => _azar.nextInt(256)),
      );
}
