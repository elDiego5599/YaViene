/// Llaves de SharedPreferences compartidas entre pantallas y providers.
///
/// Nada de esto va cifrado, y es a propósito. En el teléfono, las
/// preferencias viven en el almacenamiento privado de la app: sólo la app
/// las lee, y para sacarlas hace falta el teléfono desbloqueado y con root.
/// Cifrar ahí no protege de nada —la llave tendría que guardarse al lado del
/// dato o en el llavero, y quien puede leer uno puede leer el otro— y a
/// cambio se paga una dependencia nativa más en las dos plataformas.
///
/// Donde sí salía del teléfono era en las copias de seguridad: el pin de
/// espera (la esquina de la casa) y el historial de avisos (a qué hora se
/// tomó cuál ruta) se subían a la cuenta del usuario. En Android eso ya no
/// pasa: `android/app/src/main/res/xml/backup_rules.xml` y
/// `data_extraction_rules.xml` excluyen el fichero. En iOS los `UserDefaults`
/// entran en la copia de iCloud, que Apple guarda cifrada y atada a la cuenta
/// del propio usuario; excluirlos de ahí exige mover todo al llavero, y para
/// datos que la app vuelve a pedir en dos toques no compensa.
///
/// La regla que queda para lo que se añada aquí: si un dato no se puede
/// volver a pedir en dos toques, o identifica a la persona más que su
/// parada, no va en SharedPreferences.
abstract final class PrefsKeys {
  static const explicacionSeguirBusOculta = 'explicacion_seguir_bus_oculta';
  static const explicacionAvisoCercaniaOculta =
      'explicacion_aviso_cercania_oculta';
  // La ruta/empresa NO se persiste a propósito: al reabrir la app el usuario
  // elige su ruta de nuevo; solo el pin manual sobrevive al arranque (vive en
  // user_location_provider). Si en el futuro hay más claves, viven aquí.
}
