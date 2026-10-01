import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ya_viene_core/ya_viene_core.dart';

import '../../../../core/widgets/aviso_fallo.dart';
import '../../../../core/widgets/entrance.dart';
import '../../../../core/widgets/sheet_handle.dart';
import '../../../../core/widgets/sheet_top_border.dart';
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
      // El paso de lo que recorre distancia de verdad: la tarjeta sube desde
      // fuera de la pantalla, no un dedo.
      transitionDuration: AppMotion.entrada,
      // La entrada la reparte la hoja por dentro: la tarjeta se desliza y el
      // velo solo se aclara. Un velo a pantalla completa que además sube
      // destapa una franja arriba mientras entra.
      transitionBuilder: (context, animation, _, child) => child,
      // Techo al texto del sistema. La tarjeta lleva el asa, la cabecera,
      // dos filas de 78 y el botón, y a partir del doble deja de caber en
      // 844: al triple se salía 158 px por abajo. El doble es lo que pide
      // la norma de accesibilidad (WCAG 1.4.4) y cabe entero; de ahí para
      // arriba la tarjeta se queda en su tamaño máximo en vez de recortar
      // la ruta que el usuario vino a elegir.
      pageBuilder: (context, _, __) => MediaQuery.withClampedTextScaling(
        maxScaleFactor: 2.0,
        child: sheet,
      ),
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

  /// La tarjeta principal se descarta arrastrándola hacia abajo.
  ///
  /// Antes se plegaba y dejaba el asa pegada al borde: bajarla no despejaba
  /// nada —quedaba una tarjeta muerta tapando la hoja de distancia, dos
  /// bordes redondeados uno encima del otro— y para volver al mapa había que
  /// bajarla y además tocar fuera. Bajar una hoja es pedir que se vaya, así
  /// que se va: la tarjeta sale por abajo y el diálogo se cierra con ella.
  ///
  /// Solo la principal: dentro de las listas de empresa y de ruta el gesto
  /// se apaga, porque ahí el usuario está en mitad de una elección y el asa
  /// es lo único que separa la lista del borde de la pantalla.
  ///
  /// 1 en su sitio, 0 fuera de la pantalla. Va pegado al dedo mientras
  /// arrastra y remata solo el camino que falte al soltar; el velo del fondo
  /// lee el mismo valor, así que el mapa se aclara al ritmo del pulgar.
  late final AnimationController _presencia;
  final GlobalKey _tarjetaKey = GlobalKey();

  /// La animación de la ruta con su curva: sube frenando y se va
  /// despegándose. Se guarda junto a la ruta de la que sale y se rehace
  /// solo si esta cambia, por lo mismo que en `FadeSlideTransition`: una
  /// `CurvedAnimation` creada en cada `build` se queda enganchada como
  /// oyente y nadie la suelta.
  Animation<double>? _rutaDeLaLlegada;
  CurvedAnimation? _llegada;

  Animation<double> _llegadaDe(Animation<double> ruta) {
    if (!identical(ruta, _rutaDeLaLlegada) || _llegada == null) {
      _llegada?.dispose();
      _rutaDeLaLlegada = ruta;
      _llegada = CurvedAnimation(
        parent: ruta,
        curve: AppMotion.curvaEntrada,
        reverseCurve: AppMotion.curvaSalida,
      );
    }
    return _llegada!;
  }

  double _altoTarjeta = 0;

  /// La salida ya empezó: el diálogo se cierra al terminar la animación y
  /// hasta entonces nada puede volver a subir la tarjeta.
  bool _saliendo = false;
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
    _presencia = AnimationController(
      vsync: this,
      duration: AppMotion.entrada,
      reverseDuration: AppMotion.pausado,
      value: 1,
    );
  }

  @override
  void dispose() {
    _routeHintTimer?.cancel();
    _llegada?.dispose();
    _presencia.dispose();
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
    // Si venía a medio arrastrar, entrar en una lista la devuelve a su sitio.
    _volver();
  }

  /// Termina de sacar la tarjeta y cierra el diálogo cuando ya salió.
  ///
  /// El orden importa: cerrando al soltar el dedo, la tarjeta daba un salto
  /// desde donde estaba hasta abajo mientras el velo se apagaba de golpe.
  /// Con impulso del dedo remata con la física del arrastre, como las hojas
  /// del sistema: soltar con brío llega antes que soltar quieto.
  void _cerrar({double impulso = 0}) {
    if (_saliendo) return;
    _saliendo = true;
    HapticFeedback.lightImpact();
    if (AppMotion.reducido(context)) {
      _presencia.value = 0;
      _alSalir();
      return;
    }
    final salida = impulso != 0
        ? _presencia.fling(velocity: impulso)
        : _presencia.animateBack(0, curve: AppMotion.curvaSalida);
    // `orCancel` falla si la tarjeta se va antes de terminar (por ejemplo,
    // eligiendo ruta a la vez): ahí ya no hay nada que cerrar.
    salida.orCancel.then((_) => _alSalir(), onError: (Object _) {});
  }

  void _alSalir() {
    if (mounted) Navigator.of(context).maybePop();
  }

  /// La devuelve a su sitio: se arrastró poco y el usuario no quería irse.
  void _volver() {
    if (_saliendo || _presencia.value == 1) return;
    if (AppMotion.reducido(context)) {
      _presencia.value = 1;
    } else {
      _presencia.animateTo(1, curve: AppMotion.curvaEntrada);
    }
  }

  void _arrastreEmpieza(DragStartDetails _) {
    final alto = _tarjetaKey.currentContext?.size?.height ?? 0;
    if (alto > 0) _altoTarjeta = alto;
    _presencia.stop();
  }

  void _arrastreSigue(DragUpdateDetails details) {
    if (_altoTarjeta <= 0 || _saliendo) return;
    final avance = (details.primaryDelta ?? 0) / _altoTarjeta;
    _presencia.value = (_presencia.value - avance).clamp(0.0, 1.0);
  }

  void _arrastreTermina(DragEndDetails details) {
    final porSegundo = details.primaryVelocity ?? 0;
    // Un empujón claro manda sobre dónde quedó la tarjeta.
    if (_altoTarjeta > 0 && porSegundo.abs() > 320) {
      if (porSegundo > 0) {
        _cerrar(impulso: -porSegundo / _altoTarjeta);
      } else {
        _volver();
      }
      return;
    }
    // Media tarjeta fuera ya es intención de irse.
    if (_presencia.value < 0.5) {
      _cerrar();
    } else {
      _volver();
    }
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
    // además, sube desde abajo.
    final entrada = _llegadaDe(
        ModalRoute.of(context)?.animation ?? kAlwaysCompleteAnimation);

    return Stack(
      key: _hostKey,
      fit: StackFit.expand,
      children: [
        // El velo se aclara a la vez que la tarjeta baja: bajarla es pedir
        // ver el mapa, y un velo fijo encima dejaba el gesto a medias.
        Positioned.fill(
          child: AnimatedBuilder(
            animation: Listenable.merge([_presencia, entrada]),
            builder: (context, _) => ColoredBox(
              key: const ValueKey('selector-velo'),
              color: AppColors.ink
                  .withValues(alpha: 0.40 * _presencia.value * entrada.value),
            ),
          ),
        ),
        if (!guided) ...[
          Positioned.fill(
            // Tocar fuera sale por el mismo camino que el arrastre: la
            // tarjeta se va por abajo en vez de desvanecerse en el sitio.
            child: Semantics(
              // El velo es la única salida de la vista principal: no hay
              // botón de cerrar, solo tocar fuera o arrastrar. Sin rótulo
              // es un nodo enorme y mudo, y con VoiceOver arrastrar no es
              // una opción.
              button: true,
              label: 'Cerrar',
              onTap: _cerrar,
              excludeSemantics: true,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _cerrar,
              ),
            ),
          ),
        ],
        _buildCard(context, descartable: !guided, llegada: entrada),
        if (showOverlay)
          Positioned.fill(
            child: MapGuideOverlay(
              target: _target!,
              // En las listas el hueco no crece hacia arriba: la cabecera
              // con la flecha de volver va pegada encima y quedaba medio
              // iluminada, y tocarla sacaba de la lista en mitad de la
              // guía. Por arriba no le hace falta aire: la lista ya lleva
              // sus 16 de relleno antes de la primera fila.
              targetInsets: _view == _RouteView.main
                  ? null
                  : const EdgeInsets.fromLTRB(10, 0, 10, 10),
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

  Widget _buildCard(
    BuildContext context, {
    required bool descartable,
    required Animation<double> llegada,
  }) {
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;
    // Descartar solo tiene sentido en la vista principal: en las listas el
    // gesto se apaga y el asa vuelve a ser un adorno.
    final puedeCerrar = descartable && _view == _RouteView.main;
    return Align(
      alignment: Alignment.bottomCenter,
      child: GestureDetector(
        // El dedo manda: la tarjeta baja pegada al pulgar y termina sola el
        // camino que falte al soltar, para dentro o para fuera.
        onVerticalDragStart: puedeCerrar ? _arrastreEmpieza : null,
        onVerticalDragUpdate: puedeCerrar ? _arrastreSigue : null,
        onVerticalDragEnd: puedeCerrar ? _arrastreTermina : null,
        // La salida se pinta como fracción del alto de la propia tarjeta:
        // así arranca exacta desde el primer fotograma, sin esperar a que
        // alguien la mida, y sigue siendo un desplazamiento —no un recorte—
        // que no reconstruye el contenido en cada paso.
        //
        // La entrada va por el mismo camino: la tarjeta sube entera desde
        // abajo, frenando, como una hoja del sistema. Antes solo recorría un
        // dedo mientras se fundía, y aparecía más que llegar. Con movimiento
        // reducido no sube: se funde en su sitio.
        child: AnimatedBuilder(
          animation: Listenable.merge([_presencia, llegada]),
          builder: (context, child) {
            final reducido = AppMotion.reducido(context);
            return Opacity(
              opacity: reducido ? llegada.value : 1,
              child: FractionalTranslation(
                translation: Offset(
                    0, 1 - _presencia.value * (reducido ? 1 : llegada.value)),
                child: child,
              ),
            );
          },
          child: Material(
            key: _tarjetaKey,
            // Misma superficie que la hoja de distancia (AppColors.arena):
            // las dos tarjetas se ven una detrás de otra en el mismo flujo y
            // el salto de blanco a arena las hacía parecer de apps distintas.
            color: AppColors.arena,
            // Sobre el velo oscuro del diálogo una sombra ancha no se ve;
            // lo que define la tarjeta es el filo. Mismo tratamiento que la
            // hoja de distancia, que se ve justo después: solo arriba, que
            // es donde la tarjeta se encuentra con el mapa.
            elevation: 8,
            shadowColor: const Color(0x3314274E),
            shape: const SheetTopBorder(
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
                  Semantics(
                    // En las listas el asa no hace nada: anunciarla como
                    // botón sería ofrecer una acción que no existe.
                    button: puedeCerrar,
                    label: puedeCerrar ? 'Cerrar' : null,
                    onTap: puedeCerrar ? _cerrar : null,
                    excludeSemantics: true,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: puedeCerrar ? _cerrar : null,
                      child: const Padding(
                        padding: EdgeInsets.only(top: 16, bottom: 16),
                        // `abierta` se queda en 1: esta hoja no se pliega,
                        // se va entera, así que el asa no tiene nada que
                        // anunciar y no cambia de ancho ni de color.
                        child: SheetHandle(
                          key: ValueKey('selector-handle'),
                        ),
                      ),
                    ),
                  ),
                  // Las vistas se cruzan de lado sin cambiar el alto de la
                  // tarjeta: lo único que se mueve en vertical es la hoja
                  // entera, y de eso se encarga el desplazamiento de fuera.
                  AnimatedSwitcher(
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
                      final entra = (child.key as ValueKey?)?.value == _view;
                      final lado = _haciaDentro ? 1.0 : -1.0;
                      final desde = (entra ? lado : -lado) *
                          (AppMotion.reducido(context) ? 0.0 : 0.18);
                      final slide = Tween<Offset>(
                        begin: Offset(desde, 0),
                        end: Offset.zero,
                      ).animate(animation);
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(position: slide, child: child),
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
                ],
              ),
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
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _headerRow(title: 'Elige tu ruta'),
          const SizedBox(height: 6),
          // «en el mapa» sobraba: la hoja está encima del mapa y se ve
          // detrás. Sobrando, partía la frase en dos líneas y dejaba
          // «mapa.» solo en la segunda.
          Text(
            'Dos pasos y ves los buses moviéndose.',
            style:
                AppTextStyles.cuerpo.copyWith(color: AppColors.textSecondary),
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
              data: (companies) => _SelectorTile(
                key: widget.companyGuideKey,
                title: selectedCompany?.name ?? 'Empresa',
                subtitle: selectedCompany != null
                    ? 'Empresa de transporte masivo'
                    : 'Con cuál viajas',
                // El título es el nombre elegido y por sí solo no dice de
                // qué paso salió: «Sobusa» a secas podría ser la ruta.
                dicho: selectedCompany == null
                    ? 'Empresa. Con cuál viajas'
                    : 'Empresa: ${selectedCompany.name}',
                icon: Icons.business_outlined,
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
                child: const IndicadorCarga(
                  // Los puntos no se ven con VoiceOver: sin rótulo el hueco
                  // de la empresa se anuncia vacío.
                  semanticsLabel: 'Cargando empresas',
                ),
              ),
              error: (error, _) => _tilePlaceholder(
                key: widget.companyGuideKey,
                child: AvisoFallo(
                  compacto: true,
                  error: error,
                  que: 'las empresas',
                  onReintentar: () => ref.refresh(companiesProvider.future),
                ),
              ),
            ),
          ),
          _step(
            done: selectedRoute != null,
            current: selectedCompany != null && selectedRoute == null,
            lineUp: true,
            lineDown: false,
            child: _SelectorTile(
              key: widget.routeGuideKey,
              title: selectedRoute?.name ?? 'Ruta',
              subtitle: _routeSubtitle(selectedRoute) ??
                  (selectedRoute != null ? null : 'Cuál esperas'),
              icon: Icons.alt_route_outlined,
              isActive: selectedRoute != null,
              dicho: selectedRoute == null
                  ? 'Ruta. Cuál esperas'
                  : 'Ruta: ${selectedRoute.name}'
                      '${_terminalesDichos(selectedRoute)}',
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
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _headerRow(title: title, onBack: onBack),
            // Sin hueco fijo aquí: lo pone el relleno de la lista, que es
            // la franja que se desvanece (ver `_listaConDesvanecido`).
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
  /// La lista arranca pegada al título, no en el centro de la caja. Con dos
  /// empresas centradas quedaba un hueco arriba y otro abajo y la lista se
  /// leía como flotando; arriba, empieza donde el ojo ya está.
  ///
  /// Las dos listas llevan [_fundidoLista] de relleno arriba y abajo, justo
  /// el alto del fundido. Sin él, la primera fila en reposo quedaba dentro
  /// de la franja que se desvanece y salía con el borde de arriba lavado,
  /// como borrosa. Con el relleno, en reposo ninguna fila toca el fundido;
  /// solo las que se desplazan hacia el borde.
  static const double _fundidoLista = 16;

  Widget _listaConDesvanecido(Widget lista) {
    final conTinta = Material(
      type: MaterialType.transparency,
      child: Align(alignment: Alignment.topCenter, child: lista),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final alto = constraints.maxHeight;
        if (!alto.isFinite || alto <= 48) return ClipRect(child: conTinta);
        final fundido = (_fundidoLista / alto).clamp(0.0, 0.2);
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

  /// Cuándo arranca la fila [i] dentro del grupo de entrada de la lista.
  ///
  /// Las filas llegan una detrás de otra —la lista se asienta, no aparece
  /// de golpe dentro del empuje lateral—, a 0,08 del grupo cada una (45 ms,
  /// casi el `AppMotion.escalon`). El escalón se topa en la sexta: de ahí
  /// para abajo la fila está fuera de la tarjeta o casi, y hacerla esperar
  /// más solo retrasaría la lista.
  static double _escalonFila(int i) => math.min(i, 5) * 0.08;

  Widget _buildCompanyList(BuildContext context) {
    final companiesAsync = ref.watch(companiesProvider);
    final selectedCompany = ref.watch(selectedCompanyProvider);
    return companiesAsync.when(
      data: (companies) => ScreenEntrance(
        builder: (context, entra) => ListView(
          key: widget.companyChoiceGuideKey,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(vertical: _fundidoLista),
          // Se mide por su contenido para poder quedarse en el centro cuando
          // sobra caja; si no cabe, ocupa el alto entero y se desplaza igual.
          shrinkWrap: true,
          children: [
            if (companies.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg, vertical: AppSpacing.xl),
                child: Text(
                  'Sin empresas disponibles',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.cuerpoFuerte
                      .copyWith(color: AppColors.textSecondary),
                ),
              )
            else
              ...companies.indexed.map((fila) {
                final (i, company) = fila;
                return entra(
                    start: _escalonFila(i),
                    _compactTile(
                      icon: Icons.business_outlined,
                      iconColor: Colors.white,
                      iconBackground: _companyColor(company.id),
                      // V2: insignia de iniciales con color determinístico — se
                      // reconoce la fila antes de leer el nombre, como en Bolt.
                      badgeInitials: _companyInitials(company.name),
                      title: company.name,
                      subtitle: null,
                      // La insignia son las iniciales del nombre que va justo
                      // al lado: dichas, es el mismo dato deletreado antes de
                      // decirlo entero.
                      dicho: company.name,
                      selected: selectedCompany?.id == company.id,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        final alreadySelected =
                            ref.read(selectedCompanyProvider)?.id == company.id;
                        ref
                            .read(selectedCompanyProvider.notifier)
                            .select(company);
                        if (!alreadySelected) {
                          ref.read(selectedRouteProvider.notifier).clear();
                        }
                        ref
                            .read(mapGuideProvider.notifier)
                            .complete(MapGuideStep.company);
                        _irA(_RouteView.main);
                      },
                    ));
              }),
          ],
        ),
      ),
      loading: () => _listPlaceholder(
        key: widget.companyChoiceGuideKey,
      ),
      error: (error, _) => _listPlaceholder(
        key: widget.companyChoiceGuideKey,
        fallo: AvisoFallo(
          error: error,
          que: 'las empresas',
          onReintentar: () => ref.refresh(companiesProvider.future),
        ),
      ),
    );
  }

  Widget _buildRouteList(BuildContext context) {
    final selectedCompany = ref.watch(selectedCompanyProvider);
    if (selectedCompany == null) return const SizedBox.shrink();
    final selectedRoute = ref.watch(selectedRouteProvider);
    final routesAsync = ref.watch(routesByCompanyProvider(selectedCompany.id));
    return routesAsync.when(
      data: (routes) => ScreenEntrance(
        builder: (context, entra) => ListView(
          key: widget.routeChoiceGuideKey,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(vertical: _fundidoLista),
          shrinkWrap: true,
          children: [
            if (routes.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg, vertical: AppSpacing.xl),
                child: Text(
                  'Esta empresa no tiene rutas aún',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.cuerpoFuerte
                      .copyWith(color: AppColors.textSecondary),
                ),
              )
            else
              ...routes.indexed.map((fila) {
                final (i, route) = fila;
                // El código va en la insignia y el nombre se queda con lo
                // suyo. Seis rutas con el mismo icono verde son seis filas
                // que solo se distinguen leyendo; «B18», «C11», «C16» es
                // exactamente lo que el pasajero busca en el parabrisas.
                final codigo = _routeCode(route.name);
                return entra(
                    start: _escalonFila(i),
                    _compactTile(
                      icon: Icons.alt_route_outlined,
                      iconColor: AppColors.primary,
                      iconBackground: AppColors.primaryTint,
                      badgeInitials: codigo?.code,
                      // Verde oscuro sobre el verde claro de la insignia: la
                      // empresa lleva tinta sólida y letra blanca, la ruta va
                      // en voz más baja. Son dos niveles, no dos etiquetas.
                      badgeColor: AppColors.primaryAccessible,
                      title: codigo?.rest ?? route.name,
                      subtitle: _routeSubtitle(route) ?? 'Tiempo real',
                      dicho: '${route.name}${_terminalesDichos(route)}',
                      selected: selectedRoute?.id == route.id,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        ref.read(selectedRouteProvider.notifier).select(route);
                        ref
                            .read(mapGuideProvider.notifier)
                            .complete(MapGuideStep.route);
                        _irA(_RouteView.main);
                      },
                    ));
              }),
          ],
        ),
      ),
      loading: () => _listPlaceholder(
        key: widget.routeChoiceGuideKey,
      ),
      error: (error, _) => _listPlaceholder(
        key: widget.routeChoiceGuideKey,
        fallo: AvisoFallo(
          error: error,
          que: 'las rutas',
          onReintentar: () => ref.refresh(
            routesByCompanyProvider(selectedCompany.id).future,
          ),
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
        backgroundColor: listo ? AppColors.primaryAccessible : AppColors.acento,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 58),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.pill)),
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
              style: AppTextStyles.boton.copyWith(color: Colors.white),
            ),
          ),
          // Botón-en-botón: la flecha en su círculo propio, como los
          // primarios de la landing. Los tres rótulos avanzan (elegir /
          // ver), así que la flecha vale en los tres.
          const SizedBox(width: 10),
          Container(
            width: 30,
            height: 30,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0x2EFFFFFF),
            ),
            child: const Icon(
              Icons.arrow_forward_outlined,
              color: Colors.white,
              size: 17,
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

  /// Placeholder del tile de empresa con la MISMA altura que
  /// `_SelectorTile`: mientras cargan las empresas (o fallan) el hueco
  /// de la guía sigue anclado a su posición real.
  Widget _tilePlaceholder({Key? key, required Widget child}) {
    return Container(
      key: key,
      height: _kTileHeight,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.hairline),
      ),
      child: child,
    );
  }

  /// Estado de carga/error de las listas secundarias. Mantiene la key del
  /// objetivo de la guía para que el overlay nunca desaparezca mientras el
  /// usuario espera (y no pueda salirse tocando el back u otro botón).
  Widget _listPlaceholder({Key? key, Widget? fallo}) {
    return Center(
      key: key,
      child:
          fallo ?? const IndicadorCarga(size: 34, semanticsLabel: 'Cargando'),
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
            // Un icono sin rótulo se anuncia «botón» y nada más. El
            // `tooltip` no basta: viaja en su propio campo, aparte del
            // rótulo, y no todos los lectores lo dicen.
            icon: const Icon(
              Icons.arrow_back_outlined,
              color: AppColors.primaryDeep,
              semanticLabel: 'Volver',
            ),
            tooltip: 'Volver',
            onPressed: onBack,
            visualDensity: VisualDensity.compact,
          ),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.display,
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
    Color badgeColor = Colors.white,
    String? dicho,
    bool selected = false,
  }) {
    final base = dicho ?? title;
    // La fila de empresa o de ruta mide lo mismo que las tarjetas de
    // «Elige tu ruta» (`_SelectorTile`): 78 de alto, insignia de 44 y 12
    // entre una y otra, que es el aire que dejan los dos pasos (6 + 6). Con
    // una sola empresa la hoja se quedaba en su alto y la fila, de 56,
    // flotaba arriba como una etiqueta: ahora es la misma tarjeta que se
    // acaba de tocar.
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm + AppSpacing.xs),
      child: Semantics(
        button: true,
        // La palomita de la derecha es lo único que distingue la fila ya
        // elegida, y una palomita no se oye. `selected` la dice.
        selected: selected,
        label: subtitle == null || dicho != null ? base : '$base. $subtitle',
        // `excludeSemantics` tapa el árbol de abajo, y con él la acción
        // del ListTile: sin este toque la fila no se podría elegir.
        onTap: onTap,
        excludeSemantics: true,
        // Mismo armado que `_SelectorTile` y no un ListTile: el ListTile
        // pone su propia geometría (su relleno y sus altos de una y dos
        // líneas) y la fila salía de 80 con la tarjeta del paso en 78.
        child: Material(
          color: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            // F13: la fila ya elegida se marca al volver a la lista, en vez de
            // que todas se vean igual de "sin elegir".
            side: selected
                ? const BorderSide(color: AppColors.primary, width: 1.5)
                : const BorderSide(color: AppColors.hairline),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: ConstrainedBox(
              // Alto mínimo, como la tarjeta: con el texto del sistema en
              // grande la fila crece en vez de recortar el nombre. El filo
              // del `shape` no ocupa layout, así que el alto sale exacto.
              constraints: const BoxConstraints(minHeight: _kTileHeight),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: iconBackground,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: badgeInitials != null
                          ? Center(
                              // Un código de ruta puede ser «B18» o «C16»:
                              // cabe de sobra, pero el día que llegue uno de
                              // cuatro no se saldrá de la caja, se encogerá.
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 4),
                                child: FittedBox(
                                  child: Text(
                                    badgeInitials,
                                    style: AppTextStyles.etiqueta
                                        .copyWith(color: badgeColor),
                                  ),
                                ),
                              ),
                            )
                          : Icon(icon, color: iconColor, size: 22),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.subtitulo,
                          ),
                          if (subtitle != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.pie,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    selected
                        ? const Icon(Icons.check_circle_rounded,
                            color: AppColors.primary)
                        : const Icon(Icons.chevron_right_outlined,
                            size: 20, color: AppColors.textSecondary),
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

/// Los dos terminales, dichos como una frase y no como una flecha.
///
/// En pantalla «Centro ↔ Norte» se lee de un vistazo; en voz alta la
/// flecha se pronuncia y parte la frase en dos nombres sueltos.
String _terminalesDichos(RouteInfo route) {
  final a = route.terminalA ?? '';
  final b = route.terminalB ?? '';
  if (a.isEmpty && b.isEmpty) return '';
  if (b.isEmpty) return ', desde $a';
  if (a.isEmpty) return ', hasta $b';
  return ', entre $a y $b';
}

String? _routeSubtitle(RouteInfo? route) {
  if (route == null) return null;
  final a = route.terminalA ?? '';
  final b = route.terminalB ?? '';
  if (a.isEmpty && b.isEmpty) return null;
  return '$a ↔ $b';
}

/// Los seis colores con los que puede salir una empresa.
///
/// Antes se tomaban prestados de los tokens semánticos, y ahí estaba el
/// problema: el naranja es el de «cuidado» y el coral el de «sin conexión».
/// Una empresa de buses aparecía vestida de aviso, con el mismo color que
/// usa la app para decir que algo va mal. Este es un escalón de azul noche
/// a verde: seis peldaños que se distinguen entre sí sin que ninguno
/// signifique nada más en el resto de la app, y todos lo bastante oscuros
/// para llevar letra blanca encima.
const _companyPalette = [
  Color(0xFF14274E), // noche
  Color(0xFF22406F), // marino
  Color(0xFF1C5670), // petróleo
  Color(0xFF0F6A65), // verde azulado
  Color(0xFF1C6B4C), // bosque
  Color(0xFF3B6B2E), // oliva
];

Color _companyColor(String companyId) {
  final hash = companyId.codeUnits.fold<int>(0, (sum, c) => sum + c);
  return _companyPalette[hash % _companyPalette.length];
}

/// El código de una ruta y lo que queda del nombre sin él.
typedef RouteCode = ({String code, String rest});

/// «B18 Tcherassi» → («B18», «Tcherassi»).
///
/// Las rutas de Barranquilla se llaman por su código —el que va pintado en
/// el parabrisas y el que la gente dice en la esquina—, y el nombre que
/// sigue es el destino. Separarlos deja el código donde se busca de un
/// vistazo y el destino donde se lee.
///
/// Devuelve `null` si la primera palabra no es un código, o si no queda
/// nombre detrás: una ruta llamada solo «B18» pierde el título si se le
/// arranca el código, y una llamada «Ruta Norte» no tiene ninguno.
final _codigoDeRuta = RegExp(r'^[A-Z]{0,2}\d{1,3}[A-Z]?$');

RouteCode? _routeCode(String name) {
  final words = name.trim().split(RegExp(r'\s+'));
  if (words.length < 2) return null;
  if (!_codigoDeRuta.hasMatch(words.first)) return null;
  final rest = words.skip(1).join(' ');
  if (rest.isEmpty) return null;
  return (code: words.first, rest: rest);
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

class _SelectorTile extends StatefulWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final bool isActive;
  final VoidCallback? onTap;

  /// Aviso pegado a este tile. Sustituye al subtítulo, tiñe el filo y
  /// sacude la tarjeta una vez: el error se dice donde ocurrió.
  final String? hint;

  /// La fila entera, dicha en una frase, cuando lo escrito no se lee bien
  /// en voz alta.
  ///
  /// El subtítulo de la ruta son dos terminales unidos por una flecha
  /// («Centro ↔ Norte»): en pantalla se entiende de un vistazo, leído en
  /// voz alta es un nombre, «flecha izquierda derecha» y otro nombre.
  final String? dicho;

  const _SelectorTile({
    super.key,
    required this.title,
    this.subtitle,
    required this.icon,
    required this.isActive,
    this.hint,
    this.dicho,
    this.onTap,
  });

  @override
  State<_SelectorTile> createState() => _SelectorTileState();
}

class _SelectorTileState extends State<_SelectorTile>
    with SingleTickerProviderStateMixin {
  bool _pressed = false;
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: AppMotion.entrada,
  );

  @override
  void didUpdateWidget(covariant _SelectorTile old) {
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

    // El aviso manda sobre todo lo demás: es la razón por la que la fila
    // se sacudió, y en voz es lo único que explica por qué el toque no
    // llevó a ninguna parte.
    final base = widget.dicho ?? widget.title;
    final dicha = hint != null
        ? '$base. $hint'
        : widget.subtitle != null && widget.dicho == null
            ? '$base. ${widget.subtitle}'
            : base;

    return Semantics(
      button: true,
      label: dicha,
      // El aviso aparece sin que nadie lo pida —la sacudida es su aviso
      // visual— y sin región viva no se anuncia hasta que alguien vuelve
      // a pasar el dedo por encima.
      liveRegion: hint != null,
      // `excludeSemantics` tapa el árbol de abajo, y con él la acción del
      // gesto: sin este toque el doble toque de VoiceOver no haría nada.
      onTap: widget.onTap,
      excludeSemantics: true,
      child: GestureDetector(
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
              // Alto mínimo, no alto fijo: dentro van el nombre y su línea
              // de apoyo, y con el texto del sistema en grande las dos
              // juntas miden más de 78. Al 100% miden menos, así que la
              // fila no se mueve de donde estaba.
              constraints: const BoxConstraints(minHeight: _kTileHeight),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              // Sin sombra: la tarjeta ya flota sobre arena y una sombra
              // azulada al 4 % sobre un beige cálido no se lee como
              // profundidad, se lee como una banda gris. Separa el filo.
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.lg),
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
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Icon(
                      widget.icon,
                      color: isActive
                          ? AppColors.primary
                          : AppColors.textSecondary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.subtitulo.copyWith(
                            color: isActive
                                ? AppColors.textPrimary
                                : AppColors.textSecondary,
                          ),
                        ),
                        if (hint != null || widget.subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            hint ?? widget.subtitle!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            // El aviso ya se distingue por el ámbar; no
                            // necesita además otro peso.
                            style: hint != null
                                ? AppTextStyles.pie.copyWith(
                                    color: AppColors.warningAccessible,
                                  )
                                : AppTextStyles.pie,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_outlined,
                    size: 20,
                    color: AppColors.textSecondary,
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
                ? const Icon(Icons.check_outlined,
                    size: 13, color: Colors.white)
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
