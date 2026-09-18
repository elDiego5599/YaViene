// Stream de posiciones por ruta: escucha batch/live/left/hidden/removed del
// socket y emite snapshots filtrados. Extraído de tracking_providers.dart
// para que el stream tenga su propio archivo.
import 'dart:async';

import 'package:ya_viene_core/ya_viene_core.dart';

import '../../domain/repositories/realtime_repository.dart';

Stream<List<BusPosition>> buildRoutePositionsStream(
  RealtimeRepository service,
  Set<String> routeIds,
) {
  final controller = StreamController<List<BusPosition>>();
  final positions = <String, BusPosition>{};
  final processedEventIds = <String>{};
  Timer? emitTimer;

  void emitSnapshot() {
    if (!controller.isClosed) controller.add(positions.values.toList());
  }

  void scheduleLiveSnapshot() {
    if (emitTimer != null) return;
    emitTimer = Timer(const Duration(milliseconds: 200), () {
      emitTimer = null;
      emitSnapshot();
    });
  }

  bool belongsTo(dynamic routeId) => routeIds.contains(routeId);

  // Si [nueva] puede ocupar el lugar de [previa]. La captura del equipo manda
  // (`esMasNueva`, en core): una posición que llega tarde —el socket
  // reconectó, el lote salió de la base antes, el respaldo va atrás— no
  // retrocede el bus (T2.5).
  bool reemplaza(BusPosition nueva, BusPosition? previa) =>
      previa == null ||
      esMasNueva(
        capturaNueva: nueva.capturedAt,
        capturaPrevia: previa.capturedAt,
        fantasmaNuevo: nueva.isGhostBus,
        fantasmaPrevio: previa.isGhostBus,
      );

  // Los eventos llegan del socket como JSON sin tipar. Un `as String?` sobre
  // un campo que venga con otro tipo (un busId numérico, un routeId dentro de
  // una lista) lanzaba dentro del `listen`, fuera de cualquier `try`: el
  // error se escapaba por la zona y el evento se perdía a medias. Ahora un
  // campo que no es texto con contenido cuenta como ausente, y el evento que
  // lo necesita se descarta entero.
  String? texto(Object? valor) {
    if (valor is! String) return null;
    final limpio = valor.trim();
    return limpio.isEmpty ? null : limpio;
  }

  final batchSub = service.batchPositionStream.listen((batch) {
    final routeId = texto(batch['routeId']);
    if (routeId == null || !belongsTo(routeId)) return;
    final buses = batch['buses'];
    // El lote dice qué buses hay en la ruta; de cada uno queda la posición
    // más nueva entre la del lote y la que ya había llegado en vivo.
    final previas = Map.of(positions);
    positions.clear();
    if (buses is List) {
      for (final item in buses) {
        if (item is! Map) continue;
        final Map<String, dynamic> json;
        try {
          json = Map<String, dynamic>.from(item);
        } catch (_) {
          continue;
        }
        final pos = BusPosition.tryParse(json);
        if (pos == null) continue;
        final previa = previas[pos.busId];
        positions[pos.busId] = reemplaza(pos, previa) ? pos : previa!;
      }
    }
    emitSnapshot();
  });

  final liveSub = service.busPositionStream.listen((json) {
    final pos = BusPosition.tryParse(json);
    if (pos == null) return;
    if (!belongsTo(pos.routeId)) return;
    if (!reemplaza(pos, positions[pos.busId])) return;
    positions[pos.busId] = pos;
    scheduleLiveSnapshot();
  });

  final leftSub = service.busLeftStream.listen((event) {
    if (event['routeId'] != null && !belongsTo(event['routeId'])) return;
    final busId = texto(event['busId']);
    if (busId != null && positions.remove(busId) != null) {
      emitSnapshot();
    }
  });

  final hiddenSub = service.busHiddenStream.listen((event) {
    if (event['routeId'] != null && !belongsTo(event['routeId'])) return;
    // Un eventId que no es texto se trata como si no viniera: se pierde la
    // deduplicación, pero ocultar dos veces el mismo bus no cambia nada.
    final eventId = texto(event['eventId']);
    final busId = texto(event['busId']);
    if (busId == null) return;
    if (eventId != null) {
      if (!processedEventIds.add(eventId)) return;
      if (processedEventIds.length > 5000) processedEventIds.clear();
    }
    if (positions.remove(busId) != null) {
      emitSnapshot();
    }
  });

  final removedSub = service.busRemovedStream.listen((event) {
    if (event['routeId'] != null && !belongsTo(event['routeId'])) return;
    final busId = texto(event['busId']);
    if (busId != null && positions.remove(busId) != null) {
      emitSnapshot();
    }
  });

  final visibleSub = service.busVisibleStream.listen((event) {
    if (event['routeId'] != null && !belongsTo(event['routeId'])) return;
    final eventId = texto(event['eventId']);
    final busId = texto(event['busId']);
    if (busId == null) return;
    if (eventId != null) {
      if (!processedEventIds.add(eventId)) return;
      if (processedEventIds.length > 5000) processedEventIds.clear();
    }
    final position = event['position'];
    if (position is Map) {
      final Map<String, dynamic> json;
      try {
        json = Map<String, dynamic>.from(position);
      } catch (_) {
        return;
      }
      final pos = BusPosition.tryParse(json);
      // La posición tiene que ser la del bus que el evento dice y de una ruta
      // de este stream. Si no, quedaba guardada con la llave de otro bus, o
      // pintaba en esta ruta un bus que va por otra. Y no puede ser más
      // vieja que la que ya se tiene de él.
      if (pos != null &&
          pos.busId == busId &&
          belongsTo(pos.routeId) &&
          reemplaza(pos, positions[busId])) {
        positions[busId] = pos;
        emitSnapshot();
      }
    }
  });

  controller.onCancel = () {
    batchSub.cancel();
    liveSub.cancel();
    leftSub.cancel();
    hiddenSub.cancel();
    removedSub.cancel();
    visibleSub.cancel();
    emitTimer?.cancel();
    controller.close();
  };

  return controller.stream;
}
