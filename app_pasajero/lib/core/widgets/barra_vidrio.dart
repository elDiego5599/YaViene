import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ya_viene_core/ya_viene_core.dart';

/// La barra del título de Avisos, Buzón, Info y lo legal, como la de iOS 26
/// (dueño, 2026-10-18, con WhatsApp de referencia: «el título y los íconos,
/// pero se puede ver perfectamente el texto cuando bajo»). Sin lámina: el
/// título flota sobre lo que pasa debajo y los botones van en
/// [PildoraVidrio]. Quien la use pone `extendBodyBehindAppBar` en su
/// `Scaffold` y suma arriba `MediaQuery.paddingOf(context).top` a lo que se
/// desplaza: en reposo nada queda debajo.
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
      // Un halo blanco apenas: el título se lee entero aunque pase texto
      // detrás, como en iOS, sin tapar lo de abajo.
      title: DefaultTextStyle.merge(
        style: const TextStyle(shadows: halo),
        child: title,
      ),
      leading: leading,
      // 64: la píldora de 48 más sus 6 de aire por lado; en los 56 de
      // fábrica la flecha quedaba de 44 de ancho, bajo el mínimo tocable.
      leadingWidth: leadingWidth ?? 64,
      actions: actions,
      automaticallyImplyLeading: automaticallyImplyLeading,
      toolbarHeight: toolbarHeight,
    );

/// El halo del título sobre lo que pasa debajo.
const halo = [
  Shadow(color: Color(0xE6FFFFFF), blurRadius: 6),
  Shadow(color: Color(0xB3FFFFFF), blurRadius: 14),
];

/// La cara de [barraVidrio]: el borde de desplazamiento de iOS 26. En
/// reposo no se ve; con algo debajo, un velo blanco que arriba, tras la
/// hora, cubre lo justo para leerla y se desvanece hasta nada al pie de la
/// barra: lo de abajo se sigue leyendo. Con más contraste, opaca.
class FondoVidrio extends StatefulWidget {
  const FondoVidrio({super.key});

  /// El velo, de arriba abajo: 88 % tras la hora, 55 % a media barra y nada
  /// al pie.
  static const velo = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xE0FFFFFF), Color(0x8CFFFFFF), Color(0x00FFFFFF)],
    stops: [0, 0.5, 1],
  );

  @override
  State<FondoVidrio> createState() => _FondoVidrioState();
}

class _FondoVidrioState extends State<FondoVidrio> {
  ScrollNotificationObserverState? _observador;
  bool _debajo = false;

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
    return AnimatedOpacity(
      opacity: _debajo ? 1 : 0,
      duration: AppMotion.duracion(context, AppMotion.normal),
      curve: Curves.easeOut,
      child: DecoratedBox(
        decoration: MediaQuery.highContrastOf(context)
            ? const BoxDecoration(color: Colors.white)
            : const BoxDecoration(gradient: FondoVidrio.velo),
      ),
    );
  }
}

/// Un botón de la barra en su píldora de vidrio, como los de iOS 26: lo de
/// detrás desenfocado y saturado, un blanco que lo deja ver, el filo claro
/// donde le da la luz y una sombra que lo despega. Con más contraste, blanco
/// opaco con filo de tinta y sin desenfoque.
class PildoraVidrio extends StatelessWidget {
  const PildoraVidrio({super.key, required this.child});

  final Widget child;

  static const caraKey = ValueKey('pildora-vidrio');

  static const sombra = [
    BoxShadow(color: Color(0x1F0B1220), offset: Offset(0, 4), blurRadius: 14),
    BoxShadow(color: Color(0x0F0B1220), offset: Offset(0, 1), blurRadius: 2),
  ];

  /// `saturate(1.8)`: la matriz de saturación de la especificación de
  /// filtros, con sus pesos de luminancia.
  static const _s = 1.8, _r = 0.2126, _g = 0.7152, _b = 0.0722;
  static const _saturar = ColorFilter.matrix([
    _r + (1 - _r) * _s, _g - _g * _s, _b - _b * _s, 0, 0, //
    _r - _r * _s, _g + (1 - _g) * _s, _b - _b * _s, 0, 0, //
    _r - _r * _s, _g - _g * _s, _b + (1 - _b) * _s, 0, 0, //
    0, 0, 0, 1, 0,
  ]);

  static const _forma = BorderRadius.all(Radius.circular(AppRadius.pill));

  @override
  Widget build(BuildContext context) {
    final opaca = MediaQuery.highContrastOf(context);
    final boton = ConstrainedBox(
      // 48: el mínimo tocable de Android, que también cumple los 44 de iOS.
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      child: Center(widthFactor: 1, heightFactor: 1, child: child),
    );
    final cara = DecoratedBox(
      key: caraKey,
      decoration: BoxDecoration(
        color: opaca ? Colors.white : const Color(0xB8FFFFFF),
        borderRadius: _forma,
        border: Border.all(
          color: opaca ? AppColors.ink : const Color(0xE6FFFFFF),
          width: opaca ? 1 : 0.8,
        ),
      ),
      child: boton,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Center(
        widthFactor: 1,
        child: DecoratedBox(
          decoration:
              const BoxDecoration(borderRadius: _forma, boxShadow: sombra),
          // Recortada a la píldora: sin el recorte, el desenfoque se come
          // toda la pantalla.
          child: opaca
              ? cara
              : ClipRRect(
                  borderRadius: _forma,
                  child: BackdropFilter(
                    filter: ui.ImageFilter.compose(
                      outer: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      inner: _saturar,
                    ),
                    child: cara,
                  ),
                ),
        ),
      ),
    );
  }
}
