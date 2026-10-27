import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:ya_viene_core/core/providers/app_providers.dart'
    show enRespaldoProvider;
import 'package:ya_viene_core/shared/widgets/carga_fantasma.dart';
import 'package:ya_viene_core/shared/widgets/recuadro_latencia.dart';
import 'package:ya_viene_core/ya_viene_core.dart' show AppMotion;

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/ventana.dart';
import '../../../../shared/widgets/clock_widget.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/fleet_bus.dart';
import '../bus_estado.dart';
import '../providers/fleet_providers.dart';
import '../providers/reportes_provider.dart';
import '../widgets/bus_dialog.dart';
import '../widgets/control_map.dart';
import '../widgets/fleet_list_tile.dart';
import '../widgets/pildoras_ruta.dart';
import '../widgets/route_dialog.dart';
import '../widgets/ultimo_reporte.dart';
import '../widgets/velocidad_bus.dart';
import 'reportes_screen.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

/// Las dos pestañas de la cabecera del panel.
enum PestanaPanel { flota, reportes }

class _DashboardScreenState extends ConsumerState<DashboardScreen>
    with WidgetsBindingObserver {
  PestanaPanel _pestana = PestanaPanel.flota;
  bool _reportesAbiertos = false;

  final _searchController = TextEditingController();
  final _searchFocus = FocusNode(debugLabel: 'buscar');
  String _query = '';
  bool _refreshing = false;
  ProviderSubscription<bool>? _sessionExpiredSub;

  /// Cada búsqueda de un pasajero suma en el servidor al momento: con
  /// Reportes a la vista se vuelve a pedir cada 30 s para que se vea sumar
  /// sin tocar nada. Con Flota a la vista no se pide.
  late final Timer _reportesAlDia;

  @override
  void initState() {
    super.initState();
    _sessionExpiredSub = ref.listenManual(
      fleetProvider.select((s) => s.sessionExpired),
      (previous, expired) {
        // Solo el paso a vencida: la bandera ya no baja hasta cerrar
        // sesión, así que esto pasa una vez por sesión.
        if (!expired || !mounted) return;
        // Sin salida por fuera: con la sesión vencida el tablero ya no
        // puede hacer nada, y cerrarla con Esc dejaba al operador mirando
        // datos que no se iban a actualizar.
        mostrarVentana<void>(
          context,
          cerrable: false,
          (dialogContext) => Ventana(
            icono: Icons.lock_clock_outlined,
            titulo: 'Tu sesión expiró',
            mensaje:
                'La sesión del administrador venció o fue revocada. '
                'Vuelve a iniciar sesión para continuar.',
            principal: VentanaAccion('INICIAR SESIÓN', () async {
              Navigator.of(dialogContext).pop();
              await _logout();
            }),
          ),
        );
      },
    );
    WidgetsBinding.instance.addObserver(this);
    _reportesAlDia = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_pestana == PestanaPanel.reportes) _actualizarReportes();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(fleetProvider.notifier).start();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // La ventana vuelve al frente: puede haberse perdido eventos mientras
    // el sistema tenía la conexión dormida, y esperar al siguiente minuto
    // sería justo cuando el operador está mirando la lista.
    if (state == AppLifecycleState.resumed) {
      ref.read(fleetProvider.notifier).alVolverAlFrente();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _reportesAlDia.cancel();
    _sessionExpiredSub?.close();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    final started = DateTime.now();
    _actualizarReportes();
    try {
      await ref.read(fleetProvider.notifier).refresh();
    } finally {
      final rest =
          const Duration(milliseconds: 700) -
          DateTime.now().difference(started);
      if (rest > Duration.zero) {
        await Future<void>.delayed(rest);
      }
      if (mounted) setState(() => _refreshing = false);
    }
  }

  void _actualizarReportes() {
    ref
      ..invalidate(reportesRutasProvider)
      ..invalidate(reportesCalorProvider);
  }

  Future<void> _logout() async {
    // Apaga el socket de flota y resetea el estado antes de salir: no queda
    // una conexión viva con la sesión ya cerrada.
    ref.read(fleetProvider.notifier).stop();
    await ref.read(authProvider.notifier).logout();
    if (mounted) context.go('/login');
  }

  void _showBusDialog({FleetBus? bus}) {
    mostrarVentana<void>(
      context,
      (dialogContext) => BusDialog(
        bus: bus,
        onDelete: bus == null
            ? null
            : () async {
                try {
                  await ref.read(fleetProvider.notifier).removeBus(bus.busId);
                } catch (_) {
                  if (mounted) {
                    mostrarAvisoPanel(context, 'No se pudo eliminar el bus.');
                  }
                }
              },
      ),
    );
  }

  void _showRouteDialog() {
    mostrarVentana<void>(context, (_) => const RouteDialog());
  }

  Future<void> _confirmDeleteSelected(FleetBus bus) async {
    final confirmed = await confirmarBorrado(
      context,
      titulo: 'Eliminar bus',
      mensaje:
          '¿Eliminar ${bus.placa.isEmpty ? bus.busId : bus.placa} de la '
          'flota? Los pasajeros dejarán de verlo de inmediato. Esta acción no '
          'se puede deshacer.',
    );
    if (confirmed) {
      try {
        await ref.read(fleetProvider.notifier).removeBus(bus.busId);
      } catch (_) {
        if (mounted) mostrarAvisoPanel(context, 'No se pudo eliminar el bus.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Solo lo que el dashboard pinta: una posición que únicamente mueve al
    // bus en el mapa no reconstruye la lista (el mapa escucha aparte). Antes
    // cada `bus:position` —doce buses, uno por segundo— rehacía el dashboard
    // entero con todas sus tarjetas (R-27, N-PERF1).
    final fleet = ref.watch(fleetProvider.select(_VistaDashboard.new)).estado;

    final buses = fleet.buscar(_query);

    // Teclado: el panel es de escritorio. Tab va por secciones, de arriba
    // abajo y de izquierda a derecha: cabecera, barra, filtros de ruta, la
    // lista (botones, pestañas y cada bus con su lápiz y su interruptor
    // antes del siguiente) y el mapa. La política por omisión ordena por
    // filas de pantalla, y como las de la lista no se alinean con las del
    // mapa, saltaba de pestañas a buses a lápices sin orden. Cmd+F (Ctrl+F
    // fuera de macOS) lleva a la búsqueda, como en cualquier programa de
    // escritorio (test/teclado_panel_test.dart).
    final buscar = SingleActivator(
      LogicalKeyboardKey.keyF,
      meta: defaultTargetPlatform == TargetPlatform.macOS,
      control: defaultTargetPlatform != TargetPlatform.macOS,
    );
    return CallbackShortcuts(
      // En Reportes la búsqueda no está a la vista: el atajo no hace nada.
      bindings: {
        if (_pestana == PestanaPanel.flota) buscar: _searchFocus.requestFocus,
      },
      child: FocusTraversalGroup(
        policy: OrderedTraversalPolicy(),
        child: _cuerpo(fleet, buses),
      ),
    );
  }

  Widget _cuerpo(FleetState fleet, List<FleetBus> buses) {
    return Scaffold(
      // Blanco, no la arena del tema (dueño, 2026-10-07): las tarjetas se
      // separan por su filo. El login sigue en arena.
      backgroundColor: AppColors.surface,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _seccion(
            1,
            DashboardHeader(
              connection: fleet.connection,
              onLogout: _logout,
              refreshing: _refreshing,
              onRefresh: _refresh,
              pestana: _pestana,
              onPestana: (pestana) => setState(() {
                _pestana = pestana;
                _reportesAbiertos |= pestana == PestanaPanel.reportes;
              }),
            ),
          ),
          // Las dos pestañas quedan montadas: al volver a Flota el mapa
          // sigue donde estaba, y Reportes conserva su periodo y su ruta.
          // Reportes se arma la primera vez que se abre, no antes.
          Expanded(
            child: _CarrilPestanas(
              indice: _pestana.index,
              children: [
                _flota(fleet, buses),
                _reportesAbiertos
                    ? _seccion(2, const ReportesScreen())
                    : const SizedBox.shrink(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _flota(FleetState fleet, List<FleetBus> buses) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _seccion(
          2,
          _TopBar(
            searchController: _searchController,
            searchFocus: _searchFocus,
            onSearchChanged: (v) => setState(() => _query = v),
            onToggleAllVisibility: () {
              final visible = !fleet.buses.values.every((b) => b.visible);
              ref.read(fleetProvider.notifier).setAllVisibility(visible);
            },
            allBusesVisible:
                fleet.buses.isNotEmpty &&
                fleet.buses.values.every((b) => b.visible),
            error: fleet.error,
            onReintentar: () => ref.read(fleetProvider.notifier).refresh(),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: _seccion(
            4,
            _RouteFilters(
              fleet: fleet,
              onSelect: (routeId) =>
                  ref.read(fleetProvider.notifier).setRouteFilter(routeId),
              onAddRoute: _showRouteDialog,
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 1,
                  child: _seccion(
                    5,
                    _FleetPanel(
                      buses: buses,
                      fleet: fleet,
                      onAddBus: () => _showBusDialog(),
                      onEditBus: (bus) => _showBusDialog(bus: bus),
                      onStatusFilter: (filter) => ref
                          .read(fleetProvider.notifier)
                          .setStatusFilter(filter),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  // Con las esquinas de la lista (lg): era el único bloque
                  // de la pantalla con esquinas rectas. El filo va encima
                  // de las teselas para que el recorte no lo corte.
                  child: _seccion(
                    6,
                    // La sombra va por fuera del recorte, que si no la corta.
                    DecoratedBox(
                      key: const ValueKey('marco_mapa'),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        boxShadow: AppColors.sombraTarjeta,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        child: DecoratedBox(
                          position: DecorationPosition.foreground,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(AppRadius.lg),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Stack(
                            children: [
                              const Positioned.fill(child: ControlMap()),
                              // T7.6: lo que tarda una posición en llegar del bus
                              // a esta pantalla. Solo en depuración y si se pide
                              // al compilar (`RecuadroLatencia.pedido`).
                              if (RecuadroLatencia.pedido)
                                const Positioned(
                                  left: 16,
                                  bottom: 16,
                                  child: RecuadroLatencia(),
                                ),
                              if (fleet.selectedBus != null)
                                Positioned(
                                  right: 16,
                                  bottom: 16,
                                  child: _SelectedBusCard(
                                    bus: fleet.selectedBus!,
                                    routeName: fleet.routeName(
                                      fleet.selectedBus!.routeId,
                                    ),
                                    updating: fleet.updating.contains(
                                      fleet.selectedBus!.busId,
                                    ),
                                    onToggle: (visible) => ref
                                        .read(fleetProvider.notifier)
                                        .toggleVisibility(
                                          fleet.selectedBus!.busId,
                                          visible,
                                        ),
                                    onEdit: () =>
                                        _showBusDialog(bus: fleet.selectedBus),
                                    onDelete: () => _confirmDeleteSelected(
                                      fleet.selectedBus!,
                                    ),
                                    onClose: () => ref
                                        .read(fleetProvider.notifier)
                                        .selectBus(null),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// El estado de la flota visto por el dashboard: dos vistas son iguales si
/// el dashboard las pinta igual. [estado] puede traer posiciones viejas —el
/// `select` se queda con la vista anterior mientras sea igual—, así que aquí
/// nada lee lat, lon ni velocidad: eso es del mapa.
class _VistaDashboard {
  const _VistaDashboard(this.estado);

  final FleetState estado;

  @override
  bool operator ==(Object other) {
    if (other is! _VistaDashboard) return false;
    final a = estado;
    final b = other.estado;
    if (identical(a, b)) return true;
    if (a.connection != b.connection ||
        a.error != b.error ||
        a.selectedBusId != b.selectedBusId ||
        a.routeFilter != b.routeFilter ||
        a.statusFilter != b.statusFilter ||
        a.sessionExpired != b.sessionExpired ||
        a.flotaCargada != b.flotaCargada ||
        // `copyWith` conserva la misma lista y el mismo conjunto si no
        // cambian, y los reemplaza enteros cuando cambian.
        !identical(a.routes, b.routes) ||
        !identical(a.updating, b.updating) ||
        a.buses.length != b.buses.length) {
      return false;
    }
    for (final MapEntry(key: id, value: bus) in a.buses.entries) {
      final otro = b.buses[id];
      if (otro == null || !bus.mismaFicha(otro)) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(estado.connection, estado.buses.length);
}

/// Una parada de Tab en el orden del dashboard: todo lo de dentro se
/// recorre antes de pasar a la siguiente, en el orden en que se construye.
Widget _seccion(double orden, Widget child) => FocusTraversalOrder(
  order: NumericFocusOrder(orden),
  child: FocusTraversalGroup(
    policy: WidgetOrderTraversalPolicy(),
    child: child,
  ),
);

/// La cabecera del panel. Pública solo para probarla sin montar el mapa.
@visibleForTesting
class DashboardHeader extends ConsumerWidget {
  const DashboardHeader({
    super.key,
    required this.connection,
    required this.onLogout,
    this.pestana = PestanaPanel.flota,
    this.onPestana,
    this.refreshing = false,
    this.onRefresh,
  });

  final FleetConnection connection;
  final VoidCallback onLogout;
  final PestanaPanel pestana;
  final ValueChanged<PestanaPanel>? onPestana;
  final bool refreshing;

  /// Pone al día la flota y los reportes: va en la cabecera para servir a
  /// las dos pestañas.
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Con D1 = espejo de la demo, el respaldo sirve una flota simulada: el
    // operador tiene que saber que lo que ve no es la flota del túnel.
    final enRespaldo = ref.watch(enRespaldoProvider);
    // En línea y sin conexión van llenos con la letra blanca (dueño,
    // 2026-10-27); conectando, que dura un instante, en su matiz ámbar.
    final (label, fondo, color) = switch (connection) {
      FleetConnection.connected => (
        'En línea',
        AppColors.capsula,
        Colors.white,
      ),
      FleetConnection.disconnected => (
        'Sin conexión',
        AppColors.sinConexion,
        Colors.white,
      ),
      FleetConnection.connecting => (
        'Conectando…',
        AppColors.ghost.withValues(alpha: 0.1),
        AppColors.ghost,
      ),
    };
    return Container(
      key: const ValueKey('cabecera'),
      // La sombra hace de filo: sobre el tablero blanco la raya sola no la
      // despegaba.
      decoration: const BoxDecoration(
        color: AppColors.surface,
        boxShadow: AppColors.sombraCabecera,
      ),
      padding: const EdgeInsets.fromLTRB(20, 10, 16, 10),
      child: Row(
        children: [
          // El logo solo, sin el cuadro gris que lo encerraba (dueño,
          // 2026-10-26): 32 de alto, centrado con las pestañas.
          SvgPicture.asset(
            'assets/logo/ya_viene_logo.svg',
            height: 32,
            fit: BoxFit.contain,
          ),
          // Donde iba el rótulo «Ya Viene, control de flota», las dos
          // pestañas del panel (dueño, 2026-10-26): el logo ya dice de quién
          // es, y el texto sobraba.
          const SizedBox(width: 18),
          _Pestanas(pestana: pestana, onPestana: onPestana ?? (_) {}),
          const Spacer(),
          if (enRespaldo) ...[
            Text(
              'Conectado al respaldo',
              style: AppType.ui(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 12),
          ],
          Container(
            key: const ValueKey('chip-conexion'),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: fondo,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 7),
                Text(
                  label,
                  style: AppType.ui(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _BotonActualizar(refreshing: refreshing, onRefresh: onRefresh),
          const SizedBox(width: 8),
          // Salir revoca el token en el servidor, y eso corta todas las
          // sesiones de la cuenta (`AuthApi.logout`): quien tenga el panel
          // abierto con el mismo usuario en otro equipo vuelve a pedir la
          // clave. Que se lea antes de pulsar, no que se descubra después.
          Tooltip(
            message: 'Cierra la sesión en todos los equipos con esta cuenta',
            child: OutlinedButton.icon(
              onPressed: onLogout,
              icon: const Icon(Icons.logout, size: 15),
              label: const Text('Salir'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                side: const BorderSide(color: AppColors.borderStrong),
                minimumSize: const Size(0, 36),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                textStyle: AppType.ui(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Actualizar, del mismo alto y filo que Salir (36): un cuadro con la
/// flecha que da una vuelta con el resorte de los cambios cada vez que se
/// pulsa, mientras se piden los datos.
class _BotonActualizar extends StatefulWidget {
  const _BotonActualizar({required this.refreshing, required this.onRefresh});

  final bool refreshing;
  final VoidCallback? onRefresh;

  @override
  State<_BotonActualizar> createState() => _BotonActualizarState();
}

class _BotonActualizarState extends State<_BotonActualizar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _vuelta = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  );

  @override
  void didUpdateWidget(_BotonActualizar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.refreshing && !oldWidget.refreshing) {
      _vuelta.duration = AppMotion.duracion(
        context,
        const Duration(milliseconds: 800),
      );
      _vuelta.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _vuelta.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IconButton(
    key: const ValueKey('actualizar'),
    onPressed: widget.refreshing ? null : widget.onRefresh,
    tooltip: 'Actualizar',
    icon: RotationTransition(
      turns: CurvedAnimation(parent: _vuelta, curve: AppMotion.curvaCambio),
      child: const Icon(Icons.refresh, size: 18),
    ),
    style: IconButton.styleFrom(
      // El mínimo de 40 del tema le ganaba al tamaño fijo.
      minimumSize: const Size(36, 36),
      fixedSize: const Size(36, 36),
      padding: EdgeInsets.zero,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      foregroundColor: AppColors.textSecondary,
      disabledForegroundColor: AppColors.textSecondary,
      side: const BorderSide(color: AppColors.borderStrong),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
    ),
  );
}

/// El resorte de la píldora del pasajero (`PildoraNavegacion.resorte`):
/// amortiguado del todo y con respuesta de 0,3 s. Cápsula y pantalla se
/// mueven con él, así llegan juntas; si se cambia a mitad, sigue desde
/// donde iba y con la velocidad que traía.
final _resortePestanas = SpringDescription.withDampingRatio(
  mass: 1,
  stiffness: math.pow(2 * math.pi / 0.3, 2).toDouble(),
);

/// Flota y Reportes como la píldora de abajo del pasajero (dueño,
/// 2026-10-26: el riel gris con su lámina se veía raro): una píldora
/// blanca con su filo y la pestaña puesta sobre una cápsula verde clara,
/// que va de una a otra con [_resortePestanas]. La puesta en verde
/// accesible sobre la cápsula (4,94:1) y la otra en gris secundario sobre
/// blanco (5,38:1). Las dos miden lo que la más ancha (con su texto,
/// también agrandado), así la cápsula no cambia de ancho al moverse.
class _Pestanas extends StatefulWidget {
  const _Pestanas({required this.pestana, required this.onPestana});

  final PestanaPanel pestana;
  final ValueChanged<PestanaPanel> onPestana;

  static const _opciones = [
    (
      PestanaPanel.flota,
      'Flota',
      Icons.directions_bus_outlined,
      Icons.directions_bus_rounded,
    ),
    (
      PestanaPanel.reportes,
      'Reportes',
      Icons.insights_outlined,
      Icons.insights_rounded,
    ),
  ];

  /// Margen entre la cápsula y el canto de la píldora: con las pestañas de
  /// 34, los 40 de la cabecera.
  static const double margen = 3;

  @override
  State<_Pestanas> createState() => _PestanasState();
}

class _PestanasState extends State<_Pestanas>
    with SingleTickerProviderStateMixin {
  /// Dónde está la cápsula, en pestañas. Sin límites para que el resorte
  /// llegue con su velocidad.
  late final _capsula = AnimationController.unbounded(
    vsync: this,
    value: widget.pestana.index.toDouble(),
  );

  @override
  void didUpdateWidget(_Pestanas viejo) {
    super.didUpdateWidget(viejo);
    if (viejo.pestana != widget.pestana) {
      _deslizar(_capsula, widget.pestana.index, context);
    }
  }

  @override
  void dispose() {
    _capsula.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ultima = _Pestanas._opciones.length - 1;
    return DecoratedBox(
      // El blanco, el filo y la sombra de la píldora del pasajero, con la
      // sombra más corta: aquí va dentro de la cabecera, no flota.
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.filoPildora),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(_Pestanas.margen),
        child: IntrinsicWidth(
          child: Stack(
            children: [
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _capsula,
                  builder: (context, child) => Align(
                    // 0 a la izquierda, la última a la derecha.
                    alignment: Alignment(-1 + 2 * _capsula.value / ultima, 0),
                    child: child,
                  ),
                  child: FractionallySizedBox(
                    key: const ValueKey('capsula-pestanas'),
                    widthFactor: 1 / _Pestanas._opciones.length,
                    heightFactor: 1,
                    child: const DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppColors.capsula,
                        borderRadius: BorderRadius.all(
                          Radius.circular(AppRadius.pill),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Row(
                children: [
                  for (final (valor, texto, icono, iconoPuesto)
                      in _Pestanas._opciones)
                    Expanded(
                      child: _Pestana(
                        key: ValueKey('pestana-${valor.name}'),
                        texto: texto,
                        icono: valor == widget.pestana ? iconoPuesto : icono,
                        elegida: valor == widget.pestana,
                        onTap: () => widget.onPestana(valor),
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

/// Lleva [t] a [indice] con [_resortePestanas], desde donde va y con la
/// velocidad que trae. Con el movimiento reducido, salta.
void _deslizar(AnimationController t, int indice, BuildContext context) {
  if (AppMotion.reducido(context)) {
    t.value = indice.toDouble();
    return;
  }
  t.animateWith(
    SpringSimulation(
      _resortePestanas,
      t.value,
      indice.toDouble(),
      t.velocity,
      // Termina justo en su sitio: a una diezmilésima, la pantalla que sale
      // seguiría montada.
      snapToEnd: true,
    ),
  );
}

class _Pestana extends StatefulWidget {
  const _Pestana({
    super.key,
    required this.texto,
    required this.icono,
    required this.elegida,
    required this.onTap,
  });

  final String texto;
  final IconData icono;
  final bool elegida;
  final VoidCallback onTap;

  @override
  State<_Pestana> createState() => _PestanaState();
}

class _PestanaState extends State<_Pestana> {
  bool _apretada = false;

  void _apretar(bool si) => setState(() => _apretada = si);

  @override
  Widget build(BuildContext context) {
    // Blanco sobre la cápsula verde oscuro (5,48:1); gris secundario sobre el
    // blanco (5,38:1).
    final color = widget.elegida ? Colors.white : AppColors.textSecondary;
    return Semantics(
      button: true,
      selected: widget.elegida,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          onTapDown: (_) => _apretar(true),
          onTapUp: (_) => _apretar(false),
          onTapCancel: () => _apretar(false),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          hoverColor: Colors.transparent,
          splashFactory: NoSplash.splashFactory,
          highlightColor: Colors.transparent,
          child: AnimatedScale(
            // Responde en el instante en que se aprieta, no al soltar, como
            // la píldora del pasajero.
            scale: _apretada ? 0.94 : 1,
            duration: AppMotion.duracion(context, AppMotion.instante),
            curve: AppMotion.curvaSalida,
            child: Container(
              constraints: const BoxConstraints(minHeight: 34),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: TweenAnimationBuilder<Color?>(
                duration: AppMotion.duracion(context, AppMotion.normal),
                curve: AppMotion.curvaCambio,
                tween: ColorTween(end: color),
                builder: (context, color, _) => Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(widget.icono, size: 16, color: color),
                    const SizedBox(width: 7),
                    Text(
                      widget.texto,
                      style: AppType.ui(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: color,
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
}

/// La barra de Flota, sin título (dueño, 2026-10-26: la pestaña ya lo
/// dice): el buscador y ocultar todos a la izquierda, donde iba «Flota», y
/// el reloj a la derecha. Actualizar subió a la cabecera.
class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.searchController,
    required this.searchFocus,
    required this.onSearchChanged,
    required this.onToggleAllVisibility,
    required this.allBusesVisible,
    required this.error,
    required this.onReintentar,
  });

  final TextEditingController searchController;
  final FocusNode searchFocus;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onToggleAllVisibility;
  final bool allBusesVisible;
  final String? error;
  final VoidCallback onReintentar;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const ValueKey('barra-superior'),
      padding: const EdgeInsets.fromLTRB(20, 16, 24, 12),
      child: Row(
        children: [
          // 20 a la izquierda: el buscador arranca en línea con el logo y
          // con las rutas de abajo.
          // El buscador y la barra de la flota, del mismo alto: la barra se
          // estira a lo que mida el campo (IntrinsicHeight), así que si la
          // letra crece los dos crecen juntos.
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 300,
                  // Esc vacía la búsqueda y deja el foco en ella, para escribir
                  // otra sin volver a buscarla.
                  child: CallbackShortcuts(
                    bindings: {
                      const SingleActivator(LogicalKeyboardKey.escape): () {
                        searchController.clear();
                        onSearchChanged('');
                      },
                    },
                    child: TextField(
                      controller: searchController,
                      focusNode: searchFocus,
                      onChanged: onSearchChanged,
                      style: AppType.ui(fontSize: 13.5),
                      decoration: const InputDecoration(
                        hintText: 'Buscar placa o ruta…',
                        prefixIcon: Icon(
                          Icons.search,
                          color: AppColors.textMuted,
                          size: 19,
                        ),
                        fillColor: AppColors.surface,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Mismo filo y mismo radio que el campo, como la barra de
                // herramientas de una ventana de macOS.
                Container(
                  key: const ValueKey('barra-flota'),
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: AppColors.borderStrong),
                  ),
                  // 40 de lado, que con los 3 de relleno y el filo dan los
                  // 48 del buscador; radio sm para ir paralelo a la barra.
                  child: IconButton(
                    onPressed: onToggleAllVisibility,
                    icon: Icon(
                      allBusesVisible ? Icons.visibility_off : Icons.visibility,
                      size: 20,
                      color: AppColors.textSecondary,
                    ),
                    tooltip: allBusesVisible
                        ? 'Ocultar todos los buses'
                        : 'Mostrar todos los buses',
                    style: IconButton.styleFrom(
                      fixedSize: const Size(40, 40),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          // El fallo se dice junto al reloj, en una píldora que entra y se
          // va sola, como la de estado de Mail; antes era una franja rosada
          // de lado a lado que empujaba todo hacia abajo (dueño, 2026-10-26).
          AnimatedSwitcher(
            duration: AppMotion.duracion(context, AppMotion.normal),
            switchInCurve: AppMotion.curvaEntrada,
            switchOutCurve: AppMotion.curvaSalida,
            transitionBuilder: (child, animacion) => FadeTransition(
              opacity: animacion,
              child: ScaleTransition(
                scale: Tween(begin: 0.96, end: 1.0).animate(animacion),
                alignment: Alignment.centerRight,
                child: child,
              ),
            ),
            child: error == null
                ? const SizedBox.shrink()
                : Padding(
                    key: ValueKey(error),
                    padding: const EdgeInsets.only(right: 20),
                    child: _AvisoFlota(
                      mensaje: error!,
                      onReintentar: onReintentar,
                    ),
                  ),
          ),
          const ClockWidget(
            timeColor: AppColors.textPrimary,
            dateColor: AppColors.textMuted,
          ),
        ],
      ),
    );
  }
}

/// Píldora blanca con filo, el punto rojo y «Reintentar» dentro. El texto
/// va en tinta (15,2:1 sobre blanco) y el rojo solo en el ícono: rojo
/// sobre rosado leía como franja de error de formulario.
class _AvisoFlota extends StatelessWidget {
  const _AvisoFlota({required this.mensaje, required this.onReintentar});

  final String mensaje;
  final VoidCallback onReintentar;

  @override
  Widget build(BuildContext context) => Semantics(
    key: const ValueKey('aviso-flota'),
    liveRegion: true,
    container: true,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.28)),
        boxShadow: AppColors.sombraTarjeta,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_rounded, color: AppColors.danger, size: 16),
            const SizedBox(width: 8),
            Text(
              mensaje,
              style: AppType.ui(
                color: AppColors.textPrimary,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 10),
            // Píldora dentro de la píldora: 4 de aire alrededor, radio
            // concéntrico.
            TextButton(
              onPressed: onReintentar,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.boton,
                backgroundColor: AppColors.boton.withValues(alpha: 0.08),
                minimumSize: const Size(0, 28),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: const StadiumBorder(),
                textStyle: AppType.ui(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Flota y Reportes montadas a la vez, una junto a la otra, como las
/// pantallas del pasajero bajo su píldora: al cambiar, la nueva entra de
/// lado con el mismo resorte que la cápsula, y llegan juntas (dueño,
/// 2026-10-26: el fundido se veía raro). La que queda fuera se saca de
/// escena (Offstage, sin foco ni relojes), como hacía el IndexedStack. Con
/// el movimiento reducido no hay deslizamiento: la nueva aparece con un
/// fundido corto.
class _CarrilPestanas extends StatefulWidget {
  const _CarrilPestanas({required this.indice, required this.children});

  final int indice;
  final List<Widget> children;

  @override
  State<_CarrilPestanas> createState() => _CarrilPestanasState();
}

class _CarrilPestanasState extends State<_CarrilPestanas>
    with TickerProviderStateMixin {
  late final _posicion = AnimationController.unbounded(
    vsync: this,
    value: widget.indice.toDouble(),
  );
  late final _fundido = AnimationController(vsync: this, value: 1);

  @override
  void didUpdateWidget(_CarrilPestanas viejo) {
    super.didUpdateWidget(viejo);
    if (viejo.indice == widget.indice) return;
    _deslizar(_posicion, widget.indice, context);
    if (AppMotion.reducido(context)) {
      _fundido.duration = AppMotion.rapido;
      _fundido.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _posicion.dispose();
    _fundido.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ClipRect(
    key: const ValueKey('carril-pestanas'),
    child: ListenableBuilder(
      listenable: _posicion,
      builder: (context, _) => Stack(
        fit: StackFit.expand,
        children: [
          for (var i = 0; i < widget.children.length; i++)
            Offstage(
              offstage: (i - _posicion.value).abs() >= 1,
              child: ExcludeFocus(
                excluding: i != widget.indice,
                child: IgnorePointer(
                  ignoring: i != widget.indice,
                  child: TickerMode(
                    enabled: (i - _posicion.value).abs() < 1,
                    child: FractionalTranslation(
                      translation: Offset(i - _posicion.value, 0),
                      // Siempre envuelta, para que el cambio no vuelva a
                      // montar la pantalla (el mapa perdería su sitio).
                      child: FadeTransition(
                        opacity: i == widget.indice
                            ? _fundido
                            : kAlwaysCompleteAnimation,
                        child: widget.children[i],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

class _RouteFilters extends StatefulWidget {
  const _RouteFilters({
    required this.fleet,
    required this.onSelect,
    required this.onAddRoute,
  });

  final FleetState fleet;
  final ValueChanged<String?> onSelect;
  final VoidCallback onAddRoute;

  @override
  State<_RouteFilters> createState() => _RouteFiltersState();
}

class _RouteFiltersState extends State<_RouteFilters> {
  @override
  Widget build(BuildContext context) {
    final fleet = widget.fleet;
    // «Agregar ruta» vive al final de las rutas y no en la cabecera de la
    // lista de buses: ahí compartía fila con «BUSES» y «Agregar bus» en un
    // cuarto de la pantalla, que a 1440 son 349 px para unos 376 de
    // botones, y el verde salía cortado contra el borde. Aquí tiene todo el
    // ancho, queda junto a lo que crea, y el orden de Tab no cambia: venía
    // justo después de la última ruta. Tiene el alto y la forma de las
    // píldoras de ruta (33 = los 42 de la fila menos los 9 de abajo que
    // deja la barra de desplazamiento).
    final agregar = Padding(
      padding: const EdgeInsets.only(left: 12, bottom: 9),
      child: OutlinedButton.icon(
        onPressed: widget.onAddRoute,
        icon: const Icon(Icons.add_road, size: 16),
        label: const Text('Agregar ruta'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textSecondary,
          side: const BorderSide(color: AppColors.borderStrong),
          shape: const StadiumBorder(),
          minimumSize: const Size(0, 33),
          fixedSize: const Size.fromHeight(33),
          textStyle: AppType.ui(fontSize: 11.5, fontWeight: FontWeight.w700),
          padding: const EdgeInsets.symmetric(horizontal: 14),
        ),
      ),
    );
    // Dos paradas de Tab con número: las píldoras se construyen al
    // desplazarse, después del botón, y por orden de construcción Tab
    // llegaba a «Agregar ruta» antes que a las rutas.
    return FocusTraversalGroup(
      policy: OrderedTraversalPolicy(),
      child: Row(
        children: [
          Expanded(child: _seccion(1, _rutas(fleet))),
          _seccion(2, agregar),
        ],
      ),
    );
  }

  Widget _rutas(FleetState fleet) => TiraPildoras(
    children: [
      for (final route in fleet.routes)
        PildoraRuta(
          label: '${route.name} (${route.total})',
          active: fleet.routeFilter == route.routeId,
          onTap: () => widget.onSelect(route.routeId),
        ),
    ],
  );
}

/// El filo entre buses, igual en las filas de verdad y en las fantasma: mismo
/// largo que cuando arrancaba en la placa (61 + 10), repartido a los dos lados.
const _filo = Divider(height: 9, indent: 36, endIndent: 36);

/// La forma de [FleetListTile] sin datos: el recuadro del bus, la placa y el
/// interruptor, con el mismo relleno y el mismo filo entre filas, para que al
/// llegar la flota las filas de verdad caigan donde estaban estas.
class _FilasFantasma extends StatelessWidget {
  const _FilasFantasma();

  /// Placas de largos distintos: todas iguales se leen como un patrón y no
  /// como una lista.
  static const _anchos = [96.0, 78.0, 104.0, 86.0];

  @override
  Widget build(BuildContext context) {
    Widget bloque(double ancho, double alto, double radio) => Container(
      width: ancho,
      height: alto,
      decoration: BoxDecoration(
        color: AppColors.borderStrong,
        borderRadius: BorderRadius.circular(radio),
      ),
    );
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _anchos.length,
      separatorBuilder: (_, _) => _filo,
      itemBuilder: (_, i) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 10, 8),
        // 46: lo que mide el interruptor con su rótulo de 9 debajo, que es
        // lo más alto de la fila de verdad.
        child: SizedBox(
          height: 46,
          child: Row(
            children: [
              bloque(36, 36, AppRadius.md),
              const SizedBox(width: 12),
              bloque(_anchos[i], 12, AppRadius.sm),
              const Spacer(),
              // El interruptor: 52 × 32 a tamaño compacto.
              bloque(44, 24, AppRadius.pill),
              const SizedBox(width: 6),
            ],
          ),
        ),
      ),
    );
  }
}

class _FleetPanel extends ConsumerWidget {
  const _FleetPanel({
    required this.buses,
    required this.fleet,
    required this.onAddBus,
    required this.onEditBus,
    required this.onStatusFilter,
  });

  final List<FleetBus> buses;
  final FleetState fleet;
  final VoidCallback onAddBus;
  final ValueChanged<FleetBus> onEditBus;
  final ValueChanged<FleetStatusFilter> onStatusFilter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      key: const ValueKey('lista'),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.sombraTarjeta,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 10),
            // `Wrap` y no `Row`: con la letra del sistema a 2× la lista, un
            // cuarto de la ventana, no tiene sitio para «BUSES», la cuenta y
            // «Agregar bus» juntos —se salía 74 px a 1200—. Si no caben, el
            // botón baja a su propia línea con el nombre entero, en vez de
            // cortarse o quedarse en un «+» mudo. Cuando caben, `spaceBetween`
            // lo deja contra el borde derecho, como el `Spacer` de antes
            // (panel_angosto_test.dart).
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'BUSES',
                      style: AppType.ui(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.navy.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Text(
                        '${buses.length}',
                        style: AppType.ui(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.navy,
                        ),
                      ),
                    ),
                  ],
                ),
                FilledButton.icon(
                  onPressed: onAddBus,
                  icon: const Icon(Icons.add, size: 17),
                  label: const Text('Agregar bus'),
                  // 36 de alto y no los 52 que hereda del tema, que son los
                  // de «INGRESAR»: encabeza una lista, no es la acción de la
                  // pantalla. Y sin el espaciado de las mayúsculas, que en
                  // «Agregar bus» separaba las letras sin razón.
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.online,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 36),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    textStyle: AppType.ui(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: _StatusTabs(fleet: fleet, onSelect: onStatusFilter),
          ),
          // Sin filo debajo: el carril de las pestañas ya cierra la cabecera.
          const SizedBox(height: 4),
          Expanded(
            // Rutas y flota se piden a la vez: si las rutas llegan antes, la
            // lista vacía no es «sin buses» sino «aún no llegan». Con error
            // no: el aviso de arriba lo dice y aquí queda el vacío de siempre.
            child: buses.isEmpty && !fleet.flotaCargada && fleet.error == null
                ? const CargaFantasma(
                    semanticsLabel: 'Cargando la flota',
                    child: _FilasFantasma(),
                  )
                : buses.isEmpty
                ? Center(
                    child: Text(
                      _emptyMessage(),
                      style: AppType.ui(
                        color: AppColors.textMuted,
                        fontSize: 13,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                    itemCount: buses.length,
                    // Las filas ya no son tarjetas: las separa un filo
                    // centrado en la barra (dueño, 2026-10-07; antes
                    // arrancaba en la placa). 9 de alto: 4 de aire a cada lado.
                    separatorBuilder: (_, _) => _filo,
                    itemBuilder: (context, index) {
                      final bus = buses[index];
                      return FleetListTile(
                        bus: bus,
                        selected: fleet.selectedBusId == bus.busId,
                        updating: fleet.updating.contains(bus.busId),
                        routeName: fleet.routeName(bus.routeId),
                        onTap: () => ref
                            .read(fleetProvider.notifier)
                            .selectBus(bus.busId),
                        onToggle: (visible) => ref
                            .read(fleetProvider.notifier)
                            .toggleVisibility(bus.busId, visible),
                        onEdit: () => onEditBus(bus),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  String _emptyMessage() {
    if (fleet.routeFilter == null) return 'Selecciona una ruta';
    if (fleet.statusFilter != FleetStatusFilter.all) {
      return switch (fleet.statusFilter) {
        FleetStatusFilter.online => 'Ningún bus en línea en esta ruta',
        FleetStatusFilter.hidden => 'Ningún bus oculto en esta ruta',
        FleetStatusFilter.offline => 'Ningún bus sin señal en esta ruta',
        FleetStatusFilter.all => 'Sin buses registrados',
      };
    }
    return 'Sin buses registrados';
  }
}

class _StatusTabs extends StatelessWidget {
  const _StatusTabs({required this.fleet, required this.onSelect});

  final FleetState fleet;
  final ValueChanged<FleetStatusFilter> onSelect;

  @override
  Widget build(BuildContext context) {
    final tabs = <(FleetStatusFilter, String, int)>[
      (FleetStatusFilter.all, 'Todos', fleet.totalBuses),
      (FleetStatusFilter.online, 'En Línea', fleet.onlineBuses),
      (FleetStatusFilter.hidden, 'Ocultos', fleet.hiddenBuses),
      (FleetStatusFilter.offline, 'Sin Señal', fleet.offlineBuses),
    ];
    // Un control segmentado: las cuatro se reparten la fila por igual en
    // vez de ir cada una a su ancho. A su ancho sumaban unos 337 px y la
    // lista es un cuarto de la pantalla —330 a 1366, 309 a 1280—, así que
    // «Sin Señal» salía cortada contra el borde. Repartidas, a 1440 se ven
    // casi igual que antes (llenaban 313 de 325), y si una no cabe encoge
    // su letra lo justo ([_StatusTab]) en vez de salirse.
    //
    // Y van en su carril, como el control segmentado de macOS: sueltas
    // sobre el blanco, las tres apagadas no se leían como opciones de lo
    // mismo. El carril se come 3 por lado y el hueco entre pestañas baja de
    // 4 a 2, así que a cada pestaña le queda lo mismo que antes.
    return Container(
      key: const ValueKey('carril-estados'),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          for (final (i, (filter, label, count)) in tabs.indexed) ...[
            if (i > 0) const SizedBox(width: 2),
            Expanded(
              child: _StatusTab(
                label: label,
                count: count,
                active: fleet.statusFilter == filter,
                onTap: () => onSelect(filter),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusTab extends StatelessWidget {
  const _StatusTab({
    required this.label,
    required this.count,
    required this.active,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // La elegida, en la lámina blanca del segmentado de macOS con una sombra
    // de un punto, no llena de azul: tinta sobre blanco y el número en gris
    // secundario (5,4:1).
    return Material(
      color: active ? AppColors.surface : Colors.transparent,
      elevation: active ? 1 : 0,
      shadowColor: AppColors.textPrimary.withValues(alpha: 0.25),
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          // Centrada en su cuarto de fila y, si no le alcanza —ventana
          // achicada a mano o letra del sistema grande—, encogida lo justo:
          // cortada, «Sin Se…» ya no diría qué filtra.
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: AppType.ui(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: active
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  '$count',
                  style: AppType.ui(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textMuted,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectedBusCard extends StatelessWidget {
  const _SelectedBusCard({
    required this.bus,
    required this.routeName,
    required this.updating,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
    required this.onClose,
  });

  final FleetBus bus;
  final String? routeName;
  final bool updating;
  final ValueChanged<bool> onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onClose;

  /// Lápiz y papelera: cuadrados del alto de «Ocultar» (40) y con su radio.
  /// Eran círculos junto a un botón rectangular y la fila se leía como tres
  /// piezas sueltas.
  static const _boton = Size(40, 40);
  static final _forma = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(AppRadius.md),
  );

  @override
  Widget build(BuildContext context) {
    final estado = BusEstado.de(bus);
    return Container(
      width: 292,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.sombraFlotante,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: estado.color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(
                  Icons.directions_bus,
                  color: estado.color,
                  size: 19,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bus.placa.isEmpty ? bus.busId : bus.placa,
                      style: AppType.ui(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    // El estado, con su ícono delante: el mismo que lleva el
                    // bus en la fila de la lista y en la leyenda del mapa, y
                    // la única forma de distinguirlo si el color no se ve.
                    // El rótulo pasa de gris claro a [AppColors.textSecondary]
                    // porque a 10,5 pt el anterior daba 2,4:1 sobre la
                    // tarjeta blanca: se leía como un texto apagado más.
                    Row(
                      children: [
                        Icon(estado.icono, size: 12, color: estado.color),
                        const SizedBox(width: 5),
                        Text(
                          estado.rotulo,
                          style: AppType.mono(
                            fontSize: 10.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.close,
                  color: AppColors.textMuted,
                  size: 18,
                ),
                onPressed: onClose,
                tooltip: 'Cerrar',
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          // La ruta, entera: en la fila de la lista ya no va. El conductor
          // tampoco va aquí: el de la flota de ejemplo, «Conductor 3001», no
          // le decía nada al operador.
          if (routeName != null) ...[
            const SizedBox(height: 10),
            _infoChip(
              icon: Icons.route,
              label: routeName!,
              color: AppColors.navy,
            ),
          ],
          const SizedBox(height: 12),
          // Lo vivo del bus, en su bandeja: la velocidad en grande y, debajo,
          // cuándo se supo de él. Cambia con cada posición y la ficha no
          // (R-27): este pedazo se suscribe solo a la hora y la velocidad de
          // su bus. La velocidad, solo si transmite (oculto también); la de
          // un bus callado es de hace rato y ya no dice nada.
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(
              color: AppColors.surfaceRaised,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.border),
            ),
            child: Consumer(
              builder: (context, ref, _) {
                final (reportadoEn, velocidad) = ref.watch(
                  fleetProvider.select((s) {
                    final vivo = s.buses[bus.busId];
                    return (
                      vivo?.receivedAt ?? vivo?.capturedAt,
                      vivo != null && BusEstado.transmite(vivo)
                          ? vivo.speedKmh
                          : null,
                    );
                  }),
                );
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    VelocidadBus(kmh: velocidad),
                    const SizedBox(height: 8),
                    UltimoReporte(reportadoEn: reportadoEn),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: updating ? null : () => onToggle(!bus.visible),
                  icon: Icon(
                    bus.visible ? Icons.visibility_off : Icons.visibility,
                    size: 16,
                  ),
                  label: Text(bus.visible ? 'Ocultar' : 'Mostrar'),
                  style: FilledButton.styleFrom(
                    backgroundColor: bus.visible
                        ? AppColors.hidden
                        : AppColors.online,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    // Como «Agregar bus»: sin el espaciado de las
                    // mayúsculas, que la palabra no lleva.
                    textStyle: AppType.ui(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                    minimumSize: const Size(0, 40),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 18),
                tooltip: 'Editar bus',
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.surfaceRaised,
                  side: const BorderSide(color: AppColors.border),
                  fixedSize: _boton,
                  shape: _forma,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: onDelete,
                icon: const Icon(
                  Icons.delete_outline,
                  size: 18,
                  color: AppColors.danger,
                ),
                tooltip: 'Eliminar bus de la flota',
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.danger.withValues(alpha: 0.08),
                  side: BorderSide(
                    color: AppColors.danger.withValues(alpha: 0.25),
                  ),
                  fixedSize: _boton,
                  shape: _forma,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: AppType.ui(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
