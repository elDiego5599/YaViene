import 'package:flutter/material.dart';
import 'package:ya_viene_core/ya_viene_core.dart';

/// Spotlight reutilizable de la guía completa. Solo [target] queda libre para
/// recibir el gesto real del widget que está debajo; las cuatro barreras
/// transparentes bloquean el resto sin cerrar la guía por accidente.
class MapGuideOverlay extends StatefulWidget {
  const MapGuideOverlay({
    super.key,
    required this.target,
    required this.title,
    required this.message,
    required this.icon,
    required this.stepIndex,
    required this.stepCount,
    required this.onSkip,
    this.primaryLabel,
    this.onPrimary,
    this.onBack,
    this.targetPadding = 10,
    this.targetInsets,
    this.cartaAbajo = false,
    this.cartaSobre,
    this.radioHueco = AppRadius.card,
    this.centered = false,
  });

  final Rect target;
  final String title;
  final String message;
  final IconData icon;
  final int stepIndex;
  final int stepCount;
  final VoidCallback onSkip;
  final String? primaryLabel;
  final VoidCallback? onPrimary;

  /// F14: null en el primer paso (nada a lo que volver); en el resto,
  /// retrocede un paso de la guía.
  final VoidCallback? onBack;
  final double targetPadding;

  /// Cuánto crece el hueco por cada lado, cuando no es lo mismo en los
  /// cuatro; si está, manda sobre [targetPadding]. Las listas de empresa y
  /// de ruta tienen la cabecera pegada encima: crecer 10 px hacia arriba
  /// metía el hueco en ella y dejaba tocable la flecha de volver.
  final EdgeInsets? targetInsets;

  /// La carta va debajo del hueco aunque no quepa entera: entonces se apoya
  /// abajo del todo y pisa un poco el borde del hueco. Es el paso de los
  /// buses, cuyo hueco baja hasta la hoja para abarcar el botón de
  /// recentrar; arriba la carta tapaba el mapa que se está enseñando y se
  /// metía bajo la isla del teléfono.
  final bool cartaAbajo;

  /// Dónde empieza lo que la carta no debe tapar aunque quede fuera del
  /// hueco: la cara de arriba de la hoja. Con la carta arriba, su borde de
  /// abajo queda 12 por encima; si no cabe, baja lo que haga falta y el
  /// hueco se recorta por arriba. En la distancia y el aviso la carta tapaba
  /// la placa y el título de la hoja que explica.
  final double? cartaSobre;

  /// El canto del hueco. Una píldora se ilumina como píldora: con el canto
  /// de 24 de una tarjeta, la barra de búsqueda y el botón del aviso
  /// quedaban dentro de un rectángulo que no era su forma.
  final double radioHueco;

  /// Modo de cierre: sin área iluminada ni barreras; la carta queda centrada
  /// y la única acción es el botón primario ("Finalizar guía").
  final bool centered;

  @override
  State<MapGuideOverlay> createState() => _MapGuideOverlayState();
}

class _MapGuideOverlayState extends State<MapGuideOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _controller;

  /// Declaradas como `CurvedAnimation` y no como `Animation<double>`: el tipo
  /// general no tiene `dispose()`, y estas hay que desecharlas o se quedan
  /// enganchadas como oyentes de su controlador.
  late final CurvedAnimation _scale;
  late final CurvedAnimation _fade;
  late final Animation<double> _escala;

  /// F14: pulso breve en el borde del hueco cuando un tap cae fuera — antes
  /// la barrera lo absorbía en silencio, sin ninguna señal de "ahí no es".
  late final AnimationController _missTapController;
  late final CurvedAnimation _missTapCurva;
  late final Animation<double> _missTapPulse;

  /// Altura real de la carta, medida tras el primer layout: sirve para
  /// decidir si la carta cabe debajo del área iluminada sin solaparla.
  double? _cardHeight;
  final GlobalKey _cardKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppMotion.entrada,
    );
    _scale =
        CurvedAnimation(parent: _controller, curve: AppMotion.curvaEntrada);
    // La tarjeta crece poco —del 92 % a su tamaño— y frena sin pasarse,
    // mientras se funde. Antes nacía de cero con `easeOutBack`, que se pasa
    // de tamaño y vuelve: un rebote de juguete que desentonaba con el resto
    // de la app. Con movimiento reducido no crece nada; se resuelve en
    // `build` y no aquí porque el ajuste puede cambiar con la guía abierta.
    _escala = Tween<double>(begin: 0.92, end: 1).animate(_scale);
    _fade = CurvedAnimation(parent: _controller, curve: AppMotion.curvaEntrada);
    _controller.forward();

    _missTapController = AnimationController(
      vsync: this,
      duration: AppMotion.entrada,
    );
    _missTapPulse = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 35),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 65),
    ]).animate(_missTapCurva = CurvedAnimation(
      parent: _missTapController,
      curve: Curves.easeOut,
    ));
  }

  void _onMissTap() => _missTapController.forward(from: 0);

  @override
  void didUpdateWidget(MapGuideOverlay old) {
    super.didUpdateWidget(old);
    // Cada paso trae su texto y sus botones: la carta cambia de alto y la
    // medida del paso anterior la ponía donde ya no cabía.
    if (old.title != widget.title ||
        old.message != widget.message ||
        old.primaryLabel != widget.primaryLabel ||
        (old.onBack == null) != (widget.onBack == null)) {
      _cardHeight = null;
    }
  }

  /// La escala de entrada, o ninguna si el sistema pide menos movimiento.
  Animation<double> _escalaEntrada(BuildContext context) =>
      AppMotion.reducido(context)
          ? const AlwaysStoppedAnimation<double>(1)
          : _escala;

  @override
  void dispose() {
    _scale.dispose();
    _fade.dispose();
    _missTapCurva.dispose();
    _controller.dispose();
    _missTapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final bounds = Offset.zero & size;
        final rawHole = widget.targetInsets?.inflateRect(widget.target) ??
            widget.target.inflate(widget.targetPadding);
        var hole = rawHole.intersect(bounds);
        final bottomInset = MediaQuery.of(context).viewPadding.bottom;
        final topInset = MediaQuery.of(context).viewPadding.top;
        final card = _buildCard();
        _measureCard();

        if (widget.centered) {
          return Stack(
            fit: StackFit.expand,
            children: [
              IgnorePointer(
                child: FadeTransition(
                  opacity: _fade,
                  child: const CustomPaint(
                    key: ValueKey('guide_scrim'),
                    painter: _ScrimPainter(),
                  ),
                ),
              ),
              Positioned.fill(child: _GuideBarrier(onInvalidTap: () {})),
              Center(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 380),
                    // Se funde a la vez que crece: sin fundido, empezar en
                    // el 92 % era aparecer de golpe un poco más pequeña.
                    child: FadeTransition(
                      opacity: _fade,
                      child: ScaleTransition(
                        scale: _escalaEntrada(context),
                        child: KeyedSubtree(key: _cardKey, child: card),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        }

        // La carta se pone debajo del área iluminada solo si cabe completa
        // (sin solapar el hueco ni quedar bajo la barra de navegación); si no
        // hay espacio, va arriba. Antes de la primera medición se usa una
        // estimación segura y el primer layout la ajusta.
        final cardHeight = _cardHeight ?? 220.0;
        final fitsBelow =
            hole.bottom + 22 + cardHeight <= size.height - bottomInset;
        final placeAbove = !widget.cartaAbajo && (hole.top > 245 || !fitsBelow);
        final cardTop = placeAbove
            ? size.height -
                _aboveBottom(hole, size, bottomInset, topInset, cardHeight) -
                cardHeight
            : _belowTop(hole, size, bottomInset, cardHeight);
        // Donde la carta no cabe sin pisar el hueco, el hueco cede: lo que
        // queda bajo la carta no se ve ni se puede tocar, y un hueco que
        // sigue por debajo de ella ilumina lo que nadie ve.
        hole = _recortar(hole, cardTop, cardTop + cardHeight);
        final radio = mathMin(widget.radioHueco, hole.shortestSide / 2);

        return Stack(
          fit: StackFit.expand,
          children: [
            IgnorePointer(
              child: FadeTransition(
                opacity: _fade,
                child: CustomPaint(
                  key: const ValueKey('guide_scrim'),
                  painter: PintorHueco(hole: hole, radio: radio),
                ),
              ),
            ),
            // F14: el borde del hueco pulsa en coral cuando un tap cae fuera
            // — antes no había ninguna señal de que ese toque no contaba.
            Positioned.fromRect(
              rect: hole.inflate(4),
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _missTapPulse,
                  builder: (context, _) {
                    if (_missTapPulse.value == 0) {
                      return const SizedBox.shrink();
                    }
                    return Opacity(
                      opacity: _missTapPulse.value,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(radio + 4),
                          border: const Border.fromBorderSide(
                            BorderSide(color: AppColors.coral, width: 3),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            ..._buildBarriers(size, hole, onInvalidTap: _onMissTap),
            Positioned(
              left: 20,
              right: 20,
              top: cardTop,
              child: ScaleTransition(
                scale: _escalaEntrada(context),
                child: KeyedSubtree(key: _cardKey, child: card),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Mide la carta una sola vez (tras el primer layout) para el cálculo de
  /// `fitsBelow`. Antes de medir se usa una estimación segura.
  void _measureCard([int attempt = 0]) {
    if (_cardHeight != null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _cardHeight != null) return;
      final box = _cardKey.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.attached || box.size.height <= 0) {
        if (attempt < 10) _measureCard(attempt + 1);
        return;
      }
      setState(() => _cardHeight = box.size.height);
    });
  }

  /// [hole] sin la franja que tapa la carta (de [arriba] a [abajo]), con 12
  /// de aire. Si la carta queda en medio del hueco se queda la parte más
  /// grande; si recortar lo dejara sin sitio para un dedo, no se recorta.
  ///
  /// El aire sale del margen del hueco, nunca del objetivo: si la carta
  /// deja menos de 12 hasta él, el hueco se corta justo en su borde. Con
  /// los 12 enteros, en un SE con la letra grande la primera empresa salía
  /// con tres puntos de su canto a oscuras.
  Rect _recortar(Rect hole, double arriba, double abajo) {
    if (abajo <= hole.top || arriba >= hole.bottom) return hole;
    final objetivo = widget.target;
    final desde =
        abajo <= objetivo.top ? mathMin(abajo + 12, objetivo.top) : abajo + 12;
    final hasta = arriba >= objetivo.bottom
        ? mathMax(arriba - 12, objetivo.bottom)
        : arriba - 12;
    final debajo = Rect.fromLTRB(
        hole.left, mathMax(hole.top, desde), hole.right, hole.bottom);
    final encima = Rect.fromLTRB(
        hole.left, hole.top, hole.right, mathMin(hole.bottom, hasta));
    final mejor = debajo.height >= encima.height ? debajo : encima;
    return mejor.height >= 48 ? mejor : hole;
  }

  double _belowTop(
      Rect hole, Size size, double bottomInset, double cardHeight) {
    final proposed = hole.bottom + 22;
    // El límite superior solo evita que la carta quede bajo la barra de
    // navegación; `fitsBelow` ya garantiza que no suba hasta el hueco. Con
    // [cartaAbajo] no hay esa garantía y el límite es la carta medida: sube
    // lo justo para quedar entera sobre la barra, aunque pise el hueco.
    // Con [cartaAbajo] se apoya más abajo que el resto de pasos: el margen
    // de 12 sobre toda la zona segura la dejaba flotando a media altura y
    // le quitaba mapa al trozo iluminado. Esa zona reserva unos 34 px para
    // la barra de inicio, que se dibuja en los últimos ~13: descontando 16
    // la carta sigue sin tocarla, y en teléfonos sin zona segura queda el
    // margen de 12 de siempre.
    final maxTop = widget.cartaAbajo
        ? mathMax(
            12.0, size.height - cardHeight - mathMax(12.0, bottomInset - 16))
        : mathMax(12.0, size.height - bottomInset - 180);
    return proposed.clamp(12.0, maxTop);
  }

  double _aboveBottom(Rect hole, Size size, double bottomInset, double topInset,
      double cardHeight) {
    var proposed = size.height - hole.top + 22;
    final sobre = widget.cartaSobre;
    if (sobre != null) proposed = mathMax(proposed, size.height - sobre + 12);
    final minBottom = bottomInset + 12;
    // La carta queda sobre el objetivo con 22 px de aire y nunca sube tanto
    // que su borde superior se meta bajo la barra de estado: allí la isla
    // del teléfono le tapaba el título. Si no cabe, pisa el borde del hueco,
    // que se sigue viendo, en vez de esconder lo que hay que leer.
    final maxBottom = mathMax(
        minBottom, size.height - cardHeight - mathMax(12, topInset + 8));
    return proposed.clamp(minBottom, maxBottom);
  }

  List<Widget> _buildBarriers(Size size, Rect hole,
      {required VoidCallback onInvalidTap}) {
    final barriers = <Widget>[];
    if (hole.top > 0) {
      barriers.add(Positioned(
        top: 0,
        left: 0,
        right: 0,
        height: hole.top,
        child: _GuideBarrier(onInvalidTap: onInvalidTap),
      ));
    }
    if (hole.bottom < size.height) {
      barriers.add(Positioned(
        top: hole.bottom,
        left: 0,
        right: 0,
        bottom: 0,
        child: _GuideBarrier(onInvalidTap: onInvalidTap),
      ));
    }
    if (hole.left > 0 && hole.height > 0) {
      barriers.add(Positioned(
        top: hole.top,
        left: 0,
        width: hole.left,
        height: hole.height,
        child: _GuideBarrier(onInvalidTap: onInvalidTap),
      ));
    }
    if (hole.right < size.width && hole.height > 0) {
      barriers.add(Positioned(
        top: hole.top,
        left: hole.right,
        right: 0,
        height: hole.height,
        child: _GuideBarrier(onInvalidTap: onInvalidTap),
      ));
    }
    return barriers;
  }

  Widget _buildCard() {
    final isLast = widget.stepIndex == widget.stepCount - 1;
    // Sin bandeja aquí (la lleva el diálogo): la carta se mide y se coloca
    // al píxel con 310 px reservados abajo para una carta de ~220 —12 px
    // de bandeja la mandaban arriba a pisar el hueco en teléfonos de 952.
    // Sombra del sistema + hairline, sin Material ni elevation.
    return Container(
      key: const ValueKey('guide_card'),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.hairline),
        boxShadow: AppShadows.floating,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                // El icono repite en dibujo lo que el título dice en
                // palabras; suelto se anuncia «imagen» y nada más.
                child: ExcludeSemantics(
                  child: Icon(
                    widget.icon,
                    color: AppColors.primary,
                    size: 21,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.title,
                  key: const ValueKey('guide_title'),
                  style: AppTextStyles.subtitulo,
                ),
              ),
              // El título y el contador se tocaban: el `Expanded` se come
              // todo el ancho libre y nadie había puesto un respiro entre
              // los dos. Antes lo tapaba que el título medía un punto menos.
              const SizedBox(width: AppSpacing.sm),
              // Mismo contraste tipográfico que el ETA gigante: el número
              // que importa (el paso actual) en peso ultraligero y grande,
              // el resto en una etiqueta diminuta al lado.
              Semantics(
                // En pantalla es un número grande con su fracción
                // pequeña al lado; leído es «uno, barra seis».
                label: 'Paso ${widget.stepIndex + 1} '
                    'de ${widget.stepCount}',
                excludeSemantics: true,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '${widget.stepIndex + 1}',
                      style: const TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.w200,
                        letterSpacing: -0.8,
                        color: AppColors.primaryDeep,
                      ),
                    ),
                    Text(
                      '/${widget.stepCount}',
                      style: AppTextStyles.etiqueta.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Semantics(
            // La guía cambia de paso sola, debajo del dedo de nadie: sin
            // región viva el paso nuevo se queda escrito y callado.
            liveRegion: true,
            child: Text(
              widget.message,
              key: const ValueKey('guide_message'),
              style: AppTextStyles.cuerpo.copyWith(
                color: AppColors.textBody,
              ),
            ),
          ),
          if (widget.primaryLabel != null && widget.onPrimary != null) ...[
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                key: const ValueKey('guide_primary'),
                onPressed: widget.onPrimary,
                style: FilledButton.styleFrom(
                  textStyle: AppTextStyles.boton,
                  backgroundColor: AppColors.primaryAccessible,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                  ),
                ),
                child: Text(widget.primaryLabel!),
              ),
            ),
          ] else ...[
            const SizedBox(height: 14),
            Center(
              child: Text(
                'Toca el área iluminada para continuar',
                style: AppTextStyles.etiqueta.copyWith(
                  color: AppColors.primaryAccessible,
                ),
              ),
            ),
          ],
          // Sin respiro propio: los botones miden 48 para el dedo y traen
          // 6 de aire por arriba y por abajo alrededor de la letra. Con el
          // respiro de antes la tarjeta crecía 12 y en el paso de los buses
          // pisaba el área iluminada.
          // F14: "Atrás" solo aparece si hay un paso previo al que volver.
          if (!widget.centered)
            Row(
              mainAxisAlignment: widget.onBack == null
                  ? MainAxisAlignment.center
                  : MainAxisAlignment.spaceBetween,
              children: [
                if (widget.onBack != null)
                  TextButton.icon(
                    key: const ValueKey('guide_back'),
                    onPressed: widget.onBack,
                    icon: const Icon(Icons.arrow_back_outlined, size: 16),
                    label: const Text('Atrás'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textBody,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      minimumSize: const Size(0, 48),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      textStyle: AppTextStyles.etiqueta,
                    ),
                  ),
                TextButton(
                  key: const ValueKey('guide_skip'),
                  onPressed: widget.onSkip,
                  style: TextButton.styleFrom(
                    textStyle: AppTextStyles.etiqueta,
                    backgroundColor: AppColors.surfaceMuted,
                    foregroundColor: AppColors.textBody,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    minimumSize: const Size(0, 48),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(isLast ? 'Cerrar guía' : 'Saltar guía'),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

double mathMax(double a, double b) => a > b ? a : b;
double mathMin(double a, double b) => a < b ? a : b;

class _GuideBarrier extends StatelessWidget {
  const _GuideBarrier({required this.onInvalidTap});

  final VoidCallback onInvalidTap;

  @override
  Widget build(BuildContext context) {
    // Las barreras solo existen para rechazar los toques que caen fuera
    // del hueco. Anunciadas serían cuatro rectángulos tocables del tamaño
    // de la pantalla que no llevan a ninguna parte, y encima rodeando a lo
    // único que sí hay que tocar.
    return ExcludeSemantics(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onInvalidTap,
        child: const SizedBox.expand(),
      ),
    );
  }
}

/// Velo completo sin hueco, usado en el paso de cierre (centrado).
class _ScrimPainter extends CustomPainter {
  const _ScrimPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = AppColors.primaryDeep.withValues(alpha: 0.62),
    );
  }

  @override
  bool shouldRepaint(_ScrimPainter oldDelegate) => false;
}

/// Un solo velo guardado en una capa: el hueco queda realmente transparente
/// y no vuelve a oscurecerse por una segunda pintura debajo.
class PintorHueco extends CustomPainter {
  const PintorHueco({required this.hole, required this.radio});

  final Rect hole;
  final double radio;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(hole, Radius.circular(radio));
    final scrim = AppColors.primaryDeep.withValues(alpha: 0.62);

    canvas.saveLayer(Offset.zero & size, Paint());
    canvas.drawRect(Offset.zero & size, Paint()..color = scrim);
    canvas.drawRRect(rrect, Paint()..blendMode = BlendMode.clear);
    canvas.restore();

    // Solo efectos alrededor del borde, nunca otro velo sobre el objetivo.
    canvas.drawRRect(
      rrect.inflate(2),
      Paint()
        ..color = AppColors.primary.withValues(alpha: 0.24)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.92)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
    final light = RadialGradient(
      colors: [
        Colors.white.withValues(alpha: 0.12),
        Colors.transparent,
      ],
    ).createShader(hole);
    canvas.drawRRect(rrect, Paint()..shader = light);
  }

  @override
  bool shouldRepaint(PintorHueco oldDelegate) =>
      oldDelegate.hole != hole || oldDelegate.radio != radio;
}
