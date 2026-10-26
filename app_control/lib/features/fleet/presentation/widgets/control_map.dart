import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart';
import 'package:ya_viene_core/core/models/bus_motion.dart';
import 'package:ya_viene_core/core/providers/map_providers.dart';
import 'package:ya_viene_core/core/theme/app_motion.dart';
import 'package:ya_viene_core/core/theme/estilo_mapa.dart';
import 'package:ya_viene_core/core/theme/estilo_ruta.dart';
import 'package:ya_viene_core/shared/widgets/indicador_carga.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/fleet_bus.dart';
import '../bus_estado.dart';
import '../providers/fleet_providers.dart';

/// El estilo del mapa, el mismo del pasajero ([kEstiloMapa]): se lee una
/// vez por sesión —el JSON, la lista de teselas y los íconos de las
/// ciudades— y las teselas se piden después, según la cámara.
final estiloMapaProvider = FutureProvider<Style>(
  (ref) => StyleReader(uri: kEstiloMapa).read(),
);

class ControlMap extends ConsumerStatefulWidget {
  const ControlMap({super.key});

  /// Hasta dónde se deja llevar el centro del mapa: un cuadrado de 60 km de
  /// lado sobre el mismo centro que el del pasajero (10.977, -74.8143).
  ///
  /// Antes no había límite: se alejaba hasta el planeta entero y se
  /// arrastraba hasta Bogotá, y cada gesto bajaba teselas de sitios donde no
  /// anda un solo bus. El pasajero tiene 41 km; aquí va más holgado porque
  /// el operador mira la flota entera y un bus que se sale de su ruta —hacia
  /// Puerto Colombia, Tubará o Sabanagrande— tiene que seguir a la vista.
  ///
  /// Medio lado de 30 km: 30 / 110.574 = 0.2713° de latitud, y
  /// 30 / (111.320 · cos 10.977°) = 30 / 109.28 = 0.2745° de longitud.
  /// test/control_map_area_test.dart comprueba que sale cuadrado en km.
  static final area = LatLngBounds(
    const LatLng(10.7057, -75.0888),
    const LatLng(11.2483, -74.5398),
  );

  /// A zoom 11 una ventana de 1200 pt abarca unos 90 km: el área entera
  /// cabe con margen. Más lejos solo se ven pueblos sin buses (el pasajero,
  /// en un teléfono, para en 11.4).
  static const double zoomMinimo = 11;

  /// Igual que el pasajero. CARTO da teselas hasta 14; de ahí en adelante
  /// se agrandan los mismos vectores, sin pixelarse.
  static const double zoomMaximo = 18.5;

  /// Si el estilo no llegó (el panel abrió sin red, o CARTO tardó), se
  /// vuelve a pedir a los 10 s. Sin esto el mapa se quedaba en blanco
  /// hasta reiniciar el panel, aunque la red ya hubiera vuelto.
  static const Duration reintentoEstilo = Duration(seconds: 10);

  /// El fondo de Voyager (su capa `background`, #fbf8f3): es lo que se ve
  /// mientras llegan el estilo y las teselas, en vez del gris de
  /// flutter_map, que hacía parecer roto el mapa por un segundo.
  static const Color fondo = Color(0xFFFBF8F3);

  @override
  ConsumerState<ControlMap> createState() => _ControlMapState();
}

class _ControlMapState extends ConsumerState<ControlMap>
    with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();
  double _zoom = 12;
  Timer? _reintento;

  // El bus se desliza de una fijación GPS a la siguiente con el mismo tramo
  // de 1 s del pasajero (`BusMotion`), en vez de saltar en cada paquete
  // (dueño, 2026-10-07). El reloj es el del ticker, que solo corre mientras
  // queda algún tramo; al arrancar de nuevo vuelve a cero, y para entonces
  // los tramos viejos ya terminaron.
  // Se crea con el primer tramo: un panel sin buses en marcha no lo pide.
  Ticker? _reloj;
  Duration _transcurrido = Duration.zero;
  final Map<String, BusMotion> _tramos = {};
  static final _epoca = DateTime.utc(2000);
  DateTime get _ahora => _epoca.add(_transcurrido);

  // El marcador crece con el zoom, pero arranca más grande que antes (16 pt):
  // a zoom 12, que es como abre el panel, un bus medía 20 pt de lado y la
  // cápsula dentro apenas 15 — un grano de arroz sobre la ciudad entera.
  // El tope sube a 44 para que al acercarse se lea de quién es el bus sin
  // que el icono tape la manzana.
  double get _markerSize => (26 + (_zoom - 11) * 5).clamp(26.0, 44.0);

  @override
  void dispose() {
    _reloj?.dispose();
    _reintento?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  void _alTic(Duration transcurrido) {
    _transcurrido = transcurrido;
    final ahora = _ahora;
    _tramos.removeWhere((_, m) => m.isFinished(ahora));
    if (_tramos.isEmpty) _reloj!.stop();
    setState(() {});
  }

  /// Un tramo por cada bus que cambió de sitio, desde donde se ve ahora (a
  /// medio tramo, si iba en uno) para que no retroceda ni salte. Con
  /// movimiento reducido no hay tramo: el bus aparece en su nuevo punto.
  void _alMoverse(FleetState? antes, FleetState ahora) {
    if (antes == null || AppMotion.reducido(context)) return;
    final reloj = _reloj ??= createTicker(_alTic);
    if (!reloj.isActive) {
      _tramos.clear();
      _transcurrido = Duration.zero;
    }
    final momento = _ahora;
    for (final bus in ahora.buses.values) {
      final previo = antes.buses[bus.busId];
      if (bus.lat == null || bus.lon == null) {
        _tramos.remove(bus.busId);
        continue;
      }
      if (previo?.lat == null || previo?.lon == null) continue;
      if (previo!.lat == bus.lat && previo.lon == bus.lon) continue;
      final tramo = _tramos[bus.busId];
      final desde = tramo != null && !tramo.isFinished(momento)
          ? displayOf(tramo, momento)
          : (previo.lat!, previo.lon!, previo.heading ?? bus.heading ?? 0.0);
      _tramos[bus.busId] = BusMotion(
        fromLat: desde.$1,
        fromLon: desde.$2,
        fromHeading: desde.$3,
        toLat: bus.lat!,
        toLon: bus.lon!,
        // Sin rumbo conocido, el bus avanza sin girar.
        toHeading: bus.heading ?? desde.$3,
        start: momento,
        duration: BusMotion.tramoEntre(previo.capturedAt, bus.capturedAt),
      );
    }
    if (_tramos.isNotEmpty && !reloj.isActive) reloj.start();
  }

  static bool _inRoute(FleetState fleet, FleetBus bus) =>
      fleet.routeFilter == null || bus.routeId == fleet.routeFilter;

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<Style>>(estiloMapaProvider, (_, estado) {
      if (!estado.hasError || estado.isLoading) return;
      _reintento?.cancel();
      _reintento = Timer(ControlMap.reintentoEstilo, () {
        if (mounted) ref.invalidate(estiloMapaProvider);
      });
    });
    ref.listen<FleetState>(fleetProvider, _alMoverse);
    final estadoEstilo = ref.watch(estiloMapaProvider);
    final estilo = estadoEstilo.valueOrNull;
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
    final rutasDibujar = {
      if (fleet.routeFilter != null) fleet.routeFilter!,
      if (fleet.selectedBusId != null &&
          fleet.buses[fleet.selectedBusId]?.routeId != null)
        fleet.buses[fleet.selectedBusId]!.routeId!,
    };
    final recorridos = [
      for (final ruta in rutasDibujar)
        (
          routeId: ruta,
          points: [
            for (final p
                in ref
                        .watch(routeTrajectoryProvider(ruta))
                        .valueOrNull
                        ?.points ??
                    const [])
              LatLng(p.lat, p.lon),
          ],
        ),
    ];
    final terminales = [
      for (final recorrido in recorridos)
        if (recorrido.points.length > 1)
          Marker(
            point: recorrido.points.first,
            width: 92,
            height: 54,
            alignment: Alignment.bottomCenter,
            child: _TerminalMarker(
              key: ValueKey('terminal:${recorrido.routeId}'),
            ),
          ),
    ];

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
        // El lector de pantalla anuncia el mapa por su nombre; los buses de
        // adentro dicen su placa y su estado.
        Semantics(
          label: 'Mapa de la flota',
          child: FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: const LatLng(10.9639, -74.7964),
              initialZoom: 12,
              backgroundColor: ControlMap.fondo,
              minZoom: ControlMap.zoomMinimo,
              maxZoom: ControlMap.zoomMaximo,
              // Se limita el centro y no la vista entera: con `contain`, una
              // ventana más ancha que el área no tendría cámara válida y el
              // mapa se quedaría quieto. Así el borde puede asomar fuera del
              // cuadrado, pero la cámara siempre vuelve a la ciudad.
              cameraConstraint: CameraConstraint.containCenter(
                bounds: ControlMap.area,
              ),
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
              // El mismo mapa del pasajero: Voyager de CARTO, en vectores.
              // Antes iban las teselas de OpenStreetMap, porque CARTO solo da
              // sus rasterizadas —las que flutter_map pinta solo— con «API
              // KEY REQUIRED» atravesado; las vectoriales siguen limpias y
              // `vector_map_tiles` las pinta en escritorio (dueño,
              // 2026-09-30; test/control_map_estilo_test.dart).
              if (estilo != null)
                VectorTileLayer(
                  theme: estilo.theme,
                  sprites: estilo.sprites,
                  tileProviders: estilo.providers,
                ),
              // El recorrido de la ruta elegida, debajo de los buses y con
              // la definición compartida (`EstiloRuta` en ya_viene_core):
              // rojo de los buses activos sobre orla blanca, variante propia
              // del panel; el pasajero conserva la línea verde.
              // Una ruta sin recorrido en `rutas.json` (dada de alta aquí)
              // no pinta nada (dueño, 2026-10-07).
              if (recorridos.any((r) => r.points.length > 1))
                PolylineLayer(
                  polylines: [
                    for (final recorrido in recorridos.where(
                      (r) => r.points.length > 1,
                    )) ...[
                      Polyline(
                        points: recorrido.points,
                        color: Color(
                          int.parse(
                            EstiloRuta.orla.lineColor.replaceFirst('#', '0xFF'),
                          ),
                        ).withValues(alpha: EstiloRuta.orla.lineOpacity),
                        strokeWidth: EstiloRuta.orla.lineWidth,
                        strokeCap: StrokeCap.round,
                        strokeJoin: StrokeJoin.round,
                      ),
                      Polyline(
                        points: recorrido.points,
                        color: Color(
                          int.parse(
                            EstiloRuta.lineaPanel.lineColor.replaceFirst(
                              '#',
                              '0xFF',
                            ),
                          ),
                        ),
                        strokeWidth: EstiloRuta.lineaPanel.lineWidth,
                        strokeCap: StrokeCap.round,
                        strokeJoin: StrokeJoin.round,
                      ),
                    ],
                  ],
                ),
              MarkerLayer(markers: [...markers, ...terminales]),
            ],
          ),
        ),
        // Mientras llega el estilo solo se ve el fondo: la píldora dice que
        // el mapa viene, y se funde al llegar.
        Positioned(
          top: 16,
          left: 0,
          right: 0,
          child: Center(
            child: AnimatedSwitcher(
              duration: AppMotion.duracion(context, AppMotion.normal),
              switchInCurve: AppMotion.curvaEntrada,
              switchOutCurve: AppMotion.curvaSalida,
              child: estadoEstilo.isLoading && estilo == null
                  ? const _CargandoMapa()
                  : const SizedBox.shrink(),
            ),
          ),
        ),
        // CARTO y OpenStreetMap piden el crédito a la vista. Va discreto, en
        // la esquina contraria a la leyenda.
        const Positioned(right: 8, bottom: 4, child: _Attribution()),
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
    final tramo = _tramos[bus.busId];
    final (lat, lon, rumbo) = tramo != null
        ? displayOf(tramo, _ahora)
        // Un bus del que nunca llegó rumbo se pinta sin girar.
        : (bus.lat!, bus.lon!, bus.heading ?? 0.0);
    return Marker(
      point: LatLng(lat, lon),
      width: size,
      height: size,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Semantics(
          label:
              '${bus.placa.isEmpty ? bus.busId : bus.placa}: '
              '${BusEstado.de(bus).rotulo}',
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Opacity(
                opacity: bus.enTerminal ? 0.62 : 1,
                child: Transform.rotate(
                  angle: rumbo * math.pi / 180,
                  child: CustomPaint(
                    size: Size.square(size),
                    painter: _FlatBusPainter(
                      estado: BusEstado.de(bus),
                      selected: selected,
                    ),
                  ),
                ),
              ),
              if (bus.enTerminal)
                Positioned(
                  right: -2,
                  top: -2,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.navy,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.all(2),
                      child: Icon(
                        Icons.warehouse_outlined,
                        size: 11,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Terminal fijo del recorrido, anclado al primer punto de `rutas.json`.
class _TerminalMarker extends StatelessWidget {
  const _TerminalMarker({super.key});

  @override
  Widget build(BuildContext context) {
    final colorRuta = Color(
      int.parse(EstiloRuta.lineaPanel.lineColor.replaceFirst('#', '0xFF')),
    );
    return IgnorePointer(
      child: Semantics(
        label: 'Terminal',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: colorRuta, width: 2),
                boxShadow: AppColors.sombraFlotante,
              ),
              child: SizedBox(
                width: 28,
                height: 28,
                child: Icon(
                  Icons.warehouse_outlined,
                  size: 16,
                  color: colorRuta,
                ),
              ),
            ),
            const SizedBox(height: 2),
            DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(5),
                border: Border.all(color: AppColors.border),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                // WCAG 2.1 AA: navy #17325F sobre blanco = 12,67:1; el texto
                // pequeño supera 4,5:1. Coral #E86A5E sobre blanco = 3,16:1
                // para el ícono no textual (mínimo 3:1).
                child: Text(
                  'Terminal',
                  style: AppType.ui(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.navy,
                  ),
                ),
              ),
            ),
          ],
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
  bool get _lleno =>
      estado == BusEstado.enLinea || estado == BusEstado.inactivo;

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
      // La misma sombra de contacto del pasajero (`map_markers.dart`): gris
      // y centrada. El marcador gira con el rumbo, y la de antes —del color
      // del estado y corrida hacia abajo del dibujo— quedaba detrás del bus
      // como una estela (dueño, 2026-09-30). El desenfoque es h × 0,04,
      // la misma proporción que 2,4 sobre los 60 de la cápsula de allá.
      canvas.drawRRect(
        capsule,
        Paint()
          ..color = Colors.black.withValues(alpha: 0.24)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, h * 0.04),
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
        '© CARTO © OpenStreetMap',
        style: AppType.ui(fontSize: 10, color: AppColors.textMuted),
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
        boxShadow: AppColors.sombraFlotante,
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

/// «Cargando el mapa» con los tres puntos de la marca, en una píldora blanca
/// que flota sobre el fondo de Voyager como la leyenda.
class _CargandoMapa extends StatelessWidget {
  const _CargandoMapa();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(12, 7, 14, 7),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      boxShadow: AppColors.sombraFlotante,
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const IndicadorCarga(size: 16),
        const SizedBox(width: 8),
        Text(
          'Cargando el mapa',
          style: AppType.ui(
            color: AppColors.navy,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}
