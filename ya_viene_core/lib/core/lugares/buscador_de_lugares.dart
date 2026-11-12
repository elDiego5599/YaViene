import '../models/route_trajectory.dart';
import 'lugar.dart';

/// Convierte lo que escribe el pasajero en lugares (D25).
///
/// La app usa el índice local ([BuscadorLocal]); si un día el dueño elige
/// un proveedor en línea, entra por esta misma puerta. Un fallo de red se
/// lanza tal cual y el widget lo clasifica con `clasificarFallo`.
abstract interface class BuscadorDeLugares {
  /// Hasta [maximo] sugerencias para [consulta], las mejores primero y,
  /// entre las igual de buenas, las más cerca de [sesgo].
  ///
  /// Una consulta vacía devuelve una lista vacía.
  Future<List<Sugerencia>> buscar(
    String consulta, {
    int maximo = 8,
    GeoPoint? sesgo,
  });

  /// De dónde salen los datos, para decirlo bajo los resultados como pide
  /// su licencia.
  String get atribucion;
}
