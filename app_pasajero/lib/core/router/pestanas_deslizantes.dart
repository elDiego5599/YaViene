import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';
import 'package:ya_viene_core/ya_viene_core.dart';

import '../widgets/pildora_navegacion.dart';

/// Las pantallas de las pestañas, en fila como un carrete: pasar de una a
/// otra las desliza en horizontal (dueño, 2026-10-16), la nueva por el lado
/// hacia donde va la cápsula y la vieja por el contrario.
///
/// Ocupa el sitio del `IndexedStack` de go_router y guarda lo mismo que él:
/// todas montadas siempre, en el mismo orden, para que ninguna se vuelva a
/// montar al cambiar (el mapa no se recarga, el buzón no pierde lo escrito);
/// las que no se ven, fuera de escena y con sus relojes parados.
///
/// La fila se mueve con el resorte de la cápsula, retomado desde donde va y
/// con la velocidad que lleva: arrastrando por la píldora, cada pestaña que
/// cruza el dedo redirige el carrete sin frenazos ni saltos, y pantalla y
/// cápsula llegan juntas. Con «Reducir movimiento» no se desliza nada: la
/// de encima se funde, que es lo que hace iOS.
class PestanasDeslizantes extends StatefulWidget {
  const PestanasDeslizantes({
    super.key,
    required this.indice,
    required this.children,
  });

  /// La pestaña puesta.
  final int indice;

  /// Una pantalla por pestaña, en el orden de la píldora.
  final List<Widget> children;

  @override
  State<PestanasDeslizantes> createState() => _PestanasDeslizantesState();
}

class _PestanasDeslizantesState extends State<PestanasDeslizantes>
    with TickerProviderStateMixin {
  /// Dónde va la fila, en pestañas: 1,5 es media Avisos y medio Buzón.
  late final AnimationController _posicion = AnimationController.unbounded(
    vsync: this,
    value: widget.indice.toDouble(),
  );

  /// El fundido de «Reducir movimiento»: 1 es la nueva del todo.
  late final AnimationController _fundido = AnimationController(
    vsync: this,
    duration: AppMotion.rapido,
    value: 1,
  );

  /// La que se va mientras dura el fundido.
  int? _saliente;

  @override
  void didUpdateWidget(PestanasDeslizantes antes) {
    super.didUpdateWidget(antes);
    if (antes.indice == widget.indice) return;
    final destino = widget.indice.toDouble();
    if (AppMotion.reducido(context)) {
      _posicion.value = destino;
      _saliente = antes.indice;
      _fundido.forward(from: 0);
      return;
    }
    _saliente = null;
    _fundido.value = 1;
    _posicion.animateWith(SpringSimulation(
      PildoraNavegacion.resorte,
      _posicion.value,
      destino,
      _posicion.velocity,
      snapToEnd: true,
    ));
  }

  @override
  void dispose() {
    _posicion.dispose();
    _fundido.dispose();
    super.dispose();
  }

  /// Cuánto se ve de la pestaña [i] en el fundido: la de encima en la pila
  /// (la de índice mayor) es la que se aclara o se apaga; la de debajo
  /// queda entera, para que en ningún cuadro se transparenten las dos.
  double _opacidad(int i) {
    final saliente = _saliente;
    if (saliente == null || _fundido.isCompleted) return 1;
    if (i == widget.indice && i > saliente) return _fundido.value;
    if (i == saliente && i > widget.indice) return 1 - _fundido.value;
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_posicion, _fundido]),
      builder: (context, _) {
        final posicion = _posicion.value;
        final fundiendo = _saliente != null && !_fundido.isCompleted;
        return ColoredBox(
          // Detrás, el blanco de las pantallas: una pestaña que aún no se
          // abrió nunca está vacía, y a su paso se ve blanco y no negro.
          color: AppColors.surface,
          child: Stack(
            fit: StackFit.expand,
            children: [
              for (final (i, pantalla) in widget.children.indexed)
                _pagina(
                  pantalla,
                  // La que se funde se apaga en su sitio.
                  desfase: fundiendo && i == _saliente ? 0 : i - posicion,
                  enEscena:
                      (i - posicion).abs() < 1 || (fundiendo && i == _saliente),
                  puesta: i == widget.indice,
                  opacidad: _opacidad(i),
                ),
            ],
          ),
        );
      },
    );
  }

  // Siempre los mismos envoltorios, en el mismo orden, cambie lo que cambie:
  // así ninguna pantalla se desmonta por quedar fuera de escena.
  Widget _pagina(
    Widget pantalla, {
    required double desfase,
    required bool enEscena,
    required bool puesta,
    required double opacidad,
  }) {
    return Offstage(
      offstage: !enEscena,
      child: TickerMode(
        enabled: enEscena,
        child: IgnorePointer(
          ignoring: !puesta,
          child: ExcludeSemantics(
            excluding: !puesta,
            child: FractionalTranslation(
              translation: Offset(desfase, 0),
              child: Opacity(opacity: opacidad, child: pantalla),
            ),
          ),
        ),
      ),
    );
  }
}
