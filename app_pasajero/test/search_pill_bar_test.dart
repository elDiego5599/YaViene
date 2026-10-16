import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import 'package:ya_viene_pasajero/features/map/presentation/widgets/search_pill_bar.dart';

void main() {
  testWidgets('el texto de la pill queda centrado', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    // autoDispose: mantener vivo selectedRouteProvider con un listener.
    container.listen(selectedRouteProvider, (_, __) {});

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topCenter,
              child: SearchPillBar(),
            ),
          ),
        ),
      ),
    );

    final pill = tester.getRect(find.byType(SearchPillBar));
    final title = tester.getRect(find.text('¿Qué bus esperas?'));
    final subtitle = tester.getRect(find.text('Toca para buscar tu ruta'));
    // Las dos líneas, centradas entre sí; el bloque con su lupa, en la
    // píldora (la prueba de abajo).
    expect((title.center.dx - subtitle.center.dx).abs(), lessThan(2));
    expect((title.center.dx - pill.center.dx).abs(), lessThan(24));
    expect((title.center.dy - subtitle.center.dy).abs(), greaterThan(10));
  });

  testWidgets('la lupa va pegada a la derecha del texto y el bloque, centrado',
      (tester) async {
    // Dueño, 2026-10-16: la lupa junto al texto, a su derecha, y los dos
    // centrados en la píldora; el botón de filtros de la derecha sobraba.
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.listen(selectedRouteProvider, (_, __) {});

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topCenter,
              child: SearchPillBar(),
            ),
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.tune_outlined), findsNothing);
    expect(find.byKey(const ValueKey('pill-filtro')), findsNothing);
    final pill = tester.getRect(find.byType(SearchPillBar));
    final lupa = tester.getRect(find.byIcon(Icons.search_rounded));
    final titulo = tester.getRect(find.text('¿Qué bus esperas?'));
    final pie = tester.getRect(find.text('Toca para buscar tu ruta'));
    final textoDerecha = titulo.right > pie.right ? titulo.right : pie.right;
    final textoIzquierda = titulo.left < pie.left ? titulo.left : pie.left;
    expect(lupa.left, greaterThanOrEqualTo(textoDerecha));
    expect(lupa.left - textoDerecha, lessThanOrEqualTo(AppSpacing.sm + 1));
    expect((lupa.center.dy - pill.center.dy).abs(), lessThan(2));
    final centroBloque = (textoIzquierda + lupa.right) / 2;
    expect((centroBloque - pill.center.dx).abs(), lessThan(2));
  });

  testWidgets('la zona de búsqueda se anuncia como botón', (tester) async {
    final handle = tester.ensureSemantics();
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.listen(selectedRouteProvider, (_, __) {});

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topCenter,
              child: SearchPillBar(),
            ),
          ),
        ),
      ),
    );

    // Los dos botones de los lados ya se anunciaban; la mitad central —que
    // es la que abre el selector— no decía nada.
    expect(
      find.bySemanticsLabel('¿Qué bus esperas? Toca para buscar tu ruta'),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('con ruta elegida, arriba dice «Ruta activa» y debajo la ruta',
      (tester) async {
    final handle = tester.ensureSemantics();
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.listen(selectedRouteProvider, (_, __) {});
    container.read(selectedRouteProvider.notifier).select(
          const RouteInfo(
            id: 'R-106',
            name: 'Ruta 106',
            companyId: 'EMP-01',
          ),
        );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topCenter,
              child: SearchPillBar(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // El dueño lo pidió así: la etiqueta encima, el nombre debajo, y sin el
    // «Toca para cambiar», que ya sobraba en una píldora que todo el mundo
    // sabe que se toca.
    final etiqueta = tester.getRect(find.text('Ruta activa'));
    final nombre = tester.getRect(find.text('Ruta 106'));
    expect(etiqueta.center.dy, lessThan(nombre.center.dy));
    expect(find.textContaining('Toca para cambiar'), findsNothing);
    expect(find.bySemanticsLabel('Ruta activa: Ruta 106'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('«Ruta activa» va sola, sin punto delante', (tester) async {
    // Decisión del dueño (2026-09-27): el punto verde a la izquierda
    // sobraba; el verde de la etiqueta ya dice que hay ruta puesta.
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.listen(selectedRouteProvider, (_, __) {});
    container.read(selectedRouteProvider.notifier).select(
          const RouteInfo(id: 'R-106', name: 'Ruta 106', companyId: 'EMP-01'),
        );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topCenter,
              child: SearchPillBar(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final etiqueta = tester.getRect(find.text('Ruta activa'));
    final puntos = find.descendant(
      of: find.byType(SearchPillBar),
      matching: find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration! as BoxDecoration).shape == BoxShape.circle,
      ),
    );
    for (final punto in puntos.evaluate()) {
      final r = tester.getRect(find.byWidget(punto.widget));
      // Los botones de los lados también son círculos, de 48: el punto
      // era de 6. Se mira solo lo que es del tamaño de un punto.
      if (r.width > 12) continue;
      expect(r.bottom <= etiqueta.top || r.top >= etiqueta.bottom, isTrue,
          reason: 'hay un círculo en la línea de «Ruta activa»: $r');
    }
    // Sin nada a la izquierda: la etiqueta y el nombre van centrados entre
    // sí, y la lupa a su derecha.
    final nombre = tester.getRect(find.text('Ruta 106'));
    expect((etiqueta.center.dx - nombre.center.dx).abs(), lessThan(1));
    expect(tester.getRect(find.byIcon(Icons.search_rounded)).left,
        greaterThanOrEqualTo(nombre.right));
  });

  group('«Ruta activa» con destello', () {
    Future<void> montar(WidgetTester tester, {bool reducido = false}) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.listen(selectedRouteProvider, (_, __) {});
      container.read(selectedRouteProvider.notifier).select(
            const RouteInfo(id: 'R-106', name: 'Ruta 106', companyId: 'EMP-01'),
          );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(disableAnimations: reducido),
              child: const Scaffold(
                body: Align(
                  alignment: Alignment.topCenter,
                  child: SearchPillBar(),
                ),
              ),
            ),
          ),
        ),
      );
    }

    Finder mascara() => find.ancestor(
          of: find.text('Ruta activa'),
          matching: find.byType(ShaderMask),
        );

    testWidgets('la luz cruza, descansa sin pintar cuadros y vuelve',
        (tester) async {
      const pasada = EtiquetaRutaActiva.pasadaDura;
      const pausa = EtiquetaRutaActiva.pausa;
      await montar(tester);
      expect(mascara(), findsOneWidget, reason: 'la etiqueta no brilla');
      await tester.pump(pasada ~/ 2);
      expect(tester.binding.hasScheduledFrame, isTrue,
          reason: 'a mitad de la pasada la luz sigue moviéndose');
      await tester.pump(pasada ~/ 2 + const Duration(milliseconds: 50));
      await tester.pump(pausa ~/ 2);
      // Descansando no hay cuadros pendientes: el mapa no se recompone.
      expect(tester.binding.hasScheduledFrame, isFalse);
      await tester.pump(pausa ~/ 2 + pasada ~/ 4);
      expect(tester.binding.hasScheduledFrame, isTrue,
          reason: 'tras el descanso la luz vuelve a cruzar');
    });

    testWidgets('con el movimiento reducido se queda quieta', (tester) async {
      await montar(tester, reducido: true);
      await tester.pump(const Duration(milliseconds: 1000));
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(find.text('Ruta activa'), findsOneWidget);
    });
  });

  // ACC-01: la píldora cambiaba de texto al elegir o quitar la ruta, pero
  // el lector de pantalla solo lo decía si el foco pasaba por ella. Quien
  // elige la ruta en el selector y vuelve al mapa no se enteraba.
  testWidgets('al elegir o quitar la ruta, el lector lo anuncia una vez',
      (tester) async {
    final anuncios = <String>[];
    tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<dynamic>(
      SystemChannels.accessibility,
      (mensaje) async {
        final mapa = mensaje as Map<Object?, Object?>;
        if (mapa['type'] == 'announce') {
          anuncios.add(
              (mapa['data']! as Map<Object?, Object?>)['message']! as String);
        }
      },
    );
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockDecodedMessageHandler<dynamic>(
            SystemChannels.accessibility, null));

    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.listen(selectedRouteProvider, (_, __) {});
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topCenter,
              child: SearchPillBar(),
            ),
          ),
        ),
      ),
    );
    expect(anuncios, isEmpty, reason: 'abrir el mapa no anuncia nada');

    const ruta = RouteInfo(id: 'R-106', name: 'Ruta 106', companyId: 'EMP-01');
    container.read(selectedRouteProvider.notifier).select(ruta);
    await tester.pumpAndSettle();
    expect(anuncios, ['Ruta activa: Ruta 106']);

    // La misma ruta otra vez no es un cambio: no se repite. Una copia nueva
    // (lo que llega al recargar el catálogo), no la misma instancia: con
    // `ruta` el proveedor ni avisa y la guarda por id no se probaría.
    final otraVez =
        RouteInfo(id: ruta.id, name: ruta.name, companyId: ruta.companyId);
    expect(identical(otraVez, ruta), isFalse);
    container.read(selectedRouteProvider.notifier).select(otraVez);
    await tester.pumpAndSettle();
    expect(anuncios, hasLength(1));

    container.read(selectedRouteProvider.notifier).clear();
    await tester.pumpAndSettle();
    expect(anuncios, ['Ruta activa: Ruta 106', 'Sin ruta activa']);
  });
}
