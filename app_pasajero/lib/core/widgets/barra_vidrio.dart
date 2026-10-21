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
/// reposo no hay nada; al bajar sale de a poco, al paso del dedo, y al
/// subir se va por el mismo camino (dueño, 2026-10-19: «solo debería salir
/// cuando se baja, suavemente, que no se note mucho»). Antes se prendía de
/// golpe y se veía el salto. Lo de abajo se desenfoca más cuanto más
/// arriba, desde casi nada al pie (con 0,8 de golpe se veía la raya recta
/// entre lo desenfocado y lo nítido), y un velo blanco que tras la hora
/// cubre lo justo para leerla se desvanece hasta nada al pie de la barra.
/// Con más contraste, opaca.
class FondoVidrio extends StatefulWidget {
  const FondoVidrio({super.key});

  /// Los píxeles de desplazamiento en que el vidrio sale entero.
  static const recorrido = 40.0;

  /// Cuatro recortes progresivos: mantiene el difuminado y limita los
  /// filtros costosos que se componen sobre el scroll.
  static const capas = <(double, double)>[
    (1, 0.08),
    (0.82, 0.7),
    (0.64, 2.0),
    (0.46, 7.7),
  ];
  static const cantidadCapas = 4;

  /// El velo, de arriba abajo: 88 % tras la hora, 55 % a media barra y nada
  /// al pie.
  static const velo = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xE0FFFFFF), Color(0x8CFFFFFF), Color(0x00FFFFFF)],
    stops: [0, 0.5, 1],
  );

  static const veloKey = ValueKey('velo-vidrio');

  @override
  State<FondoVidrio> createState() => _FondoVidrioState();
}

class _FondoVidrioState extends State<FondoVidrio> {
  ScrollNotificationObserverState? _observador;

  /// Cuánto salió el vidrio, de 0 en reposo a 1.
  final _progreso = ValueNotifier<double>(0);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // El mismo aviso con que la AppBar sabe que algo le pasa debajo.
    _observador?.removeListener(_alDesplazar);
    _observador = ScrollNotificationObserver.maybeOf(context);
    _observador?.addListener(_alDesplazar);
  }

  @override
  void dispose() {
    _observador?.removeListener(_alDesplazar);
    _progreso.dispose();
    super.dispose();
  }

  void _alDesplazar(ScrollNotification aviso) {
    if (aviso.depth != 0 || aviso.metrics.axis != Axis.vertical) return;
    final t =
        (aviso.metrics.extentBefore / FondoVidrio.recorrido).clamp(0.0, 1.0);
    if (t != _progreso.value) _progreso.value = t;
  }

  @override
  Widget build(BuildContext context) {
    final opaca = MediaQuery.highContrastOf(context);
    return ValueListenableBuilder<double>(
      valueListenable: _progreso,
      builder: (context, t, _) => Stack(
        fit: StackFit.expand,
        children: [
          if (!opaca)
            LayoutBuilder(
              builder: (context, caja) => BackdropGroup(
                child: Stack(
                  children: [
                    for (final (fraccion, sigma) in FondoVidrio.capas)
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        height: caja.maxHeight * fraccion,
                        child: ClipRect(
                          child: BackdropFilter.grouped(
                            enabled: t > 0,
                            filter: ui.ImageFilter.blur(
                                sigmaX: sigma * t, sigmaY: sigma * t),
                            child: const SizedBox.expand(),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          DecoratedBox(
            key: FondoVidrio.veloKey,
            decoration: opaca
                ? BoxDecoration(color: Colors.white.withValues(alpha: t))
                : BoxDecoration(
                    gradient: LinearGradient(
                      begin: FondoVidrio.velo.begin,
                      end: FondoVidrio.velo.end,
                      stops: FondoVidrio.velo.stops,
                      colors: [
                        for (final color in FondoVidrio.velo.colors)
                          color.withValues(alpha: color.a * t),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Un botón de la barra en su píldora de vidrio, como los de iOS 26: lo de
/// detrás desenfocado y saturado, un blanco que lo deja ver, el filo claro
/// donde le da la luz y una sombra que lo despega. Con más contraste, blanco
/// opaco con filo de tinta y sin desenfoque.
class PildoraVidrio extends StatelessWidget {
  const PildoraVidrio({super.key, required this.child, this.compacta = false});

  final Widget child;

  /// Para un texto («Seleccionar», «Cancelar»): la cara mide 36, como las
  /// píldoras de las tarjetas, y el toque sigue en 48 alrededor (dueño,
  /// 2026-10-18: «demasiado grande»). Sin aire por los lados: quien la pone
  /// la alinea con el contenido.
  final bool compacta;

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
    if (compacta) {
      // La cara va detrás del botón, 6 más baja por arriba y por abajo: el
      // toque es de 48 (el mínimo de Android, que cumple los 44 de iOS) y
      // lo que se ve, de 36.
      return Center(
        widthFactor: 1,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
                top: 6, bottom: 6, child: _vidrio(context, const SizedBox())),
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              child: Center(widthFactor: 1, heightFactor: 1, child: child),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Center(
        widthFactor: 1,
        child: _vidrio(
          context,
          ConstrainedBox(
            // 48: el mínimo tocable de Android, que también cumple los 44 de
            // iOS.
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            child: Center(widthFactor: 1, heightFactor: 1, child: child),
          ),
        ),
      ),
    );
  }

  /// La sombra, el desenfoque y la cara alrededor de [contenido].
  Widget _vidrio(BuildContext context, Widget contenido) {
    final opaca = MediaQuery.highContrastOf(context);
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
      child: contenido,
    );
    return DecoratedBox(
      decoration: const BoxDecoration(borderRadius: _forma, boxShadow: sombra),
      // Recortada a la píldora: sin el recorte, el desenfoque se come toda
      // la pantalla.
      child: opaca
          ? cara
          : ClipRRect(
              borderRadius: _forma,
              child: BackdropFilter.grouped(
                filter: ui.ImageFilter.compose(
                  outer: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  inner: _saturar,
                ),
                child: cara,
              ),
            ),
    );
  }
}
