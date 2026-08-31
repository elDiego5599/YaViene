import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import '../../../../core/router/app_transitions.dart';
import '../providers/map_guide_copy.dart';
import '../providers/map_tour_provider.dart';
import 'map_tour_overlay.dart';

/// Selector compacto de empresa y ruta, a pantalla completa.
///
/// Ya no es una lista blanca gigante ni abre modales anidados: es una sola
/// carta del mismo tamaño que se alterna entre tres vistas internas
/// (principal, lista de empresas, lista de rutas). Cuando la guía está activa
/// la carta queda debajo del mismo [MapGuideOverlay] del resto de los pasos:
/// scrim oscuro único, solo el objetivo iluminado y la tarjeta flotante.
enum _RouteView { main, companies, routes }

class RouteSelectorSheet extends ConsumerStatefulWidget {
  const RouteSelectorSheet({
    super.key,
    this.companyGuideKey,
    this.companyChoiceGuideKey,
    this.routeGuideKey,
    this.routeChoiceGuideKey,
    this.launchBusesGuideKey,
  });

  final GlobalKey? companyGuideKey;
  final GlobalKey? companyChoiceGuideKey;
  final GlobalKey? routeGuideKey;
  final GlobalKey? routeChoiceGuideKey;
  final GlobalKey? launchBusesGuideKey;

  static Future<void> show(
    BuildContext context, {
    required RouteSelectorSheet sheet,
  }) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Selector de ruta',
      // El velo NO es el del framework: es fijo y se quedaba encima del mapa
      // con la tarjeta plegada, que es justo lo que uno pliega para ver. Lo
      // dibuja la hoja, y así se aclara al mismo tiempo que ella baja.
      barrierColor: Colors.transparent,
      transitionDuration: AppMotion.pausado,
      // La entrada la reparte la hoja por dentro: la tarjeta se desliza y el
      // velo solo se aclara. Un velo a pantalla completa que además sube
      // destapa una franja arriba mientras entra.
      transitionBuilder: (context, animation, _, child) => child,
      pageBuilder: (context, _, __) => sheet,
    );
  }

  @override
  ConsumerState<RouteSelectorSheet> createState() => _RouteSelectorSheetState();
}

/// Alto fijo de los dos tiles del paso 1 y 2, y de su placeholder.
///
/// Fijo a propósito: el tile activo dibuja su filo a 1.5 px y el inactivo a
/// 1.0, y en Flutter el borde de un `BoxDecoration` ocupa layout. Dejando
/// que el alto saliera del contenido, elegir empresa hacía crecer la
/// tarjeta 1 px por tile, y el placeholder de carga medía 2 px menos que el
/// tile real —que es justo lo que se medía para fijar el alto de las listas.
const double _kTileHeight = 78;

class _RouteSelectorSheetState extends ConsumerState<RouteSelectorSheet>
    with SingleTickerProviderStateMixin {
  static const double _fallbackCardHeight = 480;

  final GlobalKey _hostKey = GlobalKey();
  final GlobalKey _mainCardKey = GlobalKey();

  _RouteView _view = _RouteView.main;

  /// Sentido del último cambio de vista: hacia dentro (elegir) o de vuelta.
  /// La tarjeta ya no cambia de alto entre vistas, así que lo único que
  /// puede contar de dónde viene el contenido es por qué lado entra.
  bool _haciaDentro = true;

  /// La tarjeta principal se puede plegar para mirar el mapa sin cerrarla.
  /// Solo la principal: dentro de las listas de empresa y de ruta el gesto
  /// se apaga, porque ahí el usuario está en mitad de una elección y el asa
  /// es lo único que separa la lista del borde de la pantalla.
  ///
  /// 1 abierta, 0 plegada. Va pegado al dedo mientras arrastra y remata solo
  /// el camino que falte al soltar; el velo del fondo lee el mismo valor.
  late final AnimationController _pliegue;
  late final CurvedAnimation _opacidad;
  final GlobalKey _contenidoKey = GlobalKey();
  double _altoContenido = 0;
  bool _abierta = true;
  Rect? _target;
  MapGuideStep? _measuredStep;
  GlobalKey? _measuredKey;
  double? _cardHeight;
  bool _everGuided = false;
  bool _measuring = false;

  /// Aviso de "falta la empresa", pegado al tile que lo provocó.
  ///
  /// Antes era un SnackBar, y no se veía nunca: esta hoja se presenta con
  /// `showGeneralDialog`, o sea en una ruta por encima de la del mapa, y el
  /// único ScaffoldMessenger registrado es el del mapa. El SnackBar se
  /// pintaba debajo del velo del diálogo y debajo de la propia tarjeta.
  String? _routeHint;
  Timer? _routeHintTimer;

  @override
  void initState() {
    super.initState();
    _pliegue = AnimationController(
      vsync: this,
      duration: AppMotion.entrada,
      reverseDuration: AppMotion.pausado,
      value: 1,
    );
    _opacidad = CurvedAnimation(
      parent: _pliegue,
      // El contenido se apaga en el último tramo: desvaneciéndose desde el
      // principio, el texto se lee aplastándose contra el borde.
      curve: const Interval(0.35, 1, curve: AppMotion.curvaEntrada),
    );
  }

  @override
  void dispose() {
    _routeHintTimer?.cancel();
    _opacidad.dispose();
    _pliegue.dispose();
    super.dispose();
  }

  void _showRouteHint(String message) {
    HapticFeedback.mediumImpact();
    _routeHintTimer?.cancel();
    setState(() => _routeHint = message);
    _routeHintTimer = Timer(const Duration(milliseconds: 2600), () {
      if (mounted) setState(() => _routeHint = null);
    });
  }

  void _irA(_RouteView vista) {
    setState(() {
      _haciaDentro = vista != _RouteView.main;
      _view = vista;
    });
    // En las listas no se pliega: si venía plegada, se abre al entrar.
    _asentar(true);
  }

  /// Deja la tarjeta abierta o plegada y termina el camino que quede. Con
  /// impulso del dedo remata con la física del arrastre, como las hojas del
  /// sistema: soltar con brío llega antes que soltar quieto.
  void _asentar(bool abrir, {double impulso = 0}) {
    if (AppMotion.reducido(context)) {
      _pliegue.value = abrir ? 1 : 0;
    } else if (impulso != 0) {
      _pliegue.fling(velocity: impulso);
    } else if (abrir) {
      _pliegue.animateTo(1, curve: AppMotion.curvaEntrada);
    } else {
      _pliegue.animateBack(0, curve: AppMotion.curvaSalida);
    }
    if (_abierta == abrir) return;
    HapticFeedback.lightImpact();
    setState(() => _abierta = abrir);
  }

  void _arrastreEmpieza(DragStartDetails _) {
    final alto = _contenidoKey.currentContext?.size?.height ?? 0;
    if (alto > 0) _altoContenido = alto;
    _pliegue.stop();
  }

  void _arrastreSigue(DragUpdateDetails details) {
    if (_altoContenido <= 0) return;
    final avance = (details.primaryDelta ?? 0) / _altoContenido;
    _pliegue.value = (_pliegue.value - avance).clamp(0.0, 1.0);
  }

  void _arrastreTermina(DragEndDetails details) {
    final porSegundo = details.primaryVelocity ?? 0;
    // Un empujón claro manda sobre dónde quedó la tarjeta.
    if (_altoContenido > 0 && porSegundo.abs() > 320) {
      _asentar(porSegundo < 0, impulso: -porSegundo / _altoContenido);
      return;
    }
    _asentar(_pliegue.value >= 0.5);
  }

  void _clearRouteHint() {
    if (_routeHint == null) return;
    _routeHintTimer?.cancel();
    setState(() => _routeHint = null);
  }

  @override
  Widget build(BuildContext context) {
    final guide = ref.watch(mapGuideProvider);
    final step = guide.step;
    final guided = _isSelectionStep(step);
    _everGuided = _everGuided || guided;
    final targetKey = _targetKeyFor(step, _view);
    if (guided && targetKey != null) _scheduleMeasure(step!, targetKey);
    if (_view == _RouteView.main && _cardHeight == null) _measureMainCard();

    if (_everGuided && !guided) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted &&
            _everGuided &&
            !ref.read(mapGuideProvider).skipped &&
            !_isSelectionStep(ref.read(mapGuideProvider).step)) {
          Navigator.of(context).maybePop();
        }
      });
    }

    final copy = guided && step != null ? mapGuideCopy(step) : null;
    final showOverlay = copy != null &&
        _target != null &&
        _measuredStep == step &&
        _measuredKey == targetKey;

    // La animación de la ruta: el velo se aclara con ella y la tarjeta,
    // además, entra deslizándose desde abajo.
    final entrada =
        ModalRoute.of(context)?.animation ?? kAlwaysCompleteAnimation;

    return Stack(
      key: _hostKey,
      fit: StackFit.expand,
      children: [
        // El velo se aclara a la vez que la tarjeta baja: plegarla es pedir
        // ver el mapa, y un velo fijo encima dejaba el gesto a medias.
        Positioned.fill(
          child: AnimatedBuilder(
            animation: Listenable.merge([_pliegue, entrada]),
            builder: (context, _) => ColoredBox(
              key: const ValueKey('selector-velo'),
              color: AppColors.ink
                  .withValues(alpha: 0.40 * _pliegue.value * entrada.value),
            ),
          ),
        ),
        if (!guided) ...[
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).maybePop(),
            ),
          ),
        ],
        FadeSlideTransition(
          animation: entrada,
          begin: const Offset(0, 0.06),
          child: _buildCard(context, plegable: !guided),
        ),
        if (showOverlay)
          Positioned.fill(
            child: MapGuideOverlay(
              target: _target!,
              title: copy.title,
              message: copy.message,
              icon: copy.icon,
              stepIndex: mapGuideStepIndex(guide, step!),
              stepCount: mapGuideStepCount(guide),
              primaryLabel: copy.primaryLabel,
              onPrimary: copy.primaryLabel == null
                  ? null
                  : () => ref.read(mapGuideProvider.notifier).complete(step),
              onSkip: () => ref.read(mapGuideProvider.notifier).skip(),
            ),
          ),
      ],
    );
  }

  bool _isSelectionStep(MapGuideStep? step) {
    return step == MapGuideStep.company ||
        step == MapGuideStep.route ||
        step == MapGuideStep.launchBuses;
  }

  GlobalKey? _targetKeyFor(MapGuideStep? step, _RouteView view) {
    switch (view) {
      case _RouteView.companies:
        return widget.companyChoiceGuideKey;
      case _RouteView.routes:
        return widget.routeChoiceGuideKey;
      case _RouteView.main:
        switch (step) {
          case MapGuideStep.company:
            return widget.companyGuideKey;
          case MapGuideStep.route:
            return widget.routeGuideKey;
          case MapGuideStep.launchBuses:
            return widget.launchBusesGuideKey;
          default:
            return null;
        }
    }
  }

  void _scheduleMeasure(MapGuideStep step, GlobalKey targetKey) {
    if (_measuring) return;
    _measuring = true;
    _measureLoop(step, targetKey, 0);
  }

  /// Mide el objetivo de la guía y LO SIGUE mientras se mueve: la carta del
  /// selector anima con `AnimatedSwitcher` (deslizamiento lateral) y
  /// `AnimatedSize` (altura), así que una sola medición quedaría congelada a
  /// medio camino (objetivo "corrido" hacia la derecha). La cadena termina
  /// cuando el rect deja de cambiar (posición estable).
  void _measureLoop(MapGuideStep step, GlobalKey targetKey, int attempt) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measuring = false;
      if (!mounted) return;
      if (ref.read(mapGuideProvider).step != step) return;
      final hostBox = _hostKey.currentContext?.findRenderObject() as RenderBox?;
      final targetBox =
          targetKey.currentContext?.findRenderObject() as RenderBox?;
      if (targetBox == null || !targetBox.attached) {
        if (attempt < 12) _measureLoop(step, targetKey, attempt + 1);
        return;
      }
      if (hostBox == null || !hostBox.attached) return;
      final global = targetBox.localToGlobal(Offset.zero);
      final local = hostBox.globalToLocal(global);
      final rect = local & targetBox.size;
      if (rect.width <= 0 || rect.height <= 0) {
        if (attempt < 12) _measureLoop(step, targetKey, attempt + 1);
        return;
      }
      final changed =
          _target != rect || _measuredStep != step || _measuredKey != targetKey;
      if (changed) {
        setState(() {
          _target = rect;
          _measuredStep = step;
          _measuredKey = targetKey;
        });
        // Sigue midiendo mientras el objetivo se mueve (animación en curso).
        if (attempt < 40) _measureLoop(step, targetKey, attempt + 1);
      }
    });
  }

  void _measureMainCard() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _cardHeight != null || _view != _RouteView.main) return;
      final box = _mainCardKey.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.attached || box.size.height <= 0) return;
      setState(() => _cardHeight = box.size.height);
    });
  }

  Widget _buildCard(BuildContext context, {required bool plegable}) {
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;
    // Plegar solo tiene sentido en la vista principal: en las listas el
    // gesto se apaga y el asa vuelve a ser un adorno.
    final puedePlegar = plegable && _view == _RouteView.main;
    return Align(
      alignment: Alignment.bottomCenter,
      child: GestureDetector(
        // El dedo manda: la tarjeta baja y sube pegada al pulgar y termina
        // sola el camino que falte al soltar.
        onVerticalDragStart: puedePlegar ? _arrastreEmpieza : null,
        onVerticalDragUpdate: puedePlegar ? _arrastreSigue : null,
        onVerticalDragEnd: puedePlegar ? _arrastreTermina : null,
        child: Material(
          // Misma superficie que la hoja de distancia (AppColors.arena):
          // las dos tarjetas se ven una detrás de otra en el mismo flujo y
          // el salto de blanco a arena las hacía parecer de apps distintas.
          color: AppColors.arena,
          // Sobre el velo oscuro del diálogo una sombra ancha no se ve;
          // lo que define la tarjeta es el filo. Mismo tratamiento que la
          // hoja de distancia, que se ve justo después.
          elevation: 8,
          shadowColor: const Color(0x3314274E),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            side: BorderSide(color: AppColors.hairline),
          ),
          clipBehavior: Clip.antiAlias,
          // El inset del indicador de inicio va DENTRO de la hoja, no
          // debajo. Antes empujaba la tarjeta entera hacia arriba y
          // quedaba flotando: dos esquinas inferiores rectas cortadas a
          // media pantalla con el mapa oscurecido asomando debajo. Una
          // hoja se apoya en el borde de la pantalla; lo que se aparta
          // del indicador es su contenido.
          child: Padding(
            padding: EdgeInsets.only(bottom: bottomInset),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // El asa sale de las vistas y sube aquí: es de la hoja, no
                // del contenido. Así se queda quieta mientras las vistas
                // se cruzan de lado, y es lo único que sobrevive cuando la
                // hoja se pliega.
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: puedePlegar ? () => _asentar(!_abierta) : null,
                  child: AnimatedBuilder(
                    animation: _pliegue,
                    builder: (context, _) => Padding(
                      padding: EdgeInsets.only(
                        top: 16,
                        bottom: 16 * (1 - _pliegue.value),
                      ),
                      child: _handle(_pliegue.value),
                    ),
                  ),
                ),
                // El pliegue va dentro del Material, anclado bajo el asa:
                // por fuera, el recorte de la animación se comía las
                // esquinas redondeadas de arriba mientras la hoja crecía.
                // El factor es el controlador crudo, sin curva: con una curva
                // el arrastre dejaría de ir donde va el dedo.
                SizeTransition(
                  key: const ValueKey('selector-pliegue'),
                  sizeFactor: _pliegue,
                  alignment: Alignment.topCenter,
                  child: FadeTransition(
                    opacity: _opacidad,
                    child: KeyedSubtree(
                      key: _contenidoKey,
                      child: AnimatedSwitcher(
                        duration: AppMotion.duracion(context, AppMotion.normal),
                        switchInCurve: AppMotion.curvaEntrada,
                        switchOutCurve: AppMotion.curvaSalida,
                        // Empuje lateral, como una pila de navegación: lo
                        // que entra llega del lado hacia el que vamos y lo
                        // que sale se va por el contrario. Antes las dos
                        // vistas venían del mismo lado con un desplazamiento
                        // de 0.04 —imperceptible—, así que entrar y volver se
                        // veían idénticos: solo un parpadeo.
                        transitionBuilder: (child, animation) {
                          final entra =
                              (child.key as ValueKey?)?.value == _view;
                          final lado = _haciaDentro ? 1.0 : -1.0;
                          final desde = (entra ? lado : -lado) *
                              (AppMotion.reducido(context) ? 0.0 : 0.18);
                          final slide = Tween<Offset>(
                            begin: Offset(desde, 0),
                            end: Offset.zero,
                          ).animate(animation);
                          return FadeTransition(
                            opacity: animation,
                            child:
                                SlideTransition(position: slide, child: child),
                          );
                        },
                        child: KeyedSubtree(
                          key: ValueKey(_view),
                          child: switch (_view) {
                            _RouteView.main => _buildMainView(context),
                            _RouteView.companies => _buildListView(
                                title: 'Elige empresa',
                                onBack: () => _irA(_RouteView.main),
                                builder: (_) => _buildCompanyList(context),
                              ),
                            _RouteView.routes => _buildListView(
                                title: 'Elige ruta',
                                onBack: () => _irA(_RouteView.main),
                                builder: (_) => _buildRouteList(context),
                              ),
                          },
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
    );
  }

  Widget _buildMainView(BuildContext context) {
    final selectedCompany = ref.watch(selectedCompanyProvider);
    final selectedRoute = ref.watch(selectedRouteProvider);
    final companiesAsync = ref.watch(companiesProvider);

    return Padding(
      // La medida va en el Padding, no en la Column: las listas de empresa
      // y de ruta se dibujan como `SizedBox(height: _cardHeight)` con su
      // propio relleno dentro, así que midiendo solo el contenido salían
      // 40 px más bajas (16 arriba + 24 abajo) y la tarjeta se encogía al
      // entrar a elegir y volvía a crecer al salir. Entre las tres vistas
      // solo debe cambiar el contenido.
      key: _mainCardKey,
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _headerRow(title: 'Elige tu ruta'),
          const SizedBox(height: 6),
          const Text(
            'Dos pasos y ves los buses moviéndose en el mapa.',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 22),
          // Los dos pasos van colgados de una misma línea, con su nodo
          // cada uno. La línea no es adorno: dice lo único que había que
          // explicar de esta pantalla —que la ruta depende de la empresa—
          // y lo dice antes de que alguien toque nada. Antes eran dos
          // rótulos en versalitas ("EMPRESA", "RUTA") sobre dos tarjetas
          // idénticas, y el orden solo se descubría chocándose con él.
          _step(
            done: selectedCompany != null,
            current: selectedCompany == null,
            lineUp: false,
            lineDown: true,
            child: companiesAsync.when(
              data: (companies) => _PremiumSelectorTile(
                key: widget.companyGuideKey,
                title: selectedCompany?.name ?? 'Empresa',
                subtitle: selectedCompany != null
                    ? 'Empresa de transporte masivo'
                    : 'Con cuál viajas',
                icon: Icons.business_rounded,
                isActive: selectedCompany != null,
                onTap: () {
                  HapticFeedback.lightImpact();
                  _clearRouteHint();
                  _irA(_RouteView.companies);
                },
              ),
              // La guía ilumina el tile de empresa: mientras carga (o falla)
              // el hueco debe seguir existiendo, si no el overlay desaparece
              // y el usuario podría tocar otro botón y salirse del flujo.
              loading: () => _tilePlaceholder(
                key: widget.companyGuideKey,
                child: const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              ),
              error: (_, __) => _tilePlaceholder(
                key: widget.companyGuideKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Error al cargar empresas',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => ref.invalidate(companiesProvider),
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text('Reintentar'),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          _step(
            done: selectedRoute != null,
            current: selectedCompany != null && selectedRoute == null,
            lineUp: true,
            lineDown: false,
            child: _PremiumSelectorTile(
              key: widget.routeGuideKey,
              title: selectedRoute?.name ?? 'Ruta',
              subtitle: _routeSubtitle(selectedRoute) ??
                  (selectedRoute != null ? null : 'Cuál esperas'),
              icon: Icons.alt_route_rounded,
              isActive: selectedRoute != null,
              hint: _routeHint,
              onTap: () {
                if (selectedCompany == null) {
                  _showRouteHint('Elige primero la empresa');
                  return;
                }
                HapticFeedback.lightImpact();
                _clearRouteHint();
                _irA(_RouteView.routes);
              },
            ),
          ),
          const SizedBox(height: 26),
          _launchButton(context, selectedCompany, selectedRoute),
        ],
      ),
    );
  }

  Widget _buildListView({
    required String title,
    required VoidCallback onBack,
    required Widget Function(BuildContext) builder,
  }) {
    final height = _cardHeight ?? _fallbackCardHeight;
    return SizedBox(
      height: height,
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _headerRow(title: title, onBack: onBack),
            const SizedBox(height: 12),
            // Las filas no se cortan a filo vivo contra el título ni contra
            // el borde de la hoja: se desvanecen. Antes una fila a medio
            // salir quedaba partida por la mitad justo debajo del título y
            // parecía que se metía por detrás de él.
            Expanded(child: _listaConDesvanecido(builder(context))),
          ],
        ),
      ),
    );
  }

  /// Recorta la lista a su caja y le funde 16 px arriba y abajo.
  ///
  /// El `Material` transparente no es decorativo: es lo que arregla el bug
  /// de las filas que se veían subir por detrás del título. `ListTile`
  /// pinta su fondo con `Ink`, y un `Ink` no se dibuja donde está, sino en
  /// la capa de tinta del `Material` más cercano. El más cercano era la
  /// hoja entera, o sea por fuera del `ListView` y de cualquier recorte
  /// intermedio: las filas que salían del viewport seguían pintando su
  /// rectángulo blanco encima de la cabecera. Con un `Material` propio
  /// dentro del recorte, la tinta vive donde debe.
  Widget _listaConDesvanecido(Widget lista) {
    final conTinta = Material(type: MaterialType.transparency, child: lista);
    return LayoutBuilder(
      builder: (context, constraints) {
        final alto = constraints.maxHeight;
        if (!alto.isFinite || alto <= 48) return ClipRect(child: conTinta);
        final fundido = (16 / alto).clamp(0.0, 0.2);
        return ClipRect(
          child: ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (rect) => LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: const [
                Colors.transparent,
                Colors.black,
                Colors.black,
                Colors.transparent,
              ],
              stops: [0.0, fundido, 1 - fundido, 1.0],
            ).createShader(rect),
            child: conTinta,
          ),
        );
      },
    );
  }

  Widget _buildCompanyList(BuildContext context) {
    final companiesAsync = ref.watch(companiesProvider);
    final selectedCompany = ref.watch(selectedCompanyProvider);
    return companiesAsync.when(
      data: (companies) => ListView(
        key: widget.companyChoiceGuideKey,
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.zero,
        children: [
          if (companies.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Text(
                'Sin empresas disponibles',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
            )
          else
            ...companies.map((company) {
              return _compactTile(
                icon: Icons.business_rounded,
                iconColor: Colors.white,
                iconBackground: _companyColor(company.id),
                // V2: insignia de iniciales con color determinístico — se
                // reconoce la fila antes de leer el nombre, como en Bolt.
                badgeInitials: _companyInitials(company.name),
                title: company.name,
                subtitle: null,
                selected: selectedCompany?.id == company.id,
                onTap: () {
                  HapticFeedback.selectionClick();
                  final alreadySelected =
                      ref.read(selectedCompanyProvider)?.id == company.id;
                  ref.read(selectedCompanyProvider.notifier).select(company);
                  if (!alreadySelected) {
                    ref.read(selectedRouteProvider.notifier).clear();
                  }
                  ref
                      .read(mapGuideProvider.notifier)
                      .complete(MapGuideStep.company);
                  _irA(_RouteView.main);
                },
              );
            }),
        ],
      ),
      loading: () => _listPlaceholder(
        key: widget.companyChoiceGuideKey,
      ),
      error: (_, __) => _listPlaceholder(
        key: widget.companyChoiceGuideKey,
        message: 'Error al cargar empresas',
        onRetry: () => ref.invalidate(companiesProvider),
      ),
    );
  }

  Widget _buildRouteList(BuildContext context) {
    final selectedCompany = ref.watch(selectedCompanyProvider);
    if (selectedCompany == null) return const SizedBox.shrink();
    final selectedRoute = ref.watch(selectedRouteProvider);
    final routesAsync = ref.watch(routesByCompanyProvider(selectedCompany.id));
    return routesAsync.when(
      data: (routes) => ListView(
        key: widget.routeChoiceGuideKey,
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.zero,
        children: [
          if (routes.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Text(
                'Esta empresa no tiene rutas aún',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
            )
          else
            ...routes.map((route) => _compactTile(
                  icon: Icons.alt_route_rounded,
                  iconColor: AppColors.primary,
                  iconBackground: AppColors.primaryTint,
                  title: route.name,
                  subtitle: _routeSubtitle(route) ?? 'Tiempo real',
                  selected: selectedRoute?.id == route.id,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    ref.read(selectedRouteProvider.notifier).select(route);
                    ref
                        .read(mapGuideProvider.notifier)
                        .complete(MapGuideStep.route);
                    _irA(_RouteView.main);
                  },
                )),
        ],
      ),
      loading: () => _listPlaceholder(
        key: widget.routeChoiceGuideKey,
      ),
      error: (_, __) => _listPlaceholder(
        key: widget.routeChoiceGuideKey,
        message: 'Error al cargar las rutas',
        onRetry: () => ref.invalidate(
          routesByCompanyProvider(selectedCompany.id),
        ),
      ),
    );
  }

  /// El botón que siempre lleva al siguiente paso.
  ///
  /// Era un bloque gris muerto con la frase "Selecciona una ruta para
  /// continuar" escrita encima: instrucciones sobre un botón que no se
  /// puede pulsar. Ahora hace lo que dice y dice lo que hace —lleva al
  /// paso que falte— y cuando ya no falta ninguno, se enciende en verde.
  Widget _launchButton(
      BuildContext context, Company? company, RouteInfo? route) {
    final String label;
    final VoidCallback action;
    if (company == null) {
      label = 'Elegir empresa';
      action = () {
        HapticFeedback.lightImpact();
        _clearRouteHint();
        _irA(_RouteView.companies);
      };
    } else if (route == null) {
      label = 'Elegir ruta';
      action = () {
        HapticFeedback.lightImpact();
        _clearRouteHint();
        _irA(_RouteView.routes);
      };
    } else {
      label = 'Ver buses en vivo';
      // El botón abre el mapa, no enciende nada: los buses ya están en la
      // calle publicando su posición, existan o no pasajeros mirándolos.
      action = () async {
        HapticFeedback.mediumImpact();
        await ref
            .read(mapGuideProvider.notifier)
            .complete(MapGuideStep.launchBuses);
        if (context.mounted) Navigator.of(context).maybePop();
      };
    }
    final listo = route != null;

    return ElevatedButton(
      key: widget.launchBusesGuideKey,
      onPressed: action,
      style: ElevatedButton.styleFrom(
        backgroundColor: listo ? AppColors.primary : AppColors.primaryDeep,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 58),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        elevation: 0,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _step({
    required bool done,
    required bool current,
    required bool lineUp,
    required bool lineDown,
    required Widget child,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _StepRail(
            done: done,
            current: current,
            lineUp: lineUp,
            lineDown: lineDown,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: child,
            ),
          ),
        ],
      ),
    );
  }

  /// El asa de la hoja, la misma que la de la tarjeta de distancia: al
  /// plegarse ensancha y se oscurece un punto, que es la señal de que ahí
  /// hay algo que volver a abrir sin tener que dibujar una flecha.
  Widget _handle(double abierta) {
    return Center(
      child: Container(
        key: const ValueKey('selector-handle'),
        width: 56 - 12 * abierta,
        height: 5,
        decoration: BoxDecoration(
          color: Color.lerp(
            AppColors.textDisabled,
            AppColors.divider,
            abierta,
          ),
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }

  /// Placeholder del tile de empresa con la MISMA altura que
  /// `_PremiumSelectorTile`: mientras cargan las empresas (o fallan) el hueco
  /// de la guía sigue anclado a su posición real.
  Widget _tilePlaceholder({Key? key, required Widget child}) {
    return Container(
      key: key,
      height: _kTileHeight,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.hairline),
      ),
      child: child,
    );
  }

  /// Estado de carga/error de las listas secundarias. Mantiene la key del
  /// objetivo de la guía para que el overlay nunca desaparezca mientras el
  /// usuario espera (y no pueda salirse tocando el back u otro botón).
  Widget _listPlaceholder({Key? key, String? message, VoidCallback? onRetry}) {
    return Center(
      key: key,
      child: message == null
          ? const CircularProgressIndicator()
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Reintentar'),
                ),
              ],
            ),
    );
  }

  Widget _headerRow({
    required String title,
    VoidCallback? onBack,
  }) {
    return Row(
      children: [
        if (onBack != null)
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded,
                color: AppColors.primaryDeep),
            onPressed: onBack,
            visualDensity: VisualDensity.compact,
          ),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _compactTile({
    required IconData icon,
    required Color iconColor,
    required Color iconBackground,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
    String? badgeInitials,
    bool selected = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          // F13: la fila ya elegida se marca al volver a la lista, en vez de
          // que todas se vean igual de "sin elegir".
          side: selected
              ? const BorderSide(color: AppColors.primary, width: 1.5)
              : const BorderSide(color: AppColors.hairline),
        ),
        tileColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: iconBackground,
            borderRadius: BorderRadius.circular(12),
          ),
          child: badgeInitials != null
              ? Center(
                  child: Text(
                    badgeInitials,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.2,
                    ),
                  ),
                )
              : Icon(icon, color: iconColor, size: 20),
        ),
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            letterSpacing: -0.3,
          ),
        ),
        subtitle: subtitle == null
            ? null
            : Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
        trailing: selected
            ? const Icon(Icons.check_circle_rounded, color: AppColors.primary)
            : const Icon(Icons.chevron_right_rounded,
                color: AppColors.textDisabled),
        onTap: onTap,
      ),
    );
  }
}

String? _routeSubtitle(RouteInfo? route) {
  if (route == null) return null;
  final a = route.terminalA ?? '';
  final b = route.terminalB ?? '';
  if (a.isEmpty && b.isEmpty) return null;
  return '$a ↔ $b';
}

/// V2: paleta fija tomada de los tokens de marca — el color no se genera al
/// azar, solo se elige de forma determinística según el id de la empresa.
const _companyPalette = [
  AppColors.electricBlue,
  AppColors.coral,
  AppColors.warning,
  AppColors.primaryDeep,
  AppColors.primary,
  AppColors.primaryAccessible,
];

Color _companyColor(String companyId) {
  final hash = companyId.codeUnits.fold<int>(0, (sum, c) => sum + c);
  return _companyPalette[hash % _companyPalette.length];
}

const _companyInitialsStopWords = {'de', 'del', 'la', 'el', 'los', 'las', 'y'};

/// "Transporte del Norte" → "TN": la primera palabra y la siguiente que no
/// sea un conector, igual que el demo de la propuesta.
String _companyInitials(String name) {
  final words =
      name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  if (words.isEmpty) return '?';
  final significant = words
      .where((w) => !_companyInitialsStopWords.contains(w.toLowerCase()))
      .toList();
  if (significant.isEmpty) return words.first[0].toUpperCase();
  if (significant.length == 1) {
    final w = significant.first;
    return (w.length >= 2 ? w.substring(0, 2) : w).toUpperCase();
  }
  return (significant[0][0] + significant[1][0]).toUpperCase();
}

class _PremiumSelectorTile extends StatefulWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final bool isActive;
  final VoidCallback? onTap;

  /// Aviso pegado a este tile. Sustituye al subtítulo, tiñe el filo y
  /// sacude la tarjeta una vez: el error se dice donde ocurrió.
  final String? hint;

  const _PremiumSelectorTile({
    super.key,
    required this.title,
    this.subtitle,
    required this.icon,
    required this.isActive,
    this.hint,
    this.onTap,
  });

  @override
  State<_PremiumSelectorTile> createState() => _PremiumSelectorTileState();
}

class _PremiumSelectorTileState extends State<_PremiumSelectorTile>
    with SingleTickerProviderStateMixin {
  bool _pressed = false;
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: AppMotion.entrada,
  );

  @override
  void didUpdateWidget(covariant _PremiumSelectorTile old) {
    super.didUpdateWidget(old);
    if (widget.hint != null && old.hint != widget.hint) {
      _shake.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isActive = widget.isActive;
    final hint = widget.hint;
    final amplitud = AppMotion.reducido(context) ? 0.0 : 6.0;

    final Color borde;
    if (hint != null) {
      borde = AppColors.warning;
    } else if (isActive) {
      borde = AppColors.primary.withValues(alpha: 0.45);
    } else {
      borde = AppColors.hairline;
    }

    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedBuilder(
        animation: _shake,
        builder: (context, child) {
          final t = _shake.value;
          // Seno amortiguado: tres idas y vueltas que se apagan solas. Es
          // el gesto del campo de contraseña de iOS —dice "no" sin ocupar
          // sitio ni tapar nada.
          final dx = t == 0 || t == 1
              ? 0.0
              : math.sin(t * math.pi * 6) * (1 - t) * amplitud;
          return Transform.translate(offset: Offset(dx, 0), child: child);
        },
        child: AnimatedScale(
          scale: _pressed ? 0.975 : 1,
          duration: AppMotion.instante,
          curve: AppMotion.curvaEntrada,
          child: AnimatedContainer(
            duration: AppMotion.rapido,
            curve: AppMotion.curvaEntrada,
            height: _kTileHeight,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            // Sin sombra: la tarjeta ya flota sobre arena y una sombra
            // azulada al 4 % sobre un beige cálido no se lee como
            // profundidad, se lee como una banda gris. Separa el filo.
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: borde,
                width: isActive || hint != null ? 1.5 : 1.0,
              ),
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: AppMotion.rapido,
                  curve: AppMotion.curvaEntrada,
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isActive
                        ? AppColors.primaryTint
                        : AppColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    widget.icon,
                    color:
                        isActive ? AppColors.primary : AppColors.textDisabled,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                          color: isActive
                              ? AppColors.textPrimary
                              : AppColors.textDisabled,
                        ),
                      ),
                      if (hint != null || widget.subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          hint ?? widget.subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: hint != null
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: hint != null
                                ? AppColors.warning
                                : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: AppColors.textDisabled,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// El riel de la izquierda: nodo del paso y la línea que lo ata al otro.
class _StepRail extends StatelessWidget {
  const _StepRail({
    required this.done,
    required this.current,
    required this.lineUp,
    required this.lineDown,
  });

  final bool done;
  final bool current;
  final bool lineUp;
  final bool lineDown;

  static const double _ancho = 22;

  @override
  Widget build(BuildContext context) {
    // La línea se pinta verde solo hasta donde el usuario ya llegó: el
    // tramo de abajo se enciende cuando la empresa está elegida.
    final colorLinea = done ? AppColors.primary : AppColors.divider;
    return SizedBox(
      width: _ancho,
      child: Column(
        children: [
          Expanded(child: _tramo(lineUp, colorLinea)),
          AnimatedContainer(
            duration: AppMotion.rapido,
            curve: AppMotion.curvaEntrada,
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: done ? AppColors.primary : AppColors.arena,
              border: Border.all(
                color: done
                    ? AppColors.primary
                    : current
                        ? AppColors.primary
                        : AppColors.divider,
                width: 2,
              ),
            ),
            child: done
                ? const Icon(Icons.check_rounded, size: 13, color: Colors.white)
                : current
                    ? Center(
                        child: Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.primary,
                          ),
                        ),
                      )
                    : null,
          ),
          Expanded(child: _tramo(lineDown, colorLinea)),
        ],
      ),
    );
  }

  Widget _tramo(bool visible, Color color) {
    if (!visible) return const SizedBox.expand();
    return Center(
      child: SizedBox(
        width: 2,
        height: double.infinity,
        child: ColoredBox(color: color),
      ),
    );
  }
}
