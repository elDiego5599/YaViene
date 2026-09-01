import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import '../../../../core/providers/app_state.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/widgets/live_route_backdrop.dart';
import '../providers/map_tour_provider.dart';
import '../providers/map_view_state.dart';
import '../providers/tracking_providers.dart';
import '../providers/user_location_provider.dart';

/// Centro personal de viaje: la ruta que el usuario sigue ahora mismo, la
/// ubicación del aviso y el cierre de sesión. Fondo tinta con patrón de
/// calles y entrada escalonada (fade + slide leve).
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
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 560),
    );
    _curvaCierre = CurvedAnimation(
      parent: _entrance,
      curve: const Interval(0.0, 0.4, curve: Curves.easeOutBack),
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
  /// cambio de ruta, de sesión o de avisos— iba dejando oyentes muertos que
  /// seguían evaluando su curva en cada cuadro de cada apertura.
  final Map<double, CurvedAnimation> _escalones = {};

  /// El rebote de la X de cerrar, por lo mismo: una sola vez, no por build.
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

  /// F9: cerrar sesión ahora sí muestra spinner y bloquea el doble-tap, como
  /// cualquier otro botón asíncrono de la app.
  bool _signingOut = false;

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

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider).state;
    final email = auth.email;
    final name = (auth.name ?? '').trim();
    // Solo el nombre de pila. El saludo iba con el nombre completo y
    // "Hola, Sofía Res…" se cortaba con hueco de sobra al lado; además
    // nadie saluda por nombre y apellido.
    final nombrePila = name.isEmpty ? '' : name.split(RegExp(r'\s+')).first;
    final activeAlerts = ref.watch(activeAlertsProvider);
    final inicial = name.isNotEmpty
        ? name.characters.first.toUpperCase()
        : (email != null && email.isNotEmpty
            ? email.characters.first.toUpperCase()
            : null);

    return Drawer(
      backgroundColor: AppColors.ink,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(
          right: Radius.circular(AppRadius.sheet),
        ),
      ),
      // El mismo fondo que el inicio de sesión: la red de rutas de noche
      // con el bus recorriéndola. El drawer es la única pantalla oscura que
      // se abría sobre un plano de tinta con un rayado encima, y al venir
      // del login se notaba que eran dos apps distintas. El halo verde sube
      // a la altura de la marca, que aquí va arriba del todo.
      //
      // El fondo pinta TODO el drawer (incluida el área de la barra de
      // estado y el gesto inferior): la SafeArea queda solo para el
      // contenido.
      child: LiveRouteBackdrop(
        haloY: 0.12,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, 26, AppSpacing.lg, 20),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _staggered(
                    Row(
                      children: [
                        SvgPicture.asset(
                          'assets/icon/ya_viene_logo.svg',
                          width: 30,
                          height: 30,
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
                        // El fundido escalonado se queda: lo que marea es el
                        // desplazamiento, no la opacidad.
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
                                Icons.close_rounded,
                                color:
                                    AppColors.textOnInk.withValues(alpha: 0.75),
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
                  const SizedBox(height: 22),
                  _staggered(
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.12),
                        ),
                      ),
                      child: Row(
                        children: [
                          // El único bloque de color macizo del panel. Con
                          // todo lo demás en monocromo, el verde por fin
                          // significa algo en vez de ser un tono más.
                          Container(
                            width: 52,
                            height: 52,
                            alignment: Alignment.center,
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                            child: inicial == null
                                ? const Icon(
                                    Icons.person_rounded,
                                    color: Colors.white,
                                    size: 28,
                                  )
                                : Text(
                                    inicial,
                                    style: AppTextStyles.titulo.copyWith(
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  nombrePila.isNotEmpty
                                      ? 'Hola, $nombrePila'
                                      : 'Hola',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.subtitulo.copyWith(
                                    color: AppColors.textOnInk,
                                  ),
                                ),
                                if (email != null && email.isNotEmpty) ...[
                                  const SizedBox(height: 3),
                                  Text(
                                    email,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTextStyles.pie.copyWith(
                                      color: AppColors.textDisabled,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    0.08,
                  ),
                  const SizedBox(height: 26),
                  _staggered(const ActiveRouteCard(), 0.16),
                  const SizedBox(height: 30),
                  _staggered(
                    _grupo([
                      DrawerItem(
                        icon: Icons.notifications_none_rounded,
                        title: 'Avisos',
                        trailing: activeAlerts.isEmpty
                            ? Icon(
                                Icons.chevron_right_rounded,
                                color:
                                    AppColors.textOnInk.withValues(alpha: 0.3),
                                size: 20,
                              )
                            : Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.sm, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
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
                          // Sin cerrar el drawer: al volver de Notificaciones se
                          // regresa al menú abierto, no al mapa.
                          context.push('/notifications');
                        },
                      ),
                      DrawerItem(
                        icon: Icons.help_outline_rounded,
                        title: 'Ver guía de uso',
                        onTap: () async {
                          // F8: reiniciar la guía borra la ruta/bus activos sin
                          // avisar. Si hay algo que perder, se confirma antes.
                          final hasSelection =
                              ref.read(selectedRouteProvider) != null ||
                                  ref.read(selectedBusesProvider).isNotEmpty;
                          if (hasSelection) {
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (dialogContext) => AlertDialog(
                                title: const Text('¿Reiniciar la guía?'),
                                content: const Text(
                                  'Vas a perder la ruta y el bus que tienes '
                                  'seleccionados ahora mismo.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(dialogContext, false),
                                    child: const Text('Cancelar'),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(dialogContext, true),
                                    child: const Text('Reiniciar guía'),
                                  ),
                                ],
                              ),
                            );
                            if (confirmed != true || !context.mounted) return;
                          }
                          // La guía empieza limpia: se deselecciona el bus y se
                          // quita la ruta activa para que el flujo arranque
                          // desde cero (si la ruta queda, sus buses siguen
                          // tocables durante el paso de ubicación).
                          ref.read(selectedBusesProvider.notifier).clear();
                          ref.read(selectedRouteProvider.notifier).clear();
                          final location = ref.read(userLocationProvider);
                          await ref.read(mapGuideProvider.notifier).restart(
                                userId: auth.uid,
                                hasLocation: location.hasPosition,
                                locationSettled: location.mode !=
                                        UserLocationMode.unknown &&
                                    location.mode != UserLocationMode.locating,
                              );
                          // Sin ubicación la guía empieza pidiendo el punto de
                          // espera: hay que mostrar la ciudad para saber dónde
                          // tocar, aunque la cámara esté en otro lado.
                          if (!location.hasPosition) {
                            ref
                                .read(mapCameraRequestProvider.notifier)
                                .centerOnBarranquilla();
                          }
                          if (context.mounted) Navigator.pop(context);
                        },
                      ),
                    ]),
                    0.24,
                  ),
                  const SizedBox(height: 18),
                  // Sección propia, como en Ajustes de iOS: lo destructivo
                  // no comparte bloque con lo que no lo es.
                  _staggered(
                    _grupo([
                      DrawerItem(
                        icon: Icons.logout_rounded,
                        title:
                            _signingOut ? 'Cerrando sesión…' : 'Cerrar sesión',
                        danger: true,
                        loading: _signingOut,
                        onTap: () async {
                          if (_signingOut) return;
                          setState(() => _signingOut = true);
                          await signOutAndGoToLogin(ref, context);
                          if (mounted) setState(() => _signingOut = false);
                        },
                      ),
                    ]),
                    0.32,
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

    return Container(
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
            'RUTA ACTIVA',
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

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Flexible(
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
        Flexible(
          child: Text(
            b,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textStyle,
          ),
        ),
      ],
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
/// queda es el verde de la marca en el contador de avisos y el rojo de
/// [danger], que sí significan algo.
class DrawerItem extends StatefulWidget {
  final IconData icon;
  final String title;
  final Widget? trailing;
  final VoidCallback onTap;

  /// Acción destructiva: tiñe icono y texto. Solo "Cerrar sesión".
  final bool danger;

  /// F9: reemplaza el ícono por un spinner y bloquea el tap — mismo patrón
  /// que ya usan los botones asíncronos del login.
  final bool loading;

  const DrawerItem({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.trailing,
    this.danger = false,
    this.loading = false,
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
    final tinte = widget.danger ? AppColors.errorOnInk : AppColors.textOnInk;
    return GestureDetector(
      onTap: widget.loading ? null : widget.onTap,
      onTapDown: widget.loading ? null : (_) => setState(() => _pressed = true),
      onTapUp: widget.loading ? null : (_) => setState(() => _pressed = false),
      onTapCancel:
          widget.loading ? null : () => setState(() => _pressed = false),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: AppMotion.instante,
        curve: AppMotion.curvaSalida,
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: 15),
        color: Colors.white.withValues(alpha: _pressed ? 0.07 : 0),
        child: Row(
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: widget.loading
                  ? Padding(
                      padding: const EdgeInsets.all(2),
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: tinte.withValues(alpha: 0.7),
                      ),
                    )
                  : Icon(
                      widget.icon,
                      color: tinte.withValues(alpha: widget.danger ? 1 : 0.75),
                      size: 22,
                    ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                widget.title,
                style: AppTextStyles.cuerpoFuerte.copyWith(color: tinte),
              ),
            ),
            if (widget.trailing != null) widget.trailing!,
          ],
        ),
      ),
    );
  }
}
