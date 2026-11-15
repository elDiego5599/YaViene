import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/map_view_state.dart';
import 'package:ya_viene_pasajero/features/recarga/recarga_providers.dart';

/// La píldora de pestañas se funde con la hoja del mapa (le cede fondo,
/// filo y sombra). Si la hoja se aparta y la píldora no se entera, queda sin
/// su cuadro blanco: iconos sueltos sobre el mapa. Las dos leen este mismo
/// estado.
void main() {
  late ProviderContainer c;
  setUp(() {
    c = ProviderContainer();
    addTearDown(c.dispose);
    c.listen(hojaApartadaProvider, (_, __) {});
  });

  test('la hoja está a la vista por defecto', () {
    expect(c.read(hojaApartadaProvider), isFalse);
  });

  test('con el selector de ruta abierto, la hoja se aparta', () {
    c.read(routeSelectorOpenProvider.notifier).state = true;
    expect(c.read(hojaApartadaProvider), isTrue);
  });

  test('con la ficha de un punto de recarga, la hoja se aparta', () {
    c.read(puntoRecargaElegidoProvider.notifier).state = PuntoDeRecarga(
      id: 'a',
      nombre: 'DONDE TERESA # 1',
      lat: 10.98,
      lon: -74.78,
      direccion: 'CLL 76 N 18C 19',
      municipio: 'Soledad',
      horario: null,
      fuente: FuenteCitada(
        nombre: 'SIBUS',
        fecha: DateTime.utc(2026, 11, 11),
        url: Uri.parse('https://sibusoficial.ambq.gov.co/'),
      ),
    );
    expect(c.read(hojaApartadaProvider), isTrue);
  });
}
