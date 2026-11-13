import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_core/ya_viene_core.dart';

void main() {
  test('los motivos son los del backend, en su orden', () {
    // MOTIVOS_QUEJA y LITERAL_MOTIVO en YaVieneBackend/src/data/quejas.ts.
    expect(MotivoQueja.values.map((m) => (m.clave, m.texto)), [
      ('no_paro', 'No paró'),
      ('iba_lleno', 'Iba lleno'),
      ('mal_trato', 'Mal trato'),
      ('conduccion', 'Conducción'),
      ('otra_ruta', 'Otra ruta'),
      ('estado_bus', 'Estado del bus'),
      ('otro', 'Otro'),
    ]);
  });

  test('la clave del servidor vuelve a su motivo; una desconocida no', () {
    for (final motivo in MotivoQueja.values) {
      expect(MotivoQueja.desdeClave(motivo.clave), motivo);
    }
    expect(MotivoQueja.desdeClave('nuevo'), isNull);
    expect(MotivoQueja.desdeClave(null), isNull);
  });
}
