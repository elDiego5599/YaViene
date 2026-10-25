import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart';
import 'package:ya_viene_core/core/providers/map_providers.dart';
import 'package:ya_viene_core/core/theme/estilo_ruta.dart';
import 'package:ya_viene_core/ya_viene_core.dart' show AppMotion;

import '../../../../core/theme/app_theme.dart';
import '../providers/reportes_provider.dart';
import '../widgets/control_map.dart' show ControlMap, estiloMapaProvider;

// La escala del video: verde donde casi no buscan, amarillo, naranja y el
// rojo de los focos. Es continua: un foco pasa por todos los tonos hasta
// su borde verde, como un mapa de calor de verdad.
const _coloresCalor = [
  Color(0xFF7CC04A),
  Color(0xFFF4C430),
  Color(0xFFF28B2C),
  Color(0xFFE24B4A),
];

// #A65A00 tiene contraste 5.14:1 sobre blanco, superior al mínimo AA de 4.5:1.
const _ambarTexto = Color(0xFFA65A00);

class ReportesScreen extends ConsumerStatefulWidget {
  const ReportesScreen({super.key});

  @override
  ConsumerState<ReportesScreen> createState() => _ReportesScreenState();
}

class _ReportesScreenState extends ConsumerState<ReportesScreen> {
  int? _hora;
  String? _ruta;

  void _seleccionarHora(int? hora) {
    setState(() {
      _hora = hora;
      _ruta = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final reportes = ref.watch(reportesRutasProvider(_hora));
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            _CabeceraReportes(
              hora: _hora,
              onBack: () => Navigator.of(context).maybePop(),
              onSelectHour: _seleccionarHora,
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: reportes.when(
                  loading: () => _dosPaneles(
                    izquierda: const _TarjetaRanking(
                      child: _EstadoReporte(
                        icon: Icons.query_stats_outlined,
                        message: 'Cargando reportes',
                      ),
                    ),
                    derecha: const _TarjetaMapaEstado(
                      child: _EstadoReporte(
                        icon: Icons.map_outlined,
                        message: 'Cargando reportes',
                      ),
                    ),
                  ),
                  error: (error, stack) => _dosPaneles(
                    izquierda: _TarjetaRanking(
                      child: _EstadoReporte(
                        icon: Icons.error_outline,
                        message: 'No se pudieron cargar los reportes',
                        action: _Reintentar(
                          key: const ValueKey('reintentar-lista'),
                          onPressed: () =>
                              ref.invalidate(reportesRutasProvider(_hora)),
                        ),
                      ),
                    ),
                    derecha: const _TarjetaMapaEstado(
                      child: _EstadoReporte(
                        icon: Icons.map_outlined,
                        message: 'Elige una ruta para ver el mapa',
                      ),
                    ),
                  ),
                  data: _mostrarRutas,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mostrarRutas(List<RutaBusquedas> rutas) {
    final ordenadas = ordenarRutasBusquedas(rutas);
    if (ordenadas.isEmpty) {
      return _dosPaneles(
        izquierda: const _TarjetaRanking(
          child: _EstadoReporte(
            icon: Icons.search_off_outlined,
            message: 'Aún no hay búsquedas en este periodo',
          ),
        ),
        derecha: const _TarjetaMapaEstado(
          child: _EstadoReporte(
            icon: Icons.map_outlined,
            message: 'El mapa aparecerá cuando haya rutas con búsquedas',
          ),
        ),
      );
    }

    final rutaSeleccionada = ordenadas.firstWhere(
      (ruta) => ruta.id == _ruta,
      orElse: () => ordenadas.first,
    );
    final maxTotal = ordenadas.fold<int>(
      0,
      (maximo, ruta) => ruta.total > maximo ? ruta.total : maximo,
    );

    return _dosPaneles(
      izquierda: _TarjetaRanking(
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(12, 2, 12, 12),
          itemCount: ordenadas.length,
          separatorBuilder: (context, index) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final ruta = ordenadas[index];
            return _FilaRuta(
              puesto: index + 1,
              ruta: ruta,
              maxTotal: maxTotal,
              selected: ruta.id == rutaSeleccionada.id,
              onTap: () => setState(() => _ruta = ruta.id),
            );
          },
        ),
      ),
      derecha: _TarjetaMapa(route: rutaSeleccionada, hora: _hora),
    );
  }
}

Widget _dosPaneles({required Widget izquierda, required Widget derecha}) => Row(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: [
    Expanded(flex: 5, child: izquierda),
    const SizedBox(width: 18),
    Expanded(flex: 7, child: derecha),
  ],
);

class _CabeceraReportes extends StatelessWidget {
  const _CabeceraReportes({
    required this.hora,
    required this.onBack,
    required this.onSelectHour,
  });

  final int? hora;
  final VoidCallback onBack;
  final ValueChanged<int?> onSelectHour;

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      color: AppColors.surface,
      boxShadow: AppColors.sombraCabecera,
    ),
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    child: Row(
      children: [
        OutlinedButton.icon(
          key: const ValueKey('volver-reportes'),
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back, size: 17),
          label: const Text('Volver'),
          style: _estiloContorno(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
        const SizedBox(width: 18),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Reportes',
              style: TextStyle(
                color: AppColors.navy,
                fontSize: 21,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 2),
            Text(
              'Últimos 30 días',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          ],
        ),
        const Spacer(),
        _FiltroHora(hora: hora, onSelectHour: onSelectHour),
      ],
    ),
  );
}

class _FiltroHora extends StatelessWidget {
  const _FiltroHora({required this.hora, required this.onSelectHour});

  final int? hora;
  final ValueChanged<int?> onSelectHour;

  @override
  Widget build(BuildContext context) => MenuAnchor(
    style: MenuStyle(
      backgroundColor: const WidgetStatePropertyAll(AppColors.surface),
      surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
      shadowColor: const WidgetStatePropertyAll(Color(0x2414274E)),
      elevation: const WidgetStatePropertyAll(8),
      padding: const WidgetStatePropertyAll(EdgeInsets.all(6)),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
    ),
    menuChildren: [
      MenuItemButton(
        key: const ValueKey('filtro-hora-todo'),
        onPressed: () => onSelectHour(null),
        style: _estiloOpcionMenu(selected: hora == null),
        child: const SizedBox(width: 180, child: Text('Todo el día')),
      ),
      for (var value = 0; value < 24; value++)
        MenuItemButton(
          key: ValueKey('filtro-hora-$value'),
          onPressed: () => onSelectHour(value),
          style: _estiloOpcionMenu(selected: hora == value),
          child: SizedBox(width: 180, child: Text(horaOpcionLabel(value))),
        ),
    ],
    builder: (context, controller, child) => OutlinedButton.icon(
      key: const ValueKey('filtro-hora'),
      onPressed: () =>
          controller.isOpen ? controller.close() : controller.open(),
      icon: const Icon(Icons.schedule_outlined, size: 17),
      label: Text(hora == null ? 'Todo el día' : horaOpcionLabel(hora!)),
      style: _estiloContorno(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      ),
    ),
  );
}

ButtonStyle _estiloContorno({required EdgeInsetsGeometry padding}) =>
    OutlinedButton.styleFrom(
      foregroundColor: AppColors.navy,
      side: const BorderSide(color: AppColors.borderStrong),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      padding: padding,
      textStyle: AppType.ui(fontSize: 12, fontWeight: FontWeight.w700),
    );

ButtonStyle _estiloOpcionMenu({required bool selected}) => ButtonStyle(
  foregroundColor: const WidgetStatePropertyAll(AppColors.navy),
  backgroundColor: WidgetStateProperty.resolveWith((states) {
    if (selected || states.contains(WidgetState.hovered)) {
      return Color.alphaBlend(
        AppColors.selection.withValues(alpha: 0.07),
        AppColors.surface,
      );
    }
    return AppColors.surface;
  }),
  textStyle: WidgetStatePropertyAll(
    AppType.ui(fontSize: 12.5, fontWeight: FontWeight.w600),
  ),
  padding: const WidgetStatePropertyAll(
    EdgeInsets.symmetric(horizontal: 12, vertical: 9),
  ),
  shape: WidgetStatePropertyAll(
    RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
  ),
);

class _TarjetaRanking extends StatelessWidget {
  const _TarjetaRanking({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => _Tarjeta(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Rutas más buscadas',
                  style: TextStyle(
                    color: AppColors.navy,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                'Hora pico',
                style: AppType.ui(
                  color: AppColors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(child: child),
      ],
    ),
  );
}

class _TarjetaMapaEstado extends StatelessWidget {
  const _TarjetaMapaEstado({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => _Tarjeta(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 18, 20, 14),
          child: Text(
            'Desde dónde te buscan',
            style: TextStyle(
              color: AppColors.navy,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const Divider(height: 1),
        Expanded(child: child),
      ],
    ),
  );
}

class _TarjetaMapa extends ConsumerWidget {
  const _TarjetaMapa({required this.route, required this.hora});

  final RutaBusquedas route;
  final int? hora;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final heat = ref.watch(
      reportesCalorProvider((routeId: route.id, hora: hora)),
    );
    final (_, nombre) = _partirNombreRuta(route);
    return _Tarjeta(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 13),
            child: Row(
              children: [
                const Icon(
                  Icons.place_outlined,
                  color: AppColors.navy,
                  size: 19,
                ),
                const SizedBox(width: 9),
                const Text(
                  'Desde dónde te buscan',
                  style: TextStyle(
                    color: AppColors.navy,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    nombre,
                    key: ValueKey('ruta-mapa-${route.id}'),
                    textAlign: TextAlign.right,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.ui(
                      color: AppColors.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: heat.when(
              loading: () => const _EstadoReporte(
                icon: Icons.location_searching_outlined,
                message: 'Cargando zonas de búsqueda',
              ),
              error: (error, stack) => _EstadoReporte(
                icon: Icons.error_outline,
                message: 'No se pudieron cargar los reportes',
                action: _Reintentar(
                  key: const ValueKey('reintentar-calor'),
                  onPressed: () => ref.invalidate(
                    reportesCalorProvider((routeId: route.id, hora: hora)),
                  ),
                ),
              ),
              data: (cells) => cells.isEmpty
                  ? const _EstadoReporte(
                      icon: Icons.location_off_outlined,
                      message:
                          'Aún no hay suficientes búsquedas con ubicación en esta ruta para mostrarlas. Se muestran zonas con al menos 5 búsquedas.',
                    )
                  : _MapaCalor(routeId: route.id, hora: hora, cells: cells),
            ),
          ),
        ],
      ),
    );
  }
}

class _Tarjeta extends StatelessWidget {
  const _Tarjeta({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.card),
      border: Border.all(color: AppColors.border),
      boxShadow: AppColors.sombraTarjeta,
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: child,
    ),
  );
}

class _FilaRuta extends StatefulWidget {
  const _FilaRuta({
    required this.puesto,
    required this.ruta,
    required this.maxTotal,
    required this.selected,
    required this.onTap,
  });

  final int puesto;
  final RutaBusquedas ruta;
  final int maxTotal;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_FilaRuta> createState() => _FilaRutaState();
}

class _FilaRutaState extends State<_FilaRuta> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final (codigo, nombre) = _partirNombreRuta(widget.ruta);
    final maxHora = widget.ruta.porHora.fold<int>(
      0,
      (maximo, valor) => valor > maximo ? valor : maximo,
    );
    final horaPico = widget.ruta.total == 0 ? null : widget.ruta.horaPico;
    final etiquetaHora = horaPico == null ? null : horaPicoLabel(horaPico);
    final etiquetaSemantica = [
      'Puesto ${widget.puesto}',
      'ruta $codigo $nombre',
      '${_formatearTotal(widget.ruta.total)} búsquedas',
      if (etiquetaHora != null) 'hora pico $etiquetaHora',
    ].join(', ');

    return FocusableActionDetector(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
      },
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            widget.onTap();
            return null;
          },
        ),
      },
      onShowHoverHighlight: (value) => setState(() => _hovered = value),
      onShowFocusHighlight: (value) => setState(() => _focused = value),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: Semantics(
            key: ValueKey('fila-ruta-${widget.ruta.id}'),
            label: etiquetaSemantica,
            button: true,
            selected: widget.selected,
            onTap: widget.onTap,
            child: ExcludeSemantics(
              child: Container(
                padding: const EdgeInsets.fromLTRB(10, 11, 9, 10),
                decoration: BoxDecoration(
                  color: _colorFondoFila(),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                    color: _colorBordeFila(),
                    width: _focused ? 1.6 : 1,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 25,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 1),
                        child: Text(
                          '${widget.puesto}',
                          textAlign: TextAlign.center,
                          style: AppType.mono(
                            color: AppColors.textMuted,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.online.withValues(
                                    alpha: 0.12,
                                  ),
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.sm,
                                  ),
                                ),
                                child: Text(
                                  codigo,
                                  style: AppType.ui(
                                    color: AppColors.navy,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  nombre,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppType.ui(
                                    color: AppColors.navy,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${_formatearTotal(widget.ruta.total)} búsquedas',
                                style: AppType.mono(
                                  color: AppColors.textPrimary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: _BarraRuta(
                                  key: ValueKey('barra-ruta-${widget.ruta.id}'),
                                  value: widget.maxTotal == 0
                                      ? 0
                                      : widget.ruta.total / widget.maxTotal,
                                ),
                              ),
                              if (etiquetaHora != null) ...[
                                const SizedBox(width: 10),
                                Container(
                                  key: ValueKey('pico-hora-${widget.ruta.id}'),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _ambarTexto.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(
                                      AppRadius.pill,
                                    ),
                                  ),
                                  child: Text(
                                    etiquetaHora,
                                    style: AppType.ui(
                                      color: _ambarTexto,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 7),
                          Row(
                            children: [
                              for (var hora = 0; hora < 24; hora++)
                                Expanded(
                                  child: Padding(
                                    padding: EdgeInsets.only(
                                      right: hora == 23 ? 0 : 2,
                                    ),
                                    child: _CeldaHora(
                                      key: ValueKey(
                                        'celda-hora-${widget.ruta.id}-$hora',
                                      ),
                                      routeId: widget.ruta.id,
                                      pico: horaPico == hora,
                                      hora: hora,
                                      count: widget.ruta.porHora[hora],
                                      maxHora: maxHora,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              // Una marca cada seis horas: cada tramo ocupa
                              // seis celdas, así la etiqueta cae sobre la suya.
                              for (var hora = 0; hora < 24; hora += 6)
                                Expanded(
                                  child: Text(
                                    horaOpcionLabel(hora),
                                    maxLines: 1,
                                    overflow: TextOverflow.clip,
                                    style: AppType.ui(
                                      color: AppColors.textMuted,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _colorFondoFila() {
    if (widget.selected) {
      return Color.alphaBlend(
        AppColors.selection.withValues(alpha: 0.07),
        AppColors.surface,
      );
    }
    if (_hovered) {
      return Color.alphaBlend(
        AppColors.selection.withValues(alpha: 0.035),
        AppColors.surface,
      );
    }
    return AppColors.surface;
  }

  Color _colorBordeFila() {
    if (widget.selected) return AppColors.selection.withValues(alpha: 0.45);
    if (_focused) return AppColors.navy;
    return Colors.transparent;
  }
}

class _BarraRuta extends StatelessWidget {
  const _BarraRuta({super.key, required this.value});
  final double value;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Container(
      height: 7,
      decoration: BoxDecoration(
        color: AppColors.border,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      alignment: Alignment.centerLeft,
      child: Container(
        width: constraints.maxWidth * value.clamp(0.0, 1.0).toDouble(),
        height: 7,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.boton, Color(0xFF378ADD)],
          ),
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
      ),
    ),
  );
}

class _CeldaHora extends StatelessWidget {
  const _CeldaHora({
    super.key,
    required this.routeId,
    required this.pico,
    required this.hora,
    required this.count,
    required this.maxHora,
  });

  final String routeId;
  final bool pico;
  final int hora;
  final int count;
  final int maxHora;

  @override
  Widget build(BuildContext context) {
    // La fila entera es un botón y ya lee el total y la hora pico; la
    // celda solo lleva su número para el ratón.
    return Tooltip(
      message: '${horaOpcionLabel(hora)}, $count búsquedas',
      child: SizedBox(
        height: 17,
        child: DecoratedBox(
          key: pico ? ValueKey('pico-hora-$routeId-$hora') : null,
          decoration: BoxDecoration(
            color: _colorCalor(count, maxHora),
            borderRadius: BorderRadius.circular(3),
            border: Border.all(
              color: pico ? AppColors.navy : AppColors.surface,
              width: pico ? 2 : 0.5,
            ),
          ),
        ),
      ),
    );
  }
}

class _EstadoReporte extends StatelessWidget {
  const _EstadoReporte({
    required this.icon,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.surfaceRaised,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.border),
            ),
            child: Icon(icon, color: AppColors.navy, size: 22),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppType.ui(
              color: AppColors.textSecondary,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              height: 1.5,
            ),
          ),
          if (action != null) ...[const SizedBox(height: 14), action!],
        ],
      ),
    ),
  );
}

class _Reintentar extends StatelessWidget {
  const _Reintentar({super.key, required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => FilledButton.icon(
    onPressed: onPressed,
    icon: const Icon(Icons.refresh, size: 16),
    label: const Text('Reintentar'),
    style: FilledButton.styleFrom(
      backgroundColor: AppColors.boton,
      foregroundColor: Colors.white,
      minimumSize: const Size(0, 38),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      textStyle: AppType.ui(fontSize: 12, fontWeight: FontWeight.w700),
    ),
  );
}

class _MapaCalor extends ConsumerStatefulWidget {
  const _MapaCalor({
    required this.routeId,
    required this.hora,
    required this.cells,
  });
  final String routeId;
  final int? hora;
  final List<CeldaBusqueda> cells;

  @override
  ConsumerState<_MapaCalor> createState() => _MapaCalorState();
}

class _MapaCalorState extends ConsumerState<_MapaCalor> {
  final _controller = MapController();
  List<LatLng> _routePoints = const [];
  bool _mapReady = false;
  // Al abrir se ve solo la ruta; el calor se pinta cuando el dueño lo pide.
  bool _pintado = false;

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
      final route = await ref.read(
        routeTrajectoryProvider(widget.routeId).future,
      );
      if (!mounted) return;
      setState(() {
        _routePoints = [
          for (final point in route.points) LatLng(point.lat, point.lon),
        ];
      });
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
    final maxCount = widget.cells.fold<int>(
      1,
      (maximo, cell) => cell.count > maximo ? cell.count : maximo,
    );
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
                        // El verde separa la ruta del rojo más caliente del
                        // mapa y mantiene el estilo del pasajero.
                        EstiloRuta.linea.lineColor.replaceFirst('#', '0xFF'),
                      ),
                    ),
                    strokeWidth: EstiloRuta.linea.lineWidth,
                    strokeCap: StrokeCap.round,
                    strokeJoin: StrokeJoin.round,
                  ),
                ],
              ),
            // La mancha va encima de la ruta, como en el video: en un foco
            // el rojo tapa la línea y se lee que ahí piden el bus.
            if (_pintado)
              _CapaCalor(
                key: ValueKey('capa-calor-${widget.routeId}'),
                cells: widget.cells,
                maxCount: maxCount,
              ),
          ],
        ),
        Positioned(
          left: 16,
          top: 16,
          child: _BotonPintar(
            pintado: _pintado,
            onTap: () => setState(() => _pintado = !_pintado),
          ),
        ),
        Positioned(
          left: 16,
          bottom: 16,
          child: Row(
            children: [
              _PildoraHora(hora: widget.hora),
              // La leyenda solo explica lo que está pintado.
              AnimatedSwitcher(
                duration: AppMotion.duracion(context, AppMotion.rapido),
                switchInCurve: AppMotion.curvaEntrada,
                switchOutCurve: AppMotion.curvaSalida,
                child: _pintado
                    ? Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: _LeyendaCalor(maxCount: maxCount),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
        const Positioned(right: 8, bottom: 5, child: _AtribucionMapa()),
      ],
    );
  }
}

/// Manchas de calor como las del video de Control: cada zona es un halo
/// radial medido en metros (crece y encoge con el zoom, como la calle) que
/// baja por la escala continua verde, amarillo, naranja y rojo. Sin puntos
/// encima: el video solo muestra la banda y sus focos.
class _CapaCalor extends StatelessWidget {
  const _CapaCalor({super.key, required this.cells, required this.maxCount});

  final List<CeldaBusqueda> cells;
  final int maxCount;

  @override
  Widget build(BuildContext context) => MobileLayerTransformer(
    child: IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: _PintorCalor(
          camera: MapCamera.of(context),
          cells: cells,
          maxCount: maxCount,
        ),
      ),
    ),
  );
}

class _PintorCalor extends CustomPainter {
  _PintorCalor({
    required this.camera,
    required this.cells,
    required this.maxCount,
  });

  final MapCamera camera;
  final List<CeldaBusqueda> cells;
  final int maxCount;

  // Una celda mide unos 150 m (`PASO_LAT` del backend). Con halos de 380 m
  // las vecinas se funden en una banda continua por la ruta, como en el
  // video, y los focos crecen hasta 900 m sin tapar las calles de al lado.
  // En metros, la banda queda sobre las mismas cuadras al hacer zoom.
  static const _radioMetros = 380.0;
  static const _radioExtraMetros = 520.0;
  // Bajo 26 px el halo de una zona fría se pierde al alejar el mapa.
  static const _radioMinimoPx = 26.0;

  // Web Mercator: 256 px por tesela y 40.075.016,7 m de ecuador.
  double _pxPorMetro(double lat) =>
      256 *
      math.pow(2, camera.zoom) /
      (40075016.686 * math.cos(lat * math.pi / 180));

  @override
  void paint(Canvas canvas, Size size) {
    // Las más calientes al final, encima de las frías.
    final ordenadas = [...cells]..sort((a, b) => a.count.compareTo(b.count));
    for (final cell in ordenadas) {
      final centro = camera.getOffsetFromOrigin(LatLng(cell.lat, cell.lng));
      final intensidad = (cell.count / maxCount).clamp(0.0, 1.0);
      final radio = math.max(
        _radioMinimoPx,
        (_radioMetros + _radioExtraMetros * intensidad) * _pxPorMetro(cell.lat),
      );
      // Cada zona se apaga en su propio tono: si el anillo bajara a verde,
      // el borde verde de un foco taparía a sus vecinas naranja y el foco
      // quedaría en un punto. Así el degradado del video lo dan los datos
      // (los conteos bajan del foco hacia la banda). Las frías van al 50 %
      // para que la ruta se lea debajo y el ojo vaya primero a los focos.
      final color = _colorEnEscala(intensidad);
      final peso = 0.5 + 0.5 * intensidad;
      final pintura = Paint()
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: 0.85 * peso),
            color.withValues(alpha: 0.6 * peso),
            color.withValues(alpha: 0.25 * peso),
            color.withValues(alpha: 0),
          ],
          stops: const [0, 0.35, 0.7, 1],
        ).createShader(Rect.fromCircle(center: centro, radius: radio));
      canvas.drawCircle(centro, radio, pintura);
    }
  }

  @override
  bool shouldRepaint(_PintorCalor oldDelegate) =>
      oldDelegate.camera != camera ||
      oldDelegate.cells != cells ||
      oldDelegate.maxCount != maxCount;
}

/// Píldora que pinta o quita el calor. Apagada va blanca como las demás
/// del mapa; encendida, llena en el azul de botón con letra blanca
/// (#1E56A8 con blanco da 7,1:1).
class _BotonPintar extends StatelessWidget {
  const _BotonPintar({required this.pintado, required this.onTap});
  final bool pintado;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tinta = pintado ? Colors.white : AppColors.navy;
    return Semantics(
      button: true,
      toggled: pintado,
      label: 'Pintar mapa de calor',
      child: ExcludeSemantics(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            key: const ValueKey('alternar-calor'),
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: AnimatedContainer(
              duration: AppMotion.duracion(context, AppMotion.rapido),
              curve: AppMotion.curvaCambio,
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
              decoration: BoxDecoration(
                color: pintado
                    ? AppColors.boton
                    : AppColors.surface.withValues(alpha: 0.96),
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(
                  color: pintado ? AppColors.boton : AppColors.border,
                ),
                boxShadow: AppColors.sombraTarjeta,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    pintado
                        ? Icons.layers_clear_outlined
                        : Icons.local_fire_department_outlined,
                    size: 15,
                    color: tinta,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    pintado ? 'Quitar calor' : 'Pintar calor',
                    style: AppType.ui(
                      color: tinta,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PildoraHora extends StatelessWidget {
  const _PildoraHora({required this.hora});
  final int? hora;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: AppColors.surface.withValues(alpha: 0.96),
      borderRadius: BorderRadius.circular(AppRadius.pill),
      border: Border.all(color: AppColors.border),
      boxShadow: AppColors.sombraTarjeta,
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.schedule_outlined, size: 14, color: AppColors.navy),
        const SizedBox(width: 6),
        Text(
          hora == null ? 'Todo el día' : horaOpcionLabel(hora!),
          style: AppType.ui(
            color: AppColors.navy,
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );
}

class _LeyendaCalor extends StatelessWidget {
  const _LeyendaCalor({required this.maxCount});
  final int maxCount;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Menos búsquedas a más búsquedas, máximo $maxCount en una zona',
    child: ExcludeSemantics(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: AppColors.border),
          boxShadow: AppColors.sombraTarjeta,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Menos',
              style: AppType.ui(
                color: AppColors.textSecondary,
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 8),
            // La barra continua del video, con la misma escala del mapa.
            Container(
              key: const ValueKey('leyenda-calor'),
              width: 72,
              height: 8,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: _coloresCalor),
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Más',
              style: AppType.ui(
                color: AppColors.textSecondary,
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _AtribucionMapa extends StatelessWidget {
  const _AtribucionMapa();

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: AppColors.surface.withValues(alpha: 0.9),
      borderRadius: BorderRadius.circular(AppRadius.sm),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      child: Text(
        '© CARTO © OpenStreetMap',
        style: AppType.ui(color: AppColors.textMuted, fontSize: 9),
      ),
    ),
  );
}

(String, String) _partirNombreRuta(RutaBusquedas route) {
  final words = route.nombre.trim().split(RegExp(r'\s+'));
  if (words.length < 2) return (route.id, route.nombre.trim());
  return (words.first, words.skip(1).join(' '));
}

String _formatearTotal(int value) {
  final negative = value < 0;
  final digits = value.abs().toString();
  final chunks = <String>[];
  for (var end = digits.length; end > 0; end -= 3) {
    final start = math.max(0, end - 3).toInt();
    chunks.insert(0, digits.substring(start, end));
  }
  return '${negative ? '-' : ''}${chunks.join('.')}';
}

// Las horas sin búsquedas van en el gris del filo: se ve el hueco, pero no
// se confunde con el verde de las horas con pocas búsquedas.
Color _colorCalor(int count, int maxCount) {
  if (count <= 0 || maxCount <= 0) return AppColors.border;
  return _colorEnEscala(count / maxCount);
}

/// El tono de [_coloresCalor] para `t` de 0 (verde) a 1 (rojo), sin saltos.
Color _colorEnEscala(double t) {
  final x = t.clamp(0.0, 1.0) * (_coloresCalor.length - 1);
  final i = math.min(x.floor(), _coloresCalor.length - 2);
  return Color.lerp(_coloresCalor[i], _coloresCalor[i + 1], x - i)!;
}
