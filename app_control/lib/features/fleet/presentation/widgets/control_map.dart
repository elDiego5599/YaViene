import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/fleet_bus.dart';
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
          child: _Legend(
            // La leyenda describe lo que se ve en el mapa: escopado a la ruta
            // seleccionada como las pestañas y los marcadores (antes contaba
            // toda la empresa y los números no coincidían con nada).
            online: fleet.buses.values
                .where((b) =>
                    _inRoute(fleet, b) && b.online && b.visible && !b.isGhost)
                .length,
            hidden: fleet.buses.values
                .where((b) => _inRoute(fleet, b) && !b.visible)
                .length,
            offline: fleet.buses.values
                .where((b) => _inRoute(fleet, b) && (!b.online || b.isGhost))
                .length,
          ),
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
        child: Transform.rotate(
          // Un bus del que nunca llegó rumbo se pinta sin girar.
          angle: (bus.heading ?? 0) * math.pi / 180,
          child: CustomPaint(
            size: Size.square(size),
            painter: _FlatBusPainter(
              active: bus.online && !bus.isGhost && bus.visible,
              selected: selected,
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
  alguien parado en el paradero. Ahora es la misma cápsula y la misma
  lectura: en color reporta, gris no. El color activo sí cambia respecto al
  pasajero —verde en vez de coral— porque el fondo es otro; el porqué está
  en `AppColors.busActive`.

  La diferencia con la app es de medio: allá el ícono se hornea una vez a
  PNG y MapLibre lo reusa como sprite; aquí se pinta en cada cuadro con
  CustomPaint, porque flutter_map trabaja con widgets y el tamaño cambia con
  el zoom. La geometría es la misma proporción 32:60 de la cápsula del
  pasajero, escalada al alto del marcador.
*/
class _FlatBusPainter extends CustomPainter {
  const _FlatBusPainter({required this.active, required this.selected});

  final bool active;
  final bool selected;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final h = size.height * 0.75;
    final w = h * 32 / 60;
    final baseColor = active ? AppColors.busActive : AppColors.busGhost;

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

    if (active) {
      canvas.drawShadow(
        ui.Path()..addRRect(capsule.shift(Offset(0, h * 0.05))),
        baseColor.withValues(alpha: 0.45),
        h * 0.12,
        false,
      );
    }

    // Degradado sutil (más claro arriba) para que no se vea una silueta plana.
    final top = active ? Color.lerp(baseColor, Colors.white, 0.3)! : baseColor;
    canvas.drawRRect(
      capsule,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(center.dx, center.dy - h / 2),
          Offset(center.dx, center.dy + h / 2),
          [top, baseColor],
        ),
    );

    // Anillo blanco: separa el ícono de cualquier fondo de mapa.
    canvas.drawRRect(
      capsule,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = (w * 0.08).clamp(1.2, 2.6)
        ..color = Colors.white.withValues(alpha: active ? 0.92 : 0.5),
    );

    if (active) {
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

  @override
  bool shouldRepaint(_FlatBusPainter oldDelegate) =>
      oldDelegate.active != active || oldDelegate.selected != selected;
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

class _Legend extends StatelessWidget {
  const _Legend({
    required this.online,
    required this.hidden,
    required this.offline,
  });

  final int online;
  final int hidden;
  final int offline;

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
      // `IntrinsicWidth` y filas estiradas para que las tres cifras caigan
      // una encima de otra. Con cada fila a su ancho, la cifra iba pegada
      // detrás del nombre, y como «En línea», «Sin señal» y «Ocultos» miden
      // distinto, los tres números salían cada uno a una altura. Así la
      // caja mide lo que la fila más ancha y el `Spacer` de cada fila
      // empuja su cifra hasta el borde derecho.
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
            // Los puntos son los colores del marcador, no los del estado en
            // la lista: esta caja explica lo que hay dibujado sobre el mapa.
            _legendRow(AppColors.busActive, 'En línea', online),
            _legendRow(AppColors.busGhost, 'Sin señal', offline),
            _legendRow(AppColors.hidden, 'Ocultos', hidden),
          ],
        ),
      ),
    );
  }

  Widget _legendRow(Color color, String label, int count) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 5),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: AppType.ui(
              fontSize: 12,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          // Los 8 son el mínimo con el nombre más largo; en las otras dos
          // filas el `Spacer` se queda con lo que sobra.
          const SizedBox(width: 8),
          const Spacer(),
          Text(
            '$count',
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
