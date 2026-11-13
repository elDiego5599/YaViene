import '../domain/recarga.dart';
import '../domain/tarjeta.dart';
import 'recarga_en_curso.dart';

/// El recorrido de una recarga (D23): abre el canal del proveedor con una
/// referencia opaca, y al volver le pregunta a él cómo quedó. Ya Viene no
/// cobra, no ve tarjetas bancarias y no se fía del enlace de regreso.
class ServicioRecarga {
  ServicioRecarga({
    required this.proveedor,
    required RecargaEnCurso enCurso,
    required Future<bool> Function(Uri) abrir,
    required void Function(String) registrar,
  })  : _enCurso = enCurso,
        _abrir = abrir,
        _registrar = registrar;

  final ProveedorRecarga proveedor;
  final RecargaEnCurso _enCurso;
  final Future<bool> Function(Uri) _abrir;
  final void Function(String) _registrar;

  /// Un enlace repetido a la vez no se resuelve dos veces.
  bool _resolviendo = false;

  /// Pide la recarga y abre la página del proveedor en el navegador del
  /// sistema, nunca en una WebView dentro de la app (phishing y PCI).
  Future<ConsultaRecarga> iniciar(NumeroTarjeta numero) async {
    final inicio = await proveedor.iniciar(numero);
    switch (inicio) {
      case InicioSinRed():
        return const RecargaSinRed();
      case InicioNoDisponible():
        return const RecargaNoAbierta();
      case RecargaLista(:final referencia, :final pagina):
        if (!proveedor.paginas.permite(pagina) ||
            pagina.toString().contains(numero.digitos)) {
          _registrar(
              'recarga: página descartada (${pagina.scheme}://${pagina.host})');
          return const RecargaNoAbierta();
        }
        // La referencia se guarda antes de abrir: si el pago vuelve rápido,
        // ya está en curso.
        await _enCurso.guardar(referencia);
        if (!await _abrir(pagina)) {
          await _enCurso.olvidar();
          _registrar('recarga: el sistema no abrió ${referencia.corta}');
          return const RecargaNoAbierta();
        }
        _registrar('recarga: abierta ${referencia.corta}');
        return const RecargaPendiente();
    }
  }

  /// El pasajero vuelve por `yaviene://recarga?...`. Devuelve `null` cuando
  /// el enlace no es de la recarga en curso (basura, ajena, repetida, vieja):
  /// no pasa nada y no se pregunta nada.
  Future<ConsultaRecarga?> alVolver(String enlace) async {
    final referencia = referenciaDeEnlace(enlace);
    if (referencia == null) {
      _registrar('recarga: enlace de regreso descartado');
      return null;
    }
    if (referencia != _enCurso.leer()) {
      _registrar('recarga: referencia ajena ${referencia.corta}');
      return null;
    }
    return _resolver(referencia);
  }

  /// Repregunta por la recarga en curso, p. ej. al volver la app al frente
  /// o con «Comprobar»: así «Pendiente» y «Sin red» no quedan para siempre.
  Future<ConsultaRecarga?> reanudar() async {
    final referencia = _enCurso.leer();
    return referencia == null ? null : _resolver(referencia);
  }

  /// Hay una referencia esperando respuesta del proveedor.
  bool get hayEnCurso => _enCurso.leer() != null;

  /// Quitar la tarjeta (o cancelar) cierra la recarga en curso.
  Future<void> olvidar() => _enCurso.olvidar();

  Future<ConsultaRecarga?> _resolver(ReferenciaRecarga referencia) async {
    if (_resolviendo) return null;
    _resolviendo = true;
    try {
      final resultado = await proveedor.consultar(referencia);
      // Aprobada, rechazada o desconocida cierran la referencia: no vale dos
      // veces. Pendiente y sin red la dejan para reintentar.
      if (resultado is! RecargaPendiente && resultado is! RecargaSinRed) {
        await _enCurso.olvidar();
      }
      _registrar('recarga: ${referencia.corta} → ${resultado.runtimeType}');
      return resultado;
    } finally {
      _resolviendo = false;
    }
  }
}
