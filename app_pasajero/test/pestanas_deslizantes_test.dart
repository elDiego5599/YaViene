import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_pasajero/core/router/pestanas_deslizantes.dart';

/// Una pantalla que cuenta cuántas veces se montó: si se vuelve a montar al
/// cambiar de pestaña, perdió lo que tenía (el texto del buzón, el mapa).
class _Pagina extends StatefulWidget {
  const _Pagina(this.n, this.montajes);

  final int n;
  final List<int> montajes;

  @override
  State<_Pagina> createState() => _PaginaState();
}

class _PaginaState extends State<_Pagina> {
  @override
  void initState() {
    super.initState();
    widget.montajes.add(widget.n);
  }

  @override
  Widget build(BuildContext context) =>
      SizedBox.expand(key: ValueKey('p${widget.n}'));
}

/// Pasar de pestaña desliza en horizontal (dueño, 2026-10-16): la que llega
/// entra por el lado hacia donde va la barra y la otra sale por el
/// contrario, pegadas, como un carrete.
void main() {
  final montajes = <int>[];
  final paginas = [for (var i = 0; i < 4; i++) _Pagina(i, montajes)];

  Future<void> montar(WidgetTester tester, int indice,
      {bool reducido = false}) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MediaQuery(
      data: MediaQueryData(
          size: const Size(390, 844), disableAnimations: reducido),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: PestanasDeslizantes(indice: indice, children: paginas),
      ),
    ));
  }

  double izquierda(WidgetTester tester, int n) =>
      tester.getTopLeft(find.byKey(ValueKey('p$n'), skipOffstage: false)).dx;

  bool aLaVista(int n) => find.byKey(ValueKey('p$n')).evaluate().isNotEmpty;

  setUp(montajes.clear);

  testWidgets(
      'hacia la derecha: la nueva entra por la derecha y la otra '
      'sale por la izquierda', (tester) async {
    await montar(tester, 0);
    await montar(tester, 1);
    await tester.pump(const Duration(milliseconds: 60));

    expect(izquierda(tester, 1), inExclusiveRange(0, 390));
    // Pegadas: entre las dos no hay hueco ni se pisan.
    expect(izquierda(tester, 0), closeTo(izquierda(tester, 1) - 390, 0.01));

    await tester.pumpAndSettle();
    expect(izquierda(tester, 1), 0);
    expect(aLaVista(0), isFalse);
  });

  testWidgets('hacia la izquierda: entra por la izquierda', (tester) async {
    await montar(tester, 2);
    await montar(tester, 1);
    await tester.pump(const Duration(milliseconds: 60));

    expect(izquierda(tester, 1), inExclusiveRange(-390, 0));
    expect(izquierda(tester, 2), closeTo(izquierda(tester, 1) + 390, 0.01));
    await tester.pumpAndSettle();
    expect(izquierda(tester, 1), 0);
  });

  testWidgets('cambiar a medio camino sigue desde donde va, sin salto',
      (tester) async {
    await montar(tester, 0);
    await montar(tester, 1);
    await tester.pump(const Duration(milliseconds: 60));
    final antes = izquierda(tester, 0);

    // El dedo vuelve a Mapa antes de que Avisos llegue.
    await montar(tester, 0);
    await tester.pump(const Duration(milliseconds: 16));
    expect(izquierda(tester, 0), closeTo(antes, 40));

    await tester.pumpAndSettle();
    expect(izquierda(tester, 0), 0);
  });

  testWidgets('las pantallas siguen vivas al ir y volver', (tester) async {
    await montar(tester, 0);
    await montar(tester, 2);
    await tester.pumpAndSettle();
    await montar(tester, 0);
    await tester.pumpAndSettle();

    expect(montajes, [0, 1, 2, 3]);
  });

  testWidgets('solo la que está puesta recibe el dedo', (tester) async {
    await montar(tester, 0);
    await montar(tester, 1);
    await tester.pump(const Duration(milliseconds: 60));

    final saliente = tester.widget<IgnorePointer>(find
        .ancestor(
            of: find.byKey(const ValueKey('p0')),
            matching: find.byType(IgnorePointer))
        .first);
    expect(saliente.ignoring, isTrue);
  });

  testWidgets('con menos movimiento no se desliza: se funde', (tester) async {
    await montar(tester, 0, reducido: true);
    await montar(tester, 1, reducido: true);
    await tester.pump(const Duration(milliseconds: 60));

    // Las dos en su sitio, una sobre otra, y la de encima a medio fundir.
    expect(izquierda(tester, 0), 0);
    expect(izquierda(tester, 1), 0);
    final opacidades = [
      for (final n in [0, 1])
        tester
            .widget<Opacity>(find
                .ancestor(
                    of: find.byKey(ValueKey('p$n')),
                    matching: find.byType(Opacity))
                .first)
            .opacity
    ];
    expect(opacidades.where((o) => o > 0 && o < 1), hasLength(1));

    await tester.pumpAndSettle();
    expect(aLaVista(0), isFalse);
    expect(izquierda(tester, 1), 0);
  });
}
