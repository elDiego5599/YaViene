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
    _scale = CurvedAnimation(parent: _controller, curve: Curves.easeOutBack);
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
        final rawHole = widget.target.inflate(widget.targetPadding);
        final hole = rawHole.intersect(bounds);
        final bottomInset = MediaQuery.of(context).viewPadding.bottom;
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
                    child: ScaleTransition(
                      scale: _scale,
                      child: KeyedSubtree(key: _cardKey, child: card),
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
        final placeAbove = hole.top > 245 || !fitsBelow;

        return Stack(
          fit: StackFit.expand,
          children: [
            IgnorePointer(
              child: FadeTransition(
                opacity: _fade,
                child: CustomPaint(
                  key: const ValueKey('guide_scrim'),
                  painter: _SpotlightPainter(hole: hole),
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
                          borderRadius:
                              BorderRadius.circular(AppRadius.card + 4),
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
              top: placeAbove ? null : _belowTop(hole, size, bottomInset),
              bottom: placeAbove
                  ? _aboveBottom(hole, size, bottomInset, cardHeight)
                  : null,
              child: ScaleTransition(
                scale: _scale,
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

  double _belowTop(Rect hole, Size size, double bottomInset) {
    final proposed = hole.bottom + 22;
    // El límite superior solo evita que la carta quede bajo la barra de
    // navegación; `fitsBelow` ya garantiza que no suba hasta el hueco.
    final maxTop = mathMax(12.0, size.height - bottomInset - 180);
    return proposed.clamp(12.0, maxTop);
  }

  double _aboveBottom(
      Rect hole, Size size, double bottomInset, double cardHeight) {
    final proposed = size.height - hole.top + 22;
    final minBottom = bottomInset + 12;
    // La carta queda sobre el objetivo con 22 px de aire y nunca sube tanto
    // que su borde superior se salga de la pantalla.
    final maxBottom = mathMax(minBottom, size.height - cardHeight - 12);
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
    return Material(
      key: const ValueKey('guide_card'),
      color: Colors.white,
      elevation: 16,
      shadowColor: const Color(0x6614274E),
      borderRadius: BorderRadius.circular(AppRadius.card),
      clipBehavior: Clip.antiAlias,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: AppColors.hairline),
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
                  child: Icon(
                    widget.icon,
                    color: AppColors.primary,
                    size: 21,
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
                Row(
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
                        color: AppColors.textDisabled,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              widget.message,
              key: const ValueKey('guide_message'),
              style: AppTextStyles.cuerpo.copyWith(
                color: const Color(0xFF475569),
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
                    backgroundColor: AppColors.primary,
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
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
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
                      icon: const Icon(Icons.arrow_back_rounded, size: 16),
                      label: const Text('Atrás'),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF475569),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        minimumSize: const Size(0, 36),
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
                      foregroundColor: const Color(0xFF475569),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 22),
                      minimumSize: const Size(0, 36),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(isLast ? 'Cerrar guía' : 'Saltar guía'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

double mathMax(double a, double b) => a > b ? a : b;

class _GuideBarrier extends StatelessWidget {
  const _GuideBarrier({required this.onInvalidTap});

  final VoidCallback onInvalidTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onInvalidTap,
      child: const SizedBox.expand(),
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
class _SpotlightPainter extends CustomPainter {
  const _SpotlightPainter({required this.hole});

  final Rect hole;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect =
        RRect.fromRectAndRadius(hole, const Radius.circular(AppRadius.card));
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
  bool shouldRepaint(_SpotlightPainter oldDelegate) => oldDelegate.hole != hole;
}
