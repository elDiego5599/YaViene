part of 'reportes_screen.dart';

/// El filtro de la hora del día de «Viajes»: las ocho franjas de tres horas
/// (hora de Bogotá) que el servidor sabe contar.
class _FiltroFranja extends StatelessWidget {
  const _FiltroFranja({required this.franja, required this.onSelect});

  final int? franja;
  final ValueChanged<int?> onSelect;

  @override
  Widget build(BuildContext context) => MenuAnchor(
    style: _estiloMenu,
    menuChildren: [
      MenuItemButton(
        key: const ValueKey('filtro-franja-todo'),
        onPressed: () => onSelect(null),
        style: _estiloOpcionMenu(selected: franja == null),
        child: const SizedBox(width: 180, child: Text('Todo el día')),
      ),
      for (var f = 0; f < 8; f++)
        MenuItemButton(
          key: ValueKey('filtro-franja-$f'),
          onPressed: () => onSelect(f),
          style: _estiloOpcionMenu(selected: franja == f),
          child: SizedBox(width: 180, child: Text(franjaLabel(f))),
        ),
    ],
    builder: (context, controller, child) => OutlinedButton.icon(
      key: const ValueKey('filtro-franja'),
      onPressed: () =>
          controller.isOpen ? controller.close() : controller.open(),
      icon: const Icon(Icons.schedule_outlined, size: 17),
      label: Text(franja == null ? 'Todo el día' : franjaLabel(franja!)),
      style: _estiloContorno(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      ),
    ),
  );
}

/// Los viajes buscados (D20): la lista de pares y su mapa de flujo. Con otro
/// filtro, lo de antes se queda atenuado mientras llega lo nuevo.
class _CuerpoViajes extends ConsumerStatefulWidget {
  const _CuerpoViajes({required this.periodo, required this.franja});

  final PeriodoReporte periodo;
  final int? franja;

  @override
  ConsumerState<_CuerpoViajes> createState() => _CuerpoViajesState();
}

class _CuerpoViajesState extends ConsumerState<_CuerpoViajes> {
  ReporteViajes? _previo;

  /// El par tocado en la lista: su línea se marca en el mapa.
  int? _marcado;

  @override
  void didUpdateWidget(_CuerpoViajes old) {
    super.didUpdateWidget(old);
    if (old.periodo != widget.periodo || old.franja != widget.franja) {
      _marcado = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final args = (periodo: widget.periodo, franja: widget.franja);
    var estado = ref.watch(viajesProvider(args));
    if (estado.valueOrNull case final reporte?) _previo = reporte;
    final cargando = estado.isLoading && !estado.hasValue && !estado.hasError;
    if (cargando && _previo != null) estado = AsyncData(_previo!);
    return _Fundido(
      estado: estado,
      child: estado.when(
        loading: () => _dosPaneles(
          izquierda: const _TarjetaViajes(
            child: CargaFantasma(
              semanticsLabel: 'Cargando viajes',
              child: _QuejasFantasma(),
            ),
          ),
          derecha: const _TarjetaFlujo(
            child: CargaFantasma(
              semanticsLabel: 'Cargando el mapa de viajes',
              child: _MapaFantasma(),
            ),
          ),
        ),
        error: (error, stack) => _Tarjeta(
          child: _EstadoReporte(
            icon: Icons.error_outline,
            message: 'No se pudieron cargar los viajes',
            action: _Reintentar(
              key: const ValueKey('reintentar-viajes'),
              onPressed: () => ref.invalidate(viajesProvider(args)),
            ),
          ),
        ),
        data: (reporte) => reporte.pares.isEmpty
            ? const _Tarjeta(
                child: _EstadoReporte(
                  icon: Icons.alt_route,
                  message: 'Aún no hay suficientes viajes para mostrar',
                ),
              )
            : AnimatedOpacity(
                opacity: cargando ? 0.5 : 1,
                duration: AppMotion.duracion(context, AppMotion.rapido),
                curve: AppMotion.curvaCambio,
                child: _dosPaneles(
                  izquierda: _TarjetaViajes(
                    reporte: reporte,
                    child: _ListaViajes(
                      reporte: reporte,
                      marcado: _marcado,
                      onMarcar: (i) =>
                          setState(() => _marcado = i == _marcado ? null : i),
                    ),
                  ),
                  derecha: _TarjetaFlujo(
                    child: _MapaViajes(reporte: reporte, marcado: _marcado),
                  ),
                ),
              ),
      ),
    );
  }
}

class _TarjetaViajes extends StatelessWidget {
  const _TarjetaViajes({required this.child, this.reporte});
  final Widget child;
  final ReporteViajes? reporte;

  @override
  Widget build(BuildContext context) {
    final total = reporte?.total ?? 0;
    return _Tarjeta(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 13),
            child: Row(
              children: [
                const Expanded(
                  child: Text('Viajes buscados', style: _tituloTarjeta),
                ),
                if (total > 0)
                  Text(
                    total == 1 ? '1 viaje' : '${_formatearTotal(total)} viajes',
                    style: AppType.ui(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(child: child),
          if (reporte != null) const _PieViajes(),
        ],
      ),
    );
  }
}

/// D20: lo que el panel no muestra, dicho siempre. Un trayecto con menos de
/// cinco personas en el día podría señalar a alguien; por eso no sale.
class _PieViajes extends StatelessWidget {
  const _PieViajes();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
    decoration: const BoxDecoration(
      color: AppColors.surfaceRaised,
      border: Border(top: BorderSide(color: AppColors.border)),
    ),
    child: Row(
      children: [
        const Icon(Icons.shield_outlined, color: AppColors.navy, size: 15),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Solo salen los trayectos que 5 o más personas buscaron el mismo día',
            style: AppType.ui(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
        ),
      ],
    ),
  );
}

class _ListaViajes extends StatelessWidget {
  const _ListaViajes({
    required this.reporte,
    required this.marcado,
    required this.onMarcar,
  });

  final ReporteViajes reporte;
  final int? marcado;
  final ValueChanged<int> onMarcar;

  @override
  Widget build(BuildContext context) {
    final mayor = reporte.pares.first.total;
    return ListView.separated(
      itemCount: reporte.pares.length,
      separatorBuilder: (context, i) =>
          const Divider(height: 1, indent: 20, endIndent: 20),
      itemBuilder: (context, i) {
        final par = reporte.pares[i];
        final (salida, llegada) = reporte.etiquetasDe(par);
        return _FilaViaje(
          key: ValueKey('viaje-par-$i'),
          salida: salida,
          llegada: llegada,
          total: par.total,
          fraccion: par.total / mayor,
          marcada: i == marcado,
          onTap: () => onMarcar(i),
        );
      },
    );
  }
}

class _FilaViaje extends StatelessWidget {
  const _FilaViaje({
    super.key,
    required this.salida,
    required this.llegada,
    required this.total,
    required this.fraccion,
    required this.marcada,
    required this.onTap,
  });

  final String salida;
  final String llegada;
  final int total;

  /// Lo que pesa frente al par mayor, de 0 a 1: la barra de abajo.
  final double fraccion;
  final bool marcada;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppMotion.duracion(context, AppMotion.rapido),
        curve: AppMotion.curvaCambio,
        color: marcada
            ? AppColors.selection.withValues(alpha: 0.07)
            : AppColors.surface.withValues(alpha: 0),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                _LetraZona(salida, marcada: marcada),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(
                    Icons.arrow_forward,
                    color: AppColors.textSecondary,
                    size: 16,
                  ),
                ),
                _LetraZona(llegada, marcada: marcada),
                const Spacer(),
                Text(
                  _formatearTotal(total),
                  style: AppType.ui(
                    color: AppColors.navy,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: Stack(
                children: [
                  Container(
                    height: 5,
                    color: AppColors.navy.withValues(alpha: 0.08),
                  ),
                  FractionallySizedBox(
                    widthFactor: fraccion,
                    child: AnimatedContainer(
                      duration: AppMotion.duracion(context, AppMotion.rapido),
                      curve: AppMotion.curvaCambio,
                      height: 5,
                      color: marcada ? AppColors.boton : AppColors.navy,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// La letra de una zona. Blanco sobre navy 12,6:1 y sobre el azul de botón
/// 7,1:1; una o dos letras caben en el círculo de 24.
class _LetraZona extends StatelessWidget {
  const _LetraZona(this.letra, {required this.marcada, this.lado = 24});

  final String letra;
  final bool marcada;
  final double lado;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: AppMotion.duracion(context, AppMotion.rapido),
    curve: AppMotion.curvaCambio,
    width: lado,
    height: lado,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: marcada ? AppColors.boton : AppColors.navy,
      shape: BoxShape.circle,
    ),
    child: Text(
      letra,
      style: AppType.ui(
        color: Colors.white,
        fontSize: letra.length > 1 ? 10 : 12,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

class _TarjetaFlujo extends StatelessWidget {
  const _TarjetaFlujo({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => _Tarjeta(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 16, 20, 13),
          child: Row(
            children: [
              Icon(Icons.alt_route, color: AppColors.navy, size: 19),
              SizedBox(width: 9),
              Text('De dónde a dónde', style: _tituloTarjeta),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(child: child),
      ],
    ),
  );
}

/// El flujo de viajes: una curva por par, del tono claro de la salida al
/// oscuro de la llegada, y más ancha cuanto más viajes. Las zonas llevan solo
/// su letra: el mapa no nombra sitios.
class _MapaViajes extends ConsumerStatefulWidget {
  const _MapaViajes({required this.reporte, required this.marcado});

  final ReporteViajes reporte;
  final int? marcado;

  @override
  ConsumerState<_MapaViajes> createState() => _MapaViajesState();
}

class _MapaViajesState extends ConsumerState<_MapaViajes> {
  final _controller = MapController();
  bool _mapReady = false;

  @override
  void didUpdateWidget(_MapaViajes old) {
    super.didUpdateWidget(old);
    if (!identical(old.reporte, widget.reporte)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _fitCamera();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _fitCamera() {
    if (!_mapReady || widget.reporte.zonas.isEmpty) return;
    final bounds = LatLngBounds.fromPoints([
      for (final z in widget.reporte.zonas) LatLng(z.lat, z.lng),
    ]);
    // Una zona sola (todo dentro de ella) deja el cuadro en un punto: el
    // margen de 0,01 grados (1,1 km) la centra con calles a la vista.
    const margin = 0.01;
    _controller.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds(
          LatLng(bounds.south - margin, bounds.west - margin),
          LatLng(bounds.north + margin, bounds.east + margin),
        ),
        padding: const EdgeInsets.all(52),
      ),
    );
  }

  static const _lado = 30.0;

  @override
  Widget build(BuildContext context) {
    final style = ref.watch(estiloMapaProvider).valueOrNull;
    final reporte = widget.reporte;
    final mayor = reporte.pares.first.total;
    final lineas = <Polyline>[];
    Polyline? marcada;
    for (final (i, par) in reporte.pares.indexed) {
      if (par.dentroDeLaZona) continue;
      final elegida = i == widget.marcado;
      // Blanco bajo azul de botón sobre el papel del mapa: las líneas se
      // leen por su filo, no por el tono.
      final tinta = elegida ? AppColors.navy : AppColors.boton;
      final linea = Polyline(
        points: _curva(par),
        strokeWidth:
            2.5 + 4.5 * math.sqrt(par.total / mayor) + (elegida ? 2 : 0),
        color: tinta,
        gradientColors: [
          tinta.withValues(alpha: elegida ? 0.45 : 0.22),
          tinta.withValues(alpha: elegida ? 1 : 0.85),
        ],
        borderStrokeWidth: 1.5,
        borderColor: Colors.white.withValues(alpha: 0.9),
        strokeCap: StrokeCap.round,
      );
      if (elegida) {
        marcada = linea;
      } else {
        lineas.add(linea);
      }
    }
    // La tocada va encima de las demás.
    if (marcada != null) lineas.add(marcada);
    final enMarcado = widget.marcado == null
        ? const <PuntoZona>{}
        : {
            reporte.pares[widget.marcado!].origen,
            reporte.pares[widget.marcado!].destino,
          };
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
            if (style != null) CapaVoyager(estilo: style),
            PolylineLayer(polylines: lineas),
            MarkerLayer(
              markers: [
                for (final z in reporte.zonas.reversed)
                  Marker(
                    point: LatLng(z.lat, z.lng),
                    width: _lado,
                    height: _lado,
                    child: DecoratedBox(
                      key: ValueKey('zona-${z.etiqueta}'),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: AppColors.sombraTarjeta,
                      ),
                      child: _LetraZona(
                        z.etiqueta,
                        lado: _lado - 4,
                        marcada: enMarcado.contains((lat: z.lat, lng: z.lng)),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
        const Positioned(right: 8, bottom: 5, child: _AtribucionMapa()),
      ],
    );
  }

  /// Un arco suave de origen a destino. El de ida y el de vuelta del mismo
  /// par se curvan hacia lados opuestos y no se montan.
  static List<LatLng> _curva(ParViaje par) {
    final (a, b) = (par.origen, par.destino);
    final dx = b.lng - a.lng;
    final dy = b.lat - a.lat;
    // Punto de control: a la mitad, empujado un 18 % del largo hacia la derecha.
    final cx = (a.lng + b.lng) / 2 + dy * 0.18;
    final cy = (a.lat + b.lat) / 2 - dx * 0.18;
    const pasos = 24;
    return [
      for (var i = 0; i <= pasos; i++)
        () {
          final t = i / pasos;
          final u = 1 - t;
          return LatLng(
            u * u * a.lat + 2 * u * t * cy + t * t * b.lat,
            u * u * a.lng + 2 * u * t * cx + t * t * b.lng,
          );
        }(),
    ];
  }
}
