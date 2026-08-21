// Números que antes estaban desperdigados por el mapa. Centralizarlos aquí
// evita que un cambio en un sitio rompa otro y que el próximo dev adivine
// de dónde viene cada valor.
class MapConstants {
  MapConstants._();

  /// Radio para hit-test de buses (proyección + fallback rect).
  static const double busHitRadius = 32.0;

  /// Rect del área guía de buses (usado como fallback visual).
  static const double guideBusRectSize = 76.0;

  /// Inset inferior que deja la tarjeta de guía sobre el mapa (evita navbar).
  static const double guideBottomInset = 310.0;

  /// Ancho del icono de bus (Flat) en el canvas de 80 px.
  static const double busIconSize = 80.0;
}
