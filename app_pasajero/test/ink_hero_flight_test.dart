import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ya_viene_pasajero/core/widgets/ink_hero.dart';

GoRouter _router() => GoRouter(
      initialLocation: '/a',
      routes: [
        GoRoute(
          path: '/a',
          builder: (context, state) => Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const InkHero(),
                  TextButton(
                    onPressed: () => context.replace('/b'),
                    child: const Text('ir'),
                  ),
                ],
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/b',
          builder: (context, state) => const Scaffold(
            body: Align(alignment: Alignment.topCenter, child: InkHero()),
          ),
        ),
      ],
    );

void main() {
  testWidgets('el logo vuela entre pantallas en vez de saltar', (tester) async {
    await tester.pumpWidget(MaterialApp.router(routerConfig: _router()));
    await tester.pumpAndSettle();

    final logoEnSuSitio = find.descendant(
      of: find.byType(InkHero),
      matching: find.byType(SvgPicture),
    );
    expect(logoEnSuSitio, findsOneWidget);

    await tester.tap(find.text('ir'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));

    // A mitad de camino las dos pantallas están montadas, pero el logo no
    // está en ninguna de las dos: `Hero` lo sacó a la capa superpuesta para
    // llevarlo de un sitio al otro. Si no hubiera vuelo, habría dos.
    expect(find.byType(InkHero), findsNWidgets(2));
    expect(logoEnSuSitio, findsNothing);

    await tester.pumpAndSettle();
    expect(logoEnSuSitio, findsOneWidget);
  });
}
