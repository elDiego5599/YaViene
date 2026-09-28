import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import '../../../../core/app_info.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/widgets/dialogo.dart';
import '../../../../core/widgets/live_route_backdrop.dart';
import '../../../legal/legal_docs.dart';
import '../providers/map_tour_provider.dart';
import '../providers/map_view_state.dart';
import '../providers/tracking_providers.dart';
import '../providers/user_location_provider.dart';

/// Centro personal de viaje: la ruta que el usuario sigue ahora mismo, sus
/// avisos y la guía de uso. Sin bloque de cuenta ni «Cerrar sesión»: el
/// pasajero entra sin cuenta. Fondo tinta con patrón de calles y entrada
/// escalonada (fade + slide leve).
class AppDrawer extends ConsumerStatefulWidget {
  const AppDrawer({super.key});

  @override
  ConsumerState<AppDrawer> createState() => AppDrawerState();
}

class AppDrawerState extends ConsumerState<AppDrawer>
    with SingleTickerProviderStateMixin {
  /// Entrada escalonada: cada bloque aparece con fade + deslizamiento leve
  /// desde la izquierda, sin blur ni efectos caros. La dispara el Scaffold
  /// (onDrawerChanged) en cada apertura.
  late final AnimationController _entrance;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(vsync: this, duration: AppMotion.grupo);
    _curvaCierre = CurvedAnimation(
      parent: _entrance,
      // Crece y frena, sin pasarse de tamaño: el rebote de `easeOutBack`
      // que llevaba era lo único juguetón de un menú que por lo demás
      // entra sobrio.
      curve: const Interval(0.0, 0.4, curve: AppMotion.curvaEntrada),
    );
    _escalaCierre = Tween<double>(begin: 0.5, end: 1.0).animate(_curvaCierre);
    // Red de seguridad para la PRIMERA apertura: si onDrawerChanged llega
    // antes de que el estado exista (el drawer se construye al abrirse),
    // el post-frame la anima igual.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _entrance.forward();
    });
  }

  /// Las curvas de la entrada, una por escalón, guardadas por su instante de
  /// arranque.
  ///
  /// Antes se creaba una nueva dentro de `_staggered`, que se llama desde
  /// `build`. Cada `CurvedAnimation` se engancha como oyente del controlador
  /// y no se suelta sola, así que el drawer —que se reconstruye con cada
  /// cambio de ruta o de avisos— iba dejando oyentes muertos que
  /// seguían evaluando su curva en cada cuadro de cada apertura.
  final Map<double, CurvedAnimation> _escalones = {};

  /// La entrada de la X de cerrar, por lo mismo: una sola vez, no por build.
  /// Se asignan en initState y no con un inicializador perezoso: uno de esos
  /// se crearía por primera vez dentro de dispose() si el drawer se desmonta
  /// sin haberse construido nunca, y quedaría enganchado a un controlador
  /// que está a punto de desecharse.
  late final CurvedAnimation _curvaCierre;
  late final Animation<double> _escalaCierre;

  CurvedAnimation _escalon(double start) => _escalones.putIfAbsent(
        start,
        () => CurvedAnimation(
          parent: _entrance,
          curve: Interval(
            start,
            (start + 0.3).clamp(0.0, 1.0),
            curve: AppMotion.curvaEntrada,
          ),
        ),
      );

  @override
  void dispose() {
    for (final curva in _escalones.values) {
      curva.dispose();
    }
    _escalones.clear();
    _curvaCierre.dispose();
    _entrance.dispose();
    super.dispose();
  }

  /// Reproduce la entrada desde cero (llamada en cada apertura del drawer).
  void playEntrance() {
    if (mounted) _entrance.forward(from: 0);
  }

  /// Un solo bloque para las acciones, con filos finos entre filas.
  ///
  /// Antes cada fila era su propia tarjeta: fondo blanco al 5 %, borde al
  /// 8 %, esquinas de 16 — y encima, dos tarjetas más con alfas casi
  /// idénticas (0,08/0,12 y 0,05/0,10). Cinco superficies que no se
  /// distinguen entre sí no hacen jerarquía, hacen ruido. Agrupadas, la
  /// lista se lee de un golpe y las dos tarjetas de arriba vuelven a
  /// destacar.
  Widget _grupo(List<Widget> filas) {
    final hijos = <Widget>[];
    for (var i = 0; i < filas.length; i++) {
      if (i > 0) {
        hijos.add(Divider(
          height: 1,
          thickness: 1,
          // Sangrado hasta donde empieza el texto, como en iOS: el filo
          // separa las filas sin cortar la columna de iconos.
          indent: 52,
          color: Colors.white.withValues(alpha: 0.07),
        ));
      }
      hijos.add(filas[i]);
    }
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(children: hijos),
    );
  }

  Widget _staggered(Widget child, double start) {
    final animation = _escalon(start);
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: Offset(-0.08 * AppMotion.desplazamiento(context), 0),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
    );
  }

  /// Qué versión está instalada, dicho en una ventana propia y no con
  /// `showAboutDialog`: esa trae sus botones en inglés mientras la app no
  /// cargue las traducciones de Material, y abre una lista de licencias
  /// entera —también en inglés— desde el menú de un pasajero.
  Future<void> _acercaDe(BuildContext context) {
    return mostrarDialogo<void>(
      context,
      (dialogContext) => Dialogo(
        icono: Icons.info_outline_rounded,
        titulo: 'Ya Viene',
        detalle: 'Versión $kAppVersion',
        mensaje: 'Piloto en Barranquilla. Las posiciones salen del GPS que '
            'va instalado en cada bus.',
        principal: DialogoAccion(
          'Cerrar',
          () => Navigator.pop(dialogContext),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeAlerts = ref.watch(activeAlertsProvider);

    return Drawer(
      backgroundColor: AppColors.ink,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(
          right: Radius.circular(AppRadius.sheet),
        ),
      ),
      // El mismo fondo que el arranque y la bienvenida: la red de rutas de
      // noche con el bus recorriéndola. Antes el drawer se abría sobre un
      // plano de tinta con un rayado encima y parecía de otra app. El halo
      // verde sube a la altura de la marca, que aquí va arriba del todo.
      //
      // El fondo pinta TODO el drawer (incluida el área de la barra de
      // estado y el gesto inferior): la SafeArea queda solo para el
      // contenido.
      child: LiveRouteBackdrop(
        haloY: 0.12,
        conPie: true,
        child: SafeArea(
          child: Padding(
            padding:
                const EdgeInsets.fromLTRB(AppSpacing.lg, 26, AppSpacing.lg, 20),
            // El pie se apoya en el fondo del menú y no justo debajo del
            // último grupo: pegado arriba dejaba media pantalla de tinta
            // vacía, que se leía como un menú a medio cargar. El resto que
            // sobra lo llena el hueco, no el pie; en un teléfono bajo, donde
            // no sobra nada, todo se desplaza como antes.
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _staggered(
                        Row(
                          children: [
                            // El logo se anunciaba como "imagen", sin más, y
                            // justo al lado va el nombre escrito: es el mismo
                            // dato dos veces, y una de ellas sin decir nada.
                            ExcludeSemantics(
                              child: SvgPicture.asset(
                                'assets/icon/ya_viene_logo.svg',
                                width: 30,
                                height: 30,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Ya Viene',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.titulo.copyWith(
                                  color: AppColors.textOnInk,
                                ),
                              ),
                            ),
                            // Cerrar un menú no es destruir nada: la X deja de
                            // ser roja. Conserva el rebote de la entrada —salvo
                            // con «Reducir movimiento», donde un rebote que se
                            // pasa de tamaño y vuelve es justo lo que molesta.
                            // El fundido escalonado se queda: lo que marea es
                            // el desplazamiento, no la opacidad.
                            ScaleTransition(
                              scale: AppMotion.reducido(context)
                                  ? const AlwaysStoppedAnimation<double>(1)
                                  : _escalaCierre,
                              child: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.08),
                                  shape: BoxShape.circle,
                                ),
                                child: IconButton(
                                  key: const ValueKey('drawer_close'),
                                  onPressed: () => Navigator.pop(context),
                                  padding: EdgeInsets.zero,
                                  icon: Icon(
                                    Icons.close_outlined,
                                    color: AppColors.textOnInk
                                        .withValues(alpha: 0.75),
                                    size: 20,
                                  ),
                                  tooltip: 'Cerrar menú',
                                ),
                              ),
                            ),
                          ],
                        ),
                        0.0,
                      ),
                      // Sin la tarjeta de cuenta que iba aquí, la ruta activa
                      // sube a ser el primer bloque, con el aire que la marca
                      // dejaba antes a esa tarjeta.
                      const SizedBox(height: 22),
                      _staggered(const ActiveRouteCard(), 0.08),
                      const SizedBox(height: 30),
                      _staggered(
                        _grupo([
                          DrawerItem(
                            icon: Icons.notifications_none_outlined,
                            title: 'Avisos',
                            // La pastilla verde es un número sin frase: dicho
                            // solo, "2" detrás de "Avisos" no dice de qué.
                            dicho: activeAlerts.isEmpty
                                ? 'Avisos'
                                : activeAlerts.length == 1
                                    ? 'Avisos, 1 activo'
                                    : 'Avisos, ${activeAlerts.length} activos',
                            trailing: activeAlerts.isEmpty
                                ? Icon(
                                    Icons.chevron_right_outlined,
                                    color: AppColors.textOnInk
                                        .withValues(alpha: 0.3),
                                    size: 20,
                                  )
                                : Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: AppSpacing.sm, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryAccessible,
                                      borderRadius:
                                          BorderRadius.circular(AppRadius.pill),
                                    ),
                                    child: Text(
                                      '${activeAlerts.length}',
                                      style: AppTextStyles.etiqueta.copyWith(
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                            onTap: () {
                              // Sin cerrar el drawer: al volver de
                              // Notificaciones se regresa al menú abierto, no
                              // al mapa.
                              context.push('/notifications');
                            },
                          ),
                          DrawerItem(
                            icon: Icons.help_outline_outlined,
                            title: 'Ver guía de uso',
                            onTap: () async {
                              // F8: reiniciar la guía borra la ruta/bus activos
                              // sin avisar. Si hay algo que perder, se confirma
                              // antes.
                              final hasSelection =
                                  ref.read(selectedRouteProvider) != null ||
                                      ref
                                          .read(selectedBusesProvider)
                                          .isNotEmpty;
                              if (hasSelection) {
                                final confirmed = await mostrarDialogo<bool>(
                                  context,
                                  (dialogContext) => Dialogo(
                                    icono: Icons.restart_alt_outlined,
                                    titulo: '¿Reiniciar la guía?',
                                    mensaje:
                                        'Vas a perder la ruta y el bus que '
                                        'tienes seleccionados ahora mismo.',
                                    delicado: true,
                                    principal: DialogoAccion(
                                      'Reiniciar guía',
                                      () => Navigator.pop(dialogContext, true),
                                    ),
                                    secundaria: DialogoAccion(
                                      'Cancelar',
                                      () => Navigator.pop(dialogContext, false),
                                    ),
                                  ),
                                );
                                if (confirmed != true || !context.mounted) {
                                  return;
                                }
                              }
                              // La guía empieza limpia: se deselecciona el bus
                              // y se quita la ruta activa para que el flujo
                              // arranque desde cero (si la ruta queda, sus
                              // buses siguen tocables durante el paso de
                              // ubicación).
                              ref.read(selectedBusesProvider.notifier).clear();
                              ref.read(selectedRouteProvider.notifier).clear();
                              final location = ref.read(userLocationProvider);
                              await ref.read(mapGuideProvider.notifier).restart(
                                    hasLocation: location.hasPosition,
                                    locationSettled: location.mode !=
                                            UserLocationMode.unknown &&
                                        location.mode !=
                                            UserLocationMode.locating,
                                  );
                              // Sin ubicación la guía empieza pidiendo el punto
                              // de espera: hay que mostrar la ciudad para saber
                              // dónde tocar, aunque la cámara esté en otro
                              // lado.
                              if (!location.hasPosition) {
                                ref
                                    .read(mapCameraRequestProvider.notifier)
                                    .centerOnBarranquilla();
                              }
                              if (context.mounted) Navigator.pop(context);
                            },
                          ),
                        ]),
                        0.16,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      // Segundo grupo, y no tres filas más en el primero: lo de
                      // arriba es lo que el pasajero usa (sus avisos, la guía);
                      // esto es lo que consulta de vez en cuando. Sin cuenta,
                      // este menú es el único sitio estable donde volver a leer
                      // lo que se aceptó en la bienvenida.
                      _staggered(
                        _grupo([
                          DrawerItem(
                            icon: Icons.lock_outline_rounded,
                            title: 'Privacidad',
                            onTap: () =>
                                context.push(legalPath(legalPrivacidad.id)),
                          ),
                          DrawerItem(
                            icon: Icons.description_outlined,
                            title: 'Términos',
                            onTap: () =>
                                context.push(legalPath(legalTerminos.id)),
                          ),
                          DrawerItem(
                            icon: Icons.info_outline_rounded,
                            title: 'Acerca de',
                            onTap: () => _acercaDe(context),
                          ),
                        ]),
                        0.20,
                      ),
                    ],
                  ),
                ),
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      const SizedBox(height: 26),
                      // Los créditos del mapa viven aquí desde que la "i"
                      // azul de MapLibre dejó libre su esquina para el botón
                      // de recentrar. OpenStreetMap y CARTO piden que se
                      // vean; el pie de un menú es donde los pone todo el
                      // mundo, y donde no estorban.
                      _staggered(const _Pie(), 0.24),
                    ],
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

/// Pie del menú: los créditos del mapa, en voz baja y separados de las
/// acciones por un filo.
class _Pie extends StatelessWidget {
  const _Pie();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.xs, AppSpacing.md, AppSpacing.xs, 0),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: Text(
        // Sin «Mapa» delante: con él, «CARTO» se quedaba solo en una
        // segunda línea. Los espacios duros pegan cada © a su nombre, para
        // que con el texto grande se corte por los puntos.
        '©\u00A0MapLibre · ©\u00A0OpenStreetMap · ©\u00A0CARTO',
        style: AppTextStyles.pie.copyWith(
          color: AppColors.textOnInk.withValues(alpha: 0.35),
          height: 1.4,
        ),
      ),
    );
  }
}

/// Pieza central del drawer: la ruta que el usuario está siguiendo, con sus
/// terminales unidos por una línea de ida y vuelta. Sin ruta seleccionada
/// muestra el estado vacío.
class ActiveRouteCard extends ConsumerWidget {
  const ActiveRouteCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final route = ref.watch(selectedRouteProvider);
    final hasRoute = route != null;
    final a = route?.terminalA ?? '';
    final b = route?.terminalB ?? '';
    final showTerminals = hasRoute && (a.isNotEmpty || b.isNotEmpty);
    // Los dos terminales son una línea de ida y vuelta dibujada: leídos
    // sueltos son dos nombres de sitio sin relación entre ellos.
    final terminales = b.isEmpty ? a : 'entre $a y $b';
    final dicha = !hasRoute
        ? 'Sin ruta activa. Elige tu ruta en el mapa'
        : showTerminals
            ? 'Ruta activa: ${route.name}, $terminales'
            : 'Ruta activa: ${route.name}';

    return Semantics(
      label: dicha,
      excludeSemantics: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: hasRoute
              ? AppColors.primary.withValues(alpha: 0.10)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: hasRoute
                ? AppColors.primary.withValues(alpha: 0.20)
                : Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ruta activa',
              style: AppTextStyles.etiqueta.copyWith(
                letterSpacing: 1.2,
                color: AppColors.textDisabled,
              ),
            ),
            const SizedBox(height: 12),
            if (hasRoute) ...[
              Text(
                route.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.titulo.copyWith(
                  color: AppColors.textOnInk,
                ),
              ),
              if (showTerminals) ...[
                const SizedBox(height: 14),
                TerminalsLine(a: a, b: b),
              ],
            ] else ...[
              Text(
                'Sin ruta activa',
                style: AppTextStyles.cuerpoFuerte.copyWith(
                  color: AppColors.textOnInk,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Elige tu ruta en el mapa',
                style: AppTextStyles.pie.copyWith(
                  color: AppColors.textDisabled,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Línea verde única entre los dos terminales: se llega a ambos puntos y se
/// puede devolver. Con un solo terminal no hay línea: queda centrado.
class TerminalsLine extends StatelessWidget {
  final String a;
  final String b;

  const TerminalsLine({super.key, required this.a, required this.b});

  @override
  Widget build(BuildContext context) {
    final textStyle = AppTextStyles.pie.copyWith(
      color: AppColors.textDisabled,
    );
    // Fallback visual: ruta de un solo terminal, sin línea incompleta.
    if (b.isEmpty) {
      return Center(
        child: Text(a,
            maxLines: 1, overflow: TextOverflow.ellipsis, style: textStyle),
      );
    }

    // Punto, trazo y punto: 4 + 22 + 4.
    const linea = 30.0;
    return LayoutBuilder(
      builder: (context, restricciones) {
        // Cada punta mide lo suyo. Con dos Flexible se partían el ancho
        // mitad y mitad aunque cupieran enteras: B18 salía «Ciudad
        // Mallor… — La Playa» con sitio de sobra después de «La Playa».
        // Si no caben las dos, la corta queda entera y la larga se lleva
        // el resto; si las dos pasan de la mitad, mitad y mitad.
        final escala = MediaQuery.textScalerOf(context);
        double natural(String texto) {
          final pintor = TextPainter(
            text: TextSpan(text: texto, style: textStyle),
            textDirection: Directionality.of(context),
            textScaler: escala,
            maxLines: 1,
          )..layout();
          // Hacia arriba: con el ancho exacto, un redondeo la cortaba.
          final ancho = pintor.width.ceilToDouble();
          pintor.dispose();
          return ancho;
        }

        final libre = math.max(
          0.0,
          restricciones.maxWidth - linea - AppSpacing.sm * 2,
        );
        final anchoA = natural(a);
        final anchoB = natural(b);
        final mitad = libre / 2;
        final (topeA, topeB) = anchoA + anchoB <= libre
            ? (anchoA, anchoB)
            : anchoA <= mitad
                ? (anchoA, libre - anchoA)
                : anchoB <= mitad
                    ? (libre - anchoB, anchoB)
                    : (mitad, mitad);

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: topeA),
              child: Text(
                a,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: textStyle,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            // Línea de ida y vuelta: punto → trazo → punto, todo en verde.
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 4,
                  height: 4,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
                Container(
                  width: 22,
                  height: 2,
                  color: AppColors.primary.withValues(alpha: 0.4),
                ),
                Container(
                  width: 4,
                  height: 4,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
            const SizedBox(width: AppSpacing.sm),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: topeB),
              child: Text(
                b,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textStyle,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Una fila del menú. Vive dentro de un grupo, así que no trae superficie
/// propia: el fondo, el radio y el borde los pone el grupo.
///
/// Ya no recibe colores. Antes el constructor exigía `bgColor` e
/// `iconColor`, y esa exigencia era la que volvía estructural el arcoíris:
/// tres filas, tres parejas de color inventadas fila por fila (ámbar,
/// celeste, rojo) sin que ninguna significara nada. Un menú no es un
/// semáforo. Los iconos son del mismo gris claro y el único color que
/// queda es el verde de la marca en el contador de avisos, que sí significa
/// algo. El rojo de «Cerrar sesión» se fue con la cuenta.
class DrawerItem extends StatefulWidget {
  final IconData icon;
  final String title;
  final Widget? trailing;
  final VoidCallback onTap;

  /// La fila entera, dicha en una frase, cuando el título no basta.
  ///
  /// El título es lo que se lee; el remate —una pastilla con un número, un
  /// galón— es lo que se ve. En voz alta van juntos o no se entienden.
  final String? dicho;

  const DrawerItem({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.trailing,
    this.dicho,
  });

  @override
  State<DrawerItem> createState() => _DrawerItemState();
}

class _DrawerItemState extends State<DrawerItem> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    // Dentro de un grupo, encoger una fila la despega de sus vecinas y del
    // filo que las separa. La respuesta al toque es el fondo, que es
    // además como responde una lista en iOS.
    return Semantics(
      button: true,
      label: widget.dicho ?? widget.title,
      // `excludeSemantics` tapa el árbol de abajo, y con él la acción del
      // gesto: sin este toque el doble toque de VoiceOver no abriría la
      // fila.
      onTap: widget.onTap,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: AppMotion.instante,
          curve: AppMotion.curvaSalida,
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: 15),
          color: Colors.white.withValues(alpha: _pressed ? 0.07 : 0),
          child: Row(
            children: [
              Icon(
                widget.icon,
                color: AppColors.textOnInk.withValues(alpha: 0.75),
                size: 22,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  widget.title,
                  style: AppTextStyles.cuerpoFuerte.copyWith(
                    color: AppColors.textOnInk,
                  ),
                ),
              ),
              if (widget.trailing != null) widget.trailing!,
            ],
          ),
        ),
      ),
    );
  }
}
