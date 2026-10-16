import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:ya_viene_core/ya_viene_core.dart';

/// Una pestaña de la barra de abajo.
class Pestana {
  const Pestana(this.rotulo, this.icono, this.iconoPuesto);

  final String rotulo;
  final IconData icono;

  /// Relleno cuando está puesta, como en iOS: la forma sola ya dice cuál es,
  /// sin depender del color.
  final IconData iconoPuesto;
}

/// Las cuatro pestañas, en el orden de las ramas del router.
const kPestanas = [
  Pestana('Mapa', Icons.map_outlined, Icons.map_rounded),
  Pestana(
      'Avisos', Icons.notifications_none_rounded, Icons.notifications_rounded),
  Pestana('Buzón', Icons.feedback_outlined, Icons.feedback_rounded),
  Pestana('Más', Icons.more_horiz_rounded, Icons.more_horiz_rounded),
];

/// La barra de abajo: una píldora blanca y sólida, como la de búsqueda de
/// arriba, con la pestaña puesta sobre su cápsula verde (dueño, 2026-10-16;
/// nada de vidrio).
///
/// Se toca una pestaña, o se aprieta y se desliza el dedo de lado: la
/// cápsula va pegada al dedo y cada pestaña que cruza se abre al pasar,
/// con un toque háptico por paso, como el selector de iOS. Al soltar, la
/// cápsula se asienta en su pestaña con la velocidad que traía el dedo.
class PildoraNavegacion extends StatefulWidget {
  const PildoraNavegacion({
    super.key,
    required this.indice,
    required this.alElegir,
    this.avisosActivos = 0,
  });

  /// La pestaña puesta.
  final int indice;

  /// Pide abrir otra pestaña. Nunca llega con la que ya está puesta.
  final ValueChanged<int> alElegir;

  /// La cuenta que lleva Avisos; cero no pinta nada.
  final int avisosActivos;

  /// Alto de la píldora: la cápsula de 52 más su margen de 6 por lado, con
  /// el icono de 24 y el rótulo dentro aun con el texto en su techo.
  static const double alto = 64;

  /// Margen entre la cápsula y el borde de la píldora.
  static const double margen = 6;

  @override
  State<PildoraNavegacion> createState() => _PildoraNavegacionState();
}

class _PildoraNavegacionState extends State<PildoraNavegacion>
    with SingleTickerProviderStateMixin {
  /// Dónde está la cápsula, en pestañas: 0 es Mapa, 3 es Más. Sin límites
  /// para que el resorte pueda llegar con su velocidad.
  late final AnimationController _capsula = AnimationController.unbounded(
    vsync: this,
    value: widget.indice.toDouble(),
  );

  bool _arrastrando = false;
  int? _apretada;

  /// La pestaña bajo el dedo la última vez que se miró: el háptico y el
  /// cambio salen solo cuando esto cambia, no en cada cuadro.
  int _bajoDedo = 0;

  int get _ultima => kPestanas.length - 1;

  @override
  void didUpdateWidget(PildoraNavegacion antes) {
    super.didUpdateWidget(antes);
    // Arrastrando, la cápsula es del dedo; si la pestaña cambió por fuera
    // (un aviso tocado abre el mapa), va a su sitio.
    if (!_arrastrando && antes.indice != widget.indice) {
      _irA(widget.indice);
    }
  }

  @override
  void dispose() {
    _capsula.dispose();
    super.dispose();
  }

  void _irA(int indice, {double velocidad = 0}) {
    if (AppMotion.reducido(context)) {
      _capsula.value = indice.toDouble();
      return;
    }
    // Críticamente amortiguado (sin rebote) y con respuesta de 0,3 s: el
    // dedo ya trajo el impulso, la cápsula no tiene por qué pasarse.
    const respuesta = 0.3;
    final rigidez = math.pow(2 * math.pi / respuesta, 2).toDouble();
    _capsula.animateWith(SpringSimulation(
      SpringDescription.withDampingRatio(mass: 1, stiffness: rigidez),
      _capsula.value,
      indice.toDouble(),
      velocidad,
    ));
  }

  /// La pestaña que cae bajo una x de la píldora.
  int _pestanaEn(double x, double anchoPestana) =>
      ((x - PildoraNavegacion.margen) / anchoPestana).floor().clamp(0, _ultima);

  void _elegir(int indice) {
    if (indice != widget.indice) widget.alElegir(indice);
  }

  void _seguirDedo(double x, double anchoPestana) {
    final valor = ((x - PildoraNavegacion.margen) / anchoPestana - 0.5)
        .clamp(0.0, _ultima.toDouble());
    _capsula.value = valor;
    final bajo = valor.round();
    if (bajo != _bajoDedo) {
      _bajoDedo = bajo;
      // Un paso por pestaña cruzada, como la rueda o el control segmentado
      // de iOS. Tocar una pestaña no vibra: así lo pide la guía de Apple.
      HapticFeedback.selectionClick();
      _elegir(bajo);
    }
  }

  @override
  Widget build(BuildContext context) {
    // El rótulo crece hasta 1,2: la barra de pestañas de iOS tampoco crece
    // con el Texto Dinámico (lo agranda en el gesto largo), y a escala 3 las
    // cuatro no caben en un 390.
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.2,
      child: Container(
        height: PildoraNavegacion.alto,
        decoration: BoxDecoration(
          // Los mismos blanco, filo y sombra que la píldora de búsqueda:
          // las dos flotan sobre el mapa y son la misma familia.
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: AppColors.hairline),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryDeep.withValues(alpha: 0.08),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: LayoutBuilder(builder: (context, caja) {
          final anchoPestana =
              (caja.maxWidth - PildoraNavegacion.margen * 2) / kPestanas.length;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            // Cada pestaña se dice sola, con su toque; el gesto de la barra
            // entera no tiene nada que añadirle al lector.
            excludeFromSemantics: true,
            onTapDown: (d) => setState(
                () => _apretada = _pestanaEn(d.localPosition.dx, anchoPestana)),
            onTapUp: (d) {
              setState(() => _apretada = null);
              _elegir(_pestanaEn(d.localPosition.dx, anchoPestana));
            },
            onTapCancel: () => setState(() => _apretada = null),
            onHorizontalDragStart: (d) {
              setState(() {
                _arrastrando = true;
                _apretada = null;
              });
              _bajoDedo = widget.indice;
              _seguirDedo(d.localPosition.dx, anchoPestana);
            },
            onHorizontalDragUpdate: (d) =>
                _seguirDedo(d.localPosition.dx, anchoPestana),
            onHorizontalDragEnd: (d) {
              setState(() => _arrastrando = false);
              _irA(widget.indice,
                  velocidad: d.velocity.pixelsPerSecond.dx / anchoPestana);
            },
            onHorizontalDragCancel: () {
              setState(() => _arrastrando = false);
              _irA(widget.indice);
            },
            child: Stack(
              children: [
                AnimatedBuilder(
                  animation: _capsula,
                  builder: (context, _) => Positioned(
                    left: PildoraNavegacion.margen +
                        _capsula.value * anchoPestana,
                    top: PildoraNavegacion.margen,
                    bottom: PildoraNavegacion.margen,
                    width: anchoPestana,
                    child: const DecoratedBox(
                      decoration: BoxDecoration(
                        // Verde claro de la marca bajo verde accesible:
                        // 4,94:1, sobre el 4,5 de la norma.
                        color: AppColors.primaryTint,
                        borderRadius:
                            BorderRadius.all(Radius.circular(AppRadius.pill)),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(PildoraNavegacion.margen),
                  child: Row(
                    children: [
                      for (var i = 0; i < kPestanas.length; i++)
                        Expanded(
                          child: _PestanaVista(
                            pestana: kPestanas[i],
                            puesta: i == widget.indice,
                            apretada: i == _apretada,
                            cuenta: i == 1 ? widget.avisosActivos : 0,
                            posicion: i,
                            alTocar: () => _elegir(i),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

class _PestanaVista extends StatelessWidget {
  const _PestanaVista({
    required this.pestana,
    required this.puesta,
    required this.apretada,
    required this.cuenta,
    required this.posicion,
    required this.alTocar,
  });

  final Pestana pestana;
  final bool puesta;
  final bool apretada;
  final int cuenta;
  final int posicion;
  final VoidCallback alTocar;

  @override
  Widget build(BuildContext context) {
    // Verde accesible sobre la cápsula (4,94:1); gris secundario sobre el
    // blanco (5,38:1).
    final color =
        puesta ? AppColors.primaryAccessible : AppColors.textSecondary;
    final cuantos = cuenta == 0
        ? ''
        : cuenta == 1
            ? ', 1 activo'
            : ', $cuenta activos';
    return Semantics(
      container: true,
      button: true,
      selected: puesta,
      inMutuallyExclusiveGroup: true,
      label: '${pestana.rotulo}$cuantos, pestaña ${posicion + 1} de '
          '${kPestanas.length}',
      onTap: alTocar,
      excludeSemantics: true,
      child: AnimatedScale(
        // La respuesta al apretar sale en el instante del toque, no al
        // soltar.
        scale: apretada ? 0.9 : 1,
        duration: AppMotion.duracion(context, AppMotion.instante),
        curve: AppMotion.curvaSalida,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  puesta ? pestana.iconoPuesto : pestana.icono,
                  size: 24,
                  color: color,
                ),
                if (cuenta > 0)
                  Positioned(
                    top: -4,
                    right: -10,
                    child: Container(
                      constraints:
                          const BoxConstraints(minWidth: 18, minHeight: 18),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        // Blanco sobre verde accesible: 5,48:1. El filo
                        // blanco la despega del icono y de la cápsula.
                        color: AppColors.primaryAccessible,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: Text(
                        '$cuenta',
                        style: AppTextStyles.pie.copyWith(
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              pestana.rotulo,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              // La letra chica de la escala: a 12, «Buzón» cabe en su cuarto
              // de píldora aun con el texto a 1,2.
              style: AppTextStyles.pie.copyWith(
                fontWeight: puesta ? FontWeight.w700 : FontWeight.w600,
                letterSpacing: 0,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
