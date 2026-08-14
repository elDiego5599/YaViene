/// Llaves de SharedPreferences compartidas entre pantallas y providers.
abstract final class PrefsKeys {
  /// Última ruta seleccionada: se restaura en el arranque para que la app
  /// abra donde quedaste.
  static const String savedRouteId = 'saved_route_id';
  static const String savedCompanyId = 'saved_company_id';
}