// Los puntos de recarga de la tarjeta (D21): el archivo, la capa prendida o
// apagada, el punto elegido y lo que la píldora tiene que decir.
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ya_viene_core/ya_viene_core.dart';

import '../map/presentation/providers/user_location_provider.dart';

const kPuntosRecargaAsset = 'assets/data/puntos_recarga.json';

/// Hasta dónde un punto cuenta como «cerca»: 1 km en línea recta, unos 12
/// minutos a pie. Más lejos ya no se va a recargar caminando.
const double radioRecargaCercaMetros = 1000;

/// Los puntos del archivo, leídos una vez. Si el archivo está roto el error
/// llega entero a la píldora, que deja reintentar.
final puntosRecargaProvider = FutureProvider<List<PuntoDeRecarga>>(
  (ref) async =>
      leerPuntosDeRecarga(await rootBundle.loadString(kPuntosRecargaAsset)),
);

/// La capa se prende a mano: son 1.416 puntos y sin pedirlos solo tapan los
/// buses, que son lo que la app enseña.
final capaRecargaVisibleProvider = StateProvider<bool>((ref) => false);

/// El punto que se tocó en el mapa, el de la ficha. Apagar la capa lo
/// suelta: una ficha de un punto que ya no se ve no tiene de qué hablar.
final puntoRecargaElegidoProvider = StateProvider<PuntoDeRecarga?>((ref) {
  ref.listen<bool>(capaRecargaVisibleProvider, (_, visible) {
    if (!visible) ref.controller.state = null;
  });
  return null;
});

/// Lo que la capa tiene que decir en cada momento.
sealed class EstadoRecarga {
  const EstadoRecarga();
}

/// Nadie la ha pedido.
final class RecargaApagada extends EstadoRecarga {
  const RecargaApagada();
}

/// Prendida, con el archivo aún por leer.
final class RecargaCargando extends EstadoRecarga {
  const RecargaCargando();
}

/// El archivo no se pudo leer.
final class RecargaError extends EstadoRecarga {
  const RecargaError();
}

/// Los puntos están en el mapa, pero sin punto de la persona no hay «cerca»
/// que contar: la píldora calla y el mapa habla solo.
final class RecargaSinPunto extends EstadoRecarga {
  const RecargaSinPunto();
}

/// Los de [radioRecargaCercaMetros] a la redonda, del más cerca al más
/// lejos. Vacía es el estado «No hay puntos de recarga cerca».
final class RecargaCerca extends EstadoRecarga {
  const RecargaCerca(this.cercanos);
  final List<PuntoCercano> cercanos;
}

final estadoRecargaProvider = Provider<EstadoRecarga>((ref) {
  if (!ref.watch(capaRecargaVisibleProvider)) return const RecargaApagada();
  return ref.watch(puntosRecargaProvider).when(
        loading: () => const RecargaCargando(),
        error: (_, __) => const RecargaError(),
        data: (puntos) {
          final ubicacion = ref.watch(userLocationProvider);
          final (lat, lon) = (ubicacion.lat, ubicacion.lon);
          if (!ubicacion.hasPosition || lat == null || lon == null) {
            return const RecargaSinPunto();
          }
          return RecargaCerca(puntosCerca(
            puntos,
            lat: lat,
            lon: lon,
            radioMetros: radioRecargaCercaMetros,
          ));
        },
      );
});

/// La píldora: cuántos hay cerca, en singular o plural, o que no hay.
String textoPuntosCerca(int cuantos) => switch (cuantos) {
      0 => 'No hay puntos de recarga cerca',
      1 => '1 punto de recarga cerca de tu punto',
      _ => '$cuantos puntos de recarga cerca de tu punto',
    };

const _conectores = {'de', 'del', 'la', 'las', 'el', 'los', 'y', 'en'};
final _vocal = RegExp('[aeiouáéíóú]', caseSensitive: false);

/// Las siglas de la lista del AMB que sí llevan vocal: centro de
/// diagnóstico automotor, estación de servicio, comando de policía y el
/// colegio. Sin vocal (CC, CRA) ya se reconocen solas.
const _siglas = {'CDA', 'EDS', 'CAI', 'INEM'};

/// El nombre como se escribe un nombre: la fuente los da en mayúsculas y
/// así, en una ficha, gritan. Las siglas (CC, CDA) se quedan como están;
/// los conectores van en minúscula salvo al principio.
String nombreDelPunto(String nombre) {
  final palabras = nombre.split(' ');
  return [
    for (final (i, palabra) in palabras.indexed)
      if (i > 0 && _conectores.contains(palabra.toLowerCase()))
        palabra.toLowerCase()
      else
        palabra.split('-').map(_capitalizada).join('-'),
  ].join(' ');
}

String _capitalizada(String parte) {
  if (parte.isEmpty ||
      !_vocal.hasMatch(parte) ||
      _siglas.contains(parte.toUpperCase())) {
    return parte;
  }
  final minuscula = parte.toLowerCase();
  return minuscula[0].toUpperCase() + minuscula.substring(1);
}

const _meses = [
  'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio', //
  'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
];

/// El día de la consulta, en palabras: «11 de noviembre de 2026».
String fechaDeLaFuente(DateTime fecha) =>
    '${fecha.day} de ${_meses[fecha.month - 1]} de ${fecha.year}';

/// La ruta a pie hasta el punto, en el mapa del teléfono: Mapas de Apple en
/// el iPhone y Google Maps en Android. A pie porque el punto está cerca y
/// la persona está esperando el bus, no manejando.
Uri enlaceComoLlegar(PuntoDeRecarga punto, TargetPlatform plataforma) {
  final destino = '${_coordenada(punto.lat)},${_coordenada(punto.lon)}';
  return Uri.parse(plataforma == TargetPlatform.iOS
      ? 'https://maps.apple.com/?daddr=$destino&dirflg=w'
      : 'https://www.google.com/maps/dir/?api=1&destination=$destino'
          '&travelmode=walking');
}

/// Seis decimales (0,1 m) sin los ceros de la cola: el archivo ya viene con
/// seis y la suma de coma flotante no tiene por qué llegar al enlace.
String _coordenada(double grados) => grados
    .toStringAsFixed(6)
    .replaceFirst(RegExp(r'0+$'), '')
    .replaceFirst(RegExp(r'\.$'), '');
