import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart';
import 'package:ya_viene_core/core/providers/map_providers.dart';
import 'package:ya_viene_core/core/theme/estilo_ruta.dart';

import '../../../../core/theme/app_theme.dart';
import '../providers/reportes_provider.dart';
import '../widgets/control_map.dart' show ControlMap, estiloMapaProvider;

class ReportesScreen extends ConsumerStatefulWidget {
  const ReportesScreen({super.key});

  @override
  ConsumerState<ReportesScreen> createState() => _ReportesScreenState();
}

class _ReportesScreenState extends ConsumerState<ReportesScreen> {
  int? _hora;
  String? _ruta;

  @override
  Widget build(BuildContext context) {
    final reportes = ref.watch(reportesRutasProvider(_hora));
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Reportes'),
        backgroundColor: AppColors.surface,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 420,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Rutas más buscadas',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppColors.navy,
                          ),
                        ),
                      ),
                      DropdownButton<int?>(
                        key: const ValueKey('filtro-hora'),
                        value: _hora,
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('Todo el día'),
                          ),
                          for (var hour = 0; hour < 24; hour++)
                            DropdownMenuItem(
                              value: hour,
                              child: Text(horaOpcionLabel(hour)),
                            ),
                        ],
                        onChanged: (value) => setState(() {
                          _hora = value;
                          _ruta = null;
                        }),
                      ),
                    ],
                  ),
                  const Text('Últimos 30 días'),
                  const SizedBox(height: 14),
                  Expanded(
                    child: reportes.when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (error, stack) => Center(
                        child: _ErrorReporte(
                          onRetry: () =>
                              ref.invalidate(reportesRutasProvider(_hora)),
                        ),
                      ),
                      data: (rutas) {
                        if (rutas.isEmpty) {
                          return const Center(
                            child: Text(
                              'Aún no hay búsquedas en este periodo',
                              textAlign: TextAlign.center,
                            ),
                          );
                        }
                        final ordenadas = ordenarRutasBusquedas(rutas);
                        final maxTotal = rutas.fold<int>(
                          0,
                          (maximo, ruta) =>
                              ruta.total > maximo ? ruta.total : maximo,
                        );
                        return ListView(
                          children: [
                            for (final ruta in ordenadas)
                              _RutaReporteTile(
                                ruta: ruta,
                                maxTotal: maxTotal,
                                selected: _ruta == ruta.id,
                                onTap: () => setState(() => _ruta = ruta.id),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: _ruta == null
                  ? const Center(
                      child: Text(
                        'Elige una ruta para ver desde dónde la buscan',
                      ),
                    )
                  : _PanelCalor(routeId: _ruta!, hora: _hora),
            ),
          ],
        ),
      ),
    );
  }
}

class _RutaReporteTile extends StatelessWidget {
  const _RutaReporteTile({
    required this.ruta,
    required this.maxTotal,
    required this.selected,
    required this.onTap,
  });

  final RutaBusquedas ruta;
  final int maxTotal;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? AppColors.surfaceRaised : AppColors.surface,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    ruta.nombre,
                    style: const TextStyle(
                      color: AppColors.navy,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (ruta.horaPico != null)
                  Chip(label: Text(horaPicoLabel(ruta.horaPico!))),
              ],
            ),
            const SizedBox(height: 4),
            LinearProgressIndicator(
              value: maxTotal == 0 ? 0 : ruta.total / maxTotal,
              color: AppColors.online,
              backgroundColor: AppColors.border,
              minHeight: 6,
            ),
            const SizedBox(height: 4),
            Text('${ruta.total} búsquedas'),
          ],
        ),
      ),
    ),
  );
}

class _ErrorReporte extends StatelessWidget {
  const _ErrorReporte({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      const Icon(Icons.error_outline, color: AppColors.danger),
      const SizedBox(height: 8),
      const Text('No se pudieron cargar los reportes'),
      TextButton(onPressed: onRetry, child: const Text('Reintentar')),
    ],
  );
}

class _PanelCalor extends ConsumerWidget {
  const _PanelCalor({required this.routeId, required this.hora});
  final String routeId;
  final int? hora;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final heat = ref.watch(
      reportesCalorProvider((routeId: routeId, hora: hora)),
    );
    return heat.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: _ErrorReporte(
          onRetry: () => ref.invalidate(
            reportesCalorProvider((routeId: routeId, hora: hora)),
          ),
        ),
      ),
      data: (cells) => cells.isEmpty
          ? const Center(
              child: Text(
                'Aún no hay suficientes búsquedas con ubicación en esta ruta '
                'para mostrarlas. Se muestran zonas con al menos 5 búsquedas.',
                textAlign: TextAlign.center,
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Padding(
                  padding: EdgeInsets.only(bottom: 10),
                  child: Text(
                    'Desde dónde te buscan',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.navy,
                    ),
                  ),
                ),
                Expanded(
                  child: _MapaCalor(routeId: routeId, cells: cells),
                ),
              ],
            ),
    );
  }
}

class _MapaCalor extends ConsumerStatefulWidget {
  const _MapaCalor({required this.routeId, required this.cells});
  final String routeId;
  final List<CeldaBusqueda> cells;

  @override
  ConsumerState<_MapaCalor> createState() => _MapaCalorState();
}

class _MapaCalorState extends ConsumerState<_MapaCalor> {
  final _controller = MapController();
  List<LatLng> _routePoints = const [];
  bool _mapReady = false;

  @override
  void initState() {
    super.initState();
    _readRoute();
  }

  @override
  void didUpdateWidget(covariant _MapaCalor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.routeId != widget.routeId) _readRoute();
    if (oldWidget.cells != widget.cells ||
        oldWidget.routeId != widget.routeId) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitCamera());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _readRoute() async {
    try {
      // routeTrajectoryProvider lee rutas.json desde kRutasAsset, igual que
      // el mapa de flota; una ruta creada por la empresa puede no tener línea.
      final route = await ref.read(
        routeTrajectoryProvider(widget.routeId).future,
      );
      if (!mounted) return;
      setState(
        () => _routePoints = [
          for (final point in route.points) LatLng(point.lat, point.lon),
        ],
      );
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitCamera());
    } catch (_) {
      if (!mounted) return;
      setState(() => _routePoints = const []);
    }
  }

  void _fitCamera() {
    if (!_mapReady) return;
    final points = [
      ..._routePoints,
      for (final cell in widget.cells) LatLng(cell.lat, cell.lng),
    ];
    if (points.isEmpty) return;
    final bounds = LatLngBounds.fromPoints(points);
    const margen = 0.003;
    _controller.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds(
          LatLng(bounds.south - margen, bounds.west - margen),
          LatLng(bounds.north + margen, bounds.east + margen),
        ),
        padding: const EdgeInsets.all(56),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final style = ref.watch(estiloMapaProvider).valueOrNull;
    final maxCount = widget.cells
        .map((cell) => cell.count)
        .reduce((a, b) => a > b ? a : b);
    return Stack(
      children: [
        FlutterMap(
          mapController: _controller,
          options: MapOptions(
            initialCenter: const LatLng(10.9639, -74.7964),
            initialZoom: 12,
            backgroundColor: ControlMap.fondo,
            minZoom: ControlMap.zoomMinimo,
            maxZoom: ControlMap.zoomMaximo,
            cameraConstraint: CameraConstraint.containCenter(
              bounds: ControlMap.area,
            ),
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
            onMapReady: () {
              _mapReady = true;
              _fitCamera();
            },
          ),
          children: [
            if (style != null)
              VectorTileLayer(
                theme: style.theme,
                sprites: style.sprites,
                tileProviders: style.providers,
              ),
            if (_routePoints.length > 1)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: _routePoints,
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
                    points: _routePoints,
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
              ),
            CircleLayer(
              circles: [
                for (final cell in widget.cells)
                  CircleMarker(
                    point: LatLng(cell.lat, cell.lng),
                    radius: 9 + 20 * cell.count / maxCount,
                    color: Color.lerp(
                      AppColors.online.withValues(alpha: 0.32),
                      AppColors.online.withValues(alpha: 0.62),
                      cell.count / maxCount,
                    )!,
                    borderColor: Colors.white,
                    borderStrokeWidth: 1.5,
                  ),
              ],
            ),
          ],
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 16,
          child: _LeyendaCalor(maxCount: maxCount),
        ),
        Positioned(
          top: 12,
          right: 12,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.88),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              child: Text(
                '© CARTO © OpenStreetMap',
                style: TextStyle(fontSize: 10, color: AppColors.textMuted),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _LeyendaCalor extends StatelessWidget {
  const _LeyendaCalor({required this.maxCount});
  final int maxCount;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.md),
      boxShadow: AppColors.sombraTarjeta,
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Text('Menos búsquedas'),
              const Spacer(),
              Text('$maxCount en la zona'),
              const SizedBox(width: 12),
              const Text('Más búsquedas'),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            height: 8,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.all(Radius.circular(8)),
              gradient: LinearGradient(
                colors: [
                  AppColors.online.withValues(alpha: 0.24),
                  AppColors.online,
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
