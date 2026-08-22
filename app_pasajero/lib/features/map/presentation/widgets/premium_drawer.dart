import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import '../../../../core/providers/app_state.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/widgets/map_pattern_painter.dart';
import '../providers/map_tour_provider.dart';
import '../providers/map_view_state.dart';
import '../providers/tracking_providers.dart';
import '../providers/user_location_provider.dart';

/// Centro personal de viaje: la ruta que el usuario sigue ahora mismo, la
/// ubicación del aviso y el cierre de sesión. Fondo tinta con patrón de
/// calles y entrada escalonada (fade + slide leve).
class PremiumDrawer extends ConsumerStatefulWidget {
  const PremiumDrawer({super.key});

  @override
  ConsumerState<PremiumDrawer> createState() => PremiumDrawerState();
}

class PremiumDrawerState extends ConsumerState<PremiumDrawer>
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
    // Red de seguridad para la PRIMERA apertura: si onDrawerChanged llega
    // antes de que el estado exista (el drawer se construye al abrirse),
    // el post-frame la anima igual.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _entrance.forward();
    });
  }

  @override
  void dispose() {
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

  Widget _staggered(Widget child, double start) {
    final animation = CurvedAnimation(
      parent: _entrance,
      curve: Interval(
        start,
        (start + 0.3).clamp(0.0, 1.0),
        curve: Curves.easeOutCubic,
      ),
    );
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(-0.08, 0),
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
    final activeAlerts = ref.watch(activeAlertsProvider);

    return Drawer(
      backgroundColor: AppColors.ink,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(
          right: Radius.circular(28),
        ),
      ),
      // El patrón pinta TODO el drawer (incluido el área de la barra de
      // estado y el gesto inferior): la SafeArea queda solo para el contenido.
      child: CustomPaint(
        painter: const MapPatternPainter(),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 26, 24, 20),
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
                        const Expanded(
                          child: Text(
                            'Ya Viene',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFF8FAFC),
                              letterSpacing: -0.6,
                            ),
                          ),
                        ),
                        // Cierre explícito y editorial: la X roja "aparece" con la entrada
                        // (escala con rebote) dentro de un botón circular suave.
                        ScaleTransition(
                          scale: Tween<double>(begin: 0.5, end: 1.0).animate(
                            CurvedAnimation(
                              parent: _entrance,
                              curve: const Interval(
                                0.0,
                                0.4,
                                curve: Curves.easeOutBack,
                              ),
                            ),
                          ),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: const BoxDecoration(
                              color: Color(0x26DC2626),
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              key: const ValueKey('drawer_close'),
                              onPressed: () => Navigator.pop(context),
                              padding: EdgeInsets.zero,
                              icon: const Icon(
                                Icons.close_rounded,
                                color: Color(0xFFFF6B6B),
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
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.12),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: const Icon(
                              Icons.person_rounded,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name.isNotEmpty ? 'Hola, $name' : 'Hola',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFFF8FAFC),
                                    letterSpacing: -0.4,
                                  ),
                                ),
                                if (email != null && email.isNotEmpty) ...[
                                  const SizedBox(height: 3),
                                  Text(
                                    email,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
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
                    DrawerItem(
                      icon: Icons.notifications_none_rounded,
                      bgColor: AppColors.warningLight,
                      iconColor: AppColors.warning,
                      title: 'Avisos',
                      trailing: activeAlerts.isEmpty
                          ? const Icon(
                              Icons.chevron_right_rounded,
                              color: Color(0x4DFFFFFF),
                              size: 20,
                            )
                          : Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFB8B6B),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                '${activeAlerts.length}',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
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
                    0.24,
                  ),
                  const SizedBox(height: 12),
                  _staggered(
                    DrawerItem(
                      icon: Icons.help_outline_rounded,
                      bgColor: const Color(0xFFE0F2FE),
                      iconColor: const Color(0xFF0284C7),
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
                    0.28,
                  ),
                  _staggered(
                    Column(
                      children: [
                        Divider(color: Colors.white.withValues(alpha: 0.12)),
                        const SizedBox(height: 18),
                        DrawerItem(
                          icon: Icons.logout_rounded,
                          bgColor: AppColors.errorLight,
                          iconColor: AppColors.error,
                          title: _signingOut
                              ? 'Cerrando sesión…'
                              : 'Cerrar sesión',
                          loading: _signingOut,
                          onTap: () async {
                            if (_signingOut) return;
                            setState(() => _signingOut = true);
                            await signOutAndGoToLogin(ref, context);
                            if (mounted) setState(() => _signingOut = false);
                          },
                        ),
                      ],
                    ),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: hasRoute
            ? const Color(0x1A00A859)
            : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: hasRoute
              ? const Color(0x3300A859)
              : Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'RUTA ACTIVA',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
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
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Color(0xFFF8FAFC),
                letterSpacing: -0.5,
              ),
            ),
            if (showTerminals) ...[
              const SizedBox(height: 14),
              TerminalsLine(a: a, b: b),
            ],
          ] else ...[
            const Text(
              'Sin ruta activa',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFFF8FAFC),
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Elige tu ruta en el mapa',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
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
    const textStyle = TextStyle(
      fontSize: 12.5,
      fontWeight: FontWeight.w600,
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
        const SizedBox(width: 8),
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
              color: const Color(0x6600A859),
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
        const SizedBox(width: 8),
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

class DrawerItem extends StatefulWidget {
  final IconData icon;
  final Color bgColor;
  final Color iconColor;
  final String title;
  final Widget? trailing;
  final VoidCallback onTap;

  /// F9: reemplaza el ícono por un spinner y bloquea el tap — mismo patrón
  /// que ya usan los botones asíncronos del login.
  final bool loading;

  const DrawerItem({
    super.key,
    required this.icon,
    required this.bgColor,
    required this.iconColor,
    required this.title,
    this.trailing,
    required this.onTap,
    this.loading = false,
  });

  @override
  State<DrawerItem> createState() => _DrawerItemState();
}

class _DrawerItemState extends State<DrawerItem> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.loading ? null : widget.onTap,
      onTapDown:
          widget.loading ? null : (_) => setState(() => _pressed = true),
      onTapUp: widget.loading ? null : (_) => setState(() => _pressed = false),
      onTapCancel:
          widget.loading ? null : () => setState(() => _pressed = false),
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _pressed ? 0.975 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: _pressed ? 0.09 : 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: widget.bgColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: widget.loading
                    ? Center(
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: widget.iconColor,
                          ),
                        ),
                      )
                    : Icon(widget.icon, color: widget.iconColor, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  widget.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: -0.3,
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
