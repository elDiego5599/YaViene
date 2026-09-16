import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/fleet_bus.dart';
import '../bus_estado.dart';
import '../providers/fleet_providers.dart';

class ControlMap extends ConsumerStatefulWidget {
  const ControlMap({super.key});

  @override
  ConsumerState<ControlMap> createState() => _ControlMapState();
}

class _ControlMapState extends ConsumerState<ControlMap> {
  final MapController _mapController = MapController();
  double _zoom = 12;

  // El marcador crece con el zoom, pero arranca más grande que antes (16 pt):
  // a zoom 12, que es como abre el panel, un bus medía 20 pt de lado y la
  // cápsula dentro apenas 15 — un grano de arroz sobre la ciudad entera.
  // El tope sube a 44 para que al acercarse se lea de quién es el bus sin
  // que el icono tape la manzana.
  double get _markerSize => (26 + (_zoom - 11) * 5).clamp(26.0, 44.0);

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  static bool _inRoute(FleetState fleet, FleetBus bus) =>
      fleet.routeFilter == null || bus.routeId == fleet.routeFilter;

  @override
  Widget build(BuildContext context) {
    final fleet = ref.watch(fleetProvider);
    final size = _markerSize;
    final markers = fleet.fleetList
        .where((b) => b.lat != null && b.lon != null)
        .map(
          (b) => _buildMarker(b, fleet.selectedBusId == b.busId, size, () {
            ref.read(fleetProvider.notifier).selectBus(b.busId);
          }),
        )
        .toList();

    // Cada bus de la ruta cae en un estado y solo en uno, así que las cuatro
    // cifras suman el total. Antes eran tres contadores que se solapaban —un
    // bus oculto y sin señal se contaba dos veces— y el operador no podía
    // sumarlos para saber cuántos buses tenía.
    final conteo = <BusEstado, int>{for (final e in BusEstado.values) e: 0};
    for (final bus in fleet.buses.values) {
      if (!_inRoute(fleet, bus)) continue;
      conteo[BusEstado.de(bus)] = conteo[BusEstado.de(bus)]! + 1;
    }

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: const LatLng(10.9639, -74.7964),
            initialZoom: 12,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
            onPositionChanged: (camera, hasGesture) {
              if ((camera.zoom - _zoom).abs() > 0.05) {
                setState(() => _zoom = camera.zoom);
              }
            },
          ),
          children: [
            // Mapa de OpenStreetMap: agua azul, parques verdes, vías cálidas,
            // la misma familia de colores que ve el pasajero, en vez del gris
            // apagado con el que el panel parecía otro producto.
            //
            // El pasajero usa el estilo Voyager de CARTO, y sería lo ideal
            // aquí también, pero CARTO ya solo entrega sus teselas
            // rasterizadas —las únicas que flutter_map sabe pintar— con una
            // marca de agua "API KEY REQUIRED" atravesada encima. Allá no se
            // nota porque el mapa es vectorial y esas teselas siguen limpias.
            // Para igualar el estilo exacto en escritorio haría falta pintar
            // vectores, y el único paquete que lo hace todavía está en beta:
            // no es algo que se meta a días de una presentación.
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              // OSM no sirve teselas @2x y devuelve 404 si se le piden: sin
              // esto el mapa sale en blanco en cualquier pantalla densa.
              retinaMode: false,
              userAgentPackageName: 'co.yaviene.control',
            ),
            MarkerLayer(markers: markers),
          ],
        ),
        // OpenStreetMap pide el crédito a la vista. Va discreto, en la
        // esquina contraria a la leyenda.
        const Positioned(
          right: 8,
          bottom: 4,
          child: _Attribution(),
        ),
        Positioned(
          left: 18,
          bottom: 18,
          // La leyenda describe lo que se ve en el mapa: escopada a la ruta
          // seleccionada como las pestañas y los marcadores (antes contaba
          // toda la empresa y los números no coincidían con nada).
          child: FleetLegend(conteo: conteo),
        ),
      ],
    );
  }

  Marker _buildMarker(
    FleetBus bus,
    bool selected,
    double size,
    VoidCallback onTap,
  ) {
    return Marker(
      point: LatLng(bus.lat!, bus.lon!),
      width: size,
      height: size,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Semantics(
          label: '${bus.placa.isEmpty ? bus.busId : bus.placa}: '
              '${BusEstado.de(bus).rotulo}',
          child: Transform.rotate(
            // Un bus del que nunca llegó rumbo se pinta sin girar.
            angle: (bus.heading ?? 0) * math.pi / 180,
            child: CustomPaint(
              size: Size.square(size),
              painter: _FlatBusPainter(
                estado: BusEstado.de(bus),
                selected: selected,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/*
  El mismo bus que ve el pasajero. Antes el panel dibujaba uno propio —un
  rectángulo azul marino con dos farolas verdes— y el operador no podía
  relacionar lo que tenía en pantalla con lo que le describía por teléfono
  alguien parado en el paradero. Ahora es la misma cápsula.

  Lo que dice el dibujo son dos cosas a la vez, y ninguna es solo el color
  (T6.4). El relleno dice si el bus está reportando y el borde si hace falta
  mirarlo:

      relleno lleno + borde continuo → en línea
      relleno lleno + borde punteado → inactivo, sigue en turno
      cápsula hueca + borde continuo → sin señal
      cápsula hueca + borde punteado → oculto, lo apagó el operador

  Así el mapa se lee igual en blanco y negro, en el proyector del pitch o
  con cualquier daltonismo. Antes había un solo eje —color sí, color no— y
  tres de los cuatro estados caían del mismo lado: eran el mismo bus gris.

  La diferencia con la app es de medio: allá el ícono se hornea una vez a
  PNG y MapLibre lo reusa como sprite; aquí se pinta en cada cuadro con
  CustomPaint, porque flutter_map trabaja con widgets y el tamaño cambia con
  el zoom. La geometría es la misma proporción 32:60 de la cápsula del
  pasajero, escalada al alto del marcador.
*/
class _FlatBusPainter extends CustomPainter {
  const _FlatBusPainter({required this.estado, required this.selected});

  final BusEstado estado;
  final bool selected;

  /// Reportando: la cápsula va llena.
  bool get _lleno => estado == BusEstado.enLinea || estado == BusEstado.inactivo;

  /// Algo que mirar: el borde va punteado.
  bool get _punteado =>
      estado == BusEstado.inactivo || estado == BusEstado.oculto;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final h = size.height * 0.75;
    final w = h * 32 / 60;
    final baseColor = estado.color;

    if (selected) {
      // Halo azul eléctrico: en la app ese color está reservado a la ruta
      // que le importa al usuario. Aquí lo que le importa al operador es el
      // bus que tiene abierto en la ficha, y es el único azul del mapa.
      canvas.drawCircle(
        center,
        h * 0.62,
        Paint()
          ..color = AppColors.selection.withValues(alpha: 0.45)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, h * 0.16),
      );
    }

    final capsule = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center, width: w, height: h),
      Radius.circular(w / 2),
    );

    if (estado == BusEstado.enLinea) {
      canvas.drawShadow(
        ui.Path()..addRRect(capsule.shift(Offset(0, h * 0.05))),
        baseColor.withValues(alpha: 0.45),
        h * 0.12,
        false,
      );
    }

    if (_lleno) {
      // Degradado sutil (más claro arriba) para que no se vea una silueta
      // plana.
      canvas.drawRRect(
        capsule,
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(center.dx, center.dy - h / 2),
            Offset(center.dx, center.dy + h / 2),
            [Color.lerp(baseColor, Colors.white, 0.3)!, baseColor],
          ),
      );
    } else {
      // Hueca: blanco casi opaco para que el bus siga siendo una silueta
      // sólida sobre las calles y no un fantasma que se pierde en el mapa.
      canvas.drawRRect(
        capsule,
        Paint()..color = Colors.white.withValues(alpha: 0.88),
      );
    }

    // El borde. En la cápsula llena es blanco y sirve para separarla de
    // cualquier fondo de mapa; en la hueca es del color del estado, porque
    // ahí el borde es todo lo que hay.
    final trazo = (w * (_lleno ? 0.08 : 0.14)).clamp(1.2, 3.0);
    final borde = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = trazo
      ..color = _lleno ? Colors.white.withValues(alpha: 0.92) : baseColor;
    final contorno = ui.Path()..addRRect(capsule);
    canvas.drawPath(
      _punteado ? _aPunteado(contorno, trazo * 1.8, trazo * 1.4) : contorno,
      borde,
    );

    if (estado == BusEstado.enLinea) {
      // Insinúa un parabrisas: un óvalo tenue cerca del extremo, nada más.
      canvas.save();
      canvas.clipRRect(capsule);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(center.dx, center.dy - h * 0.26),
          width: w * 0.72,
          height: h * 0.26,
        ),
        Paint()..color = Colors.white.withValues(alpha: 0.3),
      );
      canvas.restore();
    }
  }

  /// El mismo contorno, cortado en trazos. Se recorre el camino con sus
  /// métricas y se extrae un tramo de cada [trazo] + [hueco].
  ui.Path _aPunteado(ui.Path origen, double trazo, double hueco) {
    final salida = ui.Path();
    for (final metrica in origen.computeMetrics()) {
      var desde = 0.0;
      while (desde < metrica.length) {
        final hasta = math.min(desde + trazo, metrica.length);
        salida.addPath(metrica.extractPath(desde, hasta), Offset.zero);
        desde = hasta + hueco;
      }
    }
    return salida;
  }

  @override
  bool shouldRepaint(_FlatBusPainter oldDelegate) =>
      oldDelegate.estado != estado || oldDelegate.selected != selected;
}

class _Attribution extends StatelessWidget {
  const _Attribution();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '© OpenStreetMap',
        style: AppType.ui(
          fontSize: 10,
          color: AppColors.textMuted,
        ),
      ),
    );
  }
}

/// La leyenda del mapa. Pública solo para probarla sin montar las teselas.
@visibleForTesting
class FleetLegend extends StatelessWidget {
  const FleetLegend({super.key, required this.conteo});

  /// Cuántos buses de la ruta hay en cada estado. Excluyentes: suman el total.
  final Map<BusEstado, int> conteo;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.softShadow,
      ),
      // `IntrinsicWidth` y filas estiradas para que las cuatro cifras caigan
      // una encima de otra. Con cada fila a su ancho, la cifra iba pegada
      // detrás del nombre, y como «En línea», «Sin señal» y «Oculto» miden
      // distinto, los números salían cada uno a una altura. Así la caja mide
      // lo que la fila más ancha y el `Spacer` de cada fila empuja su cifra
      // hasta el borde derecho.
      child: IntrinsicWidth(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'LEYENDA',
              style: AppType.ui(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.6,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 6),
            // Un renglón por estado, en el orden en que empeoran. El ícono es
            // el mismo que lleva el bus en la lista, así que la leyenda
            // también explica lo que se ve allá.
            for (final estado in BusEstado.values)
              _fila(estado, conteo[estado] ?? 0),
          ],
        ),
      ),
    );
  }

  Widget _fila(BusEstado estado, int cuantos) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        children: [
          Icon(
            estado.icono,
            size: 13,
            color: estado.color,
            semanticLabel: estado.rotulo,
          ),
          const SizedBox(width: 8),
          Text(
            estado.rotulo,
            style: AppType.ui(
              fontSize: 12,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          // Los 8 son el mínimo con el nombre más largo; en las otras filas
          // el `Spacer` se queda con lo que sobra.
          const SizedBox(width: 8),
          const Spacer(),
          Text(
            '$cuantos',
            style: AppType.ui(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
