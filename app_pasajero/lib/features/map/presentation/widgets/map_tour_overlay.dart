import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Coach mark de primer uso: oscurece la pantalla con el color de la marca,
/// deja un "hueco" brillante alrededor del objetivo y muestra una burbuja
/// tipo vidrio con la explicación.
///
/// Cierra con el botón o tocando cualquier parte oscura; en ambos casos se
/// llama a [onDone] (el dueño marca el paso del tour como visto).
class MapTourOverlay extends StatefulWidget {
  const MapTourOverlay({
    super.key,
    required this.target,
    required this.title,
    required this.subtitle,
    this.icon = Icons.touch_app_rounded,
    this.buttonLabel = 'Entendido',
    this.stepIndex = 0,
    this.stepCount = 1,
    required this.onDone,
  });

  /// Rect del objetivo en coordenadas del overlay (toda la pantalla).
  final Rect target;
  final String title;
  final String subtitle;
  final IconData icon;

  /// "Siguiente" en tours de varios pasos seguidos; por defecto "Entendido".
  final String buttonLabel;

  /// Posición de este paso en el tour (para los puntos indicadores).
  final int stepIndex;
  final int stepCount;
  final VoidCallback onDone;

  @override
  State<MapTourOverlay> createState() => _MapTourOverlayState();
}

class _MapTourOverlayState extends State<MapTourOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
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
    final hole = widget.target.inflate(20);
    const bubbleH = 156.0;
    final size = MediaQuery.of(context).size;
    final below = hole.bottom + 30 + bubbleH <= size.height - 24;
    final bubbleTop = below ? hole.bottom + 30 : hole.top - 30 - bubbleH;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Scrim con hueco: tocar cualquier parte oscura cierra el tour.
        GestureDetector(
          key: const ValueKey('tour_scrim'),
          behavior: HitTestBehavior.opaque,
          onTap: widget.onDone,
          child: FadeTransition(
            opacity: CurvedAnimation(
              parent: _ctrl,
              curve: const Interval(0, 0.6, curve: Curves.easeOut),
            ),
            child: CustomPaint(
              painter: _HolePainter(hole: hole),
            ),
          ),
        ),
        // Burbuja tipo vidrio: entra con rebote.
        Positioned(
          key: const ValueKey('tour_bubble'),
          left: 20,
          right: 20,
          top: bubbleTop,
          child: ScaleTransition(
            scale: _scale,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(26),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.97),
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.9),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF14274E).withValues(alpha: 0.3),
                        blurRadius: 40,
                        offset: const Offset(0, 16),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFF00A859), Color(0xFF059669)],
                              ),
                            ),
                            child: Icon(
                              widget.icon,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              widget.title,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          widget.subtitle,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500,
                            height: 1.45,
                            color: Color(0xFF475569),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: FilledButton(
                          key: const ValueKey('tour_ok'),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF00A859),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          onPressed: widget.onDone,
                          child: Text(
                            widget.buttonLabel,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                      ),
                      if (widget.stepCount > 1) ...[
                        const SizedBox(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            for (var i = 0; i < widget.stepCount; i++)
                              Container(
                                width: i == widget.stepIndex ? 22 : 8,
                                height: 8,
                                margin: const EdgeInsets.symmetric(
                                    horizontal: 3),
                                decoration: BoxDecoration(
                                  color: i == widget.stepIndex
                                      ? const Color(0xFF00A859)
                                      : const Color(0xFFCBD5E1),
                                  borderRadius: BorderRadius.circular(99),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Velo de marca con transparencia y un hueco difuminado alrededor del
/// objetivo: solo lo que se debe usar queda iluminado, el resto se cubre.
/// El borde del hueco se desvanece (pluma) y el interior recibe una luz
/// suave para que el objetivo "brille" (estilo coach mark premium).
class _HolePainter extends CustomPainter {
  const _HolePainter({required this.hole});

  final Rect hole;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(hole, const Radius.circular(30));
    final scrim = const Color(0xFF14274E).withValues(alpha: 0.58);

    // Velo con transparencia: el mapa sigue asomando detrás.
    canvas.drawRect(Offset.zero & size, Paint()..color = scrim);

    // Hueco: se recorta el rectángulo del objetivo (BlendMode.clear exige
    // una capa guardada).
    canvas.saveLayer(Offset.zero & size, Paint());
    canvas.drawRect(Offset.zero & size, Paint()..color = scrim);
    canvas.drawRRect(rrect, Paint()..blendMode = BlendMode.clear);
    canvas.restore();

    // Pluma: borde oscuro difuminado que funde el velo con el hueco (nada
    // de cortes duros).
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = const Color(0xFF14274E).withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 20
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );

    // Luz interior suave: el objetivo queda "encendido".
    final inner = RadialGradient(
      colors: [
        Colors.white.withValues(alpha: 0.12),
        Colors.white.withValues(alpha: 0.02),
        Colors.transparent,
      ],
    ).createShader(rrect.outerRect);
    canvas.drawRRect(rrect, Paint()..shader = inner);

    // Resplandor verde sutil alrededor del hueco.
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = const Color(0xFF00A859).withValues(alpha: 0.2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    // Anillo blanco fino que resalta el objetivo.
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
  }

  @override
  bool shouldRepaint(_HolePainter oldDelegate) => oldDelegate.hole != hole;
}