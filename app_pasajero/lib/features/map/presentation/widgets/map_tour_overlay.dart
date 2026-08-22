import 'package:flutter/material.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import '../../../../core/widgets/map_pattern_painter.dart';

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
  final double targetPadding;

  /// Modo de cierre: sin área iluminada ni barreras; la carta queda centrada
  /// y la única acción es el botón primario ("Finalizar guía").
  final bool centered;

  @override
  State<MapGuideOverlay> createState() => _MapGuideOverlayState();
}

class _MapGuideOverlayState extends State<MapGuideOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _fade;

  /// Altura real de la carta, medida tras el primer layout: sirve para
  /// decidir si la carta cabe debajo del área iluminada sin solaparla.
  double? _cardHeight;
  final GlobalKey _cardKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    );
    _scale = CurvedAnimation(parent: _controller, curve: Curves.easeOutBack);
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
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
              const Positioned.fill(child: _GuideBarrier()),
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
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
            ..._buildBarriers(size, hole),
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

  List<Widget> _buildBarriers(Size size, Rect hole) {
    final barriers = <Widget>[];
    if (hole.top > 0) {
      barriers.add(Positioned(
        top: 0,
        left: 0,
        right: 0,
        height: hole.top,
        child: const _GuideBarrier(),
      ));
    }
    if (hole.bottom < size.height) {
      barriers.add(Positioned(
        top: hole.bottom,
        left: 0,
        right: 0,
        bottom: 0,
        child: const _GuideBarrier(),
      ));
    }
    if (hole.left > 0 && hole.height > 0) {
      barriers.add(Positioned(
        top: hole.top,
        left: 0,
        width: hole.left,
        height: hole.height,
        child: const _GuideBarrier(),
      ));
    }
    if (hole.right < size.width && hole.height > 0) {
      barriers.add(Positioned(
        top: hole.top,
        left: hole.right,
        right: 0,
        height: hole.height,
        child: const _GuideBarrier(),
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
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.divider),
        ),
        child: CustomPaint(
          painter: const MapPatternPainter(color: AppColors.primaryDeep),
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
                    borderRadius: BorderRadius.circular(12),
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
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.35,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
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
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
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
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                height: 1.4,
                color: Color(0xFF475569),
              ),
            ),
            if (widget.primaryLabel != null && widget.onPrimary != null) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  key: const ValueKey('guide_primary'),
                  onPressed: widget.onPrimary,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  child: Text(
                    widget.primaryLabel!,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ] else ...[
              const SizedBox(height: 14),
              const Center(
                child: Text(
                  'Toca el área iluminada para continuar',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 8),
            if (!widget.centered)
              Center(
                child: TextButton(
                  key: const ValueKey('guide_skip'),
                  onPressed: widget.onSkip,
                  style: TextButton.styleFrom(
                    backgroundColor: AppColors.surfaceMuted,
                    foregroundColor: const Color(0xFF475569),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    minimumSize: const Size(0, 36),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    isLast ? 'Cerrar guía' : 'Saltar guía',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
          ),
        ),
      ),
    );
  }
}

double mathMax(double a, double b) => a > b ? a : b;

class _GuideBarrier extends StatelessWidget {
  const _GuideBarrier();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {},
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
    final rrect = RRect.fromRectAndRadius(hole, const Radius.circular(24));
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
