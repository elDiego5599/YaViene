import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import '../../../../core/utils/bus_labels.dart';
import '../../../map/presentation/providers/tracking_providers.dart';
import '../../../map/presentation/providers/user_location_provider.dart';
import '../../../map/presentation/utils/geo.dart';
import '../providers/alert_history_provider.dart';
import '../providers/proximity_alerts_provider.dart';

/// Centro de avisos: los avisos activos (esperando la notificación) y el
/// historial de los ya enviados. Permite desactivar, borrar de a uno o
/// borrar todo; borrar un aviso activo lo desactiva.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(alertHistoryProvider);
    final route = ref.watch(selectedRouteProvider);
    final location = ref.watch(userLocationProvider);
    // Sin ruta activa no hay buses que consultar (ni suscripción a '').
    final positions = route == null
        ? const <BusPosition>[]
        : ref.watch(busPositionsSourceProvider(route.id).select(
            (value) => value.value ?? const <BusPosition>[],
          ));

    // Orden editorial: primero los activos, luego los enviados. El orden de
    // persistencia se conserva para que la selección sea estable.
    final entries = [
      ...history.where((e) => !e.sent),
      ...history.where((e) => e.sent),
    ].toList();

    return Scaffold(
      // Era un gris azulado suelto (#F8FAFC). Las tarjetas son blancas y
      // el resto de superficies claras de la app son arena; un gris frío
      // entre ellas se lee como una pantalla de otra app.
      backgroundColor: AppColors.arena,
      appBar: AppBar(
        backgroundColor: AppColors.arena,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        // El menú la llama "Avisos", el estado vacío dice "avisos" y el
        // botón del mapa dice "Avísame". Esta era la única pantalla que
        // usaba otra palabra para la misma cosa.
        //
        // El título y la acción crecen con el texto del sistema, pero solo
        // hasta un punto: la barra mide 56 y no se estira, y con el texto
        // al triple el título y «Seleccionar» se salían 46 px por la
        // derecha. En iOS el título de la barra de navegación no crece con
        // Texto Dinámico —crecen el contenido y la vuelta atrás—, así que
        // ponerle techo aquí se parece más al sistema que dejarlo suelto.
        title: MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.3,
          child: const Text('Avisos'),
        ),
        leading: IconButton(
          // La flecha de la barra no es la de Material —que trae su
          // rótulo puesto—, es un icono a secas: sin esto se anuncia
          // «botón» y nada más.
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 20,
            semanticLabel: 'Volver',
          ),
          tooltip: 'Volver',
          color: AppColors.textPrimary,
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: entries.isEmpty
            ? null
            : [
                MediaQuery.withClampedTextScaling(
                  maxScaleFactor: 1.3,
                  child: const _SelectAction(),
                ),
              ],
      ),
      body: entries.isEmpty
          ? const _EmptyState()
          : _HistoryList(
              entries: entries,
              positions: positions,
              location: location,
              route: route,
            ),
    );
  }
}

/// Acción "Seleccionar"/"Borrar todas" en la barra superior.
class _SelectAction extends ConsumerWidget {
  const _SelectAction();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selection = ref.watch(alertSelectionProvider);
    final selecting = selection.active;

    return TextButton(
      onPressed: () {
        if (selecting) {
          // Borrar todo: los activos se desactivan, el historial se limpia.
          final notifier = ref.read(proximityAlertsProvider.notifier);
          for (final e in ref.read(alertHistoryProvider)) {
            if (!e.sent) {
              ref.read(activeAlertsProvider.notifier).deactivateAlert(e.busId);
              notifier.disarmAlert(e.busId);
            }
          }
          ref.read(alertHistoryProvider.notifier).clearAll();
          ref.read(alertSelectionProvider.notifier).clear();
        } else {
          ref.read(alertSelectionProvider.notifier).enter();
        }
      },
      style: TextButton.styleFrom(
        textStyle: AppTextStyles.etiqueta,
        foregroundColor: selecting ? AppColors.error : AppColors.primaryDeep,
        disabledForegroundColor: AppColors.textDisabled,
      ),
      child: Text(selecting ? 'Borrar todas' : 'Seleccionar'),
    );
  }
}

/// Estado del modo selección: activo o no, y el conjunto de busIds marcados.
class _SelectionState {
  final bool active;
  final Set<String> selected;

  const _SelectionState(this.active, this.selected);
}

class _SelectionNotifier extends StateNotifier<_SelectionState> {
  _SelectionNotifier() : super(const _SelectionState(false, {}));

  void enter() => state = const _SelectionState(true, {});

  void toggle(String busId) {
    final next = {...state.selected};
    if (!next.add(busId)) next.remove(busId);
    state = _SelectionState(true, next);
  }

  void clear() => state = const _SelectionState(false, {});
}

final alertSelectionProvider =
    StateNotifierProvider<_SelectionNotifier, _SelectionState>(
        (ref) => _SelectionNotifier());

class _HistoryList extends ConsumerStatefulWidget {
  final List<AlertHistoryEntry> entries;
  final List<BusPosition> positions;
  final UserLocationState location;
  final RouteInfo? route;

  const _HistoryList({
    required this.entries,
    required this.positions,
    required this.location,
    required this.route,
  });

  @override
  ConsumerState<_HistoryList> createState() => _HistoryListState();
}

class _HistoryListState extends ConsumerState<_HistoryList> {
  /// Los avisos que ya entraron alguna vez, por id de bus.
  ///
  /// `ListView` desmonta lo que sale de la pantalla y lo vuelve a construir
  /// al volver: sin esta memoria, cada aviso reentraba con su fundido cada
  /// vez que se desplazaba de vuelta a la vista, y la lista parecía estar
  /// cargando otra vez algo que ya estaba ahí.
  final Set<String> _yaEntraron = {};

  @override
  Widget build(BuildContext context) {
    final entries = widget.entries;
    final positions = widget.positions;
    final location = widget.location;
    final route = widget.route;
    final selection = ref.watch(alertSelectionProvider);
    final selecting = selection.active;
    final selected = selection.selected;

    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(
                20, AppSpacing.sm, 20, AppSpacing.xl),
            itemCount: entries.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final entry = entries[index];
              final pos = positions.cast<BusPosition?>().firstWhere(
                    (p) => p?.busId == entry.busId,
                    orElse: () => null,
                  );
              final distanceMeters =
                  !entry.sent && pos != null && location.hasPosition
                      ? haversineMeters(
                              location.lat!, location.lon!, pos.lat, pos.lon)
                          .round()
                      : null;
              return _TileEntrance(
                key: ValueKey(entry.busId),
                busId: entry.busId,
                yaEntraron: _yaEntraron,
                // El desfase se topa a los seis primeros: más allá, la
                // espera del último se notaría más que el efecto.
                orden: index.clamp(0, 5),
                child: _AlertTile(
                  entry: entry,
                  routeName: entry.routeName ??
                      (route?.id == entry.routeId ? route?.name : null),
                  distanceMeters: distanceMeters,
                  selecting: selecting,
                  selected: selected.contains(entry.busId),
                  onToggleSelect: () => ref
                      .read(alertSelectionProvider.notifier)
                      .toggle(entry.busId),
                  onDisable: () {
                    ref
                        .read(activeAlertsProvider.notifier)
                        .deactivateAlert(entry.busId);
                    ref
                        .read(proximityAlertsProvider.notifier)
                        .disarmAlert(entry.busId);
                    ref.read(alertHistoryProvider.notifier).remove(entry.busId);
                  },
                ),
              );
            },
          ),
        ),
        // Barra de acciones del modo selección.
        AnimatedSize(
          duration: AppMotion.rapido,
          curve: AppMotion.curvaEntrada,
          child: selecting
              ? Container(
                  padding: const EdgeInsets.fromLTRB(
                      20, AppSpacing.xs, 20, AppSpacing.lg),
                  child: SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        textStyle: AppTextStyles.boton,
                        backgroundColor: AppColors.error,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        disabledBackgroundColor: AppColors.divider,
                        disabledForegroundColor: AppColors.textDisabled,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppRadius.pill),
                        ),
                      ),
                      onPressed: selected.isEmpty
                          ? null
                          : () {
                              final notifier =
                                  ref.read(proximityAlertsProvider.notifier);
                              for (final busId in selected) {
                                ref
                                    .read(activeAlertsProvider.notifier)
                                    .deactivateAlert(busId);
                                notifier.disarmAlert(busId);
                                ref
                                    .read(alertHistoryProvider.notifier)
                                    .remove(busId);
                              }
                              ref.read(alertSelectionProvider.notifier).clear();
                            },
                      icon: const Icon(Icons.delete_outline_rounded, size: 20),
                      label: Text(
                        selected.isEmpty
                            ? 'Selecciona avisos'
                            : 'Borrar ${selected.length}',
                      ),
                    ),
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

/// Entrada suave de cada tile del historial: aparece con un fundido y un
/// pequeño deslizamiento hacia arriba al montarse (una sola vez, sin timers).
class _TileEntrance extends StatefulWidget {
  final Widget child;

  /// Puesto en la lista, para escalonar la entrada.
  final int orden;

  final String busId;

  /// Compartido con la lista: quién ya entró y no debe volver a hacerlo.
  final Set<String> yaEntraron;

  const _TileEntrance({
    super.key,
    required this.child,
    required this.orden,
    required this.busId,
    required this.yaEntraron,
  });

  @override
  State<_TileEntrance> createState() => _TileEntranceState();
}

class _TileEntranceState extends State<_TileEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  /// Declarada como `CurvedAnimation` y no como `Animation<double>`: el tipo
  /// general no tiene `dispose()`, y esta hay que desecharla.
  late final CurvedAnimation _anim;

  static const Duration _entrada = AppMotion.entrada;
  static const Duration _paso = AppMotion.escalon;

  @override
  void initState() {
    super.initState();
    // La espera del turno va dentro del propio controlador, como un
    // `Interval`, y no como un temporizador aparte: un temporizador que
    // dispara después de desmontar el widget es un fallo clásico, y aquí
    // desmontar pasa constantemente al desplazar la lista.
    final espera = _paso * widget.orden;
    final total = espera + _entrada;
    _controller = AnimationController(vsync: this, duration: total);
    _anim = CurvedAnimation(
      parent: _controller,
      curve: Interval(
        espera.inMilliseconds / total.inMilliseconds,
        1,
        curve: AppMotion.curvaEntrada,
      ),
    );
    if (widget.yaEntraron.add(widget.busId)) {
      _controller.forward();
    } else {
      // Ya entró antes: se muestra puesto, sin repetir la entrada.
      _controller.value = 1;
    }
  }

  @override
  void dispose() {
    // La curva también se desecha: se engancha como oyente del controlador
    // y no se suelta sola.
    _anim.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: Offset(0, 0.06 * AppMotion.desplazamiento(context)),
          end: Offset.zero,
        ).animate(_anim),
        child: widget.child,
      ),
    );
  }
}

class _AlertTile extends StatelessWidget {
  final AlertHistoryEntry entry;
  final String? routeName;
  final int? distanceMeters;
  final bool selecting;
  final bool selected;
  final VoidCallback onToggleSelect;
  final VoidCallback onDisable;

  const _AlertTile({
    required this.entry,
    required this.routeName,
    required this.distanceMeters,
    required this.selecting,
    required this.selected,
    required this.onToggleSelect,
    required this.onDisable,
  });

  @override
  Widget build(BuildContext context) {
    final sent = entry.sent;
    final subtitle = sent
        ? 'Notificación enviada · ${_formatTime(entry.sentAt!)}'
        : distanceMeters != null
            ? 'Está a $distanceMeters m de tu ubicación · esperando aviso'
            : 'Esperando señal del bus';

    // La fila entera, dicha de un tirón: el punto medio del separador se
    // pronuncia, y el guion de la placa no dice qué es cada mitad.
    final dichoBus = routePlateSpoken(
      busId: entry.busId,
      routeName: routeName,
      routeId: entry.routeId,
    );
    final dicha = '$dichoBus. ${subtitle.replaceAll(' · ', ', ')}';

    final accion = selecting
        ? Semantics(
            // Una casilla suelta se anuncia «casilla, sin marcar»: sin el
            // nombre del bus, no se sabe cuál se está marcando.
            label: dichoBus,
            child: Checkbox(
              value: selected,
              onChanged: (_) => onToggleSelect(),
              activeColor: AppColors.primaryDeep,
              visualDensity: VisualDensity.compact,
            ),
          )
        : sent
            ? Text(
                'Enviado',
                style: AppTextStyles.etiqueta.copyWith(
                  color: AppColors.textDisabled,
                ),
              )
            // Rojo de error para algo que se deshace en un toque desde el
            // mapa. El rojo queda para "Borrar todas", que sí borra.
            : Semantics(
                // En una lista de avisos, cinco botones que dicen
                // «Desactivar» y nada más son cinco botones iguales.
                label: 'Desactivar el aviso de $dichoBus',
                excludeSemantics: true,
                onTap: onDisable,
                button: true,
                child: TextButton(
                  onPressed: onDisable,
                  style: TextButton.styleFrom(
                    textStyle: AppTextStyles.etiqueta,
                    foregroundColor: AppColors.primaryDeep,
                  ),
                  child: const Text('Desactivar'),
                ),
              );

    // Con el texto del sistema al doble, «Desactivar» ya no cabe al lado
    // del nombre del bus: la fila se desbordaba 31 px por la derecha y la
    // acción quedaba fuera de la pantalla. Pasado ese punto la tarjeta se
    // parte en dos y la acción baja, pegada a la derecha. Es lo que hace
    // iOS cuando una celda deja de caber, y no cuesta nada al 100%:
    // debajo de ese umbral la fila es exactamente la de antes.
    final accionAbajo = MediaQuery.textScalerOf(context).scale(10) > 15;

    final fila = Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: sent ? AppColors.warningLight : AppColors.primaryTint,
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          // El glifo dice lo mismo que el subtítulo: enviado o esperando.
          child: ExcludeSemantics(
            child: Icon(
              sent
                  ? Icons.notifications_active_rounded
                  : Icons.directions_bus_filled_rounded,
              // El glifo va en la variante accesible: sobre su propio
              // tinte, el color de relleno se queda en 2,8:1 y la norma
              // pide 3:1 hasta para un icono.
              color: sent
                  ? AppColors.warningAccessible
                  : AppColors.primaryAccessible,
              size: 24,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Semantics(
            label: dicha,
            excludeSemantics: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  routePlateLabel(
                    busId: entry.busId,
                    routeName: routeName,
                    routeId: entry.routeId,
                  ),
                  style: AppTextStyles.subtitulo,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(subtitle, style: AppTextStyles.pie),
              ],
            ),
          ),
        ),
        if (!accionAbajo) ...[
          const SizedBox(width: 12),
          accion,
        ],
      ],
    );

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: selected ? AppColors.primaryDeep : AppColors.divider,
          width: selected ? 1.5 : 1.0,
        ),
      ),
      child: accionAbajo
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                fila,
                const SizedBox(height: AppSpacing.sm),
                Align(alignment: Alignment.centerRight, child: accion),
              ],
            )
          : fila,
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.primaryTint,
                borderRadius: BorderRadius.circular(AppRadius.card),
              ),
              // La campana repite en dibujo el título que va debajo.
              child: const ExcludeSemantics(
                child: Icon(
                  Icons.notifications_none_rounded,
                  color: AppColors.primary,
                  size: 36,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No tienes avisos activos',
              style: AppTextStyles.subtitulo,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'En el mapa, toca un bus y activa "Avísame" para que te '
              'notifiquemos cuando se acerque a tu ubicación.',
              textAlign: TextAlign.center,
              style: AppTextStyles.cuerpo.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatTime(DateTime d) {
  const months = [
    'ene',
    'feb',
    'mar',
    'abr',
    'may',
    'jun',
    'jul',
    'ago',
    'sep',
    'oct',
    'nov',
    'dic',
  ];
  final h = d.hour.toString().padLeft(2, '0');
  final m = d.minute.toString().padLeft(2, '0');
  return '${d.day} ${months[d.month - 1]} · $h:$m';
}
