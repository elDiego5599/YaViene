/// Llaves de SharedPreferences compartidas entre pantallas y providers.
abstract final class PrefsKeys {
  // La ruta/empresa NO se persiste a propósito: al reabrir la app el usuario
  // elige su ruta de nuevo; solo el pin manual sobrevive al arranque (vive en
  // user_location_provider). Si en el futuro hay más claves, viven aquí.
}
