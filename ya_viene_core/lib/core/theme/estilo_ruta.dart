/// Estilo compartido del recorrido y sus paradas en ambos mapas.
final class RutaLinea {
  const RutaLinea(
      {required this.lineColor,
      required this.lineWidth,
      required this.lineOpacity,
      required this.lineCap,
      required this.lineJoin});
  final String lineColor;
  final double lineWidth;
  final double lineOpacity;
  final String lineCap;
  final String lineJoin;
}

final class RutaParada {
  const RutaParada(
      {required this.circleRadius,
      required this.circleColor,
      required this.circleStrokeWidth,
      required this.circleStrokeColor,
      this.circleOpacity = 1,
      this.circleStrokeOpacity = 1});
  final double circleRadius;
  final String circleColor;
  final double circleStrokeWidth;
  final String circleStrokeColor;
  final double circleOpacity;
  final double circleStrokeOpacity;
}

abstract final class EstiloRuta {
  static const String _verde = '#00A859';

  static const RutaLinea orla = RutaLinea(
    lineColor: '#FFFFFF',
    lineWidth: 8.0,
    lineOpacity: 0.95,
    lineCap: 'round',
    lineJoin: 'round',
  );

  static const RutaLinea linea = RutaLinea(
    lineColor: _verde,
    lineWidth: 4.0,
    lineOpacity: 1.0,
    lineCap: 'round',
    lineJoin: 'round',
  );

  static const RutaParada paradaFija = RutaParada(
    circleRadius: 7.0,
    circleColor: '#FFFFFF',
    circleStrokeWidth: 2.5,
    circleStrokeColor: _verde,
  );

  static const RutaParada paradaInformal = RutaParada(
    circleRadius: 30.0,
    circleColor: _verde,
    circleOpacity: 0.12,
    circleStrokeWidth: 1.5,
    circleStrokeColor: _verde,
    circleStrokeOpacity: 0.3,
  );
}
