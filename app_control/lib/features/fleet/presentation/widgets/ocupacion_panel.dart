import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:ya_viene_core/ya_viene_core.dart' show AppMotion;

import '../../../../core/theme/app_theme.dart';
import '../providers/ocupacion_provider.dart' show primeraHoraServicio;
import 'escala_calor.dart';

enum _Aforo {
  vacio('Vacío'),
  medio('Medio'),
  lleno('Lleno');

  const _Aforo(this.texto);
  final String texto;

  // Hasta 20 % se va sentado; desde 80 %, de pie y apretado.
  static _Aforo de(int pct) => pct <= 20
      ? vacio
      : pct >= 80
      ? lleno
      : medio;
}

String _hora(int h) => '${h > 12 ? h - 12 : h}';
String _meridiano(int h) => h % 24 < 12 ? 'a. m.' : 'p. m.';

/// El tono de un porcentaje en la escala del mapa: verde vacío, rojo lleno.
Color _tono(int pct) => colorEnEscala(pct / 100);

/// La ocupación bajo el ranking, en el lugar del resumen de todas las rutas:
/// la cifra de la hora elegida arriba, las horas abajo para elegir, en la
/// misma escala de color del mapa.
/// [horas] trae una por hora de servicio; null es una hora sin viajes aún.
class OcupacionResumen extends StatefulWidget {
  const OcupacionResumen({super.key, required this.horas, required this.rango});

  final List<int?> horas;

  /// De cuántos buses y de qué fechas es el promedio, a la vista bajo el
  /// título («nadie sabe si es un promedio», dueño, 2026-10-27).
  final String rango;

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
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ocupación promedio',
                      style: AppType.ui(
                        color: AppColors.navy,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      widget.rango,
                      key: const ValueKey('ocupacion-rango'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.ui(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
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
          const SizedBox(height: 14),
          // 40 px con o sin viajes: las barras no saltan.
          SizedBox(
            height: 40,
            child: pct == null || elegida == null
                ? Align(
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
                  )
                : Row(
                    children: [
                      // 36 px con tracking negativo, más que el total de cada
                      // ruta, porque es la cifra que se busca; en tinta, porque los tonos de la escala no
                      // llegan a 4,5:1 sobre blanco.
                      Text(
                        '$pct %',
                        key: const ValueKey('aforo-cifra'),
                        style: AppType.ui(
                          color: AppColors.navy,
                          fontSize: 36,
                          fontWeight: FontWeight.w800,
                          height: 1,
                          letterSpacing: -1,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(width: 12),
                      _Ficha(pct: pct),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          'de ${_hora(elegida)} a ${_hora(elegida + 1)} '
                          '${_meridiano(elegida + 1)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppType.ui(
                            color: AppColors.textSecondary,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 16),
          // Las barras toman el alto que deja la tarjeta: con una ruta sola
          // en el cuadro no queda un hueco blanco abajo (dueño, 2026-10-27).
          Expanded(
            child: LayoutBuilder(
              builder: (context, caja) => Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var i = 0; i < widget.horas.length; i++)
                    Expanded(
                      child: _Barra(
                        hora: primeraHoraServicio + i,
                        pct: widget.horas[i],
                        alto: caja.maxHeight,
                        elegida: primeraHoraServicio + i == elegida,
                        alTocar: () =>
                            setState(() => _elegida = primeraHoraServicio + i),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Un eje fijo bajo la primera barra de cada seis horas: los
          // extremos se alinean al borde y nunca se salen de la tarjeta.
          SizedBox(
            key: const ValueKey('ocupacion-eje'),
            height: 15,
            child: Stack(
              children: [
                for (final i in const [0, 6, 12, 18])
                  Align(
                    alignment: Alignment(
                      -1 + 2 * (i + 0.5) / widget.horas.length,
                      0,
                    ),
                    child: Text(
                      '${_hora(primeraHoraServicio + i)} '
                      '${_meridiano(primeraHoraServicio + i)}',
                      maxLines: 1,
                      style: AppType.ui(
                        color: AppColors.textMuted,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Estado del aforo: un punto en el tono de la escala y el texto en tinta,
/// sobre gris claro (tinta sobre #F1F5F9: 11,6:1).
class _Ficha extends StatelessWidget {
  const _Ficha({required this.pct});

  final int pct;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(8, 4, 10, 4),
    decoration: BoxDecoration(
      color: AppColors.surfaceRaised,
      borderRadius: BorderRadius.circular(AppRadius.pill),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: AppMotion.normal,
          curve: AppMotion.curvaCambio,
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: _tono(pct), shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          _Aforo.de(pct).texto,
          key: const ValueKey('aforo-estado'),
          style: AppType.ui(
            color: AppColors.navy,
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );
}

/// Una hora: barra baja y redonda según su ocupación, en la escala del mapa.
/// Las demás van en su tono aclarado; la elegida, en su tono entero con un
/// halo. Al pasar el puntero sube de tono y dice su hora y su cifra; al
/// presionar se hunde un poco, antes de soltar.
class _Barra extends StatefulWidget {
  const _Barra({
    required this.hora,
    required this.pct,
    required this.alto,
    required this.elegida,
    required this.alTocar,
  });

  final int hora;
  final double alto;

  /// null: la hora aún no llega; queda una raya baja que no se toca.
  final int? pct;
  final bool elegida;
  final VoidCallback alTocar;

  @override
  State<_Barra> createState() => _BarraState();
}

class _BarraState extends State<_Barra> {
  var _encima = false;
  var _presionada = false;

  @override
  Widget build(BuildContext context) {
    final pct = widget.pct;
    final alto = widget.alto;
    if (pct == null) {
      return Semantics(
        label:
            '${_hora(widget.hora)} ${_meridiano(widget.hora)}, sin viajes aún',
        child: Padding(
          key: ValueKey('aforo-hora-${widget.hora}'),
          padding: EdgeInsets.fromLTRB(3, alto - 4, 3, 0),
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
    final tono = _tono(pct);
    // Las demás, el tono al 45 % sobre la tarjeta (70 % con el puntero):
    // se leen como fondo y la elegida resalta sin cambiar de color.
    final tinte = elegida
        ? tono
        : Color.alphaBlend(
            tono.withValues(alpha: _encima ? 0.7 : 0.45),
            AppColors.surface,
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
            child: Tooltip(
              message:
                  '${_hora(widget.hora)} ${_meridiano(widget.hora)}, '
                  '$pct %',
              child: SizedBox(
                height: alto,
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
                      // Nunca menos de 8 px, para que la hora más vacía siga
                      // siendo una barra que se puede tocar.
                      height: (alto * pct / 100).clamp(8, alto),
                      decoration: BoxDecoration(
                        color: tinte,
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: [
                          if (elegida)
                            BoxShadow(
                              color: tono.withValues(alpha: 0.35),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
