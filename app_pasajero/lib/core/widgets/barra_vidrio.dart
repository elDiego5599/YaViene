import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ya_viene_core/ya_viene_core.dart';

/// La barra del título de Avisos, Buzón, Info y lo legal, como el nav de la
/// web (dueño, 2026-10-18: «que se pueda ver el texto a través de él cuando
/// uno baja, excepto obviamente el título»). Quien la use pone
/// `extendBodyBehindAppBar` en su `Scaffold` y suma arriba
/// `MediaQuery.paddingOf(context).top` a lo que se desplaza: en reposo nada
/// queda debajo.
AppBar barraVidrio({
  required Widget title,
  Widget? leading,
  double? leadingWidth,
  List<Widget>? actions,
  bool automaticallyImplyLeading = true,
  double? toolbarHeight,
}) =>
    AppBar(
      // La cara la pinta [FondoVidrio]; la de la barra queda transparente y
      // sin la sombra de Material al pasarle algo debajo.
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      // Con la barra transparente Flutter calcula la hora en blanco: va en
      // oscuro, sobre lo blanco.
      systemOverlayStyle: SystemUiOverlayStyle.dark,
      centerTitle: true,
      flexibleSpace: const FondoVidrio(),
      title: title,
      leading: leading,
      leadingWidth: leadingWidth,
      actions: actions,
      automaticallyImplyLeading: automaticallyImplyLeading,
      toolbarHeight: toolbarHeight,
    );

/// La cara de [barraVidrio]: la de `.nav` en `YaVieneWeb`
/// (`componentes/nav.css`). En reposo no se ve; con algo debajo, blanco al
/// 82 % sobre lo de abajo saturado ×1,6 y desenfocado 12, con un filo de
/// 1 px y una sombra que apenas cae. Con más contraste, opaca y sin
/// desenfoque, como `accesibilidad.css` en la web.
class FondoVidrio extends StatefulWidget {
  const FondoVidrio({super.key});

  /// El filo de abajo y la sombra suave: `0 1px 0 rgba(11,18,32,.06)` y
  /// `0 8px 24px -16px rgba(11,18,32,.18)` del nav.
  static const sombra = [
    BoxShadow(color: Color(0x0F0B1220), offset: Offset(0, 1)),
    BoxShadow(
      color: Color(0x2E0B1220),
      offset: Offset(0, 8),
      blurRadius: 24,
      spreadRadius: -16,
    ),
  ];

  @override
  State<FondoVidrio> createState() => _FondoVidrioState();
}

class _FondoVidrioState extends State<FondoVidrio> {
  ScrollNotificationObserverState? _observador;
  bool _debajo = false;

  /// `saturate(1.6)` de CSS: la matriz de saturación de la especificación
  /// de filtros, con sus pesos de luminancia.
  static const _s = 1.6, _r = 0.2126, _g = 0.7152, _b = 0.0722;
  static const _saturar = ColorFilter.matrix([
    _r + (1 - _r) * _s, _g - _g * _s, _b - _b * _s, 0, 0, //
    _r - _r * _s, _g + (1 - _g) * _s, _b - _b * _s, 0, 0, //
    _r - _r * _s, _g - _g * _s, _b + (1 - _b) * _s, 0, 0, //
    0, 0, 0, 1, 0,
  ]);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // El mismo aviso que usa `AppBar` para saber si hay algo debajo.
    _observador?.removeListener(_alDesplazar);
    _observador = ScrollNotificationObserver.maybeOf(context);
    _observador?.addListener(_alDesplazar);
  }

  @override
  void dispose() {
    _observador?.removeListener(_alDesplazar);
    super.dispose();
  }

  void _alDesplazar(ScrollNotification aviso) {
    if (aviso is! ScrollUpdateNotification ||
        !defaultScrollNotificationPredicate(aviso)) {
      return;
    }
    final m = aviso.metrics;
    final debajo = switch (m.axisDirection) {
      AxisDirection.up => m.extentAfter > 0,
      AxisDirection.down => m.extentBefore > 0,
      _ => _debajo,
    };
    if (debajo != _debajo) setState(() => _debajo = debajo);
  }

  @override
  Widget build(BuildContext context) {
    final opaca = MediaQuery.highContrastOf(context);
    final cara = AnimatedContainer(
      duration: AppMotion.duracion(context, AppMotion.normal),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: !_debajo
            ? Colors.white.withValues(alpha: 0)
            : opaca
                ? Colors.white
                : Colors.white.withValues(alpha: 0.82),
        boxShadow: _debajo ? FondoVidrio.sombra : const [],
      ),
    );
    if (opaca) return cara;
    // Recortado a la barra: sin el recorte, el desenfoque se come toda la
    // pantalla.
    return ClipRect(
      child: BackdropFilter(
        enabled: _debajo,
        filter: ui.ImageFilter.compose(
          outer: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          inner: _saturar,
        ),
        child: cara,
      ),
    );
  }
}
