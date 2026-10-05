import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import '../../../../core/widgets/latido.dart';
import '../providers/map_tour_provider.dart';
import '../providers/map_view_state.dart';
import 'route_selector_sheet.dart';

class SearchPillBar extends ConsumerStatefulWidget {
  const SearchPillBar({
    super.key,
    this.pillKey,
    this.searchActionKey,
    this.companyGuideKey,
    this.companyChoiceGuideKey,
    this.routeGuideKey,
    this.routeChoiceGuideKey,
    this.launchBusesGuideKey,
    this.onSearchOpened,
  });

  /// GlobalKey sobre la píldora blanca real: el tour de primer uso la mide
  /// para recortar su hueco exactamente sobre ella.
  final GlobalKey? pillKey;
  final GlobalKey? searchActionKey;
  final GlobalKey? companyGuideKey;
  final GlobalKey? companyChoiceGuideKey;
  final GlobalKey? routeGuideKey;
  final GlobalKey? routeChoiceGuideKey;
  final GlobalKey? launchBusesGuideKey;
  final VoidCallback? onSearchOpened;

  @override
  ConsumerState<SearchPillBar> createState() => _SearchPillBarState();
}

class _SearchPillBarState extends ConsumerState<SearchPillBar> {
  bool _menuPressed = false;
  bool _actionPressed = false;
  bool _searchPressed = false;

  void _onMenuTap() {
    // Con la guía en marcha el menú la dejaría a medias. Hoy el velo ya
    // tapa el botón; esto lo cubre en los pasos que lo destapen.
    final guia = ref.read(mapGuideProvider);
    if (guia.isActive || guia.bienvenida) return;
    HapticFeedback.lightImpact();
    Scaffold.of(context).openDrawer();
  }

  void _onSearchTap() {
    HapticFeedback.lightImpact();
    _openSelector();
  }

  @override
  Widget build(BuildContext context) {
    final selectedRoute = ref.watch(selectedRouteProvider);
    // La hoja de abajo también abre el selector («Escoge empresa y ruta»):
    // lo pide, y se abre aquí como desde la lupa.
    ref.listen<int>(pedirSelectorProvider, (_, __) => _openSelector());
    // ACC-01: el texto de la píldora cambia, pero el lector solo lo lee si
    // el foco pasa por aquí. Quien eligió la ruta en el selector y volvió
    // al mapa no se enteraba de que quedó puesta: se le dice una vez, y
    // solo si de verdad cambió.
    ref.listen<RouteInfo?>(selectedRouteProvider, (antes, ahora) {
      if (antes?.id == ahora?.id) return;
      SemanticsService.sendAnnouncement(
        View.of(context),
        ahora != null ? 'Ruta activa: ${ahora.name}' : 'Sin ruta activa',
        TextDirection.ltr,
      );
    });

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Container(
          key: widget.pillKey,
          // Alto mínimo, no alto fijo. Dentro van dos líneas de texto, y
          // con el tamaño del sistema al 135% —que iOS ofrece sin entrar
          // siquiera en accesibilidad— no cabían y se recortaban.
          //
          // El alto fijo apretaba el contenido a 46: el botón del menú
          // pide 48 y se quedaba sin dos. Ahora cabe entero, y el relleno
          // baja a 5 para que la píldora siga midiendo los mismos 60 de
          // antes (48 + 5 + 5 + los dos del filo).
          constraints: const BoxConstraints(minHeight: 60),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            // La píldora flota sobre un mapa de colores impredecibles: el
            // filo la recorta contra un parque verde o una avenida clara,
            // donde solo la sombra la dejaba difusa.
            border: Border.all(color: AppColors.hairline),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryDeep.withValues(alpha: 0.08),
                blurRadius: 24,
                offset: const Offset(0, 8),
              )
            ],
          ),
          child: Row(
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _onMenuTap,
                onTapDown: (_) => setState(() => _menuPressed = true),
                onTapUp: (_) => setState(() => _menuPressed = false),
                onTapCancel: () => setState(() => _menuPressed = false),
                child: Semantics(
                  button: true,
                  label: 'Abrir menú',
                  child: Tooltip(
                    message: 'Menú',
                    child: AnimatedContainer(
                      duration: AppMotion.instante,
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _menuPressed
                            ? AppColors.surfaceMuted
                            : Colors.transparent,
                      ),
                      child: const Icon(
                        Icons.menu_outlined,
                        color: AppColors.primaryDeep,
                        size: 22,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: GestureDetector(
                  key: widget.searchActionKey,
                  behavior: HitTestBehavior.opaque,
                  onTap: _onSearchTap,
                  onTapDown: (_) => setState(() => _searchPressed = true),
                  onTapUp: (_) => setState(() => _searchPressed = false),
                  onTapCancel: () => setState(() => _searchPressed = false),
                  // El bloque de texto queda centrado en la píldora: cada fila
                  // usa MainAxisAlignment.center y Flexible para poder
                  // elidir nombres de ruta largos sin desbordar.
                  child: Semantics(
                    button: true,
                    // Ya se anuncia como botón: repetir «toca para cambiar»
                    // en la etiqueta solo alargaba lo que dice el lector.
                    label: selectedRoute != null
                        ? 'Ruta activa: ${selectedRoute.name}'
                        : '¿Qué bus esperas? Toca para buscar tu ruta',
                    excludeSemantics: true,
                    // Los dos botones de los lados se apagan al tocarlos y
                    // esta zona —que es la mitad de la píldora— no acusaba
                    // recibo de nada. Un texto sin fondo propio responde
                    // atenuándose, como en iOS.
                    child: AnimatedOpacity(
                      opacity: _searchPressed ? 0.5 : 1,
                      duration: AppMotion.instante,
                      // `heightFactor: 1` centra el texto a lo ancho sin
                      // estirarlo a lo alto. Sin él, al quitarle el alto
                      // fijo a la píldora este centro se comía todo el
                      // alto disponible y la píldora crecía hasta llenar
                      // la pantalla.
                      // T6.6: la zona que se toca mide 48 de alto aunque el
                      // texto con ruta puesta mida ~40 (220 × 40 lo marcaba
                      // la guía de Android). Crece el área que se puede
                      // tocar, no el dibujo: la píldora sigue en 60.
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 48),
                        child: Center(
                          heightFactor: 1,
                          // Al elegir o quitar la ruta, el texto se releva
                          // fundiéndose en vez de cambiar de un cuadro al
                          // siguiente: la píldora es lo primero que se mira,
                          // y ahí un corte seco se lee como un parpadeo.
                          child: AnimatedSwitcher(
                            duration:
                                AppMotion.duracion(context, AppMotion.normal),
                            // Encadenado, como en la hoja de abajo: dos
                            // nombres cruzados a la vez no se leen.
                            switchInCurve: const Interval(0.3, 1,
                                curve: AppMotion.curvaEntrada),
                            switchOutCurve: const Interval(0.6, 1,
                                curve: AppMotion.curvaSalida),
                            transitionBuilder: _relevoDeTexto,
                            child: selectedRoute != null
                                ? _rutaActiva(selectedRoute.name)
                                : _sinRuta(),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              // La X y el botón de filtros se relevan fundiéndose con un
              // leve cambio de escala, como un icono que se convierte en
              // otro, y no de un cuadro al siguiente.
              AnimatedSwitcher(
                duration: AppMotion.duracion(context, AppMotion.normal),
                switchInCurve: AppMotion.curvaEntrada,
                switchOutCurve: AppMotion.curvaSalida,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(
                    scale: Tween<double>(begin: 0.8, end: 1).animate(animation),
                    child: child,
                  ),
                ),
                child: selectedRoute != null
                    ? _buildCloseButton()
                    : _buildFilterButton(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Con ruta: la etiqueta «Ruta activa» arriba, en pequeño y en verde, y
  /// el nombre de la ruta debajo, que es lo que de verdad se lee. Antes iba
  /// al revés y con «Toca para cambiar» pegado: el nombre quedaba arriba sin
  /// contexto y la instrucción sobraba en una píldora que ya se sabe tocar.
  /// La clave es la ruta: al cambiar de una a otra el texto se releva.
  Widget _rutaActiva(String nombre) {
    return Column(
      key: ValueKey(nombre),
      mainAxisSize: MainAxisSize.min,
      children: [
        const EtiquetaRutaActiva(),
        const SizedBox(height: 1),
        Text(
          nombre,
          style: AppTextStyles.subtitulo,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _sinRuta() {
    return Column(
      key: const ValueKey('sin-ruta'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '¿Qué bus esperas?',
          style: AppTextStyles.subtitulo,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 2),
        Text(
          'Toca para buscar tu ruta',
          style: AppTextStyles.pie,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  /// El relevo del texto de la píldora: fundido con un paso corto hacia
  /// arriba, lo justo para que se lea que cambió sin que la píldora parezca
  /// moverse.
  Widget _relevoDeTexto(Widget child, Animation<double> animation) {
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: Offset(0, 0.2 * AppMotion.desplazamiento(context)),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
    );
  }

  Widget _buildActionButton({
    required Key key,
    required Color iconColor,
    required IconData icon,
    required VoidCallback onTap,
    required String semanticLabel,
    bool filled = false,
  }) {
    // La llave es la que deja al relevo de la cola distinguir la X del
    // botón de filtros: sin ella son el mismo widget y cambian de golpe.
    return GestureDetector(
      key: key,
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onTapDown: (_) => setState(() => _actionPressed = true),
      onTapUp: (_) => setState(() => _actionPressed = false),
      onTapCancel: () => setState(() => _actionPressed = false),
      child: Semantics(
        button: true,
        label: semanticLabel,
        child: Tooltip(
          message: semanticLabel,
          child: AnimatedContainer(
            duration: AppMotion.instante,
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _actionPressed
                  ? AppColors.surfaceMuted
                  : (filled
                      ? AppColors.surfaceMuted.withValues(alpha: 0.7)
                      : Colors.transparent),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
        ),
      ),
    );
  }

  /// Botón de limpiar, no de borrar.
  ///
  /// Estaba en rojo de error. Quitar la ruta elegida no destruye nada —se
  /// vuelve a elegir en dos toques— y el rojo prometía una consecuencia
  /// que no existe. Va en gris con su círculo, como la X que limpia un
  /// campo de texto en iOS.
  Widget _buildCloseButton() {
    return _buildActionButton(
      key: const ValueKey('pill-quitar-ruta'),
      iconColor: AppColors.textSecondary,
      filled: true,
      icon: Icons.close_outlined,
      semanticLabel: 'Quitar ruta activa',
      onTap: () {
        HapticFeedback.mediumImpact();
        // Quitar la ruta activa deja la elección en blanco: también se limpia
        // la empresa para que la nueva elección empiece desde cero.
        ref.read(selectedRouteProvider.notifier).clear();
        ref.read(selectedCompanyProvider.notifier).clear();
      },
    );
  }

  /// Abre el selector y avisa mientras esté arriba.
  ///
  /// El aviso es lo que aparta la hoja de distancia, que se apoya en el
  /// mismo borde: la bandera se baja cuando el diálogo termina de cerrarse,
  /// haya elegido ruta o no, así que la hoja vuelve sola si el usuario se
  /// arrepintió.
  Future<void> _openSelector() async {
    widget.onSearchOpened?.call();
    ref.read(routeSelectorOpenProvider.notifier).state = true;
    try {
      await RouteSelectorSheet.show(
        context,
        sheet: RouteSelectorSheet(
          companyGuideKey: widget.companyGuideKey,
          companyChoiceGuideKey: widget.companyChoiceGuideKey,
          routeGuideKey: widget.routeGuideKey,
          routeChoiceGuideKey: widget.routeChoiceGuideKey,
          launchBusesGuideKey: widget.launchBusesGuideKey,
        ),
      );
    } finally {
      if (mounted) ref.read(routeSelectorOpenProvider.notifier).state = false;
    }
  }

  Widget _buildFilterButton() {
    return _buildActionButton(
      key: const ValueKey('pill-filtro'),
      iconColor: AppColors.primaryDeep,
      icon: Icons.tune_outlined,
      semanticLabel: 'Cambiar ruta',
      onTap: () {
        HapticFeedback.lightImpact();
        _openSelector();
      },
    );
  }
}

/// «Ruta activa» con un destello: la etiqueta va en esmeralda hondo y una
/// franja de luz la cruza de izquierda a derecha, como el brillo que pasa
/// por un metal. Dice que la ruta está viva sin dibujar nada más: ni punto
/// (el dueño lo quitó), ni chapa, ni halo alrededor.
///
/// Segunda versión (dueño, 2026-09-27: «se ve estático»). La primera iba de
/// #065F46 a #038750 cada 6 s: la franja brillaba 2,1 veces la tinta y en
/// 12 px el ojo no la veía pasar. El pico no puede aclararse más sin bajar
/// de 4,5:1, así que ahora la tinta es más honda (#064E3B) y el pico es el
/// verde de marca oscurecido justo hasta 4,5 (#008846): 3,1 veces más luz,
/// con el tono de la marca. Va en w600 —más letra por donde pase la luz— y
/// vuelve cada 3 s.
///
/// Cruza y descansa en vez de correr sin parar (ver [Latido]).
class EtiquetaRutaActiva extends StatelessWidget {
  const EtiquetaRutaActiva({super.key});

  /// Lo que tarda la luz en cruzar.
  static const pasadaDura = Duration(milliseconds: 1600);

  /// El descanso entre pasadas.
  static const pausa = Duration(milliseconds: 1400);

  /// La tinta en reposo: 9,7:1 sobre blanco.
  static const tinta = Color(0xFF064E3B);

  /// Lo más claro de la franja: el verde de marca (#00A859) oscurecido hasta
  /// donde el texto aún da 4,56:1 (F4 pide 4,5). El de marca a secas se
  /// queda en 3,1 y ya no se lee.
  static const destello = Color(0xFF008846);

  /// Velocidad de la luz: arranca y frena suave, pero cruza casi pareja —
  /// una `easeInOut` la dejaba medio latido quieta en los bordes, fuera del
  /// texto, y el cruce de verdad duraba un suspiro.
  static const _curva = Cubic(0.45, 0, 0.55, 1);

  /// El degradado en el punto `t` (0 → 1) de la pasada. La franja entra y
  /// sale por fuera del texto, así que en 0 y en 1 todo es tinta.
  static LinearGradient pasada(double t) {
    const medioAncho = 0.3;
    final centro = -medioAncho + (1 + 2 * medioAncho) * t;
    double tope(double x) => x.clamp(0.0, 1.0);
    return LinearGradient(
      colors: const [tinta, destello, tinta],
      stops: [
        tope(centro - medioAncho),
        tope(centro),
        tope(centro + medioAncho),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Latido(
      dura: pasadaDura,
      pausa: pausa,
      // Una línea con puntos suspensivos: con el texto al 300 % la
      // etiqueta sola ya no cabe en la píldora y tiene que recortarse.
      child: Text(
        'Ruta activa',
        style: AppTextStyles.pie.copyWith(
          color: tinta,
          fontWeight: FontWeight.w600,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
      ),
      builder: (context, t, quieto, texto) => ShaderMask(
        // srcIn: el degradado pinta solo donde hay letra.
        blendMode: BlendMode.srcIn,
        shaderCallback: (caja) =>
            pasada(_curva.transform(t)).createShader(caja),
        child: texto,
      ),
    );
  }
}
