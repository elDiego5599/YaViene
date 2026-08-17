import 'package:flutter/material.dart';

/// Coach mark de primer uso: oscurece toda la pantalla con el color de la
/// marca y deja un "hueco" brillante alrededor del objetivo (la píldora de
/// búsqueda), con una burbuja explicativa justo debajo.
///
/// Cierra con el botón "Entendido" o tocando cualquier parte oscura; en ambos
/// casos se llama a [onDone] (el dueño marca el tour como visto).
class MapTourOverlay extends StatefulWidget {
  const MapTourOverlay({super.key, required this.target, required this.onDone});

  /// Rect del objetivo en coordenadas del overlay (toda la pantalla).
  final Rect target;
  final VoidCallback onDone;

  @override
  State<MapTourOverlay> createState() => _MapTourOverlayState();
}

class _MapTourOverlayState extends State<MapTourOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
  );
  late final Animation<double> _scale = CurvedAnimation(
    parent: _ctrl,
    curve: Curves.easeOutBack,
  );

  @override
  void initState() {
    super.initState();
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hole = widget.target.inflate(18);
    const bubbleH = 148.0;
    final size = MediaQuery.of(context).size;
    final below = hole.bottom + 28 + bubbleH <= size.height - 20;
    final bubbleTop = below ? hole.bottom + 28 : hole.top - 28 - bubbleH;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Scrim con hueco: tocar cualquier parte oscura cierra el tour.
        GestureDetector(
          key: const ValueKey('tour_scrim'),
          behavior: HitTestBehavior.opaque,
          onTap: widget.onDone,
          child: CustomPaint(
            painter: _HolePainter(
              hole: hole,
              scrim: const Color(0xFF14274E).withValues(alpha: 0.84),
              ring: const Color(0xFFFFFFFF).withValues(alpha: 0.92),
            ),
          ),
        ),
        // Burbuja explicativa: entra con rebote y no intercepta el toque de
        // cierre salvo en su propio botón.
        Positioned(
          key: const ValueKey('tour_bubble'),
          left: 24,
          right: 24,
          top: bubbleTop,
          child: ScaleTransition(
            scale: _scale,
            child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF14274E).withValues(alpha: 0.25),
                      blurRadius: 28,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFF00A859)
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.touch_app_rounded,
                            color: Color(0xFF00A859),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Text(
                            'Elige tu ruta',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Toca la píldora de arriba para buscar tu línea y '
                        'elegir tu sentido.',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                          height: 1.35,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: FilledButton(
                        key: const ValueKey('tour_ok'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF00A859),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: widget.onDone,
                        child: const Text(
                          'Entendido',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
    );
  }
}

/// Pinta el velo oscuro con un hueco redondeado alrededor del objetivo y un
/// anillo blanco que lo resalta (estilo coach mark).
class _HolePainter extends CustomPainter {
  const _HolePainter({
    required this.hole,
    required this.scrim,
    required this.ring,
  });

  final Rect hole;
  final Color scrim;
  final Color ring;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect =
        RRect.fromRectAndRadius(hole, const Radius.circular(28));
    canvas.saveLayer(Offset.zero & size, Paint());
    canvas.drawRect(Offset.zero & size, Paint()..color = scrim);
    // BlendMode.clear recorta el hueco: la píldora queda "iluminada".
    canvas.drawRRect(rrect, Paint()..blendMode = BlendMode.clear);
    canvas.restore();
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = ring
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  @override
  bool shouldRepaint(_HolePainter oldDelegate) =>
      oldDelegate.hole != hole || oldDelegate.scrim != scrim;
}