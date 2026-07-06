import 'package:equatable/equatable.dart';

/// Información de una ruta de transporte.
/// Corresponde a la entidad [Ruta] del modelo de datos en Plan.md, Sección 3.
///
/// Nota: el [sentido] (ida/vuelta) se maneja a nivel de UI con el
/// [selectedSentidoProvider], no en este modelo, para mantener la flexibilidad
/// de cambiar el sentido sin recargar la ruta.
class RouteInfo extends Equatable {
  final String id;
  final String name;
  final String companyId;

  const RouteInfo({
    required this.id,
    required this.name,
    required this.companyId,
  });

  @override
  List<Object?> get props => [id, name, companyId];
}
