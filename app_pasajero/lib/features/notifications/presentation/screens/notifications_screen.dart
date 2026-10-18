import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ya_viene_core/ya_viene_core.dart';

import '../../../../core/utils/bus_labels.dart';
import '../../../../core/utils/distancia.dart';
import '../../../../core/widgets/aviso.dart';
import '../../../../core/widgets/borde_desvanecido.dart';
import '../../../../core/widgets/dialogo.dart';
import '../../../../core/widgets/placa_bus.dart';
import '../../../../core/widgets/tamano_animado.dart';
import '../../../map/presentation/providers/distancia_al_bus.dart';
import '../../../map/presentation/providers/tracking_providers.dart';
import '../../../map/presentation/widgets/alert_guards.dart' show avisosAlTope;
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
    // Sin ruta activa no hay buses que consultar (ni suscripción a '').
    final positions = route == null
        ? const <BusPosition>[]
        : ref.watch(busPositionsSourceProvider(route.id).select(
            (value) => value.value ?? const <BusPosition>[],
          ));

    // Orden editorial: primero los activos, luego los enviados (cada grupo
    // con su encabezado, en `_HistoryList`). El orden de persistencia se
    // conserva dentro de cada grupo para que la selección sea estable.
    final entries = [
      ...history.where((e) => !e.sent),
      ...history.where((e) => e.sent),
    ].toList();
    final selecting = ref.watch(alertSelectionProvider).active;

    return Scaffold(
      // Blanco, como el resto de pantallas claras (dueño, 2026-10-16): las
      // tarjetas, también blancas, se despegan por su sombra y no por un
      // fondo de otro tono.
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        // Lo que pasa debajo se funde (`BordeDesvanecido`): la barra no se
        // oscurece ni se separa con sombra.
        scrolledUnderElevation: 0,
        centerTitle: true,
        // La pestaña la llama "Avisos", el estado vacío dice "avisos" y el
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
        // Seleccionando, a la izquierda va «Cancelar»: antes no había cómo
        // salir de la selección sin borrar (dueño, 2026-10-02).
        leadingWidth: selecting ? 104 : null,
        leading: selecting
            ? MediaQuery.withClampedTextScaling(
                maxScaleFactor: 1.3,
                child: TextButton(
                  onPressed: ref.read(alertSelectionProvider.notifier).clear,
                  style: TextButton.styleFrom(
                    textStyle: AppTextStyles.etiqueta,
                    foregroundColor: AppColors.primaryDeep,
                  ),
                  child: const Text('Cancelar'),
                ),
              )
            // Fuera de la selección no hay flecha: Avisos es una pestaña de
            // la barra de abajo y no hay detrás a dónde volver.
            : null,
        automaticallyImplyLeading: false,
        actions: entries.isEmpty
            ? null
            : [
                MediaQuery.withClampedTextScaling(
                  maxScaleFactor: 1.3,
                  child: const _SelectAction(),
                ),
              ],
      ),
      body: Column(
        children: [
          // Al borrar el último, la lista se apaga y el estado vacío
          // aparece en su lugar; antes era un corte seco.
          Expanded(
            child: AnimatedSwitcher(
              duration: AppMotion.duracion(context, AppMotion.normal),
              switchInCurve: AppMotion.curvaEntrada,
              switchOutCurve: AppMotion.curvaSalida,
              child: entries.isEmpty
                  ? const _EmptyState(key: ValueKey('vacio'))
                  : _HistoryList(
                      key: const ValueKey('lista'),
                      entries: entries,
                      positions: positions,
                      route: route,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pregunta antes de borrar varios (o todos) y, si dice que sí, borra.
/// Borrar de a muchos es fácil de tocar sin querer y se lleva avisos que
/// están esperando: un sí explícito, como en el panel con los buses.
Future<void> _borrarConfirmando(
    BuildContext context, WidgetRef ref, Set<String> ids) async {
  final n = ids.length;
  final si = await mostrarDialogo<bool>(
    context,
    (ctx) => Dialogo(
      delicado: true,
      icono: Icons.delete_outline_rounded,
      titulo: n == 1 ? '¿Borrar este aviso?' : '¿Borrar los $n avisos?',
      mensaje: 'Los que siguen esperando dejan de avisarte y se borran '
          'del historial.',
      principal: DialogoAccion('Borrar', () => Navigator.pop(ctx, true)),
      secundaria: DialogoAccion('Cancelar', () => Navigator.pop(ctx, false)),
    ),
  );
  if (si != true || !context.mounted) return;
  ref.read(alertSelectionProvider.notifier).clear();
  _borrar(context, ref, ids, n == 1 ? 'Aviso borrado' : '$n avisos borrados');
}

/// Borra las entradas [ids] (ver [AlertHistoryEntry.id]) —las que esperan
/// se desactivan y dejan de vigilarse— y deja abajo la tarjeta con
/// «Deshacer», que las devuelve como estaban: en su sitio, con su fecha y
/// su ancla, y vigilando otra vez las que esperaban. Los notificadores se
/// leen antes: si la pantalla se cierra, el «Deshacer» sigue sirviendo.
void _borrar(
    BuildContext context, WidgetRef ref, Set<String> ids, String hecho) {
  final historial = ref.read(alertHistoryProvider.notifier);
  final activos = ref.read(activeAlertsProvider.notifier);
  final vigilancia = ref.read(proximityAlertsProvider.notifier);
  final antes = ref.read(alertHistoryProvider);
  // Solo se desarma el bus de la que espera: borrar un enviado no apaga el
  // aviso que ese mismo bus tenga armado ahora.
  for (final e in antes) {
    if (e.sent || !ids.contains(e.id)) continue;
    activos.deactivateAlert(e.busId);
    vigilancia.disarmAlert(e.busId);
  }
  historial.quitar(ids);
  mostrarAviso(
    context,
    hecho,
    icono: Icons.delete_outline_rounded,
    accion: (
      'Deshacer',
      (contexto) {
        var sinCupo = false;
        for (final e in historial.reponer(antes)) {
          // Entre tanto se armaron otros dos: este no cabe y no se queda
          // en «Esperando» sin vigilar.
          if (!e.sent && !vigilancia.rearmar(e)) {
            historial.quitar({e.id});
            sinCupo = true;
          }
        }
        if (sinCupo) mostrarAviso(contexto, avisosAlTope);
      },
    ),
  );
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
          _borrarConfirmando(context, ref,
              {for (final e in ref.read(alertHistoryProvider)) e.id});
        } else {
          ref.read(alertSelectionProvider.notifier).enter();
        }
      },
      style: TextButton.styleFrom(
        textStyle: AppTextStyles.etiqueta,
        foregroundColor: selecting ? AppColors.error : AppColors.primaryDeep,
        disabledForegroundColor: AppColors.textSecondary,
      ),
      child: Text(selecting ? 'Borrar todas' : 'Seleccionar'),
    );
  }
}

/// Estado del modo selección: activo o no, y las entradas marcadas (por
/// [AlertHistoryEntry.id]: el mismo bus puede estar enviado y esperando).
class _SelectionState {
  final bool active;
  final Set<String> selected;

  const _SelectionState(this.active, this.selected);
}

class _SelectionNotifier extends StateNotifier<_SelectionState> {
  _SelectionNotifier() : super(const _SelectionState(false, {}));

  void enter() => state = const _SelectionState(true, {});

  void toggle(String id) {
    final next = {...state.selected};
    if (!next.add(id)) next.remove(id);
    state = _SelectionState(true, next);
  }

  void clear() => state = const _SelectionState(false, {});
}

/// `autoDispose`: al salir de la pantalla la selección se olvida. Antes
/// seguía puesta al volver a entrar (dueño, 2026-10-02).
final alertSelectionProvider =
    StateNotifierProvider.autoDispose<_SelectionNotifier, _SelectionState>(
        (ref) => _SelectionNotifier());

class _HistoryList extends ConsumerStatefulWidget {
  final List<AlertHistoryEntry> entries;
  final List<BusPosition> positions;
  final RouteInfo? route;

  const _HistoryList({
    super.key,
    required this.entries,
    required this.positions,
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

  /// Los que se acaban de borrar o desactivar, con el puesto que tenían,
  /// mientras se despiden (ver [_Salida]).
  final Map<String, (AlertHistoryEntry, int)> _saliendo = {};

  @override
  void didUpdateWidget(_HistoryList old) {
    super.didUpdateWidget(old);
    final quedan = {for (final e in widget.entries) e.id};
    // Volvió («Deshacer») mientras se iba: deja de irse.
    _saliendo.removeWhere((id, _) => quedan.contains(id));
    if (AppMotion.reducido(context)) return;
    for (final (i, e) in old.entries.indexed) {
      if (quedan.contains(e.id)) continue;
      _saliendo.putIfAbsent(e.id, () => (e, i));
      // Si vuelve, que vuelva a entrar.
      _yaEntraron.remove(e.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Los que se van, en el puesto que tenían: así nada salta mientras se
    // despiden.
    final entries = [...widget.entries];
    for (final (e, i) in _saliendo.values.toList()
      ..sort((a, b) => a.$2.compareTo(b.$2))) {
      entries.insert(i.clamp(0, entries.length), e);
    }
    final positions = widget.positions;
    final route = widget.route;
    final selection = ref.watch(alertSelectionProvider);
    final selecting = selection.active;
    final selected = selection.selected;

    // Lo que espera y lo que ya sonó iban en una sola lista, distinguidos
    // solo por el color del medallón (dueño, 2026-09-30: «no se ve al nivel
    // de la app»). Ahora van en dos grupos con su encabezado, como las
    // secciones de una lista de Ajustes en iOS: se ve de un vistazo qué
    // sigue en pie, y el lector de pantalla salta de grupo en grupo.
    final esperando = entries.where((e) => !e.sent).toList();
    final enviados = entries.where((e) => e.sent).toList();
    // Un grupo que solo tiene tarjetas yéndose se va con ellas: su
    // encabezado viaja dentro de la primera (ver abajo).
    bool vivo(List<AlertHistoryEntry> grupo) =>
        grupo.any((e) => !_saliendo.containsKey(e.id));
    final filas = <Object>[
      if (vivo(esperando)) 'Esperando',
      ...esperando,
      if (vivo(enviados)) 'Enviados',
      ...enviados,
    ];

    return Column(
      children: [
        Expanded(
          child: BordeDesvanecido(
            // Al subir, la lista se disuelve bajo la barra en vez de
            // cortarse en seco contra ella (dueño, 2026-10-16).
            child: ListView.builder(
              // Arriba, lo que se funde: en reposo la primera fila queda
              // entera.
              padding: const EdgeInsets.fromLTRB(
                  20, BordeDesvanecido.alto, 20, AppSpacing.xl),
              itemCount: filas.length,
              itemBuilder: (context, index) {
                final fila = filas[index];
                if (fila is String) {
                  return _Encabezado(fila, primero: index == 0);
                }
                final entry = fila as AlertHistoryEntry;
                final seVa = _saliendo.containsKey(entry.id);
                final pos = positions.cast<BusPosition?>().firstWhere(
                      (p) => p?.busId == entry.busId,
                      orElse: () => null,
                    );
                // La misma de la hoja: por la ruta, desde el punto del aviso.
                final distanceMeters = !entry.sent && pos != null
                    ? distanciaAlBusDesdeTuPunto(ref, pos)?.round()
                    : null;
                // El puesto entre los avisos, sin contar los encabezados: el
                // escalón es entre tarjetas.
                final orden = entries.indexOf(entry);
                final tile = _AlertTile(
                  entry: entry,
                  routeName: entry.routeName ??
                      (route?.id == entry.routeId ? route?.name : null),
                  distanceMeters: distanceMeters,
                  selecting: selecting && !seVa,
                  selected: selected.contains(entry.id),
                  onToggleSelect: () {
                    HapticFeedback.selectionClick();
                    ref.read(alertSelectionProvider.notifier).toggle(entry.id);
                  },
                  // Uno solo, a la vista y con su botón: no pregunta,
                  // pero se puede deshacer.
                  onDisable: () =>
                      _borrar(context, ref, {entry.id}, 'Aviso desactivado'),
                );
                if (seVa) {
                  final grupo = entry.sent ? enviados : esperando;
                  final primeraDelGrupo = !vivo(grupo) && grupo.first == entry;
                  return _Salida(
                    key: ValueKey('sale-${entry.id}'),
                    alTerminar: () =>
                        setState(() => _saliendo.remove(entry.id)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (primeraDelGrupo)
                          _Encabezado(
                            entry.sent ? 'Enviados' : 'Esperando',
                            primero: index == 0,
                          ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: tile,
                        ),
                      ],
                    ),
                  );
                }
                return Padding(
                  // 12 entre tarjetas, como antes el separador.
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _TileEntrance(
                    key: ValueKey(entry.id),
                    id: entry.id,
                    yaEntraron: _yaEntraron,
                    // El desfase se topa a los seis primeros: más allá, la
                    // espera del último se notaría más que el efecto.
                    orden: orden.clamp(0, 5),
                    child: tile,
                  ),
                );
              },
            ),
          ),
        ),
        // Barra de acciones del modo selección.
        TamanoAnimado(
          duracion: AppMotion.rapido,
          curva: AppMotion.curvaEntrada,
          // Con la barra de abajo apartada, el botón queda sobre la barra
          // de inicio del iPhone, no debajo de ella.
          child: selecting
              ? Container(
                  padding: EdgeInsets.fromLTRB(20, AppSpacing.xs, 20,
                      AppSpacing.lg + MediaQuery.paddingOf(context).bottom),
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
                        disabledForegroundColor: AppColors.textBody,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                      ),
                      onPressed: selected.isEmpty
                          ? null
                          : () => _borrarConfirmando(context, ref, selected),
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

/// El encabezado de un grupo de avisos: «Esperando» o «Enviados».
///
/// En `etiqueta` y en el gris secundario, como los rótulos de sección de
/// iOS: ordena sin competir con el nombre de la ruta, que va en
/// `subtitulo`. Es encabezado también para el lector de pantalla.
class _Encabezado extends StatelessWidget {
  const _Encabezado(this.texto, {required this.primero});

  final String texto;

  /// El primero va pegado a lo de arriba; el segundo se separa del grupo
  /// anterior lo bastante para que se lea como otro grupo y no como otra
  /// tarjeta.
  final bool primero;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xs,
        primero ? AppSpacing.sm : AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.sm,
      ),
      child: Semantics(
        header: true,
        child: Text(
          texto,
          style: AppTextStyles.etiqueta.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

/// Entrada suave de cada tile del historial: aparece con un fundido y un
/// pequeño deslizamiento hacia arriba al montarse (una sola vez, sin timers).
class _TileEntrance extends StatefulWidget {
  final Widget child;

  /// Puesto en la lista, para escalonar la entrada.
  final int orden;

  final String id;

  /// Compartido con la lista: quién ya entró y no debe volver a hacerlo.
  final Set<String> yaEntraron;

  const _TileEntrance({
    super.key,
    required this.child,
    required this.orden,
    required this.id,
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
    if (widget.yaEntraron.add(widget.id)) {
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

/// La despedida de una tarjeta borrada o desactivada.
///
/// Antes se iba de golpe y lo de abajo saltaba a su sitio (dueño,
/// 2026-10-02: «no me gusta nada»). Ahora, como una fila que se borra en
/// iOS: primero se corre un poco a la izquierda y se apaga, y ya apagada
/// su hueco se cierra, de modo que lo de abajo sube sin salto. Mientras
/// tanto no se toca ni se lee: ya no está en el historial.
class _Salida extends StatefulWidget {
  const _Salida({super.key, required this.child, required this.alTerminar});

  final Widget child;
  final VoidCallback alTerminar;

  @override
  State<_Salida> createState() => _SalidaState();
}

class _SalidaState extends State<_Salida> with SingleTickerProviderStateMixin {
  // 460 ms: el apagado (0–55 %) y el cierre del hueco (35–100 %) se
  // solapan un poco para que no se lean como dos pasos.
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 460),
  )
    ..addStatusListener((estado) {
      if (estado == AnimationStatus.completed) widget.alTerminar();
    })
    ..forward();

  late final CurvedAnimation _apagado = CurvedAnimation(
    parent: _c,
    curve: const Interval(0, 0.55, curve: AppMotion.curvaSalida),
  );
  late final CurvedAnimation _cierre = CurvedAnimation(
    parent: _c,
    curve: const Interval(0.35, 1, curve: AppMotion.curvaCambio),
  );

  @override
  void dispose() {
    _apagado.dispose();
    _cierre.dispose();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ExcludeSemantics(
        child: SizeTransition(
          sizeFactor: ReverseAnimation(_cierre),
          alignment: Alignment.topCenter,
          child: FadeTransition(
            opacity: ReverseAnimation(_apagado),
            child: SlideTransition(
              position: Tween<Offset>(
                begin: Offset.zero,
                end: const Offset(-0.12, 0),
              ).animate(_apagado),
              child: ScaleTransition(
                scale: Tween<double>(begin: 1, end: 0.97).animate(_apagado),
                child: widget.child,
              ),
            ),
          ),
        ),
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
        ? 'Notificación enviada: ${_formatTime(entry.sentAt!)}'
        : distanceMeters != null
            ? 'Está a ${distanciaAviso(distanceMeters!)} $restoDistancia'
            // Sin posición del bus puede ser que se fue al patio, donde lo
            // ocultan y nadie sabe cuándo vuelve. El aviso no espera para
            // siempre (vence a las `vidaDeUnAviso` de armado): se dice hasta
            // cuándo, para que nadie cuente con él pasada esa hora.
            : 'Esperando señal del bus, el aviso sigue hasta las '
                '${_hora(entry.createdAt.add(vidaDeUnAviso))}';

    // La fila entera, dicha de un tirón: el guion de la placa no dice qué
    // es cada mitad.
    final dichoBus = routePlateSpoken(
      busId: entry.busId,
      routeName: routeName,
      routeId: entry.routeId,
    );
    final dicha = '$dichoBus. $subtitle';

    // Un aviso ya enviado no lleva acción: «Enviado» a la derecha repetía
    // lo que el subtítulo dice con fecha y hora, y una fila que solo
    // informa, en iOS, no lleva nada a la derecha.
    // Seleccionando, la acción es el círculo de la marca, a la derecha
    // donde estaba la casilla (dueño, 2026-10-02); entra creciendo.
    final Widget? accion = selecting
        ? TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: AppMotion.duracion(context, AppMotion.normal),
            curve: AppMotion.curvaEntrada,
            builder: (context, t, circulo) => Opacity(
              opacity: t,
              child: Transform.scale(scale: 0.6 + 0.4 * t, child: circulo),
            ),
            child: _CirculoSeleccion(
              key: ValueKey('circulo-${entry.id}'),
              marcado: selected,
              dicho: dichoBus,
              alTocar: onToggleSelect,
            ),
          )
        : sent
            ? null
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
                  // Píldora tonal: era texto suelto, que junto a una tarjeta
                  // con placa y medallón no se leía como botón. Gris de
                  // superficie y no verde: desactivar no es la acción
                  // principal de la pantalla. El blanco sigue siendo de 48
                  // (`padded`) aunque la píldora mida 36.
                  style: TextButton.styleFrom(
                    textStyle: AppTextStyles.etiqueta,
                    foregroundColor: AppColors.primaryDeep,
                    backgroundColor: AppColors.surfaceMuted,
                    side: const BorderSide(color: AppColors.hairline),
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    minimumSize: const Size(0, 36),
                    tapTargetSize: MaterialTapTargetSize.padded,
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

    // El estado, con un glifo que lo dice de un vistazo: el bus ya tiene
    // distancia, no da señal o el aviso ya sonó. El ámbar es solo para
    // «sin señal», lo único que pide atención.
    final (IconData iconoEstado, Color tintaEstado) = sent
        ? (Icons.check_circle_outline, AppColors.primaryAccessible)
        : distanceMeters != null
            ? (Icons.near_me_outlined, AppColors.primaryAccessible)
            : (Icons.schedule, AppColors.warningAccessible);

    final fila = Row(
      children: [
        // Medallón de 44 (era 48 con radio de 16: casi un círculo que no
        // llegaba a serlo). Verde siempre: la campana de lo que ya sonó iba
        // en gris, pero un aviso que llegó es un acierto, no algo apagado
        // (dueño, 2026-10-02). Lo vigente ya se distingue por el bus, la
        // distancia en vivo y el grupo «Esperando».
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.primaryTint,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: ExcludeSemantics(
            child: Icon(
              sent
                  ? Icons.notifications_active_outlined
                  : Icons.directions_bus_filled_outlined,
              // El glifo va en la variante accesible: sobre su propio
              // tinte, el color de relleno se queda en 2,8:1 y la norma
              // pide 3:1 hasta para un icono.
              color: AppColors.primaryAccessible,
              size: 22,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Semantics(
            label: dicha,
            excludeSemantics: true,
            // La ruta escrita y, debajo, la placa en su lámina blanca: la
            // misma de la hoja de distancia, para cotejarla con el bus que
            // llega. Antes iban en una línea, «Ruta - ABC123», y la placa
            // se perdía al final del nombre.
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rutaLegible(routeName, entry.routeId) ?? 'Bus',
                  style: AppTextStyles.subtitulo,
                ),
                const SizedBox(height: 6),
                PlacaBus(busPlaca(entry.busId)),
              ],
            ),
          ),
        ),
        if (accion != null && !accionAbajo) ...[
          const SizedBox(width: 12),
          accion,
        ],
      ],
    );

    // El estado en una franja arena dentro de la tarjeta blanca: separa lo
    // que el aviso es (ruta y placa) de cómo va. Ya se dice en `dicha`; aquí
    // no se vuelve a leer.
    final estado = ExcludeSemantics(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.arena,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          children: [
            Icon(iconoEstado, size: 16, color: tintaEstado),
            const SizedBox(width: AppSpacing.sm),
            // `pie` en el gris de cuerpo y no en el secundario: es letra
            // chica y es lo que el pasajero vino a mirar.
            Expanded(
              child: distanceMeters == null
                  ? Text(
                      subtitle,
                      style:
                          AppTextStyles.pie.copyWith(color: AppColors.textBody),
                    )
                  : _LineaDistancia(distanceMeters!),
            ),
          ],
        ),
      ),
    );

    final tarjeta = AnimatedContainer(
      key: ValueKey('aviso-${entry.id}'),
      duration: AppMotion.duracion(context, AppMotion.rapido),
      curve: AppMotion.curvaEntrada,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        // Marcada, un velo del azul del círculo y su filo fino: el borde
        // grueso de 1,5 en tinta se leía como error de formulario.
        color: selected && selecting
            ? Color.alphaBlend(
                AppColors.acento.withValues(alpha: 0.06), AppColors.surface)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: selected && selecting
              ? AppColors.acento.withValues(alpha: 0.45)
              : AppColors.hairline,
        ),
        // Lo que espera se levanta del fondo con la sombra de las píldoras
        // del mapa; lo enviado, con la suave: sobre el blanco una tarjeta
        // sin sombra es solo su filo, pero lo que ya sonó va un paso atrás.
        boxShadow: sent
            ? AppShadows.soft
            : [
                BoxShadow(
                  color: AppColors.primaryDeep.withValues(alpha: 0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          fila,
          const SizedBox(height: 12),
          estado,
          if (accion != null && accionAbajo) ...[
            const SizedBox(height: AppSpacing.sm),
            Align(alignment: Alignment.centerRight, child: accion),
          ],
        ],
      ),
    );

    // En modo selección se marca tocando la tarjeta entera, como en Fotos:
    // el círculo solo es un blanco chico. Para el lector de pantalla el
    // círculo, con su nombre, es el control.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      excludeFromSemantics: true,
      onTap: selecting ? onToggleSelect : null,
      child: tarjeta,
    );
  }
}

/// La marca de selección: un círculo con filo que, marcado, se llena del
/// azul de los botones llenos con el chulito blanco y grueso, como en Mail
/// o Fotos. Era la casilla de Material, con su chulito fino dibujado a
/// trazo (dueño, 2026-10-02: «no me gusta el chulito ese»).
class _CirculoSeleccion extends StatelessWidget {
  const _CirculoSeleccion({
    super.key,
    required this.marcado,
    required this.dicho,
    required this.alTocar,
  });

  final bool marcado;

  /// Ruta y placa: una casilla suelta se anuncia «casilla, sin marcar» y
  /// no se sabe cuál se está marcando.
  final String dicho;
  final VoidCallback alTocar;

  @override
  Widget build(BuildContext context) {
    final duracion = AppMotion.duracion(context, AppMotion.rapido);
    return Semantics(
      container: true,
      checked: marcado,
      label: dicho,
      onTap: alTocar,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: alTocar,
        child: AnimatedContainer(
          duration: duracion,
          curve: AppMotion.curvaEntrada,
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: marcado ? AppColors.acento : AppColors.surface,
            // Sin marcar, el filo en el gris secundario: sobre blanco, el
            // de las tarjetas (hairline) no se ve.
            border: Border.all(
              color: marcado ? AppColors.acento : AppColors.textSecondary,
              width: 1.5,
            ),
          ),
          // El chulito entra con un rebote corto, como en iOS.
          child: AnimatedScale(
            duration: duracion,
            curve: marcado ? Curves.easeOutBack : AppMotion.curvaSalida,
            scale: marcado ? 1 : 0,
            child: marcado
                ? const Icon(Icons.check_rounded, size: 18, color: Colors.white)
                : const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Medallón con aro: el tinte al 50 % alrededor y el disco lleno
            // en el centro, separado por un filo blanco. Era un cuadrado
            // redondeado de 72 sin más, más chico que todo lo que lo rodea.
            Container(
              width: 112,
              height: 112,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primaryTint.withValues(alpha: 0.5),
              ),
              child: Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primaryTint,
                  border: Border.all(color: AppColors.surface, width: 4),
                ),
                // La campana repite en dibujo el título que va debajo. En la
                // variante accesible: el verde de relleno sobre su propio
                // tinte se queda por debajo del 3:1 que pide un icono.
                child: const ExcludeSemantics(
                  child: Icon(
                    Icons.notifications_none_outlined,
                    color: AppColors.primaryAccessible,
                    size: 34,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'No tienes avisos activos',
              textAlign: TextAlign.center,
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
  return '${d.day} ${months[d.month - 1]}, ${_hora(d)}';
}

String _hora(DateTime d) {
  final h = d.hour.toString().padLeft(2, '0');
  final m = d.minute.toString().padLeft(2, '0');
  return '$h:$m';
}

/// Lo que sigue a la cifra en la franja de un aviso que espera.
const restoDistancia = 'de tu ubicación, esperando aviso';

/// «Está a 14 km de tu ubicación, esperando aviso», siempre en una fila.
/// La cifra cambia con cada posición del bus: en un hueco de ancho fijo y
/// con cifras tabulares, «9 m» y «14 km» miden lo mismo y el resto no se
/// corre ni salta de fila. Si el teléfono es angosto, la fila entera se
/// encoge (`scaleDown`); como su ancho no depende de la cifra, se encoge
/// siempre igual.
class _LineaDistancia extends StatelessWidget {
  const _LineaDistancia(this.metros);

  final int metros;

  /// Los textos más anchos que da [distanciaAviso] en la ciudad (el área
  /// metropolitana cabe en 41 km): el hueco mide como el mayor.
  static const _masAnchos = ['000 m', '0,0 km', '00 km'];

  @override
  Widget build(BuildContext context) {
    final estilo = AppTextStyles.pie.copyWith(
      color: AppColors.textBody,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final negrita = estilo.copyWith(fontWeight: FontWeight.w700);
    final cifra = distanciaAviso(metros);
    final escala = MediaQuery.textScalerOf(context);
    double ancho(String texto) {
      final pintor = TextPainter(
        text: TextSpan(text: texto, style: negrita),
        textDirection: TextDirection.ltr,
        textScaler: escala,
      )..layout();
      final w = pintor.width;
      pintor.dispose();
      return w;
    }

    // Más de 99 km no pasa en la ciudad; si pasa, el hueco crece y nada
    // se corta.
    final hueco = [cifra, ..._masAnchos].map(ancho).reduce(
          (a, b) => a > b ? a : b,
        );
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Está a ', style: estilo),
          SizedBox(
            key: const ValueKey('hueco-distancia'),
            width: hueco.ceilToDouble(),
            child: Text(
              cifra,
              style: negrita,
              textAlign: TextAlign.end,
              maxLines: 1,
              softWrap: false,
            ),
          ),
          Text(' $restoDistancia', style: estilo, maxLines: 1, softWrap: false),
        ],
      ),
    );
  }
}
