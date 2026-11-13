part of 'reportes_screen.dart';

/// Lo que se mira en Reportes: desde dónde buscan la ruta (D17) o de qué se
/// quejan los pasajeros (D18).
enum _ModoReporte { busquedas, quejas }

class _FiltroMotivo extends StatelessWidget {
  const _FiltroMotivo({required this.motivo, required this.onSelect});

  final MotivoQueja? motivo;
  final ValueChanged<MotivoQueja?> onSelect;

  @override
  Widget build(BuildContext context) => MenuAnchor(
    style: _estiloMenu,
    menuChildren: [
      MenuItemButton(
        key: const ValueKey('filtro-motivo-todo'),
        onPressed: () => onSelect(null),
        style: _estiloOpcionMenu(selected: motivo == null),
        child: const SizedBox(width: 180, child: Text('Todos los motivos')),
      ),
      for (final opcion in MotivoQueja.values)
        MenuItemButton(
          key: ValueKey('filtro-motivo-${opcion.clave}'),
          onPressed: () => onSelect(opcion),
          style: _estiloOpcionMenu(selected: motivo == opcion),
          child: SizedBox(width: 180, child: Text(opcion.texto)),
        ),
    ],
    builder: (context, controller, child) => OutlinedButton.icon(
      key: const ValueKey('filtro-motivo'),
      onPressed: () =>
          controller.isOpen ? controller.close() : controller.open(),
      icon: const Icon(Icons.chat_bubble_outline, size: 16),
      label: Text(motivo?.texto ?? 'Todos los motivos'),
      style: _estiloContorno(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      ),
    ),
  );
}

/// La lista y el mapa de las quejas del filtro. Con otro filtro, lo de antes
/// se queda atenuado mientras llega lo nuevo, como el mapa de búsquedas.
class _CuerpoQuejas extends ConsumerStatefulWidget {
  const _CuerpoQuejas({
    required this.routeId,
    required this.periodo,
    required this.motivo,
  });

  final String? routeId;
  final PeriodoReporte periodo;
  final MotivoQueja? motivo;

  @override
  ConsumerState<_CuerpoQuejas> createState() => _CuerpoQuejasState();
}

class _CuerpoQuejasState extends ConsumerState<_CuerpoQuejas> {
  ReporteQuejas? _previo;

  /// La celda de la queja tocada en la lista: su burbuja se marca en el mapa.
  ({double lat, double lng})? _marcada;

  @override
  void didUpdateWidget(_CuerpoQuejas old) {
    super.didUpdateWidget(old);
    if (old.routeId != widget.routeId ||
        old.periodo != widget.periodo ||
        old.motivo != widget.motivo) {
      _marcada = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final args = (
      routeId: widget.routeId,
      periodo: widget.periodo,
      motivo: widget.motivo,
    );
    var estado = ref.watch(quejasProvider(args));
    if (estado.valueOrNull case final reporte?) _previo = reporte;
    final cargando = estado.isLoading && !estado.hasValue && !estado.hasError;
    if (cargando && _previo != null) estado = AsyncData(_previo!);
    return _Fundido(
      estado: estado,
      child: estado.when(
        loading: () => _dosPaneles(
          izquierda: const _TarjetaQuejas(
            child: CargaFantasma(
              semanticsLabel: 'Cargando quejas',
              child: _QuejasFantasma(),
            ),
          ),
          derecha: const _TarjetaLugares(
            child: CargaFantasma(
              semanticsLabel: 'Cargando el mapa de quejas',
              child: _MapaFantasma(),
            ),
          ),
        ),
        // Un solo error para los dos cuadros: es la misma carga.
        error: (error, stack) => _Tarjeta(
          child: _EstadoReporte(
            icon: Icons.error_outline,
            message: 'No se pudieron cargar las quejas',
            action: _Reintentar(
              key: const ValueKey('reintentar-quejas'),
              onPressed: () => ref.invalidate(quejasProvider(args)),
            ),
          ),
        ),
        data: (reporte) => AnimatedOpacity(
          opacity: cargando ? 0.5 : 1,
          duration: AppMotion.duracion(context, AppMotion.rapido),
          curve: AppMotion.curvaCambio,
          child: _dosPaneles(
            izquierda: _TarjetaQuejas(
              reporte: reporte,
              child: reporte.quejas.isEmpty
                  ? const _EstadoReporte(
                      icon: Icons.chat_bubble_outline,
                      message: 'Aún no hay quejas en este periodo',
                    )
                  : _ListaQuejas(
                      quejas: reporte.quejas,
                      marcada: _marcada,
                      onMarcar: (celda) => setState(
                        () => _marcada = celda == _marcada ? null : celda,
                      ),
                    ),
            ),
            derecha: _TarjetaLugares(
              child: reporte.celdas.isEmpty
                  ? const _EstadoReporte(
                      icon: Icons.place_outlined,
                      message: 'Ninguna queja trae lugar',
                    )
                  : _MapaQuejas(celdas: reporte.celdas, marcada: _marcada),
            ),
          ),
        ),
      ),
    );
  }
}

const _tituloTarjeta = TextStyle(
  color: AppColors.navy,
  fontSize: 17,
  fontWeight: FontWeight.w800,
);

class _TarjetaQuejas extends StatelessWidget {
  const _TarjetaQuejas({required this.child, this.reporte});
  final Widget child;
  final ReporteQuejas? reporte;

  @override
  Widget build(BuildContext context) {
    final total = reporte?.quejas.length ?? 0;
    return _Tarjeta(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 13),
            child: Row(
              children: [
                const Expanded(child: Text('Quejas', style: _tituloTarjeta)),
                if (total > 0)
                  Text(
                    // La lista trae hasta 500; el mapa las cuenta todas.
                    reporte!.alTope
                        ? 'Las ${_formatearTotal(total)} más recientes'
                        : total == 1
                        ? '1 queja'
                        : '${_formatearTotal(total)} quejas',
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
          if (total > 0) const _FranjaSinVerificar(),
          Expanded(child: child),
        ],
      ),
    );
  }
}

/// D18: la queja es lo que cuenta un pasajero sin cuenta. El panel lo dice
/// siempre que hay alguna a la vista, para que nadie la lea como un hecho.
class _FranjaSinVerificar extends StatelessWidget {
  const _FranjaSinVerificar();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
    decoration: const BoxDecoration(
      color: AppColors.surfaceRaised,
      border: Border(bottom: BorderSide(color: AppColors.border)),
    ),
    child: Row(
      children: [
        const Icon(Icons.info_outline, color: AppColors.navy, size: 15),
        const SizedBox(width: 8),
        Text(
          'Sin verificar',
          style: AppType.ui(
            color: AppColors.navy,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Lo cuenta el pasajero y nadie lo ha comprobado',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppType.ui(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}

class _ListaQuejas extends StatelessWidget {
  const _ListaQuejas({
    required this.quejas,
    required this.marcada,
    required this.onMarcar,
  });

  final List<QuejaPanel> quejas;
  final ({double lat, double lng})? marcada;
  final ValueChanged<({double lat, double lng})> onMarcar;

  @override
  Widget build(BuildContext context) => ListView.separated(
    itemCount: quejas.length,
    separatorBuilder: (context, i) =>
        const Divider(height: 1, indent: 20, endIndent: 20),
    itemBuilder: (context, i) {
      final queja = quejas[i];
      final celda = queja.celda;
      return _FilaQueja(
        key: ValueKey('queja-${queja.id}'),
        queja: queja,
        marcada: celda != null && celda == marcada,
        onTap: celda == null ? null : () => onMarcar(celda),
      );
    },
  );
}

class _FilaQueja extends StatelessWidget {
  const _FilaQueja({
    super.key,
    required this.queja,
    required this.marcada,
    required this.onTap,
  });

  final QuejaPanel queja;
  final bool marcada;

  /// Nulo si la queja no trae lugar: no hay burbuja que marcar.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ruta = queja.ruta;
    final (codigo, nombre) = ruta == null
        ? (queja.routeId, '')
        : _partirNombre(queja.routeId, ruta);
    final pie = AppType.ui(
      color: AppColors.textSecondary,
      fontSize: 12,
      fontWeight: FontWeight.w600,
    );
    return Material(
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _FichaMotivo(queja.motivo?.texto ?? MotivoQueja.otro.texto),
                  const Spacer(),
                  Text(
                    cuandoLabel(queja.cuando, conHora: queja.hora != null),
                    style: pie,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                queja.texto,
                style: AppType.ui(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _FichaCodigo(codigo),
                  if (nombre.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        nombre,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: pie,
                      ),
                    ),
                  ],
                  if (queja.busId case final bus?) ...[
                    const SizedBox(width: 14),
                    const Icon(
                      Icons.directions_bus_outlined,
                      color: AppColors.textSecondary,
                      size: 15,
                    ),
                    const SizedBox(width: 4),
                    Text(bus, style: pie),
                  ],
                  if (onTap != null) ...[
                    const SizedBox(width: 14),
                    Icon(
                      Icons.place_outlined,
                      color: marcada
                          ? AppColors.boton
                          : AppColors.textSecondary,
                      size: 15,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      'En el mapa',
                      style: marcada
                          ? pie.copyWith(color: AppColors.boton)
                          : pie,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FichaMotivo extends StatelessWidget {
  const _FichaMotivo(this.texto);
  final String texto;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: AppColors.navy.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(AppRadius.sm),
    ),
    child: Text(
      texto,
      style: AppType.ui(
        color: AppColors.navy,
        fontSize: 11.5,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

/// La forma de tres quejas sin datos, con el relleno de [_FilaQueja].
class _QuejasFantasma extends StatelessWidget {
  const _QuejasFantasma();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < 3; i++) ...const [
          _Bloque(ancho: 78, alto: 22),
          SizedBox(height: 10),
          _Bloque(alto: 13),
          SizedBox(height: 7),
          _Bloque(ancho: 220, alto: 13),
          SizedBox(height: 30),
        ],
      ],
    ),
  );
}

class _TarjetaLugares extends StatelessWidget {
  const _TarjetaLugares({required this.child});
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
              Icon(Icons.place_outlined, color: AppColors.navy, size: 19),
              SizedBox(width: 9),
              Text('Dónde pasó', style: _tituloTarjeta),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(child: child),
      ],
    ),
  );
}

/// Cuántas quejas hay en cada celda de 150 m (la rejilla de D17). Solo la
/// cuenta: ni placa ni bus, que en el mapa señalarían a una persona.
class _MapaQuejas extends ConsumerStatefulWidget {
  const _MapaQuejas({required this.celdas, required this.marcada});

  final List<CeldaQueja> celdas;
  final ({double lat, double lng})? marcada;

  @override
  ConsumerState<_MapaQuejas> createState() => _MapaQuejasState();
}

class _MapaQuejasState extends ConsumerState<_MapaQuejas> {
  final _controller = MapController();
  bool _mapReady = false;

  @override
  void didUpdateWidget(_MapaQuejas old) {
    super.didUpdateWidget(old);
    if (!identical(old.celdas, widget.celdas)) {
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
    if (!_mapReady || widget.celdas.isEmpty) return;
    final bounds = LatLngBounds.fromPoints([
      for (final celda in widget.celdas) LatLng(celda.lat, celda.lng),
    ]);
    const margin = 0.003;
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

  @override
  Widget build(BuildContext context) {
    final style = ref.watch(estiloMapaProvider).valueOrNull;
    // Vienen de más a menos: la primera es la mayor.
    final mayor = widget.celdas.first.total;
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
            MarkerLayer(
              markers: [
                // Al revés: la mayor se pinta encima de las que tapa.
                for (var i = widget.celdas.length - 1; i >= 0; i--)
                  Marker(
                    point: LatLng(widget.celdas[i].lat, widget.celdas[i].lng),
                    width: _Burbuja.lado,
                    height: _Burbuja.lado,
                    child: _Burbuja(
                      key: ValueKey('burbuja-queja-$i'),
                      total: widget.celdas[i].total,
                      mayor: mayor,
                      marcada:
                          widget.marcada?.lat == widget.celdas[i].lat &&
                          widget.marcada?.lng == widget.celdas[i].lng,
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
}

class _Burbuja extends StatelessWidget {
  const _Burbuja({
    super.key,
    required this.total,
    required this.mayor,
    required this.marcada,
  });

  final int total;
  final int mayor;
  final bool marcada;

  /// El cuadro del marcador: la burbuja mayor (48) más lo que crece marcada.
  static const lado = 60.0;

  @override
  Widget build(BuildContext context) {
    // De 28 a 48: el área, no el diámetro, sigue a la cuenta.
    final diametro = 28 + 20 * math.sqrt(total / mayor);
    return Center(
      child: AnimatedScale(
        scale: marcada ? 1.2 : 1,
        duration: AppMotion.duracion(context, AppMotion.normal),
        curve: AppMotion.curvaRebote,
        child: AnimatedContainer(
          duration: AppMotion.duracion(context, AppMotion.rapido),
          curve: AppMotion.curvaCambio,
          width: diametro,
          height: diametro,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            // Blanco sobre navy 12,6:1 y sobre el azul de botón 7,1:1.
            color: marcada ? AppColors.boton : AppColors.navy,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: AppColors.sombraTarjeta,
          ),
          child: Text(
            _formatearTotal(total),
            style: AppType.ui(
              color: Colors.white,
              fontSize: total > 999 ? 10 : 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}
