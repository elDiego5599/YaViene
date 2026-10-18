import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/map_view_state.dart';
import 'package:ya_viene_pasajero/features/map/presentation/widgets/search_pill_bar.dart';

void main() {
  Future<ProviderContainer> montarPill(WidgetTester tester) async {
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
    return container;
  }

  // El subtítulo vuelve (dueño, 2026-10-16): pregunta y subtítulo
  // centrados, uno sobre otro.
  testWidgets('sin ruta dice la pregunta y su subtítulo, centrados',
      (tester) async {
    await montarPill(tester);

    final pill = tester.getRect(find.byType(SearchPillBar));
    final titulo = tester.getRect(find.text('¿Qué bus esperas?'));
    final sub = tester.getRect(find.text('Toca para buscar tu ruta'));
    expect((titulo.center.dx - pill.center.dx).abs(), lessThan(2));
    expect((sub.center.dx - pill.center.dx).abs(), lessThan(2));
    expect(sub.top, greaterThanOrEqualTo(titulo.bottom));
  });

  testWidgets('la lupa va en la punta derecha de la píldora', (tester) async {
    // Dueño, 2026-10-16: «la lupa de la pill del inicio colócala en la punta
    // derecha»; en el hueco de 48 donde con ruta va la X.
    await montarPill(tester);

    expect(find.byIcon(Icons.tune_outlined), findsNothing);
    final pill = tester.getRect(find.byType(SearchPillBar));
    final hueco = tester.getRect(find.byKey(const ValueKey('pill-lupa')));
    final lupa = tester.getRect(find.byIcon(Icons.search_rounded));
    // 20 de margen, 8 de relleno y 1 de filo: lo último de la píldora.
    expect(hueco.right, pill.right - 20 - 8 - 1);
    expect(hueco.width, 48);
    expect(lupa.center.dx, closeTo(hueco.center.dx, 0.5));
    expect((lupa.center.dy - pill.center.dy).abs(), lessThan(2));
  });

  // Dueño, 2026-10-18: «del lado izquierdo en la pill de arriba podemos
  // poner el logito de la app para no dejar ese espacio vacío». El mismo
  // archivo del logo, sin tocarlo, concéntrico con la punta redonda de la
  // píldora: su centro queda a medio alto del filo izquierdo.
  testWidgets('el logo llena la punta izquierda, concéntrico con ella',
      (tester) async {
    final handle = tester.ensureSemantics();
    await montarPill(tester);

    // La píldora es la primera caja decorada: su fondo blanco con filo.
    final pill = tester.getRect(find
        .descendant(
            of: find.byType(SearchPillBar), matching: find.byType(DecoratedBox))
        .first);
    expect(pill.height, 60);
    final logo = find.byKey(const ValueKey('pill-logo'));
    expect(logo, findsOneWidget);
    final r = tester.getRect(logo);
    expect(r.width, r.height);
    expect(r.center.dy, closeTo(pill.center.dy, 0.5));
    expect(r.center.dx - pill.left, closeTo(pill.height / 2, 0.5));
    // El aire alrededor del logo, el mismo arriba, abajo y a la izquierda.
    expect(r.left - pill.left, closeTo(r.top - pill.top, 0.5));
    expect(r.top - pill.top, greaterThanOrEqualTo(10));
    // El nombre ya lo dice el botón: el logo no se anuncia aparte.
    expect(
        find.descendant(
            of: find.byType(SearchPillBar),
            matching: find.bySemanticsLabel(RegExp('[Ll]ogo|[Ii]magen'))),
        findsNothing);
    handle.dispose();
  });

  testWidgets('tocar la lupa también abre la búsqueda', (tester) async {
    final container = await montarPill(tester);
    final abierta = <bool>[];
    container.listen(routeSelectorOpenProvider, (_, v) => abierta.add(v));

    await tester.tap(find.byKey(const ValueKey('pill-lupa')));
    await tester.pump();
    expect(abierta, contains(true));
  });

  testWidgets('la zona de búsqueda se anuncia como botón', (tester) async {
    final handle = tester.ensureSemantics();
    await montarPill(tester);

    expect(find.bySemanticsLabel('¿Qué bus esperas? Toca para buscar tu ruta'),
        findsOneWidget);
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
    // sí; en la punta derecha, la X ocupa el sitio de la lupa.
    final nombre = tester.getRect(find.text('Ruta 106'));
    expect((etiqueta.center.dx - nombre.center.dx).abs(), lessThan(1));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('pill-lupa')), findsNothing);
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
