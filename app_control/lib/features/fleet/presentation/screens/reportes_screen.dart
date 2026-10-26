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
import 'package:ya_viene_core/ya_viene_core.dart' show AppMotion;

import '../../../../core/theme/app_theme.dart';
import '../providers/reportes_provider.dart';
import '../widgets/control_map.dart' show ControlMap, estiloMapaProvider;
import '../widgets/ocupacion_panel.dart';

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

enum _Pestana { busquedas, ocupacion }

class _ReportesScreenState extends ConsumerState<ReportesScreen> {
  int? _hora;
  PeriodoReporte _periodo = PeriodoReporte.mes;
  String? _ruta;
  _Pestana _pestana = _Pestana.busquedas;

  // Otra hora u otro periodo no cambian la ruta elegida: el dueño compara
  // la misma ruta a distintas horas.
  void _seleccionarHora(int? hora) => setState(() => _hora = hora);

  @override
  Widget build(BuildContext context) {
    final reportes = ref.watch(
      reportesRutasProvider((periodo: _periodo, hora: _hora)),
    );
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            _CabeceraReportes(
              hora: _hora,
              periodo: _periodo,
              pestana: _pestana,
              onBack: () => Navigator.of(context).maybePop(),
              onSelectHour: _seleccionarHora,
              onSelectPeriodo: (periodo) => setState(() => _periodo = periodo),
              onSelectPestana: (pestana) => setState(() => _pestana = pestana),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: _pestana == _Pestana.ocupacion
                    ? const OcupacionPanel()
                    : reportes.when(
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
                itemCount: ordenadas.length,
                separatorBuilder: (context, index) => const SizedBox(height: 4),
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
            const Divider(height: 1),
            _ResumenRutas(rutas: ordenadas),
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

class _CabeceraReportes extends StatelessWidget {
  const _CabeceraReportes({
    required this.hora,
    required this.periodo,
    required this.pestana,
    required this.onBack,
    required this.onSelectHour,
    required this.onSelectPeriodo,
    required this.onSelectPestana,
  });

  final int? hora;
  final PeriodoReporte periodo;
  final _Pestana pestana;
  final VoidCallback onBack;
  final ValueChanged<int?> onSelectHour;
  final ValueChanged<PeriodoReporte> onSelectPeriodo;
  final ValueChanged<_Pestana> onSelectPestana;

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
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Reportes',
              style: TextStyle(
                color: AppColors.navy,
                fontSize: 21,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              pestana == _Pestana.ocupacion
                  ? 'Aforo con IA'
                  : periodoSubtitulo(periodo),
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(width: 28),
        _Segmentos<_Pestana>(
          valor: pestana,
          opciones: const [
            (_Pestana.busquedas, 'Búsquedas', 'pestana-busquedas'),
            (_Pestana.ocupacion, 'Ocupación', 'pestana-ocupacion'),
          ],
          onSelect: onSelectPestana,
        ),
        const Spacer(),
        // El periodo y la hora solo filtran las búsquedas.
        if (pestana == _Pestana.busquedas) ...[
          _Segmentos<PeriodoReporte>(
            valor: periodo,
            opciones: [
              for (final p in PeriodoReporte.values)
                (p, periodoLabel(p), 'periodo-${p.name}'),
            ],
            onSelect: onSelectPeriodo,
          ),
          const SizedBox(width: 10),
          _FiltroHora(hora: hora, onSelectHour: onSelectHour),
        ],
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

/// Bajo el ranking, todas las rutas juntas: cuántas búsquedas suman y a qué
/// hora se busca más en la empresa entera. Llena el hueco que dejan pocas
/// rutas con lo que el ranking, ruta por ruta, no dice.
class _ResumenRutas extends StatelessWidget {
  const _ResumenRutas({required this.rutas});

  final List<RutaBusquedas> rutas;

  // 72 px: el alto de seis filas del ranking cabe sobre él en 900 px.
  static const _altoBarras = 72.0;
  static const _pico = TextStyle(
    color: _ambarTexto,
    fontSize: 12.5,
    fontWeight: FontWeight.w600,
  );

  @override
  Widget build(BuildContext context) {
    final porHora = List<int>.generate(
      24,
      (h) => rutas.fold(0, (suma, ruta) => suma + ruta.porHora[h]),
    );
    final total = rutas.fold(0, (suma, ruta) => suma + ruta.total);
    final maximo = porHora.reduce(math.max);
    final pico = maximo > 0 ? porHora.indexOf(maximo) : null;
    const rotulo = TextStyle(
      color: AppColors.textSecondary,
      fontSize: 11,
      fontWeight: FontWeight.w600,
    );
    return Padding(
      key: const ValueKey('resumen-rutas'),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Todas tus rutas',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatearTotal(total),
                key: const ValueKey('resumen-total'),
                style: const TextStyle(
                  color: AppColors.navy,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  height: 1,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: 8),
              const Padding(
                padding: EdgeInsets.only(bottom: 3),
                child: Text(
                  'búsquedas',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              if (pico != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Row(
                    children: [
                      const Text('Hora pico ', style: _pico),
                      Text(
                        horaPicoLabel(pico),
                        key: const ValueKey('resumen-pico'),
                        style: _pico.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: _altoBarras,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var h = 0; h < 24; h++)
                  Expanded(
                    child: Padding(
                      // 1,5 px por lado: 3 de aire, como las celdas de hora.
                      padding: const EdgeInsets.symmetric(horizontal: 1.5),
                      child: AnimatedContainer(
                        key: ValueKey('resumen-hora-$h'),
                        duration: AppMotion.normal,
                        curve: AppMotion.curvaCambio,
                        height: maximo > 0
                            ? _altoBarras * porHora[h] / maximo
                            : 0,
                        decoration: BoxDecoration(
                          color: _colorCalor(porHora[h], maximo),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(3),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('12 a. m.', style: rotulo),
              Text('6 a. m.', style: rotulo),
              Text('12 p. m.', style: rotulo),
              Text('6 p. m.', style: rotulo),
              Text('11 p. m.', style: rotulo),
            ],
          ),
        ],
      ),
    );
  }
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
  Widget build(BuildContext context, WidgetRef ref) {
    final heat = ref.watch(
      reportesCalorProvider((routeId: route.id, periodo: periodo, hora: hora)),
    );
    final (codigo, nombre) = _partirNombreRuta(route);
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
                  // Al elegir otra ruta el nombre se funde, como el mapa.
                  child: AnimatedSwitcher(
                    duration: AppMotion.duracion(context, AppMotion.rapido),
                    switchInCurve: AppMotion.curvaEntrada,
                    switchOutCurve: AppMotion.curvaSalida,
                    layoutBuilder: (actual, previos) => Stack(
                      alignment: Alignment.centerRight,
                      children: [...previos, ?actual],
                    ),
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
                    reportesCalorProvider((
                      routeId: route.id,
                      periodo: periodo,
                      hora: hora,
                    )),
                  ),
                ),
              ),
              data: (cells) => cells.isEmpty
                  ? const _EstadoReporte(
                      icon: Icons.location_off_outlined,
                      message:
                          'Aún no hay suficientes búsquedas con ubicación en esta ruta para mostrarlas. Se muestran zonas con al menos 5 búsquedas.',
                    )
                  : _MapaCalor(
                      routeId: route.id,
                      codigo: codigo,
                      hora: hora,
                      porHora: route.porHora,
                      onSelectHour: onSelectHour,
                      cells: cells,
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
                        Text(
                          '${_formatearTotal(widget.ruta.total)} búsquedas',
                          style: AppType.mono(
                            color: AppColors.textPrimary,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Barra y hora pico arrancan bajo la ficha (22 px del
                    // puesto), así la fila lee en dos columnas limpias.
                    Padding(
                      padding: const EdgeInsets.only(left: 22),
                      child: Row(
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
                            const SizedBox(width: 14),
                            Row(
                              key: ValueKey('pico-hora-${widget.ruta.id}'),
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Ámbar sobre blanco: 5,0:1.
                                const Icon(
                                  Icons.schedule_outlined,
                                  size: 12,
                                  color: _ambarTexto,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  etiquetaHora,
                                  style: AppType.ui(
                                    color: _ambarTexto,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    // Las 24 horas solo en la ruta elegida: repetidas en
                    // cada fila amontonaban la lista.
                    AnimatedSize(
                      duration: AppMotion.duracion(context, AppMotion.normal),
                      curve: AppMotion.curvaCambio,
                      alignment: Alignment.topCenter,
                      child: !widget.selected
                          ? const SizedBox(width: double.infinity)
                          : Padding(
                              padding: const EdgeInsets.fromLTRB(22, 14, 0, 0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
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
                                  const SizedBox(height: 5),
                                  Row(
                                    children: [
                                      // Una marca cada seis horas: cada
                                      // tramo ocupa seis celdas, así la
                                      // etiqueta cae sobre la suya.
                                      for (var hora = 0; hora < 24; hora += 6)
                                        Expanded(
                                          child: Text(
                                            horaOpcionLabel(hora),
                                            maxLines: 1,
                                            overflow: TextOverflow.clip,
                                            style: AppType.ui(
                                              color: AppColors.textMuted,
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
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
    required this.codigo,
    required this.hora,
    required this.porHora,
    required this.onSelectHour,
    required this.cells,
  });
  final String routeId;
  final String codigo;
  final int? hora;
  final List<int> porHora;
  final ValueChanged<int?> onSelectHour;
  final List<CeldaBusqueda> cells;

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
  // El mapa abre pintado (dueño, 2026-10-26); el botón lo quita y lo vuelve
  // a pintar.
  bool _pintado = true;
  late final _calor = AnimationController(vsync: this)
    ..addStatusListener(_alCambiarCalor);
  late final _nivel = CurvedAnimation(
    parent: _calor,
    curve: AppMotion.curvaEntrada,
    reverseCurve: AppMotion.curvaSalida,
  );
  // El pulso marca el foco más caliente cuando el calor termina de subir.
  late final _pulso = AnimationController(vsync: this);

  @override
  void initState() {
    super.initState();
    _readRoute();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _calor
      ..duration = AppMotion.duracion(context, _crecerCalor)
      ..reverseDuration = AppMotion.duracion(context, AppMotion.normal);
    _pulso.duration = AppMotion.duracion(context, AppMotion.pulso);
    // Al abrir, el calor crece desde la ruta como en el video.
    if (_pintado && _calor.isDismissed) _crecer();
  }

  @override
  void didUpdateWidget(covariant _MapaCalor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.routeId != widget.routeId) _readRoute();
    if (oldWidget.cells != widget.cells ||
        oldWidget.routeId != widget.routeId) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitCamera());
      // Otra ruta u otra hora: el calor vuelve a crecer desde la ruta.
      if (_pintado) _crecer();
    }
  }

  @override
  void dispose() {
    _nivel.dispose();
    _calor.dispose();
    _pulso.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _alCambiarCalor(AnimationStatus status) {
    if (status == AnimationStatus.completed) _pulso.forward(from: 0);
    // Apagado del todo, la capa sale del árbol.
    if (status == AnimationStatus.dismissed && mounted) setState(() {});
  }

  void _crecer() {
    _pulso.reset();
    _calor.forward(from: 0);
  }

  void _alternar() {
    setState(() => _pintado = !_pintado);
    _pintado ? _crecer() : _calor.reverse();
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
            if (_routePoints.length > 1)
              AnimatedBuilder(
                animation: _nivel,
                builder: (context, _) {
                  // Con el calor pintado el corredor ya dibuja la ruta y en
                  // el video no hay línea debajo: se apaga del todo.
                  final queda = 1 - _nivel.value.clamp(0.0, 1.0);
                  return PolylineLayer(
                    polylines: [
                      Polyline(
                        points: _routePoints,
                        color: orla.withValues(
                          alpha: EstiloRuta.orla.lineOpacity * queda,
                        ),
                        strokeWidth: EstiloRuta.orla.lineWidth,
                        strokeCap: StrokeCap.round,
                        strokeJoin: StrokeJoin.round,
                      ),
                      Polyline(
                        points: _routePoints,
                        color: linea.withValues(alpha: queda),
                        strokeWidth: EstiloRuta.linea.lineWidth,
                        strokeCap: StrokeCap.round,
                        strokeJoin: StrokeJoin.round,
                      ),
                    ],
                  );
                },
              ),
            if (_pintado || !_calor.isDismissed)
              _CapaCalor(
                key: ValueKey('capa-calor-${widget.routeId}'),
                cells: widget.cells,
                nivel: _nivel,
                pulso: _pulso,
              ),
          ],
        ),
        Positioned(
          left: 16,
          top: 16,
          child: _BotonPintar(pintado: _pintado, onTap: _alternar),
        ),
        Positioned(
          left: 16,
          bottom: 16,
          // En columna: con la ventana mínima (1200 px) la fila de las dos
          // tarjetas pisaría la atribución del mapa.
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // La leyenda solo explica lo que está pintado; entra subiendo
              // 8 px, como la tarjeta del video.
              AnimatedSwitcher(
                duration: AppMotion.duracion(context, AppMotion.normal),
                switchInCurve: AppMotion.curvaEntrada,
                switchOutCurve: AppMotion.curvaSalida,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween(
                      begin: Offset(0, 0.1 * AppMotion.desplazamiento(context)),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                ),
                child: _pintado
                    ? Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _LeyendaCalor(
                          codigo: widget.codigo,
                          maxCount: maxCount,
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
              _HorasMapa(
                porHora: widget.porHora,
                hora: widget.hora,
                onSelectHour: widget.onSelectHour,
              ),
            ],
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
/// manchas sueltas. Al pintarse nace verde y sube a sus tonos con [nivel];
/// al final un anillo blanco se abre en cada pico, como en el video.
class _CapaCalor extends StatefulWidget {
  const _CapaCalor({
    super.key,
    required this.cells,
    required this.nivel,
    required this.pulso,
  });

  final List<CeldaBusqueda> cells;
  final Animation<double> nivel;
  final Animation<double> pulso;

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
            pulso: widget.pulso,
          ),
        ),
      ),
    );
  }
}

/// El campo de calor ya coloreado, en dos imágenes (verde del arranque y
/// tonos finales) con sus esquinas en el mapa y sus picos.
class _RasterCalor {
  _RasterCalor._(
    this.verde,
    this.color,
    this.noroeste,
    this.sureste,
    this.picos,
  );

  final ui.Image verde;
  final ui.Image color;
  final LatLng noroeste;
  final LatLng sureste;
  final List<LatLng> picos;

  // Cada búsqueda se reparte en una campana de 200 m: con celdas de unos
  // 150 m (`PASO_LAT` del backend) las vecinas se funden en un corredor
  // de unos 600 m, el ancho de la banda del video. Bajo 12 px el corredor
  // se vuelve un hilo al alejar el mapa.
  static const _sigmaMetros = 200.0;
  static const _sigmaMinimoPx = 12.0;
  // Un píxel del campo cubre al menos 2 del mapa; el lado no pasa de 1200.
  static const _ladoMaximo = 1200;
  // Picos: sobre la mitad del máximo y a más de 1,2 km entre sí; tres como
  // mucho, como en el video.
  static const _picoDesde = 0.5;
  static const _picosSeparacionMetros = 1200.0;
  static const _picosMaximo = 3;

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
    final base = _coloresCalor.first;
    for (var i = 0; i < d.length; i++) {
      final borde = _suave(0.03, 0.8, s[i]);
      if (borde <= 0) continue;
      // Potencia 0,7: el corredor (unas 25 búsquedas contra 500 del foco)
      // queda verde, como en el video, y los focos suben a amarillo, naranja
      // y rojo en una mancha ancha, no en un punto.
      final t = math.pow(d[i] / dMax, 0.7).toDouble();
      // Corredor al 55 %, como el del video, deja leer las calles debajo;
      // los focos llegan al 90 %.
      _pixel(color, i * 4, _colorEnEscala(t), borde * (0.55 + 0.35 * t));
      _pixel(verde, i * 4, base, borde * 0.55);
    }

    final separacion = _picosSeparacionMetros * pxPorMetro / escala;
    final candidatos = [
      for (var i = 0; i < d.length; i++)
        if (d[i] >= _picoDesde * dMax) i,
    ]..sort((a, b) => d[b].compareTo(d[a]));
    final picos = <int>[];
    for (final i in candidatos) {
      if (picos.length == _picosMaximo) break;
      final lejos = picos.every(
        (p) =>
            math.sqrt(
              math.pow(p % ancho - i % ancho, 2) +
                  math.pow(p ~/ ancho - i ~/ ancho, 2),
            ) >=
            separacion,
      );
      if (lejos) picos.add(i);
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
      [for (final p in picos) aMapa((p % ancho) + 0.5, (p ~/ ancho) + 0.5)],
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
    required this.pulso,
  }) : super(repaint: Listenable.merge([nivel, pulso]));

  final MapCamera camera;
  final _RasterCalor? raster;
  final Animation<double> nivel;
  final Animation<double> pulso;

  // El anillo se abre de 5 a 26 px y se queda, como los del video, que
  // rodean el foco sin salirse de la banda; el punto blanco marca el centro.
  static const _anilloDesdePx = 5.0;
  static const _anilloHastaPx = 26.0;
  static const _puntoPx = 5.0;

  @override
  void paint(Canvas canvas, Size size) {
    final r = raster;
    if (r == null) return;
    final n = nivel.value.clamp(0.0, 1.0);
    // El corredor aparece en el primer 40 % y el resto sube de tono. El
    // tono va en cuadrático: el resorte llega casi entero a la mitad del
    // tiempo, y sin esto el verde del arranque (32,3 s del video) ni se ve.
    final aparece = (n / 0.4).clamp(0.0, 1.0);
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

    final p = pulso.value;
    if (p <= 0) return;
    final abre = Curves.easeOutCubic.transform(p);
    final aparecePico = (p * 4).clamp(0.0, 1.0) * n;
    for (final pico in r.picos) {
      final centro = camera.getOffsetFromOrigin(pico);
      canvas
        ..drawCircle(
          centro,
          _puntoPx,
          Paint()..color = Colors.white.withValues(alpha: 0.95 * aparecePico),
        )
        ..drawCircle(
          centro,
          _anilloDesdePx + (_anilloHastaPx - _anilloDesdePx) * abre,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6
            ..color = Colors.white.withValues(alpha: 0.85 * aparecePico),
        );
    }
  }

  @override
  bool shouldRepaint(_PintorCalor oldDelegate) =>
      oldDelegate.camera != camera ||
      oldDelegate.raster != raster ||
      oldDelegate.nivel != nivel ||
      oldDelegate.pulso != pulso;
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

/// Las 24 horas de la ruta sobre el mapa: cada barra mide sus búsquedas en
/// la escala del calor y al tocarla el mapa se pinta solo a esa hora; tocar
/// la elegida, o «Todo el día», vuelve al día entero.
class _HorasMapa extends StatelessWidget {
  const _HorasMapa({
    required this.porHora,
    required this.hora,
    required this.onSelectHour,
  });

  final List<int> porHora;
  final int? hora;
  final ValueChanged<int?> onSelectHour;

  // 336 px: con 12 de aire por lado quedan 312 para 24 barras de 11 px y
  // 23 huecos de 2 px, el ancho más chico que todavía se apunta con el
  // ratón sin errar de hora.
  static const _ancho = 336.0;
  static const _altoBarras = 30.0;

  @override
  Widget build(BuildContext context) {
    final maximo = porHora.fold<int>(0, math.max);
    return Container(
      width: _ancho,
      padding: const EdgeInsets.fromLTRB(12, 9, 12, 8),
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
              const Icon(
                Icons.schedule_outlined,
                size: 14,
                color: AppColors.navy,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  hora == null ? 'Todo el día' : horaPicoLabel(hora!),
                  key: const ValueKey('hora-mapa-rotulo'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.ui(
                    color: AppColors.navy,
                    fontSize: 11,
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
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
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
              // Como la tira de la lista: una marca cada seis barras.
              for (var h = 0; h < 24; h += 6)
                Expanded(
                  child: Text(
                    horaOpcionLabel(h),
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
                    color: _colorCalor(
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

/// Tarjeta de la leyenda como la del video de Control: la ficha de la ruta,
/// el alcance del aviso (se arma hasta 3 km a la redonda, así que se busca
/// también lejos de la calle) y la escala de menos a más.
class _LeyendaCalor extends StatelessWidget {
  const _LeyendaCalor({required this.codigo, required this.maxCount});
  final String codigo;
  final int maxCount;

  @override
  Widget build(BuildContext context) {
    final rotulo = AppType.ui(
      color: AppColors.textSecondary,
      fontSize: 9.5,
      fontWeight: FontWeight.w700,
    );
    return Semantics(
      label:
          'Ruta $codigo, solo por donde pasa. Menos búsquedas a más '
          'búsquedas, máximo $maxCount en una zona',
      child: ExcludeSemantics(
        // Del ancho de las horas, para que las dos tarjetas del mapa se
        // lean como una sola columna alineada.
        child: Container(
          width: _HorasMapa._ancho,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.boton,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Text(
                        codigo,
                        style: AppType.ui(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      'Solo por donde pasa',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.ui(
                        color: AppColors.textMuted,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // La barra continua del video, con la misma escala del mapa.
              Container(
                key: const ValueKey('leyenda-calor'),
                height: 6,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: _coloresCalor),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Con letra más grande del sistema se cortan antes de
                  // montarse una sobre otra.
                  Flexible(
                    child: Text(
                      'Menos búsquedas',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: rotulo,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Más búsquedas',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: rotulo,
                    ),
                  ),
                ],
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
