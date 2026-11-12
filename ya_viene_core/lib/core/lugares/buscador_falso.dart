import '../models/route_trajectory.dart';
import 'buscador_de_lugares.dart';
import 'lugar.dart';

/// Un buscador de mentira para pruebas y arneses: responde lo que se le
/// dio por consulta exacta, tarda lo que se le pida y puede fallar, para
/// ver cada estado del buscador sin el índice de verdad.
class BuscadorFalso implements BuscadorDeLugares {
  BuscadorFalso({
    this.respuestas = const {},
    this.error,
    this.demora = Duration.zero,
    this.atribucion = '© Datos de prueba',
  });

  /// Lo que responde cada consulta, tal como se escribe.
  final Map<String, List<Sugerencia>> respuestas;

  /// Si no es null, toda búsqueda lo lanza.
  final Object? error;
  final Duration demora;

  @override
  final String atribucion;

  /// Cada búsqueda pedida, en orden.
  final consultas = <({String consulta, GeoPoint? sesgo})>[];

  @override
  Future<List<Sugerencia>> buscar(
    String consulta, {
    int maximo = 8,
    GeoPoint? sesgo,
  }) async {
    consultas.add((consulta: consulta, sesgo: sesgo));
    if (demora > Duration.zero) await Future<void>.delayed(demora);
    if (error case final e?) throw e;
    return (respuestas[consulta] ?? const []).take(maximo).toList();
  }
}
