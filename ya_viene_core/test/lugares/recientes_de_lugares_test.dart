import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_core/core/lugares/lugar.dart';
import 'package:ya_viene_core/core/lugares/recientes_de_lugares.dart';
import 'package:ya_viene_core/core/models/route_trajectory.dart';

Sugerencia _sitio(String nombre, {double lat = 11.0, double lon = -74.8}) =>
    Sugerencia(
      lugar: Lugar(
        punto: GeoPoint(lat: lat, lon: lon),
        origen: OrigenLugar.sitio,
        nombre: nombre,
      ),
      tipo: TipoLugar.barrio,
      contexto: 'Barrio, Barranquilla',
    );

void main() {
  late AlmacenEnMemoria almacen;
  late RecientesDeLugares recientes;

  setUp(() {
    almacen = AlmacenEnMemoria();
    recientes = RecientesDeLugares(almacen);
  });

  test('sin nada guardado no hay recientes', () async {
    expect(await recientes.lista(), isEmpty);
  });

  test('el último elegido va primero', () async {
    await recientes.guardar(_sitio('El Prado'));
    await recientes.guardar(_sitio('Boston'));
    expect(
        (await recientes.lista()).map((s) => s.nombre), ['Boston', 'El Prado']);
  });

  test('elegir otra vez uno que ya estaba lo sube, sin repetirlo', () async {
    await recientes.guardar(_sitio('El Prado'));
    await recientes.guardar(_sitio('Boston'));
    await recientes.guardar(_sitio('El Prado'));
    expect(
        (await recientes.lista()).map((s) => s.nombre), ['El Prado', 'Boston']);
  });

  test('dos lugares con el mismo nombre en sitios distintos son dos', () async {
    await recientes.guardar(_sitio('Calle 30', lat: 10.96));
    await recientes.guardar(_sitio('Calle 30', lat: 10.91));
    expect(await recientes.lista(), hasLength(2));
  });

  test('guarda solo los ocho últimos', () async {
    for (var i = 0; i < 10; i++) {
      await recientes.guardar(_sitio('Lugar $i'));
    }
    final lista = await recientes.lista();
    expect(lista, hasLength(RecientesDeLugares.maximo));
    expect(lista.first.nombre, 'Lugar 9');
    expect(lista.last.nombre, 'Lugar 2');
  });

  test('se borra uno y se borran todos', () async {
    await recientes.guardar(_sitio('El Prado'));
    await recientes.guardar(_sitio('Boston'));
    await recientes.borrar(_sitio('El Prado'));
    expect((await recientes.lista()).map((s) => s.nombre), ['Boston']);
    await recientes.borrarTodos();
    expect(await recientes.lista(), isEmpty);
    expect(almacen.texto, isNull, reason: 'borrar todo no deja rastro');
  });

  test('sobrevive a lo guardado por otra versión o a medias', () async {
    almacen.texto = '{no es json';
    expect(await recientes.lista(), isEmpty);
    almacen.texto = '[{"lugar": 3}]';
    expect(await recientes.lista(), isEmpty);
    await recientes.guardar(_sitio('Boston'));
    expect((await recientes.lista()).map((s) => s.nombre), ['Boston']);
  });

  // Los guardados antes del formato de aquí (dueño, 2026-11-15) se leen ya
  // como «Clle 72 #46-20», y al volver a elegirlos no se duplican.
  test('lo guardado con el nombre largo vuelve a la manera de aquí', () async {
    await recientes.guardar(_sitio('Calle 72 # 46-20'));
    expect((await recientes.lista()).single.nombre, 'Clle 72 #46-20');
    await recientes.guardar(_sitio('Clle 72 #46-20'));
    expect(await recientes.lista(), hasLength(1));
  });

  test('lo que se guarda vuelve igual', () async {
    final boston = _sitio('Boston', lat: 10.99412, lon: -74.80031);
    await recientes.guardar(boston);
    expect(await RecientesDeLugares(almacen).lista(), [boston]);
  });
}
