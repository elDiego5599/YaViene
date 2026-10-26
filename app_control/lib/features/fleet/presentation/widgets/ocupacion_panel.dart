import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:ya_viene_core/ya_viene_core.dart' show AppMotion;

import '../../../../core/theme/app_theme.dart';
import '../providers/ocupacion_provider.dart' show primeraHoraServicio;

enum _Aforo {
  vacio('Vacío', AppColors.online),
  medio('Medio', AppColors.ghost),
  lleno('Lleno', AppColors.offline);

  const _Aforo(this.texto, this.color);
  final String texto;
  final Color color;

  // Hasta 20 % se va sentado; desde 80 %, de pie y apretado.
  static _Aforo de(int pct) => pct <= 20
      ? vacio
      : pct >= 80
      ? lleno
      : medio;
}

String _hora(int h) => '${h > 12 ? h - 12 : h}';
String _meridiano(int h) => h % 24 < 12 ? 'a. m.' : 'p. m.';

// Puestos del bus dibujado: seis ventanas, dos cabezas en cada una.
const _puestos = 12;

/// La ocupación bajo el ranking, en el lugar del resumen de todas las rutas:
/// el bus y la cifra de la hora elegida arriba, las horas abajo para elegir.
/// [horas] trae una por hora de servicio; null es una hora sin viajes aún.
class OcupacionResumen extends StatefulWidget {
  const OcupacionResumen({super.key, required this.horas, required this.buses});

  final List<int?> horas;

  /// Buses de la ruta: la ocupación es su promedio.
  final int buses;

  @override
  State<OcupacionResumen> createState() => _OcupacionResumenState();
}

class _OcupacionResumenState extends State<OcupacionResumen> {
  // Arranca en la hora más llena, la que la empresa quiere ver primero.
  late int? _elegida = _masLlena();

  int? _masLlena() {
    int? hora;
    for (var i = 0; i < widget.horas.length; i++) {
      final pct = widget.horas[i];
      if (pct != null && (hora == null || pct > widget.horas[hora]!)) hora = i;
    }
    return hora == null ? null : primeraHoraServicio + hora;
  }

  // Otra ruta u otro periodo: las barras crecen o bajan a lo nuevo y la
  // elegida vuelve a la más llena.
  @override
  void didUpdateWidget(OcupacionResumen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.horas, widget.horas)) _elegida = _masLlena();
  }

  @override
  Widget build(BuildContext context) {
    final elegida = _elegida;
    final pct = elegida == null
        ? null
        : widget.horas[elegida - primeraHoraServicio];
    return Padding(
      key: const ValueKey('ocupacion'),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                'Ocupación',
                style: AppType.ui(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  widget.buses == 1
                      ? 'de 1 bus'
                      : 'promedio de ${widget.buses} buses',
                  key: const ValueKey('ocupacion-buses'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.ui(color: AppColors.textMuted, fontSize: 12),
                ),
              ),
              const Spacer(),
              // La nota de las cámaras va en el globo: aquí no cabe una línea
              // entera sin quitarle alto a las barras.
              Tooltip(
                key: const ValueKey('ocupacion-sin-camaras'),
                message:
                    'Aún no hay buses con cámara de aforo conectada. Con ella, '
                    'un modelo de IA dirá cómo va cada bus.',
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceRaised,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.videocam_off_outlined,
                        size: 13,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Datos de ejemplo',
                        style: AppType.ui(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (pct == null || elegida == null)
            // 49 px, el alto del bus: las barras no saltan.
            SizedBox(
              height: 49,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Aún no hay viajes en este periodo',
                  key: const ValueKey('ocupacion-sin-viajes'),
                  style: AppType.ui(
                    color: AppColors.textSecondary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            )
          else
            Row(
              children: [
                // 112 px: el bus a 2,3:1 mide 49 de alto, lo mismo que la cifra
                // y su ficha juntas, y el renglón queda parejo.
                SizedBox(
                  width: 112,
                  child: _Bus(pct: pct, color: _Aforo.de(pct).color),
                ),
                const SizedBox(width: 18),
                // 30 px con tracking negativo, como el total de cada ruta.
                AnimatedDefaultTextStyle(
                  duration: AppMotion.normal,
                  curve: AppMotion.curvaCambio,
                  style: AppType.ui(
                    color: _Aforo.de(pct).color,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    height: 1,
                    letterSpacing: -0.8,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                  child: Text('$pct %', key: const ValueKey('aforo-cifra')),
                ),
                const SizedBox(width: 12),
                _Ficha(aforo: _Aforo.de(pct)),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    'de ${_hora(elegida)} a ${_hora(elegida + 1)} '
                    '${_meridiano(elegida + 1)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.ui(
                      color: AppColors.textSecondary,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < widget.horas.length; i++)
                Expanded(
                  child: _Barra(
                    hora: primeraHoraServicio + i,
                    pct: widget.horas[i],
                    elegida: primeraHoraServicio + i == elegida,
                    alTocar: () =>
                        setState(() => _elegida = primeraHoraServicio + i),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Estado del aforo en su color sobre su mismo tono al 8 %. Contraste medido
/// sobre ese fondo: verde 4,9:1, ámbar 4,85:1, rojo 4,83:1 (AA, 4,5:1).
class _Ficha extends StatelessWidget {
  const _Ficha({required this.aforo});

  final _Aforo aforo;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: AppMotion.normal,
    curve: AppMotion.curvaCambio,
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: Color.alphaBlend(
        aforo.color.withValues(alpha: 0.08),
        AppColors.surface,
      ),
      borderRadius: BorderRadius.circular(AppRadius.pill),
    ),
    child: Text(
      aforo.texto,
      key: const ValueKey('aforo-estado'),
      style: AppType.ui(
        color: aforo.color,
        fontSize: 12.5,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

/// El bus de lado con sus pasajeros: los puestos se llenan según la cifra y
/// cada cabeza nueva entra con el resorte, en el color del estado.
class _Bus extends StatelessWidget {
  const _Bus({required this.pct, required this.color});

  final int pct;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ocupados = (pct * _puestos / 100).round();
    return Semantics(
      key: const ValueKey('aforo-bus'),
      container: true,
      label: 'Bus con $ocupados de $_puestos puestos ocupados',
      child: AspectRatio(
        aspectRatio: 2.3,
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: ocupados.toDouble()),
          duration: AppMotion.normal,
          curve: AppMotion.curvaCambio,
          builder: (_, llenos, _) => TweenAnimationBuilder<Color?>(
            tween: ColorTween(end: color),
            duration: AppMotion.normal,
            curve: AppMotion.curvaCambio,
            builder: (_, tinte, _) => CustomPaint(
              painter: _PintorBus(llenos: llenos, color: tinte ?? color),
            ),
          ),
        ),
      ),
    );
  }
}

class _PintorBus extends CustomPainter {
  _PintorBus({required this.llenos, required this.color});

  final double llenos;
  final Color color;

  static const _llanta = AppColors.navy;
  static const _vidrio = Color(0xFFEAF0F7);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final linea = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = AppColors.borderStrong;
    final ruedaR = h * 0.13;
    final suelo = h - ruedaR * 0.35;
    final abajo = suelo - ruedaR;

    // Sombra suave bajo el bus, para que se pose en la tarjeta.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.5, suelo),
        width: w * 0.9,
        height: h * 0.07,
      ),
      Paint()
        ..color = AppColors.navy.withValues(alpha: 0.08)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    // Techo con su caja del aire y la carrocería.
    final techo = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.2, h * 0.02, w * 0.36, h * 0.07),
      const Radius.circular(4),
    );
    canvas
      ..drawRRect(techo, Paint()..color = AppColors.surfaceRaised)
      ..drawRRect(techo, linea);
    final cuerpo = RRect.fromRectAndCorners(
      Rect.fromLTRB(0, h * 0.07, w, abajo),
      topLeft: Radius.circular(h * 0.14),
      topRight: Radius.circular(h * 0.2),
      bottomLeft: Radius.circular(h * 0.06),
      bottomRight: Radius.circular(h * 0.08),
    );
    canvas
      ..drawRRect(cuerpo, Paint()..color = AppColors.surface)
      ..drawRRect(cuerpo, linea);

    // Seis ventanas de pasajeros y el parabrisas al frente.
    final arriba = h * 0.16;
    final altoVentana = h * 0.36;
    const izq = 0.04;
    const der = 0.78;
    final hueco = w * 0.012;
    final anchoVentana = (w * (der - izq) - hueco * 5) / 6;
    final vidrio = Paint()..color = _vidrio;
    for (var v = 0; v < 6; v++) {
      final x = w * izq + v * (anchoVentana + hueco);
      final ventana = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, arriba, anchoVentana, altoVentana),
        Radius.circular(h * 0.04),
      );
      canvas
        ..drawRRect(ventana, vidrio)
        ..save()
        ..clipRRect(ventana);
      // Dos puestos por ventana; se llenan ventana por ventana a lo largo
      // del bus, como sube la gente, y luego el segundo de cada una.
      for (var lado = 0; lado < 2; lado++) {
        final puesto = lado * 6 + v;
        final alfa = (llenos - puesto).clamp(0.0, 1.0);
        if (alfa == 0) continue;
        _pasajero(
          canvas,
          Offset(x + anchoVentana * (lado == 0 ? 0.32 : 0.7), arriba),
          altoVentana,
          anchoVentana,
          color.withValues(alpha: alfa),
        );
      }
      canvas.restore();
    }
    final frente = RRect.fromRectAndCorners(
      Rect.fromLTRB(w * 0.82, arriba, w * 0.965, arriba + altoVentana * 1.25),
      topLeft: Radius.circular(h * 0.04),
      bottomLeft: Radius.circular(h * 0.04),
      topRight: Radius.circular(h * 0.1),
      bottomRight: Radius.circular(h * 0.04),
    );
    canvas.drawRRect(frente, vidrio);

    // Las franjas de la marca: azul y, debajo, la verde más corta.
    final franja = arriba + altoVentana + h * 0.08;
    canvas
      ..drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.015, franja, w * 0.78, h * 0.035),
          const Radius.circular(3),
        ),
        Paint()..color = AppColors.boton,
      )
      ..drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.015, franja + h * 0.05, w * 0.5, h * 0.02),
          const Radius.circular(2),
        ),
        Paint()..color = AppColors.online,
      )
      // Farol ámbar al frente.
      ..drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.955, franja + h * 0.01, w * 0.03, h * 0.045),
          const Radius.circular(3),
        ),
        Paint()..color = const Color(0xFFF4C430),
      );

    // Ruedas: llanta en tinta y rin claro, sobre el suelo.
    for (final cx in [w * 0.2, w * 0.8]) {
      final c = Offset(cx, abajo);
      canvas
        ..drawCircle(c, ruedaR * 1.18, Paint()..color = AppColors.surface)
        ..drawCircle(c, ruedaR, Paint()..color = _llanta)
        ..drawCircle(c, ruedaR * 0.45, Paint()..color = AppColors.borderStrong)
        ..drawCircle(c, ruedaR * 0.14, Paint()..color = _llanta);
    }
  }

  // Cabeza y hombros, asomados desde el borde de abajo de la ventana.
  void _pasajero(
    Canvas canvas,
    Offset arriba,
    double altoVentana,
    double anchoVentana,
    Color color,
  ) {
    final pintura = Paint()..color = color;
    final r = anchoVentana * 0.13;
    final cabeza = arriba + Offset(0, altoVentana * 0.48);
    canvas
      ..drawCircle(cabeza, r, pintura)
      ..drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: cabeza + Offset(0, r * 2.9),
            width: r * 3.1,
            height: r * 3.2,
          ),
          Radius.circular(r * 1.4),
        ),
        pintura,
      );
  }

  @override
  bool shouldRepaint(_PintorBus old) =>
      old.llenos != llenos || old.color != color;
}

/// Una hora: barra baja y redonda según su ocupación. Llena y vacía van
/// teñidas de su color, lo medio en gris como en el video; la elegida, en su
/// color entero con un halo. Al pasar el puntero se oscurece y dice su hora;
/// al presionar se hunde un poco, antes de soltar.
class _Barra extends StatefulWidget {
  const _Barra({
    required this.hora,
    required this.pct,
    required this.elegida,
    required this.alTocar,
  });

  final int hora;

  /// null: la hora aún no llega; queda una raya baja que no se toca.
  final int? pct;
  final bool elegida;
  final VoidCallback alTocar;

  @override
  State<_Barra> createState() => _BarraState();
}

class _BarraState extends State<_Barra> {
  // 56 px: bajo el ranking las barras son el índice, no el dato.
  static const _alto = 56.0;
  var _encima = false;
  var _presionada = false;

  @override
  Widget build(BuildContext context) {
    final pct = widget.pct;
    if (pct == null) {
      return Semantics(
        label:
            '${_hora(widget.hora)} ${_meridiano(widget.hora)}, sin viajes aún',
        child: Padding(
          key: ValueKey('aforo-hora-${widget.hora}'),
          padding: const EdgeInsets.fromLTRB(3, _alto - 4, 3, 32),
          child: AnimatedContainer(
            duration: AppMotion.normal,
            curve: AppMotion.curvaCambio,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      );
    }
    final aforo = _Aforo.de(pct);
    final elegida = widget.elegida;
    // Tintes sobre la tarjeta blanca: rojo y verde al 24 %, gris #DCE2EA;
    // con el puntero encima suben a 40 % y #CBD3DE.
    final tinte = elegida
        ? aforo.color
        : aforo == _Aforo.medio
        ? (_encima ? const Color(0xFFCBD3DE) : const Color(0xFFDCE2EA))
        : Color.alphaBlend(
            aforo.color.withValues(alpha: _encima ? 0.4 : 0.24),
            AppColors.surface,
          );
    final rotulo = AppType.ui(
      color: elegida ? AppColors.navy : AppColors.textSecondary,
      fontSize: elegida ? 11 : 10,
      fontWeight: elegida ? FontWeight.w800 : FontWeight.w600,
      height: 1.15,
    );
    return Semantics(
      button: true,
      selected: elegida,
      label:
          '${_hora(widget.hora)} ${_meridiano(widget.hora)}, '
          '$pct %, ${aforo.texto}',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _encima = true),
        onExit: (_) => setState(() => _encima = false),
        child: GestureDetector(
          key: ValueKey('aforo-hora-${widget.hora}'),
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => setState(() => _presionada = true),
          onTapCancel: () => setState(() => _presionada = false),
          onTap: () {
            setState(() => _presionada = false);
            widget.alTocar();
          },
          child: Padding(
            // 3 px por lado: 6 de aire entre las 19 barras.
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Column(
              children: [
                SizedBox(
                  height: _alto,
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: AnimatedScale(
                      scale: _presionada ? 0.94 : 1,
                      duration: AppMotion.instante,
                      curve: AppMotion.curvaCambio,
                      alignment: Alignment.bottomCenter,
                      child: AnimatedContainer(
                        duration: AppMotion.normal,
                        curve: AppMotion.curvaCambio,
                        // Nunca menos de 8 px, para que la hora más vacía
                        // siga siendo una barra que se puede tocar.
                        height: (_alto * pct / 100).clamp(8, _alto),
                        decoration: BoxDecoration(
                          color: tinte,
                          borderRadius: BorderRadius.circular(6),
                          boxShadow: [
                            if (elegida)
                              BoxShadow(
                                color: aforo.color.withValues(alpha: 0.35),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  height: 26,
                  child: ExcludeSemantics(
                    child: AnimatedSwitcher(
                      duration: AppMotion.rapido,
                      switchInCurve: AppMotion.curvaCambio,
                      switchOutCurve: AppMotion.curvaSalida,
                      child: elegida || _encima
                          // Dos líneas de 11 × 1,15 = 25,3 px caben en 26;
                          // con otra fuente se encoge en vez de desbordar.
                          ? FittedBox(
                              key: ValueKey(elegida),
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.topCenter,
                              child: Column(
                                children: [
                                  Text(_hora(widget.hora), style: rotulo),
                                  Text(_meridiano(widget.hora), style: rotulo),
                                ],
                              ),
                            )
                          : const SizedBox.shrink(),
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
}
