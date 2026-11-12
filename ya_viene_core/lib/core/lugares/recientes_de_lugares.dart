import 'dart:convert';

import 'lugar.dart';

/// Donde los recientes viven en el teléfono, como un solo texto.
///
/// El core no depende de `shared_preferences`: la app pone su adaptador y
/// las pruebas y el arnés usan [AlmacenEnMemoria]. Nada de esto sale del
/// teléfono (Ley 1581): lo que alguien busca dice dónde vive.
abstract interface class AlmacenDeRecientes {
  Future<String?> leer();

  /// Con `null` borra lo guardado.
  Future<void> escribir(String? texto);
}

class AlmacenEnMemoria implements AlmacenDeRecientes {
  AlmacenEnMemoria([this.texto]);

  String? texto;

  @override
  Future<String?> leer() async => texto;

  @override
  Future<void> escribir(String? texto) async => this.texto = texto;
}

/// Los últimos lugares elegidos en el buscador, el más nuevo primero.
class RecientesDeLugares {
  RecientesDeLugares(this._almacen);

  /// Los que caben en la lista vacía del buscador sin desplazar.
  static const maximo = 8;

  final AlmacenDeRecientes _almacen;

  Future<List<Sugerencia>> lista() async {
    final texto = await _almacen.leer();
    if (texto == null) return const [];
    try {
      return [
        for (final s in jsonDecode(texto) as List<dynamic>)
          Sugerencia.fromJson(s as Map<String, dynamic>),
      ];
    } on Object {
      // Guardado por otra versión o cortado a medias: se empieza de cero
      // en vez de romper la búsqueda. El próximo guardado lo reemplaza.
      return const [];
    }
  }

  /// Pone [elegida] arriba; si ya estaba (mismo nombre y mismo punto), la
  /// sube en vez de repetirla.
  Future<void> guardar(Sugerencia elegida) async {
    final resto = (await lista()).where((s) => s.lugar != elegida.lugar);
    await _escribir([elegida, ...resto].take(maximo).toList());
  }

  Future<void> borrar(Sugerencia sugerencia) async {
    await _escribir(
      (await lista()).where((s) => s.lugar != sugerencia.lugar).toList(),
    );
  }

  Future<void> borrarTodos() => _almacen.escribir(null);

  Future<void> _escribir(List<Sugerencia> lista) => _almacen.escribir(
        lista.isEmpty ? null : jsonEncode([for (final s in lista) s.toJson()]),
      );
}
