import 'package:ya_viene_core/ya_viene_core.dart' show MotivoQueja;

/// Una queja de un pasajero sobre una ruta de la empresa (D18), como la
/// lista `GET /api/panel/quejas`. Nadie la verificó: la pantalla lo dice.
class QuejaPanel {
  const QuejaPanel({
    required this.id,
    required this.motivo,
    required this.texto,
    required this.routeId,
    required this.ruta,
    required this.busId,
    required this.celda,
    required this.hora,
    required this.creado,
  });

  final String id;

  /// Nulo si el backend trae un motivo que este panel aún no conoce: la
  /// lista no se cae por eso y lo muestra como «Otro».
  final MotivoQueja? motivo;
  final String texto;
  final String routeId;

  /// El nombre de la ruta en la flota; nulo si la empresa ya no la tiene.
  final String? ruta;
  final String? busId;

  /// La celda de 150 m de la rejilla de D17, si el pasajero dio el lugar.
  final ({double lat, double lng})? celda;

  /// La hora del hecho, en punto, si el pasajero la dio.
  final DateTime? hora;

  /// Cuándo llegó al buzón.
  final DateTime creado;

  /// Por lo que se ordena y filtra en el backend: el hecho o, sin él, la
  /// llegada.
  DateTime get cuando => hora ?? creado;

  factory QuejaPanel.fromJson(Map<String, dynamic> json) {
    final celda = json['celda'] as Map?;
    return QuejaPanel(
      id: json['id'] as String,
      motivo: MotivoQueja.desdeClave(json['motivo'] as String?),
      texto: json['texto'] as String,
      routeId: json['routeId'] as String,
      ruta: json['ruta'] as String?,
      busId: json['busId'] as String?,
      celda: celda == null
          ? null
          : (
              lat: (celda['lat'] as num).toDouble(),
              lng: (celda['lng'] as num).toDouble(),
            ),
      hora: _instante(json['hora']),
      creado: _instante(json['creado'])!,
    );
  }
}

/// Cuántas quejas del filtro cayeron en una celda: el mapa las cuenta todas,
/// aunque la lista se corte en [ReporteQuejas.tope].
class CeldaQueja {
  const CeldaQueja({required this.lat, required this.lng, required this.total});

  final double lat;
  final double lng;
  final int total;

  factory CeldaQueja.fromJson(Map<String, dynamic> json) => CeldaQueja(
    lat: (json['lat'] as num).toDouble(),
    lng: (json['lng'] as num).toDouble(),
    total: (json['total'] as num).toInt(),
  );
}

class ReporteQuejas {
  const ReporteQuejas({required this.quejas, required this.celdas});

  static const vacio = ReporteQuejas(quejas: [], celdas: []);

  /// Lo que el backend lista de una vez (`MAX_LISTA` en `quejas.ts`).
  static const tope = 500;

  /// La más reciente arriba.
  final List<QuejaPanel> quejas;
  final List<CeldaQueja> celdas;

  /// La lista llegó cortada: hay más viejas que no se ven.
  bool get alTope => quejas.length >= tope;

  factory ReporteQuejas.fromJson(Map<String, dynamic> json) => ReporteQuejas(
    quejas: [
      for (final q in json['quejas'] as List)
        QuejaPanel.fromJson(Map<String, dynamic>.from(q as Map)),
    ],
    celdas: [
      for (final c in json['celdas'] as List)
        CeldaQueja.fromJson(Map<String, dynamic>.from(c as Map)),
    ],
  );
}

DateTime? _instante(Object? ms) => ms == null
    ? null
    : DateTime.fromMillisecondsSinceEpoch((ms as num).toInt(), isUtc: true);
