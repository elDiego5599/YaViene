/// Por qué se queja el pasajero (D18). La clave es la del backend
/// (`MOTIVOS_QUEJA` en `src/data/quejas.ts`) y el texto el mismo que leen el
/// correo y el panel (`LITERAL_MOTIVO`); el orden también es el suyo. Vive en
/// el core porque el pasajero la escribe y el panel la lee.
enum MotivoQueja {
  noParo('no_paro', 'No paró'),
  ibaLleno('iba_lleno', 'Iba lleno'),
  malTrato('mal_trato', 'Mal trato'),
  conduccion('conduccion', 'Conducción'),
  otraRuta('otra_ruta', 'Otra ruta'),
  estadoBus('estado_bus', 'Estado del bus'),
  otro('otro', 'Otro');

  const MotivoQueja(this.clave, this.texto);

  final String clave;
  final String texto;

  /// El motivo de una clave del servidor; `null` si este cliente no la conoce
  /// (un motivo nuevo del backend no tumba la lista).
  static MotivoQueja? desdeClave(String? clave) {
    for (final motivo in values) {
      if (motivo.clave == clave) return motivo;
    }
    return null;
  }
}
