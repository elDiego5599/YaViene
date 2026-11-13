import 'package:equatable/equatable.dart';

import '../models/route_trajectory.dart';

/// De dónde salió un [Lugar].
enum OrigenLugar {
  /// La ubicación del teléfono.
  gps,

  /// Un punto que la persona tocó o arrastró en el mapa.
  pin,

  /// Un nombre que escribió y eligió en el buscador.
  sitio,
}

/// Dónde empieza o termina un viaje (`docs/viaje-completo.md`, sección 2).
///
/// Sin [nombre] si vino del GPS o del pin: el mapa no lleva nombres de
/// sitios (reglas del producto, 5) y no se inventa uno.
class Lugar extends Equatable {
  const Lugar({required this.punto, required this.origen, this.nombre})
      : assert(
          origen != OrigenLugar.sitio || nombre != null,
          'Un sitio buscado siempre trae su nombre',
        );

  final GeoPoint punto;
  final OrigenLugar origen;
  final String? nombre;

  factory Lugar.fromJson(Map<String, dynamic> json) => Lugar(
        punto: GeoPoint.fromJson(json['punto'] as Map<String, dynamic>),
        origen: OrigenLugar.values.byName(json['origen'] as String),
        nombre: json['nombre'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'punto': punto.toJson(),
        'origen': origen.name,
        if (nombre != null) 'nombre': nombre,
      };

  @override
  List<Object?> get props => [punto, origen, nombre];
}

/// Qué clase de lugar encontró el buscador; decide el ícono de la fila.
enum TipoLugar {
  barrio,

  /// Una calle, carrera, avenida, diagonal o transversal entera.
  via,

  /// Una esquina o una placa: «Calle 72 con 46», «Calle 72 # 46-20».
  cruce,

  /// Un sitio con nombre: centro comercial, universidad, hospital.
  sitio,
}

/// Una fila de resultados: el [lugar] y cómo se dice.
class Sugerencia extends Equatable {
  const Sugerencia({
    required this.lugar,
    required this.tipo,
    required this.contexto,
  });

  /// Siempre con `origen: sitio` y su nombre.
  final Lugar lugar;
  final TipoLugar tipo;

  /// La línea gris bajo el nombre: «Barrio, Barranquilla»,
  /// «Centro comercial, Puerto Colombia».
  final String contexto;

  String get nombre => lugar.nombre!;

  factory Sugerencia.fromJson(Map<String, dynamic> json) => Sugerencia(
        lugar: Lugar.fromJson(json['lugar'] as Map<String, dynamic>),
        tipo: TipoLugar.values.byName(json['tipo'] as String),
        contexto: json['contexto'] as String,
      );

  Map<String, dynamic> toJson() => {
        'lugar': lugar.toJson(),
        'tipo': tipo.name,
        'contexto': contexto,
      };

  @override
  List<Object?> get props => [lugar, tipo, contexto];
}
