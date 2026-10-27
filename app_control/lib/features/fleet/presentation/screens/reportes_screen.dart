import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart';
import 'package:ya_viene_core/core/providers/map_providers.dart';
import 'package:ya_viene_core/core/theme/estilo_ruta.dart';
import 'package:ya_viene_core/shared/widgets/carga_fantasma.dart';
import 'package:ya_viene_core/ya_viene_core.dart' show AppMotion;

import '../../../../core/theme/app_theme.dart';
import '../providers/fleet_providers.dart' show fleetProvider;
import '../providers/ocupacion_provider.dart';
import '../providers/reportes_provider.dart';
import '../widgets/control_map.dart' show ControlMap, estiloMapaProvider;
import '../widgets/escala_calor.dart';
import '../widgets/ocupacion_panel.dart';

class ReportesScreen extends ConsumerStatefulWidget {
  const ReportesScreen({super.key});

  @override
  ConsumerState<ReportesScreen> createState() => _ReportesScreenState();
}

class _ReportesScreenState extends ConsumerState<ReportesScreen> {
  int? _hora;
  PeriodoReporte _periodo = PeriodoReporte.mes;
  String? _ruta;
  // La última lista que llegó: al cambiar de hora o de periodo se queda a la
  // vista, atenuada, mientras llega la nueva. El fantasma es solo la primera
  // vez (dueño, 2026-10-26).
  List<RutaBusquedas>? _previas;

  // Otra hora u otro periodo no cambian la ruta elegida: el dueño compara
  // la misma ruta a distintas horas.
  void _seleccionarHora(int? hora) => setState(() => _hora = hora);

  @override
  Widget build(BuildContext context) {
    var reportes = ref.watch(
      reportesRutasProvider((periodo: _periodo, hora: _hora)),
    );
    if (reportes.valueOrNull case final rutas?) _previas = rutas;
    final recargando = reportes.isLoading && !reportes.hasValue;
    if (recargando && _previas != null) reportes = AsyncData(_previas!);
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            _CabeceraReportes(
              hora: _hora,
              periodo: _periodo,
              onSelectHour: _seleccionarHora,
              onSelectPeriodo: (periodo) => setState(() => _periodo = periodo),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: _Fundido(
                  estado: reportes,
                  child: reportes.when(
                    loading: () => _dosPaneles(
                      izquierda: const _TarjetaRanking(
                        child: CargaFantasma(
                          semanticsLabel: 'Cargando reportes',
                          child: _FilasFantasma(),
                        ),
                      ),
                      derecha: const _TarjetaMapaEstado(
                        child: CargaFantasma(
                          semanticsLabel: 'Cargando el mapa',
                          child: _MapaFantasma(),
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
                            onPressed: () => ref.invalidate(
                              reportesRutasProvider((
                                periodo: _periodo,
                                hora: _hora,
                              )),
                            ),
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
                    data: (rutas) =>
                        _mostrarRutas(rutas, recargando: recargando),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mostrarRutas(List<RutaBusquedas> rutas, {required bool recargando}) {
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: AnimatedOpacity(
                opacity: recargando ? 0.45 : 1,
                duration: AppMotion.duracion(context, AppMotion.normal),
                curve: AppMotion.curvaCambio,
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
                  itemCount: ordenadas.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 4),
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
            ),
            const Divider(height: 1),
            OcupacionResumen(
              horas: ref.watch(
                ocupacionProvider((
                  routeId: rutaSeleccionada.id,
                  periodo: _periodo,
                )),
              ),
              buses: ref.watch(
                fleetProvider.select(
                  (s) => s.buses.values
                      .where((b) => b.routeId == rutaSeleccionada.id)
                      .length,
                ),
              ),
            ),
          ],
        ),
      ),
      derecha: _TarjetaMapa(
        route: rutaSeleccionada,
        hora: _hora,
        periodo: _periodo,
        onSelectHour: _seleccionarHora,
      ),
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

// Valor del segmento «Fecha» antes de elegir un día: nunca es el periodo
// vigente, así que no sale marcado.
final _sinDia = PeriodoReporte.delDia(DateTime(2000));

class _CabeceraReportes extends StatelessWidget {
  const _CabeceraReportes({
    required this.hora,
    required this.periodo,
    required this.onSelectHour,
    required this.onSelectPeriodo,
  });

  final int? hora;
  final PeriodoReporte periodo;
  final ValueChanged<int?> onSelectHour;
  final ValueChanged<PeriodoReporte> onSelectPeriodo;

  // El calendario va de hoy en Bogotá hasta 395 días atrás: el servidor
  // guarda 396 (`RETENCION_MS`), y el más viejo ya puede venir a medias.
  // Sale en un cuadro bajo los periodos, con el estilo del menú de la hora:
  // es un filtro más, no una tarea que pida velo.
  Widget _calendario(MenuController menu) {
    final hoy = DateTime.now().toUtc().subtract(const Duration(hours: 5));
    final ultimo = DateTime(hoy.year, hoy.month, hoy.day);
    final elegido = periodo.dia;
    return Builder(
      builder: (context) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(
            context,
          ).colorScheme.copyWith(primary: AppColors.boton),
        ),
        // 52 de cabecera y 7 filas de 42 (la de los días de la semana y seis
        // semanas): el alto de un mes que ocupa seis, sin recortar.
        // El menú ya rueda con el PrimaryScrollController: el mes y la lista
        // de años del calendario no deben colgarse de él también.
        child: PrimaryScrollController.none(
          child: SizedBox(
            key: const ValueKey('calendario-dia'),
            width: 344,
            height: 346,
            child: CalendarDatePicker(
              initialDate: elegido == null
                  ? ultimo
                  : DateTime(elegido.year, elegido.month, elegido.day),
              firstDate: ultimo.subtract(const Duration(days: 395)),
              lastDate: ultimo,
              onDateChanged: (dia) {
                menu.close();
                onSelectPeriodo(PeriodoReporte.delDia(dia));
              },
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      color: AppColors.surface,
      boxShadow: AppColors.sombraCabecera,
    ),
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    child: Row(
      children: [
        // Sin título ni periodo a la izquierda: Reportes es una pestaña de
        // la cabecera y el periodo ya se lee en los filtros, que van a la
        // derecha (dueño, 2026-10-26).
        const Spacer(),
        MenuAnchor(
          style: _estiloMenu,
          alignmentOffset: const Offset(0, 6),
          menuChildren: [
            Builder(
              builder: (context) =>
                  _calendario(MenuController.maybeOf(context)!),
            ),
          ],
          builder: (context, menu, _) => _Segmentos<PeriodoReporte>(
            valor: periodo,
            opciones: [
              for (final p in PeriodoReporte.values)
                (p, periodoLabel(p), 'periodo-${p.name}'),
              // El día elegido se queda escrito en su segmento; sin día, dice
              // «Fecha» y abre el calendario.
              periodo.dia == null
                  ? (_sinDia, 'Fecha', 'periodo-dia')
                  : (periodo, periodoLabel(periodo), 'periodo-dia'),
            ],
            onSelect: (p) {
              if (p.dia == null) {
                menu.close();
                onSelectPeriodo(p);
              } else {
                menu.isOpen ? menu.close() : menu.open();
              }
            },
          ),
        ),
        const SizedBox(width: 10),
        _FiltroHora(hora: hora, onSelectHour: onSelectHour),
      ],
    ),
  );
}

/// Control segmentado como el de macOS: un riel gris con la opción elegida
/// en blanco y sombra. Alto de 38 px, el de los botones de la cabecera.
/// Navy sobre blanco da 12,7:1 y el gris secundario sobre el riel, 4,9:1.
class _Segmentos<T> extends StatelessWidget {
  const _Segmentos({
    required this.valor,
    required this.opciones,
    required this.onSelect,
  });

  final T valor;
  final List<(T, String, String)> opciones;
  final ValueChanged<T> onSelect;

  @override
  Widget build(BuildContext context) => Container(
    height: 38,
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(
      color: AppColors.surfaceRaised,
      borderRadius: BorderRadius.circular(AppRadius.md),
      border: Border.all(color: AppColors.border),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (opcion, texto, clave) in opciones)
          _Segmento(
            key: ValueKey(clave),
            texto: texto,
            elegido: opcion == valor,
            onTap: () => onSelect(opcion),
          ),
      ],
    ),
  );
}

class _Segmento extends StatelessWidget {
  const _Segmento({
    super.key,
    required this.texto,
    required this.elegido,
    required this.onTap,
  });

  final String texto;
  final bool elegido;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: elegido,
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: AnimatedContainer(
          duration: AppMotion.duracion(context, AppMotion.rapido),
          curve: AppMotion.curvaCambio,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: elegido ? AppColors.surface : AppColors.surfaceRaised,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            boxShadow: elegido ? AppColors.sombraTarjeta : const [],
          ),
          child: Text(
            texto,
            style: AppType.ui(
              color: elegido ? AppColors.navy : AppColors.textSecondary,
              fontSize: 12,
              fontWeight: elegido ? FontWeight.w800 : FontWeight.w700,
            ),
          ),
        ),
      ),
    ),
  );
}

class _FiltroHora extends StatelessWidget {
  const _FiltroHora({required this.hora, required this.onSelectHour});

  final int? hora;
  final ValueChanged<int?> onSelectHour;

  @override
  Widget build(BuildContext context) => MenuAnchor(
    style: _estiloMenu,
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

const _estiloMenu = MenuStyle(
  backgroundColor: WidgetStatePropertyAll(AppColors.surface),
  surfaceTintColor: WidgetStatePropertyAll(Colors.transparent),
  shadowColor: WidgetStatePropertyAll(Color(0x2414274E)),
  elevation: WidgetStatePropertyAll(8),
  padding: WidgetStatePropertyAll(EdgeInsets.all(6)),
  shape: WidgetStatePropertyAll(
    RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(AppRadius.md)),
      side: BorderSide(color: AppColors.border),
    ),
  ),
);

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
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 18, 20, 12),
          child: Text(
            'Rutas más buscadas',
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

class _TarjetaMapa extends ConsumerStatefulWidget {
  const _TarjetaMapa({
    required this.route,
    required this.hora,
    required this.periodo,
    required this.onSelectHour,
  });

  final RutaBusquedas route;
  final int? hora;
  final PeriodoReporte periodo;
  final ValueChanged<int?> onSelectHour;

  @override
  ConsumerState<_TarjetaMapa> createState() => _TarjetaMapaState();
}

class _TarjetaMapaState extends ConsumerState<_TarjetaMapa> {
  // Lo último que pintó el mapa: con otra ruta, hora o periodo se queda,
  // atenuado y con su píldora, mientras llega lo nuevo.
  (RutaBusquedas, List<CeldaBusqueda>)? _previo;

  @override
  Widget build(BuildContext context) {
    final args = (
      routeId: widget.route.id,
      periodo: widget.periodo,
      hora: widget.hora,
    );
    var heat = ref.watch(reportesCalorProvider(args));
    if (heat.valueOrNull case final cells?) _previo = (widget.route, cells);
    final cargando = heat.isLoading && !heat.hasValue && !heat.hasError;
    final previo = _previo;
    if (cargando && previo != null) heat = AsyncData(previo.$2);
    return _Tarjeta(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // El nombre de la ruta ya va en su ficha, sobre el mapa.
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 13),
            child: Row(
              children: [
                Icon(Icons.place_outlined, color: AppColors.navy, size: 19),
                SizedBox(width: 9),
                Text(
                  'Desde dónde te buscan',
                  style: TextStyle(
                    color: AppColors.navy,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _Fundido(
              estado: heat,
              child: heat.when(
                loading: () => const CargaFantasma(
                  semanticsLabel: 'Cargando zonas de búsqueda',
                  child: _MapaFantasma(),
                ),
                error: (error, stack) => _EstadoReporte(
                  icon: Icons.error_outline,
                  message: 'No se pudieron cargar los reportes',
                  action: _Reintentar(
                    key: const ValueKey('reintentar-calor'),
                    onPressed: () =>
                        ref.invalidate(reportesCalorProvider(args)),
                  ),
                ),
                data: (cells) {
                  final route = cargando ? previo!.$1 : widget.route;
                  return _MapaCalor(
                    routeId: route.id,
                    codigo: _partirNombreRuta(route).$1,
                    hora: widget.hora,
                    porHora: route.porHora,
                    onSelectHour: widget.onSelectHour,
                    cells: cells,
                    cargando: cargando,
                  );
                },
              ),
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
                padding: const EdgeInsets.fromLTRB(12, 14, 14, 14),
                decoration: BoxDecoration(
                  color: _colorFondoFila(),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                    color: _colorBordeFila(),
                    width: _focused ? 1.6 : 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        // 22 px: caben dos cifras en mono a 12 pt.
                        SizedBox(
                          width: 22,
                          child: Text(
                            '${widget.puesto}',
                            style: AppType.mono(
                              color: AppColors.textMuted,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.online.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(AppRadius.sm),
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
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            nombre,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppType.ui(
                              color: AppColors.navy,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // La cifra sola: la cabecera ya dice que son
                        // búsquedas (dueño, 2026-10-26: «demasiado texto»).
                        Text(
                          _formatearTotal(widget.ruta.total),
                          style: AppType.mono(
                            color: AppColors.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // La barra arranca bajo la ficha (22 px del puesto). La
                    // hora pico y las 24 horas viven en la tira del mapa: una
                    // sola tira, no dos.
                    Padding(
                      padding: const EdgeInsets.only(left: 22),
                      child: _BarraRuta(
                        key: ValueKey('barra-ruta-${widget.ruta.id}'),
                        value: widget.maxTotal == 0
                            ? 0
                            : widget.ruta.total / widget.maxTotal,
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
          color: AppColors.boton,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
      ),
    ),
  );
}

/// La forma de [_FilaRuta] sin datos: puesto, ficha, nombre y total arriba,
/// la barra debajo desde los 22 px del puesto, con el mismo relleno y el
/// mismo radio, para que al llegar la lista las filas caigan donde estaban.
class _FilasFantasma extends StatelessWidget {
  const _FilasFantasma();

  /// Nombres de largos distintos: iguales se leerían como un patrón.
  static const _nombres = [148.0, 112.0, 164.0, 96.0, 130.0, 104.0];

  /// La barra de cada fila, de la más buscada a la menos.
  static const _barras = [1.0, 0.78, 0.6, 0.46, 0.34, 0.22];

  @override
  Widget build(BuildContext context) => ListView.separated(
    padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
    physics: const NeverScrollableScrollPhysics(),
    itemCount: _nombres.length,
    separatorBuilder: (_, _) => const SizedBox(height: 4),
    itemBuilder: (_, i) => Container(
      key: ValueKey('fantasma-ruta-$i'),
      padding: const EdgeInsets.fromLTRB(12, 14, 14, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // 22 px del puesto; su cifra mono de 12 pt mide unos 8 de ancho.
              const SizedBox(
                width: 22,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _Bloque(ancho: 9, alto: 10),
                ),
              ),
              // La ficha: código de 10,5 pt con 7 y 3 de relleno.
              const _Bloque(ancho: 34, alto: 19),
              const SizedBox(width: 10),
              _Bloque(ancho: _nombres[i], alto: 11),
              const Spacer(),
              const _Bloque(ancho: 82, alto: 10),
            ],
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.only(left: 22),
            child: FractionallySizedBox(
              widthFactor: _barras[i],
              child: const _Bloque(alto: 6),
            ),
          ),
        ],
      ),
    ),
  );
}

/// El mapa mientras llega: el fondo de Voyager con unas manchas donde irían
/// las zonas y la leyenda abajo, para que el calor llegue a un sitio tomado.
class _MapaFantasma extends StatelessWidget {
  const _MapaFantasma();

  /// Centro (fracción del ancho y del alto) y radio de cada mancha.
  static const _manchas = [
    (0.32, 0.38, 46.0),
    (0.58, 0.30, 30.0),
    (0.66, 0.62, 54.0),
    (0.40, 0.70, 26.0),
  ];

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: ControlMap.fondo,
    child: LayoutBuilder(
      builder: (context, c) => Stack(
        children: [
          for (final (x, y, r) in _manchas)
            Positioned(
              left: c.maxWidth * x - r,
              top: c.maxHeight * y - r,
              child: _Bloque(ancho: r * 2, alto: r * 2, radio: r),
            ),
          // La leyenda: 8 abajo, como la de verdad.
          const Positioned(
            left: 0,
            right: 0,
            bottom: 8,
            child: Center(
              child: _Bloque(ancho: 220, alto: 30, radio: AppRadius.pill),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Al pasar de cargando a datos (o a error) lo nuevo se funde sobre lo que
/// latía; dentro de un mismo estado los cambios van sin fundido, como antes.
class _Fundido extends StatelessWidget {
  const _Fundido({required this.estado, required this.child});
  final AsyncValue<Object?> estado;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: AppMotion.duracion(context, AppMotion.normal),
    switchInCurve: AppMotion.curvaEntrada,
    switchOutCurve: AppMotion.curvaSalida,
    layoutBuilder: (actual, previos) =>
        Stack(fit: StackFit.expand, children: [...previos, ?actual]),
    child: KeyedSubtree(
      key: ValueKey(
        estado.isLoading && !estado.hasValue && !estado.hasError
            ? 'carga'
            : estado.hasError
            ? 'error'
            : 'datos',
      ),
      child: child,
    ),
  );
}

/// Un trozo de esqueleto: el gris del borde fuerte, como las filas de la flota.
class _Bloque extends StatelessWidget {
  const _Bloque({this.ancho, required this.alto, this.radio = AppRadius.sm});
  final double? ancho;
  final double alto;
  final double radio;

  @override
  Widget build(BuildContext context) => Container(
    width: ancho ?? double.infinity,
    height: alto,
    decoration: BoxDecoration(
      color: AppColors.borderStrong,
      borderRadius: BorderRadius.circular(radio),
    ),
  );
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
    required this.codigo,
    required this.hora,
    required this.porHora,
    required this.onSelectHour,
    required this.cells,
    required this.cargando,
  });
  final String routeId;
  final String codigo;
  final int? hora;
  final List<int> porHora;
  final ValueChanged<int?> onSelectHour;
  final List<CeldaBusqueda> cells;

  /// Llega otra hora, ruta o periodo: el mapa de antes se queda atenuado
  /// hasta que llegue el nuevo, sin volver al esqueleto.
  final bool cargando;

  @override
  ConsumerState<_MapaCalor> createState() => _MapaCalorState();
}

// Como en el video de Control: el calor nace verde pálido sobre la ruta y
// sube a sus tonos en 1,3 s (de 32,3 a 33,6 s del video).
const _crecerCalor = Duration(milliseconds: 1300);

class _MapaCalorState extends ConsumerState<_MapaCalor>
    with TickerProviderStateMixin {
  final _controller = MapController();
  List<LatLng> _routePoints = const [];
  bool _mapReady = false;
  // La ruta arranca sin pintar: el calor se lee solo (dueño, 2026-10-26).
  bool _verRuta = false;
  late final _calor = AnimationController(vsync: this);
  late final _nivel = CurvedAnimation(
    parent: _calor,
    curve: AppMotion.curvaEntrada,
  );
  late final _espera = AnimationController(
    vsync: this,
    value: widget.cargando ? 1 : 0,
  );
  late final _atenuado = CurvedAnimation(
    parent: _espera,
    curve: AppMotion.curvaCambio,
  );

  @override
  void initState() {
    super.initState();
    _readRoute();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _calor.duration = AppMotion.duracion(context, _crecerCalor);
    _espera.duration = AppMotion.duracion(context, AppMotion.normal);
    // Al abrir, el calor crece desde la ruta como en el video.
    if (_calor.isDismissed) _crecer();
  }

  @override
  void didUpdateWidget(covariant _MapaCalor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.routeId != widget.routeId) _readRoute();
    if (oldWidget.cargando != widget.cargando) {
      widget.cargando ? _espera.forward() : _espera.reverse();
    }
    // Mientras espera, la cámara y el calor se quedan como estaban.
    if (widget.cargando) return;
    if (oldWidget.cells != widget.cells ||
        oldWidget.routeId != widget.routeId) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitCamera());
      // Otra ruta u otra hora: el calor vuelve a crecer desde la ruta.
      _crecer();
    }
  }

  @override
  void dispose() {
    _nivel.dispose();
    _calor.dispose();
    _atenuado.dispose();
    _espera.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _crecer() => _calor.forward(from: 0);

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
    final orla = Color(
      int.parse(EstiloRuta.orla.lineColor.replaceFirst('#', '0xFF')),
    );
    // El verde separa la ruta del rojo más caliente del mapa y mantiene el
    // estilo del pasajero.
    final linea = Color(
      int.parse(EstiloRuta.linea.lineColor.replaceFirst('#', '0xFF')),
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
            // La ruta va debajo del calor y a media luz (dueño, 2026-10-26):
            // el calor manda y la línea solo asoma por dónde pasa.
            if (_verRuta && _routePoints.length > 1)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: _routePoints,
                    color: orla.withValues(
                      alpha: EstiloRuta.orla.lineOpacity * 0.5,
                    ),
                    strokeWidth: EstiloRuta.orla.lineWidth,
                    strokeCap: StrokeCap.round,
                    strokeJoin: StrokeJoin.round,
                  ),
                  Polyline(
                    points: _routePoints,
                    color: linea.withValues(alpha: 0.45),
                    strokeWidth: EstiloRuta.linea.lineWidth,
                    strokeCap: StrokeCap.round,
                    strokeJoin: StrokeJoin.round,
                  ),
                ],
              ),
            _CapaCalor(
              key: ValueKey('capa-calor-${widget.routeId}'),
              cells: widget.cells,
              nivel: _nivel,
              atenuado: _atenuado,
            ),
          ],
        ),
        Positioned(
          top: 14,
          left: 0,
          right: 0,
          child: Center(
            child: AnimatedSwitcher(
              duration: AppMotion.duracion(context, AppMotion.normal),
              switchInCurve: AppMotion.curvaEntrada,
              switchOutCurve: AppMotion.curvaCambio,
              child: widget.cargando
                  ? const _PildoraCargando(key: ValueKey('mapa-cargando'))
                  : const SizedBox.shrink(),
            ),
          ),
        ),
        Positioned(
          left: 16,
          bottom: 16,
          child: _HorasMapa(
            key: const ValueKey('horas-mapa'),
            routeId: widget.routeId,
            codigo: widget.codigo,
            porHora: widget.porHora,
            hora: widget.hora,
            sinZonas: widget.cells.isEmpty && !widget.cargando,
            onSelectHour: widget.onSelectHour,
          ),
        ),
        Positioned(
          top: 14,
          right: 14,
          child: _BotonRuta(
            pintada: _verRuta,
            onTap: () => setState(() => _verRuta = !_verRuta),
          ),
        ),
        const Positioned(right: 8, bottom: 5, child: _AtribucionMapa()),
      ],
    );
  }
}

/// Mapa de calor como el del video de Control: las búsquedas se suman en
/// un campo de densidad continuo, así la ruta se lee como un corredor verde
/// que se calienta a amarillo, naranja y rojo donde más buscan, en vez de
/// manchas sueltas. Al pintarse nace verde y sube a sus tonos con [nivel].
class _CapaCalor extends StatefulWidget {
  const _CapaCalor({
    super.key,
    required this.cells,
    required this.nivel,
    required this.atenuado,
  });

  final List<CeldaBusqueda> cells;
  final Animation<double> nivel;
  final Animation<double> atenuado;

  @override
  State<_CapaCalor> createState() => _CapaCalorState();
}

class _CapaCalorState extends State<_CapaCalor> {
  _RasterCalor? _raster;
  int? _zoomRaster;
  int _pedido = 0;

  @override
  void didUpdateWidget(covariant _CapaCalor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cells != widget.cells) _zoomRaster = null;
  }

  @override
  void dispose() {
    _pedido++;
    _raster?.dispose();
    super.dispose();
  }

  // El campo se calcula una vez por zoom entero: entre medias se escala, y
  // como es suave no se nota.
  void _pedir(MapCamera camera) {
    final zoom = camera.zoom.round();
    if (zoom == _zoomRaster) return;
    _zoomRaster = zoom;
    final pedido = ++_pedido;
    _RasterCalor.crear(camera, widget.cells, zoom).then((raster) {
      if (!mounted || pedido != _pedido) {
        raster?.dispose();
        return;
      }
      setState(() {
        _raster?.dispose();
        _raster = raster;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.of(context);
    _pedir(camera);
    return MobileLayerTransformer(
      child: IgnorePointer(
        child: CustomPaint(
          size: Size.infinite,
          painter: _PintorCalor(
            camera: camera,
            raster: _raster,
            nivel: widget.nivel,
            atenuado: widget.atenuado,
          ),
        ),
      ),
    );
  }
}

/// El campo de calor ya coloreado, en dos imágenes (verde del arranque y
/// tonos finales) con sus esquinas en el mapa.
class _RasterCalor {
  _RasterCalor._(this.verde, this.color, this.noroeste, this.sureste);

  final ui.Image verde;
  final ui.Image color;
  final LatLng noroeste;
  final LatLng sureste;

  // Cada búsqueda se reparte en una campana de 200 m: con celdas de unos
  // 150 m (`PASO_LAT` del backend) las vecinas se funden en un corredor
  // de unos 600 m, el ancho de la banda del video. Bajo 12 px el corredor
  // se vuelve un hilo al alejar el mapa.
  static const _sigmaMetros = 200.0;
  static const _sigmaMinimoPx = 12.0;
  // Un píxel del campo cubre al menos 2 del mapa; el lado no pasa de 1200.
  static const _ladoMaximo = 1200;

  static Future<_RasterCalor?> crear(
    MapCamera camera,
    List<CeldaBusqueda> cells,
    int zoom,
  ) async {
    if (cells.isEmpty) return null;
    final z = zoom.toDouble();
    final pxPorMetro =
        256 *
        math.pow(2, z) /
        (40075016.686 * math.cos(cells.first.lat * math.pi / 180));
    final mundo = [
      for (final c in cells) camera.projectAtZoom(LatLng(c.lat, c.lng), z),
    ];
    final sigmaMundo = math.max(_sigmaMetros * pxPorMetro, _sigmaMinimoPx);
    final margen = 3 * sigmaMundo;
    var minX = double.infinity, minY = double.infinity;
    var maxX = -double.infinity, maxY = -double.infinity;
    for (final p in mundo) {
      minX = math.min(minX, p.dx - margen);
      minY = math.min(minY, p.dy - margen);
      maxX = math.max(maxX, p.dx + margen);
      maxY = math.max(maxY, p.dy + margen);
    }
    final escala = math.max(
      2.0,
      math.max(maxX - minX, maxY - minY) / _ladoMaximo,
    );
    final ancho = ((maxX - minX) / escala).ceil();
    final alto = ((maxY - minY) / escala).ceil();
    final sigma = sigmaMundo / escala;
    final radio = (3 * sigma).ceil();
    final campana = [
      for (var i = -radio; i <= radio; i++)
        math.exp(-(i * i) / (2 * sigma * sigma)),
    ];

    // d suma las búsquedas (el tono); s suma solo la presencia (el borde),
    // para que el corredor se apague suave aunque su tono sea verde.
    final d = Float64List(ancho * alto);
    final s = Float64List(ancho * alto);
    for (var i = 0; i < cells.length; i++) {
      final cx = ((mundo[i].dx - minX) / escala).round();
      final cy = ((mundo[i].dy - minY) / escala).round();
      final count = cells[i].count.toDouble();
      for (
        var y = math.max(0, cy - radio);
        y <= math.min(alto - 1, cy + radio);
        y++
      ) {
        final gy = campana[y - cy + radio];
        final fila = y * ancho;
        for (
          var x = math.max(0, cx - radio);
          x <= math.min(ancho - 1, cx + radio);
          x++
        ) {
          final g = gy * campana[x - cx + radio];
          d[fila + x] += count * g;
          s[fila + x] += g;
        }
      }
    }
    var dMax = 0.0;
    for (final v in d) {
      if (v > dMax) dMax = v;
    }
    if (dMax <= 0) return null;

    final verde = Uint8List(ancho * alto * 4);
    final color = Uint8List(ancho * alto * 4);
    final base = coloresCalor.first;
    for (var i = 0; i < d.length; i++) {
      final borde = _suave(0.03, 0.8, s[i]);
      if (borde <= 0) continue;
      // Potencia 0,7: el corredor (unas 25 búsquedas contra 500 del foco)
      // queda verde, como en el video, y los focos suben a amarillo, naranja
      // y rojo en una mancha ancha, no en un punto.
      final t = math.pow(d[i] / dMax, 0.7).toDouble();
      // Corredor al 55 %, como el del video, deja leer las calles debajo;
      // los focos llegan al 90 %.
      _pixel(color, i * 4, colorEnEscala(t), borde * (0.55 + 0.35 * t));
      _pixel(verde, i * 4, base, borde * 0.55);
    }

    LatLng aMapa(double x, double y) =>
        camera.unprojectAtZoom(Offset(minX + x * escala, minY + y * escala), z);
    final imagenes = await Future.wait([
      _imagen(verde, ancho, alto),
      _imagen(color, ancho, alto),
    ]);
    return _RasterCalor._(
      imagenes[0],
      imagenes[1],
      aMapa(0, 0),
      aMapa(ancho.toDouble(), alto.toDouble()),
    );
  }

  // decodeImageFromPixels toma rgba8888 premultiplicado: sin multiplicar
  // por alfa el borde del corredor sale blanco, como un halo.
  static void _pixel(Uint8List pixeles, int o, Color tono, double alfa) {
    pixeles
      ..[o] = (tono.r * alfa * 255).round()
      ..[o + 1] = (tono.g * alfa * 255).round()
      ..[o + 2] = (tono.b * alfa * 255).round()
      ..[o + 3] = (alfa * 255).round();
  }

  static double _suave(double desde, double hasta, double x) {
    final t = ((x - desde) / (hasta - desde)).clamp(0.0, 1.0);
    return t * t * (3 - 2 * t);
  }

  static Future<ui.Image> _imagen(Uint8List pixeles, int ancho, int alto) {
    final listo = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      pixeles,
      ancho,
      alto,
      ui.PixelFormat.rgba8888,
      listo.complete,
    );
    return listo.future;
  }

  void dispose() {
    verde.dispose();
    color.dispose();
  }
}

class _PintorCalor extends CustomPainter {
  _PintorCalor({
    required this.camera,
    required this.raster,
    required this.nivel,
    required this.atenuado,
  }) : super(repaint: Listenable.merge([nivel, atenuado]));

  final MapCamera camera;
  final _RasterCalor? raster;
  final Animation<double> nivel;
  final Animation<double> atenuado;

  @override
  void paint(Canvas canvas, Size size) {
    final r = raster;
    if (r == null) return;
    final n = nivel.value.clamp(0.0, 1.0);
    // El corredor aparece en el primer 40 % y el resto sube de tono. El
    // tono va en cuadrático: el resorte llega casi entero a la mitad del
    // tiempo, y sin esto el verde del arranque (32,3 s del video) ni se ve.
    // Mientras llega otra hora el calor de antes baja al 35 %: se ve que
    // espera sin dejar el mapa en blanco.
    final queda = 1 - 0.65 * atenuado.value.clamp(0.0, 1.0);
    final aparece = (n / 0.4).clamp(0.0, 1.0) * queda;
    final tono = n * n;
    final destino = Rect.fromPoints(
      camera.getOffsetFromOrigin(r.noroeste),
      camera.getOffsetFromOrigin(r.sureste),
    );
    final fuente = Rect.fromLTWH(
      0,
      0,
      r.color.width.toDouble(),
      r.color.height.toDouble(),
    );
    // Verde y tonos se mezclan en lineal dentro de una capa (plus), sin el
    // bajón de opacidad de un fundido de dos imágenes translúcidas.
    canvas
      ..saveLayer(destino, Paint()..color = Color.fromRGBO(0, 0, 0, aparece))
      ..drawImageRect(
        r.verde,
        fuente,
        destino,
        Paint()
          ..filterQuality = FilterQuality.medium
          ..color = Color.fromRGBO(0, 0, 0, 1 - tono),
      )
      ..drawImageRect(
        r.color,
        fuente,
        destino,
        Paint()
          ..filterQuality = FilterQuality.medium
          ..blendMode = BlendMode.plus
          ..color = Color.fromRGBO(0, 0, 0, tono),
      )
      ..restore();
  }

  @override
  bool shouldRepaint(_PintorCalor oldDelegate) =>
      oldDelegate.camera != camera ||
      oldDelegate.raster != raster ||
      oldDelegate.nivel != nivel ||
      oldDelegate.atenuado != atenuado;
}

/// La única tira de horas de Reportes, sobre el mapa: la ficha de la ruta,
/// la hora pico marcada con un punto, cada barra en la escala del calor y,
/// debajo, esa escala de menos a más. Tocar una barra pinta el mapa solo a
/// esa hora; tocar la elegida, o «Todo el día», vuelve al día entero.
class _HorasMapa extends StatelessWidget {
  const _HorasMapa({
    super.key,
    required this.routeId,
    required this.codigo,
    required this.porHora,
    required this.hora,
    required this.sinZonas,
    required this.onSelectHour,
  });

  final String routeId;
  final String codigo;
  final List<int> porHora;
  final int? hora;
  final bool sinZonas;
  final ValueChanged<int?> onSelectHour;

  // 420 px, un cuarto más que antes para leerse de lejos (dueño,
  // 2026-10-26): con 14 de aire por lado quedan 392 para 24 barras de
  // 14,4 px y 23 huecos de 2 px.
  static const _ancho = 420.0;
  static const _altoBarras = 40.0;

  @override
  Widget build(BuildContext context) {
    final maximo = porHora.fold<int>(0, math.max);
    final pico = maximo == 0 ? null : porHora.indexOf(maximo);
    final rotulo = switch ((hora, pico)) {
      (final h?, _) => horaPicoLabel(h),
      (null, final p?) => 'Pico ${horaPicoLabel(p)}',
      _ => 'Todo el día',
    };
    final pie = AppType.ui(
      color: AppColors.textSecondary,
      fontSize: 11.5,
      fontWeight: FontWeight.w700,
    );
    return Container(
      width: _ancho,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.sombraTarjeta,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (codigo.isNotEmpty) ...[
                // Blanco sobre el azul de botón: 7,1:1.
                Container(
                  key: ValueKey('ruta-mapa-$routeId'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.boton,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Text(
                    codigo,
                    style: AppType.ui(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  rotulo,
                  key: const ValueKey('hora-mapa-rotulo'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.ui(
                    color: AppColors.navy,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (hora != null)
                // Azul de botón sobre blanco: 7,1:1.
                InkWell(
                  key: const ValueKey('hora-mapa-todo'),
                  onTap: () => onSelectHour(null),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    child: Text(
                      'Todo el día',
                      style: AppType.ui(
                        color: AppColors.boton,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          // El punto navy sobre la barra más alta: el pico se ve sin leerlo.
          SizedBox(
            height: 9,
            child: Row(
              children: [
                for (var h = 0; h < 24; h++)
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: h == 23 ? 0 : 2),
                      child: h == pico
                          ? Align(
                              alignment: Alignment.topCenter,
                              child: Container(
                                key: const ValueKey('hora-mapa-pico'),
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: AppColors.navy,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            )
                          : null,
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(
            height: _altoBarras,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var h = 0; h < 24; h++)
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: h == 23 ? 0 : 2),
                      child: _BarraHoraMapa(
                        key: ValueKey('hora-mapa-$h'),
                        hora: h,
                        count: porHora[h],
                        maximo: maximo,
                        elegida: hora == h,
                        apagada: hora != null && hora != h,
                        onTap: () => onSelectHour(hora == h ? null : h),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              // Una marca cada seis barras.
              for (var h = 0; h < 24; h += 6)
                Expanded(
                  child: Text(
                    horaOpcionLabel(h),
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    style: AppType.ui(
                      color: AppColors.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (sinZonas)
            Text(
              'Sin zonas con 5 búsquedas o más',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: pie,
            )
          else
            Semantics(
              label: 'Escala del mapa, de menos a más búsquedas',
              child: ExcludeSemantics(
                // La misma escala del mapa y de las barras.
                child: Row(
                  children: [
                    Text('Menos', style: pie),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        key: const ValueKey('leyenda-calor'),
                        height: 6,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: coloresCalor),
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('Más', style: pie),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Píldora que pinta o quita la ruta. Apagada va blanca como la tarjeta de
/// las horas; encendida, llena en el azul de botón con letra blanca
/// (#1E56A8 con blanco da 7,1:1).
class _BotonRuta extends StatelessWidget {
  const _BotonRuta({required this.pintada, required this.onTap});

  final bool pintada;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tinta = pintada ? Colors.white : AppColors.navy;
    return Semantics(
      button: true,
      toggled: pintada,
      label: 'Pintar la ruta',
      child: ExcludeSemantics(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            key: const ValueKey('alternar-ruta'),
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: AnimatedContainer(
              duration: AppMotion.duracion(context, AppMotion.rapido),
              curve: AppMotion.curvaCambio,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: pintada
                    ? AppColors.boton
                    : AppColors.surface.withValues(alpha: 0.96),
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(
                  color: pintada ? AppColors.boton : AppColors.border,
                ),
                boxShadow: AppColors.sombraTarjeta,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.route_outlined, size: 16, color: tinta),
                  const SizedBox(width: 6),
                  Text(
                    pintada ? 'Quitar ruta' : 'Ver ruta',
                    style: AppType.ui(
                      color: tinta,
                      fontSize: 12,
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

class _BarraHoraMapa extends StatefulWidget {
  const _BarraHoraMapa({
    super.key,
    required this.hora,
    required this.count,
    required this.maximo,
    required this.elegida,
    required this.apagada,
    required this.onTap,
  });

  final int hora;
  final int count;
  final int maximo;
  final bool elegida;
  final bool apagada;
  final VoidCallback onTap;

  @override
  State<_BarraHoraMapa> createState() => _BarraHoraMapaState();
}

class _BarraHoraMapaState extends State<_BarraHoraMapa> {
  bool _encima = false;

  @override
  Widget build(BuildContext context) {
    // Una hora sin búsquedas deja 3 px en el gris del filo: se ve el hueco.
    final alto = widget.maximo == 0
        ? 3.0
        : 3 + (_HorasMapa._altoBarras - 3) * widget.count / widget.maximo;
    // Con una hora elegida las otras bajan al 35 % y se leen como fondo.
    final opacidad = widget.apagada && !_encima ? 0.35 : 1.0;
    return Semantics(
      button: true,
      selected: widget.elegida,
      label: '${horaOpcionLabel(widget.hora)}, ${widget.count} búsquedas',
      child: ExcludeSemantics(
        child: Tooltip(
          message: '${horaOpcionLabel(widget.hora)}, ${widget.count} búsquedas',
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            onEnter: (_) => setState(() => _encima = true),
            onExit: (_) => setState(() => _encima = false),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onTap,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: AnimatedContainer(
                  duration: AppMotion.duracion(context, AppMotion.rapido),
                  curve: AppMotion.curvaCambio,
                  height: alto,
                  decoration: BoxDecoration(
                    color: colorCalor(
                      widget.count,
                      widget.maximo,
                    ).withValues(alpha: opacidad),
                    borderRadius: BorderRadius.circular(2),
                    // La elegida lleva el borde navy de la hora pico de la
                    // lista.
                    border: widget.elegida
                        ? Border.all(color: AppColors.navy, width: 1.5)
                        : null,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Píldora del mapa mientras llega otra hora, ruta o periodo.
class _PildoraCargando extends StatelessWidget {
  const _PildoraCargando({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: 'Cargando',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 6, 12, 6),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(color: AppColors.border),
            boxShadow: AppColors.sombraTarjeta,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox.square(
                dimension: 11,
                child: CircularProgressIndicator(
                  strokeWidth: 1.6,
                  color: AppColors.boton,
                ),
              ),
              const SizedBox(width: 7),
              Text(
                'Cargando',
                style: AppType.ui(
                  color: AppColors.navy,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
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
