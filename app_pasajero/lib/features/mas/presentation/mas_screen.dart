import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import '../../../core/app_info.dart';
import '../../../core/router/app_router.dart';
import '../../../core/widgets/barra_vidrio.dart';
import '../../../core/widgets/dialogo.dart';
import '../../../core/widgets/titulo_seccion.dart';
import '../../legal/legal_docs.dart';
import '../../map/presentation/providers/map_tour_provider.dart';
import '../../map/presentation/providers/map_view_state.dart';
import '../../map/presentation/providers/tracking_providers.dart';
import '../../map/presentation/providers/user_location_provider.dart';
import 'fondo_ilustrado.dart';

/// La pestaña «Info»: la ruta que se sigue, la guía de uso y lo que se
/// consulta de vez en cuando (lo legal y, en Acerca de, la versión y los
/// créditos del mapa).
/// Es lo que quedó del menú lateral cuando Avisos y el buzón pasaron a ser
/// pestañas de la píldora de abajo (dueño, 2026-10-16).
///
/// Sin la entrada escalonada del menú: cambiar de pestaña es instantáneo en
/// iOS, y una página que se arma por partes cada vez que se vuelve a ella
/// se lee como lenta. Fondo de ilustraciones (dueño, 2026-10-18), con
/// tarjetas blancas que se despegan con su sombra (dueño, 2026-10-16).
class MasScreen extends ConsumerWidget {
  const MasScreen({super.key});

  /// Lo más ancho que se abre la columna. Las filas a lo ancho de un
  /// teléfono grande se veían «todo muy ancho» (dueño, 2026-10-16): como
  /// las listas de Ajustes, la columna se queda en una medida que se lee
  /// de un vistazo y respira a los lados.
  static const double anchoMaximo = 340;

  /// La píldora blanca de la marca sobre las ilustraciones.
  static const pildoraKey = ValueKey('mas-pildora');

  /// El aire a cada lado de la columna, más que el de las demás pestañas:
  /// sobre las ilustraciones, el fondo que se ve a los lados es el que hace
  /// que las tarjetas floten.
  static const double margen = 32;

  /// Un solo bloque para las acciones, con filos finos entre filas.
  ///
  /// Antes cada fila era su propia tarjeta: fondo blanco al 5 %, borde al
  /// 8 %, esquinas de 16 — y encima, dos tarjetas más con alfas casi
  /// idénticas (0,08/0,12 y 0,05/0,10). Cinco superficies que no se
  /// distinguen entre sí no hacen jerarquía, hacen ruido. Agrupadas, la
  /// lista se lee de un golpe y la tarjeta de arriba vuelve a destacar.
  Widget _grupo(List<Widget> filas) {
    final hijos = <Widget>[];
    for (var i = 0; i < filas.length; i++) {
      if (i > 0) {
        hijos.add(const Divider(
          height: 1,
          thickness: 1,
          // Sangrado hasta donde empieza el texto, como en iOS: el filo
          // separa las filas sin cortar la columna de iconos.
          indent: 52,
          color: AppColors.divider,
        ));
      }
      hijos.add(filas[i]);
    }
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: _tarjeta,
      child: Column(children: hijos),
    );
  }

  /// Qué versión está instalada, dicho en una ventana propia y no con
  /// `showAboutDialog`: esa trae sus botones en inglés mientras la app no
  /// cargue las traducciones de Material, y abre una lista de licencias
  /// entera —también en inglés— desde la app de un pasajero.
  Future<void> _acercaDe(BuildContext context) {
    return mostrarDialogo<void>(
      context,
      (dialogContext) => Dialogo(
        icono: Icons.info_outline_rounded,
        titulo: 'Ya Viene',
        detalle: 'Versión $kAppVersion',
        // Los créditos del mapa van aquí y no sueltos en Info (dueño,
        // 2026-10-18: «quita la pill de MapLibre y eso ponlo dentro de
        // Acerca de»). Los espacios duros pegan cada © a su nombre.
        mensaje: 'Piloto en Barranquilla. Las posiciones salen del GPS que '
            'va instalado en cada bus.\n\n'
            'Mapa: ©\u00A0MapLibre, ©\u00A0OpenStreetMap, ©\u00A0CARTO',
        principal: DialogoAccion(
          'Cerrar',
          () => Navigator.pop(dialogContext),
        ),
      ),
    );
  }

  /// La guía empieza de cero en el mapa. F8: reiniciarla borra la ruta y el
  /// bus activos, así que si hay algo que perder se confirma antes.
  Future<void> _verGuia(BuildContext context, WidgetRef ref) async {
    final hasSelection = ref.read(selectedRouteProvider) != null ||
        ref.read(selectedBusesProvider).isNotEmpty;
    if (hasSelection) {
      final confirmed = await mostrarDialogo<bool>(
        context,
        (dialogContext) => Dialogo(
          icono: Icons.restart_alt_outlined,
          titulo: '¿Reiniciar la guía?',
          mensaje: 'Vas a perder la ruta y el bus que '
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
      if (confirmed != true || !context.mounted) return;
    }
    // La guía empieza limpia: se deselecciona el bus y se quita la ruta
    // activa para que el flujo arranque desde cero (si la ruta queda, sus
    // buses siguen tocables durante el paso de ubicación).
    ref.read(selectedBusesProvider.notifier).clear();
    ref.read(selectedRouteProvider.notifier).clear();
    final location = ref.read(userLocationProvider);
    await ref.read(mapGuideProvider.notifier).restart(
          hasLocation: location.hasPosition,
          locationSettled: location.mode != UserLocationMode.unknown &&
              location.mode != UserLocationMode.locating,
        );
    // Sin ubicación la guía empieza pidiendo el punto de espera: hay que
    // mostrar la ciudad para saber dónde tocar, aunque la cámara esté en
    // otro lado.
    if (!location.hasPosition) {
      ref.read(mapCameraRequestProvider.notifier).centerOnBarranquilla();
    }
    // La guía vive en el mapa: se va a esa pestaña.
    if (context.mounted) context.go(AppRoutes.map);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // El fondo es claro: la hora y la batería en oscuro.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      // El fondo pinta TODA la pantalla, también bajo la barra de estado y
      // la píldora: la SafeArea queda solo para el contenido.
      child: FondoIlustrado(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          // Lo de abajo pasa por debajo de la barra, que es de vidrio como
          // en Avisos y Buzón (dueño, 2026-10-18).
          extendBodyBehindAppBar: true,
          // La marca al centro, como en el arranque, y fija: al bajar se
          // escondía con lo demás (dueño, 2026-10-16). En reposo, 26 por
          // encima y 26 hasta la tarjeta, como antes.
          appBar: barraVidrio(
            title: MediaQuery.withClampedTextScaling(
              // El techo de los títulos de las otras barras: la barra no se
              // estira.
              maxScaleFactor: 1.3,
              child: const _Marca(),
            ),
            automaticallyImplyLeading: false,
            toolbarHeight: 26 + _Marca.alto + 26,
          ),
          // Bajo el Scaffold, que suma la barra al relleno de arriba.
          // El Builder lee el relleno con la barra ya sumada.
          body: Builder(
            builder: (context) => SafeArea(
              top: false,
              // El scroll va a todo el ancho: su recorte no corta las sombras
              // de las tarjetas; el margen y el ancho máximo van dentro.
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(margen, 0, margen, 20),
                    sliver: SliverToBoxAdapter(
                      child: Center(
                        child: ConstrainedBox(
                          constraints:
                              const BoxConstraints(maxWidth: anchoMaximo),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // En reposo, bajo la barra.
                              SizedBox(
                                  height: MediaQuery.paddingOf(context).top),
                              const ActiveRouteCard(),
                              const TituloSeccion('Ayuda'),
                              _grupo([
                                FilaMas(
                                  icon: Icons.help_outline_outlined,
                                  title: 'Ver guía de uso',
                                  onTap: () => _verGuia(context, ref),
                                ),
                              ]),
                              const TituloSeccion('Información'),
                              // Segundo grupo: lo que se consulta de vez en
                              // cuando. Sin cuenta, este es el único sitio
                              // estable donde volver a leer lo que se aceptó
                              // en la bienvenida.
                              _grupo([
                                FilaMas(
                                  icon: Icons.lock_outline_rounded,
                                  title: 'Privacidad',
                                  onTap: () => context
                                      .push(legalPath(legalPrivacidad.id)),
                                ),
                                FilaMas(
                                  icon: Icons.description_outlined,
                                  title: 'Términos',
                                  onTap: () =>
                                      context.push(legalPath(legalTerminos.id)),
                                ),
                                FilaMas(
                                  icon: Icons.info_outline_rounded,
                                  title: 'Acerca de',
                                  onTap: () => _acercaDe(context),
                                ),
                              ]),
                            ],
                          ),
                        ),
                      ),
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

/// El logo y el nombre, arriba de Info.
class _Marca extends StatelessWidget {
  const _Marca();

  /// Lo que mide con la letra normal: el logo de 30 y 8 arriba y abajo. La
  /// barra se mide con esto; con la letra grande el nombre crece hasta 4
  /// más, repartidos en el aire de los lados.
  static const double alto = 8 + 30 + 8;

  @override
  Widget build(BuildContext context) {
    return _Pildora(
      padding: const EdgeInsets.fromLTRB(14, 8, 18, 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // El logo se anunciaba como "imagen", sin más, y justo al lado va
          // el nombre escrito: es el mismo dato dos veces.
          ExcludeSemantics(
            child: SvgPicture.asset(
              'assets/icon/ya_viene_logo.svg',
              width: 30,
              height: 30,
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Semantics(
              header: true,
              child: Text(
                'Ya Viene',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                // En tinta sobre su píldora blanca (`mas_screen_test`).
                style:
                    AppTextStyles.titulo.copyWith(color: AppColors.textPrimary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Lo que se lee suelto sobre las ilustraciones va en una píldora blanca y
/// opaca, con la sombra de las tarjetas: los dibujos no se meten detrás de la
/// letra.
class _Pildora extends StatelessWidget {
  const _Pildora({required this.padding, required this.child});

  final EdgeInsets padding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: MasScreen.pildoraKey,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        boxShadow: AppShadows.floating,
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

/// La superficie de las tarjetas de Info: blanca y opaca sobre el fondo, con
/// la sombra flotante para que se despegue (dueño, 2026-10-16: «lo que ya es
/// blanco, ponerle sombras para diferenciar»).
final _tarjeta = BoxDecoration(
  color: AppColors.surface,
  borderRadius: BorderRadius.circular(AppRadius.lg),
  boxShadow: AppShadows.floating,
);

/// Pieza central de Info: la ruta que el usuario está siguiendo, con sus
/// terminales unidos por una línea de ida y vuelta. Sin ruta seleccionada
/// muestra el estado vacío.
///
/// Tocarla lleva al mapa, que es donde vive la ruta; sin ruta, además abre
/// el selector, como «Escoge empresa y ruta» en la hoja (revisión externa,
/// 2026-10-18: parecía un botón y no hacía nada). Al tocarla se hunde como
/// las tarjetas del selector.
class ActiveRouteCard extends ConsumerStatefulWidget {
  const ActiveRouteCard({super.key});

  @override
  ConsumerState<ActiveRouteCard> createState() => _ActiveRouteCardState();
}

class _ActiveRouteCardState extends ConsumerState<ActiveRouteCard> {
  bool _pressed = false;

  void _abrir() {
    HapticFeedback.selectionClick();
    if (ref.read(selectedRouteProvider) == null) {
      ref.read(pedirSelectorProvider.notifier).state++;
    }
    context.go(AppRoutes.map);
  }

  void _hundir(bool hundida) => setState(() => _pressed = hundida);

  @override
  Widget build(BuildContext context) {
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
      button: true,
      label: dicha,
      hint: hasRoute ? 'Ver en el mapa' : 'Elegir ruta en el mapa',
      // Sin esto, `excludeSemantics` se llevaría la acción del gesto y el
      // doble toque de VoiceOver no haría nada.
      onTap: _abrir,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: _abrir,
        onTapDown: (_) => _hundir(true),
        onTapUp: (_) => _hundir(false),
        onTapCancel: () => _hundir(false),
        behavior: HitTestBehavior.opaque,
        // 0,975: lo mismo que se hunden las tarjetas del selector.
        child: AnimatedScale(
          scale: _pressed ? 0.975 : 1,
          duration: AppMotion.instante,
          curve: AppMotion.curvaSalida,
          child: _tarjetaRuta(route, hasRoute, showTerminals, a, b),
        ),
      ),
    );
  }

  Widget _tarjetaRuta(
      RouteInfo? route, bool hasRoute, bool showTerminals, String a, String b) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: _tarjeta,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // El chevrón dice que la tarjeta se toca, como una fila de
          // Ajustes.
          Row(
            children: [
              Expanded(
                child: Text(
                  'Ruta activa',
                  style: AppTextStyles.etiqueta.copyWith(
                    letterSpacing: 1.2,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  size: 22, color: AppColors.textSecondary),
            ],
          ),
          const SizedBox(height: 12),
          if (hasRoute) ...[
            Text(
              route!.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.titulo,
            ),
            if (showTerminals) ...[
              const SizedBox(height: 14),
              TerminalsLine(a: a, b: b),
            ],
          ] else ...[
            Text(
              'Sin ruta activa',
              style: AppTextStyles.cuerpoFuerte,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Elige tu ruta en el mapa',
              style: AppTextStyles.pie,
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
    final textStyle = AppTextStyles.pie;
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

/// Una fila de Info. Vive dentro de un grupo, así que no trae superficie
/// propia: el fondo, el radio y el borde los pone el grupo.
///
/// Ya no recibe colores. Antes el constructor exigía `bgColor` e
/// `iconColor`, y esa exigencia era la que volvía estructural el arcoíris:
/// tres filas, tres parejas de color inventadas fila por fila (ámbar,
/// celeste, rojo) sin que ninguna significara nada. Una lista no es un
/// semáforo. Los iconos son del mismo gris y el único color que
/// queda es el verde de la marca en el contador de avisos, que sí significa
/// algo. El rojo de «Cerrar sesión» se fue con la cuenta.
class FilaMas extends StatefulWidget {
  final IconData icon;
  final String title;
  final Widget? trailing;
  final VoidCallback onTap;

  /// La fila entera, dicha en una frase, cuando el título no basta.
  ///
  /// El título es lo que se lee; el remate —una pastilla con un número, un
  /// galón— es lo que se ve. En voz alta van juntos o no se entienden.
  final String? dicho;

  const FilaMas({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.trailing,
    this.dicho,
  });

  @override
  State<FilaMas> createState() => _FilaMasState();
}

class _FilaMasState extends State<FilaMas> {
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
          color: _pressed ? AppColors.surfaceMuted : AppColors.surface,
          child: Row(
            children: [
              Icon(
                widget.icon,
                color: AppColors.textSecondary,
                size: 22,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  widget.title,
                  style: AppTextStyles.cuerpoFuerte,
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
