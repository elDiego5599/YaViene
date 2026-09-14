// Pruebas de a qué backend decide hablarle la app en el arranque.
//
// Lo que se protege aquí es un fallo de demo, no un detalle de red: la URL del
// backend es constante de compilación, así que sin respaldo una APK ya
// repartida se queda muerta si el túnel de ngrok se cae, y la única salida es
// recompilar e instalar de nuevo.
import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_core/ya_viene_core.dart';

const principal = 'https://tunel.ngrok-free.dev';
const respaldo = 'https://ya-viene-backend.fly.dev';

/// Sonda de mentira: contesta que sí solo a las URLs de [vivas], y apunta a
/// quién se le preguntó y con cuánta espera.
({
  Future<bool> Function(String, Duration) sonda,
  List<String> preguntadas,
  List<Duration> esperas,
}) sondaFalsa(Set<String> vivas) {
  final preguntadas = <String>[];
  final esperas = <Duration>[];
  return (
    sonda: (String url, Duration espera) async {
      preguntadas.add(url);
      esperas.add(espera);
      return vivas.contains(url);
    },
    preguntadas: preguntadas,
    esperas: esperas,
  );
}

void main() {
  test('con la principal viva no se pregunta por el respaldo', () async {
    final f = sondaFalsa({principal, respaldo});
    final elegida = await BackendResolver.resolver(
      principal: principal,
      respaldo: respaldo,
      sonda: f.sonda,
    );
    expect(elegida, principal);
    // Importa que sea exactamente una: este camino es el 99 % de los
    // arranques, y cada pregunta de más es tiempo de pantalla en blanco.
    expect(f.preguntadas, [principal]);
  });

  test('con la principal caída se usa el respaldo', () async {
    final f = sondaFalsa({respaldo});
    final elegida = await BackendResolver.resolver(
      principal: principal,
      respaldo: respaldo,
      sonda: f.sonda,
    );
    expect(elegida, respaldo);
    expect(f.preguntadas, [principal, respaldo]);
  });

  test('si ninguna contesta se devuelve la principal', () async {
    // A propósito: así el mensaje de error que ve el usuario habla del sitio
    // que se configuró, y no de un respaldo que él no sabe que existe.
    final f = sondaFalsa({});
    final elegida = await BackendResolver.resolver(
      principal: principal,
      respaldo: respaldo,
      sonda: f.sonda,
    );
    expect(elegida, principal);
  });

  test('sin respaldo configurado no se pregunta nada', () async {
    final f = sondaFalsa({});
    final elegida = await BackendResolver.resolver(
      principal: principal,
      respaldo: '',
      sonda: f.sonda,
    );
    expect(elegida, principal);
    expect(f.preguntadas, isEmpty);
  });

  test('un respaldo igual a la principal no gasta una petición', () async {
    final f = sondaFalsa({});
    final elegida = await BackendResolver.resolver(
      principal: principal,
      respaldo: principal,
      sonda: f.sonda,
    );
    expect(elegida, principal);
    expect(f.preguntadas, isEmpty);
  });

  test('el respaldo espera más que la principal', () async {
    // La máquina de Fly duerme mientras no se usa y la primera petición la
    // levanta: medido, ese arranque en frío tarda unos 8 segundos, así que
    // con la espera corta de la principal el respaldo nunca llegaría a tiempo.
    final f = sondaFalsa({});
    await BackendResolver.resolver(
      principal: principal,
      respaldo: respaldo,
      sonda: f.sonda,
    );
    expect(f.esperas.first, BackendResolver.esperaPrincipal);
    expect(f.esperas.last, BackendResolver.esperaRespaldo);
    expect(f.esperas.last, greaterThan(f.esperas.first));
  });
}
