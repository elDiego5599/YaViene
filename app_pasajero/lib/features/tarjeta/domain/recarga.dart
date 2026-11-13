import 'tarjeta.dart';

/// Identifica una recarga ante el proveedor sin decir de qué tarjeta es.
/// Opaca a propósito: es lo único que viaja en la URL de la página de pago y
/// en el enlace de regreso, y ninguna de las dos puede llevar el número (D23).
final class ReferenciaRecarga {
  const ReferenciaRecarga._(this.valor);

  /// Letras, dígitos, guion y guion bajo (base64 seguro para URL): nada que
  /// un enlace hostil pueda usar para colar rutas, comillas o saltos.
  static final _forma = RegExp(r'^[A-Za-z0-9_-]{16,64}$');

  /// `null` si no tiene la forma. La única puerta de entrada de texto ajeno.
  static ReferenciaRecarga? leer(String? texto) =>
      texto != null && _forma.hasMatch(texto)
          ? ReferenciaRecarga._(texto)
          : null;

  final String valor;

  /// Lo único que se puede escribir en un registro.
  String get corta => '${valor.substring(0, 4)}…';

  @override
  bool operator ==(Object other) =>
      other is ReferenciaRecarga && other.valor == valor;

  @override
  int get hashCode => valor.hashCode;

  @override
  String toString() => 'ReferenciaRecarga($corta)';
}

/// Lo que dice el proveedor de una recarga. Nunca lo que dice el enlace de
/// regreso: ese estado no se lee (D23).
sealed class ConsultaRecarga {
  const ConsultaRecarga();
}

/// El proveedor confirmó el pago. [valor] en pesos, solo si él lo dice.
final class RecargaAprobada extends ConsultaRecarga {
  const RecargaAprobada({this.valor});

  final int? valor;

  @override
  bool operator ==(Object other) =>
      other is RecargaAprobada && other.valor == valor;

  @override
  int get hashCode => Object.hash('aprobada', valor);
}

final class RecargaRechazada extends ConsultaRecarga {
  const RecargaRechazada();

  @override
  bool operator ==(Object other) => other is RecargaRechazada;

  @override
  int get hashCode => 1;
}

/// El proveedor aún no resuelve (o no contesta): ni se acredita ni se niega.
final class RecargaPendiente extends ConsultaRecarga {
  const RecargaPendiente();

  @override
  bool operator ==(Object other) => other is RecargaPendiente;

  @override
  int get hashCode => 2;
}

/// El proveedor no conoce esa referencia.
final class RecargaDesconocida extends ConsultaRecarga {
  const RecargaDesconocida();

  @override
  bool operator ==(Object other) => other is RecargaDesconocida;

  @override
  int get hashCode => 3;
}

/// El teléfono no tiene red: se puede reintentar.
final class RecargaSinRed extends ConsultaRecarga {
  const RecargaSinRed();

  @override
  bool operator ==(Object other) => other is RecargaSinRed;

  @override
  int get hashCode => 4;
}

/// No se pudo abrir el canal del proveedor: página fuera de la lista, con el
/// número en la URL, o que el sistema no abrió.
final class RecargaNoAbierta extends ConsultaRecarga {
  const RecargaNoAbierta();

  @override
  bool operator ==(Object other) => other is RecargaNoAbierta;

  @override
  int get hashCode => 5;
}

/// Lo que responde el proveedor al pedirle una recarga nueva.
sealed class InicioRecarga {
  const InicioRecarga();
}

final class RecargaLista extends InicioRecarga {
  const RecargaLista({required this.referencia, required this.pagina});

  final ReferenciaRecarga referencia;

  /// Dónde paga el pasajero. El servicio la contrasta con [PaginasDePago].
  final Uri pagina;
}

final class InicioSinRed extends InicioRecarga {
  const InicioSinRed();
}

final class InicioNoDisponible extends InicioRecarga {
  const InicioNoDisponible();
}

/// Las únicas páginas que la app abre para pagar: esquema y host exactos, sin
/// credenciales en la URL. Una página que el proveedor devuelva fuera de aquí
/// se descarta, venga de donde venga.
final class PaginasDePago {
  const PaginasDePago({
    required this.hosts,
    this.esquemas = const {'https'},
    this.puertos = const {},
  });

  final Set<String> hosts;
  final Set<String> esquemas;

  /// Puertos que valen además del de fábrica del esquema. Solo la pasarela
  /// simulada, que corre en un puerto propio, los usa.
  final Set<int> puertos;

  bool permite(Uri url) =>
      esquemas.contains(url.scheme) &&
      url.userInfo.isEmpty &&
      hosts.contains(url.host.toLowerCase()) &&
      (!url.hasPort || puertos.contains(url.port));
}

/// Quien procesa el pago: el operador o el banco cuando haya convenio, y
/// mientras tanto `RecargaSimulada`. Ya Viene nunca cobra.
abstract interface class ProveedorRecarga {
  /// Mientras sea cierto, la pantalla lleva la etiqueta «Simulación» (D8).
  bool get simulado;

  PaginasDePago get paginas;

  /// Pide una recarga para [numero]. El número es asunto del proveedor: el
  /// proveedor lo asocia a la referencia de su lado y no lo pone en la URL.
  /// Nunca lanza.
  Future<InicioRecarga> iniciar(NumeroTarjeta numero);

  /// El estado de verdad, preguntado al proveedor. Nunca lanza.
  Future<ConsultaRecarga> consultar(ReferenciaRecarga referencia);
}

/// Saca la referencia del enlace de regreso `yaviene://recarga?referencia=…`.
/// Todo lo demás del enlace (incluido `estado`) se ignora: el enlace es
/// entrada hostil y solo sirve para decir «vuelvo de esta recarga».
ReferenciaRecarga? referenciaDeEnlace(String? enlace) {
  if (enlace == null || enlace.length > 512) return null;
  final Uri uri;
  try {
    uri = Uri.parse(enlace);
  } on FormatException {
    return null;
  }
  if (uri.scheme != 'yaviene' ||
      uri.host != 'recarga' ||
      uri.hasPort ||
      uri.userInfo.isNotEmpty ||
      (uri.path.isNotEmpty && uri.path != '/')) {
    return null;
  }
  final valores = uri.queryParametersAll['referencia'];
  if (valores == null || valores.length != 1) return null;
  return ReferenciaRecarga.leer(valores.single);
}
