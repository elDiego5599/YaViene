import 'package:flutter/material.dart';
import 'package:ya_viene_core/ya_viene_core.dart';

/// Envuelve un hijo para que entre en el instante que se le pida, medido en
/// fracciones de la duración total del grupo.
typedef Entrada = Widget Function(
  Widget child, {
  double start,
  Offset begin,
});

/// Entrada de pantalla: un solo controlador para todo el grupo.
///
/// El desfase entre elementos se expresa como `Interval` sobre el mismo
/// reloj, no como un controlador por elemento: diez elementos cuestan un
/// ticker, no diez. Es el mismo patrón que ya usa el panel lateral.
///
/// El deslizamiento pasa por [AppMotion], así que con «quitar animaciones»
/// puesto los elementos aparecen con fundido y sin moverse.
class ScreenEntrance extends StatefulWidget {
  const ScreenEntrance({
    super.key,
    required this.builder,
    this.duration = const Duration(milliseconds: 700),
  });

  /// Cuánto dura el grupo entero, del primer elemento al último.
  final Duration duration;

  final Widget Function(BuildContext context, Entrada entra) builder;

  @override
  State<ScreenEntrance> createState() => _ScreenEntranceState();
}

class _ScreenEntranceState extends State<ScreenEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  /// Una curva por instante de arranque, memorizada.
  ///
  /// `_entra` se llama desde `build`, así que sin memorizar se crearía una
  /// `CurvedAnimation` nueva por elemento y por construcción, y cada una se
  /// engancha como oyente del controlador sin soltarse.
  final Map<double, CurvedAnimation> _curvas = {};

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..forward();
  }

  @override
  void dispose() {
    for (final curva in _curvas.values) {
      curva.dispose();
    }
    _curvas.clear();
    _controller.dispose();
    super.dispose();
  }

  CurvedAnimation _curva(double start) {
    // El arranque se topa en 0.8 para que a cada elemento le quede un tramo
    // real por delante: un `Interval` con principio y fin iguales divide
    // entre cero al evaluarse.
    final inicio = start.clamp(0.0, 0.8);
    return _curvas.putIfAbsent(
      inicio,
      () => CurvedAnimation(
        parent: _controller,
        curve: Interval(
          inicio,
          (inicio + 0.55).clamp(0.0, 1.0),
          curve: AppMotion.curvaEntrada,
        ),
      ),
    );
  }

  Widget _entra(
    Widget child, {
    double start = 0,
    Offset begin = const Offset(0, 0.12),
  }) {
    final curva = _curva(start);
    return FadeTransition(
      opacity: curva,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: begin * AppMotion.desplazamiento(context),
          end: Offset.zero,
        ).animate(curva),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _entra);
}
