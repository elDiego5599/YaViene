import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import 'package:ya_viene_pasajero/core/utils/distancia.dart';
import 'package:ya_viene_pasajero/core/widgets/dialogo.dart';
import 'package:ya_viene_pasajero/core/widgets/placa_bus.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/tracking_providers.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/user_location_provider.dart';
import 'package:ya_viene_pasajero/features/notifications/presentation/providers/alert_history_provider.dart';
import 'package:ya_viene_pasajero/features/notifications/presentation/providers/proximity_alerts_provider.dart';
import 'package:ya_viene_pasajero/features/notifications/presentation/screens/notifications_screen.dart';
import 'helpers/borde.dart';

class _TestUserLocation extends UserLocationNotifier {
  void set(UserLocationState state) => this.state = state;
}

void main() {
  const userLat = 6.2442;
  const userLon = -75.5812;

  BusPosition bus(String id, {double lat = userLat}) => BusPosition(
        busId: id,
        routeId: 'R1',
        lat: lat,
        lon: userLon,
        heading: 0,
        speedKmh: 30,
        timestamp: DateTime.now(),
        isGhostBus: false,
      );

  RouteInfo routeR1() => const RouteInfo(
        id: 'R1',
        name: 'Ruta 1',
        companyId: 'C1',
      );

  /// Los fondos de las pantallas son blancos y lo blanco que va encima se
  /// despega con sombra (dueño, 2026-10-16). La barra de arriba, del mismo
  /// blanco: si no, se lee como una franja de otro papel.
  void exigeFondoBlanco(WidgetTester tester) {
    expect(tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
        AppColors.surface,
        reason: 'el fondo de Avisos');
    expect(tester.widget<AppBar>(find.byType(AppBar)).backgroundColor,
        AppColors.surface,
        reason: 'la barra de Avisos');
  }

  Future<ProviderContainer> pumpScreen(
      WidgetTester tester, List<BusPosition> buses,
      {List<GeoPoint>? ruta, double lat = userLat}) async {
    final container = ProviderContainer(overrides: [
      userLocationProvider.overrideWith((ref) => _TestUserLocation()),
      if (ruta != null)
        routeTrajectoryProvider.overrideWith(
          (ref, routeId) => RouteTrajectory(
              routeId: routeId, routeName: 'Ruta 1', points: ruta),
        ),
      busPositionsSourceProvider.overrideWith(
        (ref, routeId) => Stream.value(buses),
      ),
      // La notificación de verdad no se puede pintar en un test (el plugin
      // no tiene canal), y desde que `notifyBusNear` devuelve si de verdad
      // se mostró, el fallo dejaría el aviso sin marcar. Aquí se mide el
      // camino en que el aviso sí salió: se sustituye por uno que responde
      // que sí.
      proximityAlertsProvider.overrideWith(
        (ref) => ProximityAlertsNotifier(ref,
            notify: ({
              required String busId,
              String? routeName,
              String? routeId,
              required int distanceMeters,
            }) async =>
                true),
      ),
    ]);
    addTearDown(container.dispose);
    // Mantiene vivo el provider autoDispose de la ruta seleccionada: sin
    // listeners, `select` deja un Timer(0) de descarte pendiente que el
    // framework de tests reporta como "timer still pending".
    final sub = container.listen<RouteInfo?>(
      selectedRouteProvider,
      (_, __) {},
    );
    addTearDown(sub.close);
    (container.read(userLocationProvider.notifier) as _TestUserLocation).set(
      UserLocationState(
        mode: UserLocationMode.manual,
        lat: lat,
        lon: userLon,
      ),
    );
    container.read(selectedRouteProvider.notifier).select(routeR1());
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: NotificationsScreen()),
      ),
    );
    return container;
  }

  void arm(ProviderContainer c, String busId) {
    c.read(activeAlertsProvider.notifier).toggleAlert(busId);
    c.read(proximityAlertsProvider.notifier).armAlert(busId, 'R1');
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Avisos va sobre blanco', (tester) async {
    await pumpScreen(tester, const []);
    await tester.pump();
    exigeFondoBlanco(tester);
  });

  /// La tarjeta de un aviso. La ruta va escrita y la placa en su lámina
  /// blanca (`PlacaBus`), como en la hoja de distancia: ya no van las dos
  /// juntas en una sola línea con guion.
  ///
  /// La llave es la de la entrada (`bus@fecha`), no la del bus: el mismo bus
  /// puede salir en «Enviados» y otra vez en «Esperando».
  Finder aviso(String busId) => find.byWidgetPredicate((w) =>
      w.key is ValueKey<String> &&
      (w.key! as ValueKey<String>).value.startsWith('aviso-$busId@'));

  /// El círculo de selección de la tarjeta de [busId].
  Finder circulo(String busId) => find.byWidgetPredicate((w) =>
      w.key is ValueKey<String> &&
      (w.key! as ValueKey<String>).value.startsWith('circulo-$busId@'));

  /// Deja terminar una animación: arranca en el cuadro siguiente al cambio
  /// (un `pump(d)` solo la deja quieta) y la despedida de una tarjeta se
  /// cierra en otro más.
  Future<void> asentar(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();
  }

  /// Acepta la ventana de «¿Borrar…?» que sale antes de borrar.
  Future<void> confirmar(WidgetTester tester, String titulo) async {
    expect(find.text(titulo), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Borrar'));
    await tester.pump(const Duration(milliseconds: 500));
  }

  /// Toca «Deshacer» en la tarjeta que sale abajo después de borrar.
  Future<void> deshacer(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 750));
    await tester.tap(find.text('Deshacer'));
    await tester.pump(const Duration(milliseconds: 750));
  }

  void expectAviso(String busId, {String ruta = 'Ruta 1'}) {
    expect(aviso(busId), findsOneWidget);
    expect(find.descendant(of: aviso(busId), matching: find.text(ruta)),
        findsOneWidget);
    expect(
      find.descendant(
        of: find.descendant(of: aviso(busId), matching: find.byType(PlacaBus)),
        matching: find.text(busId),
      ),
      findsOneWidget,
    );
  }

  testWidgets('estado vacío sin avisos ni historial', (tester) async {
    await pumpScreen(tester, const []);

    expect(find.text('No tienes avisos activos'), findsOneWidget);
  });

  testWidgets('desactivar un aviso activo lo borra de la lista',
      (tester) async {
    final container = await pumpScreen(tester, [bus('A-1')]);
    arm(container, 'A-1');
    await tester.pump();

    expectAviso('A-1');
    expect(find.textContaining('esperando aviso'), findsOneWidget);

    await tester.tap(find.text('Desactivar'));
    await tester.pump();
    // Se despide (ver «se despide antes de irse»), y después no está.
    await asentar(tester);

    expect(aviso('A-1'), findsNothing);
    expect(container.read(activeAlertsProvider), isEmpty);
    expect(container.read(alertHistoryProvider), isEmpty);
  });

  // «Está a 14408 m de tu ubicación · esperando aviso» partía la franja en
  // dos filas en un iPhone, y cada cifra nueva corría el resto (dueño,
  // 2026-10-01). En el teléfono más angosto, a 9 m y a 14 km, el resto
  // queda en el mismo sitio y en una sola fila.
  testWidgets('la distancia del aviso no corre el texto ni salta de fila',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    Future<Rect> resto(double lat, String cifra) async {
      final container = await pumpScreen(tester, [bus('A-1', lat: lat)]);
      arm(container, 'A-1');
      await tester.pump();
      expect(find.text(cifra), findsOneWidget);
      final texto = find.text(' $restoDistancia');
      final rect = tester.getRect(texto);
      final linea = tester.renderObject<RenderParagraph>(
        find.descendant(of: texto, matching: find.byType(RichText)),
      );
      expect(linea.didExceedMaxLines, isFalse);
      await tester.pumpWidget(const SizedBox());
      return rect;
    }

    final cerca = await resto(userLat + 0.00008, '9 m');
    final lejos = await resto(userLat + 0.1296, '14 km');
    expect(lejos, cerca);
    // Una fila de `pie` (12 × 1,3), no dos.
    expect(cerca.height, lessThan(20));
  });

  // «Las distancias no corresponden» (dueño, 2026-10-16): la hoja decía
  // 13,4 km por la ruta y Avisos 10 km en recta del mismo bus. Avisos
  // mide como la hoja: por el recorrido, desde el punto del aviso. Una U de
  // 1500 m de ida, 400 de lado y 1500 de vuelta: el bus en la punta de
  // ida, la persona enfrente, a 400 m en recta y 3,4 km por la ruta.
  testWidgets('la distancia del aviso es la de la hoja: por la ruta',
      (tester) async {
    GeoPoint m(double x, double y) => GeoPoint(
          lat: userLat + y / 111320,
          lon: userLon + x / (111320 * math.cos(userLat * math.pi / 180)),
        );
    final u = [m(0, 0), m(1500, 0), m(1500, 400), m(0, 400)];
    final b = bus('A-1', lat: userLat).copyWith(heading: 90);
    final container =
        await pumpScreen(tester, [b], ruta: u, lat: m(0, 400).lat);
    await tester.pump();
    arm(container, 'A-1');
    await tester.pump();
    await tester.pump();

    expect(find.text('3,4 km'), findsOneWidget);
  });

  test('la distancia del aviso: metros hasta 999, luego kilómetros', () {
    expect(distanciaAviso(9), '9 m');
    expect(distanciaAviso(999), '999 m');
    expect(distanciaAviso(1000), '1,0 km');
    expect(distanciaAviso(14408), '14 km');
  });

  // El bus se fue al patio, donde lo ocultan: la fila no puede quedarse
  // diciendo solo «esperando señal», como si fuera a volver en cualquier
  // momento. Dice hasta qué hora sigue en pie el aviso.
  testWidgets('sin señal del bus, dice hasta qué hora espera el aviso',
      (tester) async {
    final container = await pumpScreen(tester, const []);
    arm(container, 'A-1');
    await tester.pump();

    final vence = container.read(alertHistoryProvider).single.createdAt.add(
          vidaDeUnAviso,
        );
    final hora = '${vence.hour.toString().padLeft(2, '0')}:'
        '${vence.minute.toString().padLeft(2, '0')}';
    expect(
      find.text('Esperando señal del bus, el aviso sigue hasta las $hora'),
      findsOneWidget,
    );
  });

  testWidgets('un aviso enviado se muestra como historial con su fecha',
      (tester) async {
    final container = await pumpScreen(tester, [bus('A-1')]);
    arm(container, 'A-1');
    // testWidgets usa timers falsos: pump() descarga el microtask del stream.
    await tester.pump();
    await container.read(proximityAlertsProvider.notifier).check();
    await tester.pump();

    expectAviso('A-1');
    // «Notificación enviada: 6 oct, 17:35» (dueño, 2026-10-18), sin «·».
    final enviado = container.read(alertHistoryProvider).single.sentAt!;
    const meses = [
      'ene',
      'feb',
      'mar',
      'abr',
      'may',
      'jun',
      'jul',
      'ago',
      'sep',
      'oct',
      'nov',
      'dic'
    ];
    final hora = '${enviado.hour.toString().padLeft(2, '0')}:'
        '${enviado.minute.toString().padLeft(2, '0')}';
    expect(
      find.text('Notificación enviada: ${enviado.day} '
          '${meses[enviado.month - 1]}, $hora'),
      findsOneWidget,
    );
    expect(find.text('Desactivar'), findsNothing);
    // «Enviado» a la derecha repetía, en gris y más chico, lo que la línea
    // de debajo del nombre ya dice con fecha y hora. Lo enviado ya no tiene
    // nada que hacer: la fila se queda sin acción, como una celda de iOS
    // que solo informa.
    expect(find.text('Enviado'), findsNothing);
  });

  testWidgets('borrar avisos seleccionados desactiva los activos',
      (tester) async {
    final container = await pumpScreen(tester, [bus('A-1'), bus('A-2')]);
    arm(container, 'A-1');
    arm(container, 'A-2');
    await tester.pump();

    await tester.tap(find.text('Seleccionar'));
    await tester.pump();
    // Deja terminar la entrada de la barra inferior (AnimatedSize).
    await tester.pump(const Duration(milliseconds: 300));
    // Selecciona solo A-1 (el círculo de su fila).
    await tester.tap(circulo('A-1'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Borrar 1'));
    await tester.pump(const Duration(milliseconds: 500));
    await confirmar(tester, '¿Borrar este aviso?');
    await asentar(tester);

    expect(aviso('A-1'), findsNothing);
    expectAviso('A-2');
    expect(container.read(activeAlertsProvider), {'A-2'});
  });

  testWidgets('borrar todas limpia historial y desactiva todo', (tester) async {
    final container = await pumpScreen(tester, [bus('A-1'), bus('A-2')]);
    arm(container, 'A-1');
    arm(container, 'A-2');
    await tester.pump();

    await tester.tap(find.text('Seleccionar'));
    await tester.pump();
    // Deja terminar la entrada de la barra inferior (AnimatedSize).
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Borrar todas'));
    await tester.pump(const Duration(milliseconds: 500));
    await confirmar(tester, '¿Borrar los 2 avisos?');

    expect(find.text('No tienes avisos activos'), findsOneWidget);
    expect(container.read(activeAlertsProvider), isEmpty);
    expect(container.read(alertHistoryProvider), isEmpty);
  });

  // La nota «En iPhone el aviso suena con la app abierta.» se fue (dueño,
  // 2026-10-18); en su sitio va la de qué se hace aquí (abajo).
  testWidgets('en iPhone la pestaña no lleva la nota de la app abierta',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      final container = await pumpScreen(tester, [bus('A-1')]);
      expect(find.textContaining('app abierta'), findsNothing);

      arm(container, 'A-1');
      await tester.pump();
      expectAviso('A-1');
      expect(find.textContaining('app abierta'), findsNothing);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  // Sobre blanco, una tarjeta blanca sin sombra es solo su filo: también
  // lo que ya sonó se despega del fondo.
  testWidgets('las tarjetas de Avisos se despegan del blanco con sombra',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      final container = await pumpScreen(
          tester, [bus('A-1'), bus('A-2', lat: userLat + 0.05)]);
      arm(container, 'A-1');
      arm(container, 'A-2');
      await tester.pump();
      await container.read(proximityAlertsProvider.notifier).check();
      await tester.pump();
      expect(container.read(alertHistoryProvider).where((e) => e.sent),
          hasLength(1));

      for (final id in ['A-1', 'A-2']) {
        final caja = tester.widget<AnimatedContainer>(aviso(id)).decoration!
            as BoxDecoration;
        expect(caja.boxShadow, isNotEmpty, reason: 'la tarjeta de $id');
      }
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  // Rediseño del centro de avisos (dueño, 2026-09-30: «la noto bastante
  // fea y no se ve al nivel de la app»). Lo que espera y lo que ya sonó
  // iban mezclados en una sola lista, distinguidos solo por el color del
  // medallón.
  testWidgets('los avisos van en dos grupos: esperando arriba, enviados abajo',
      (tester) async {
    // A-2 lejos (unos 5 km al norte): sigue esperando. A-1 encima: suena.
    final container =
        await pumpScreen(tester, [bus('A-1'), bus('A-2', lat: userLat + 0.05)]);
    arm(container, 'A-1');
    arm(container, 'A-2');
    await tester.pump();
    await container.read(proximityAlertsProvider.notifier).check();
    await tester.pump();

    final esperando = find.text('Esperando');
    final enviados = find.text('Enviados');
    expect(esperando, findsOneWidget);
    expect(enviados, findsOneWidget);
    double y(Finder f) => tester.getTopLeft(f).dy;
    expect(y(esperando), lessThan(y(aviso('A-2'))));
    expect(y(aviso('A-2')), lessThan(y(enviados)));
    expect(y(enviados), lessThan(y(aviso('A-1'))));
    // Los encabezados se anuncian como tales: el lector salta de grupo en
    // grupo en vez de leer la lista entera.
    final semantica = tester.ensureSemantics();
    // La lista acaba de reemplazar al estado vacío: que termine de entrar.
    await asentar(tester);
    expect(tester.getSemantics(esperando),
        isSemantics(label: 'Esperando', isHeader: true));
    semantica.dispose();
  });

  testWidgets('sin avisos enviados no sale el grupo «Enviados»',
      (tester) async {
    final container = await pumpScreen(tester, const []);
    arm(container, 'A-1');
    await tester.pump();
    expect(find.text('Esperando'), findsOneWidget);
    expect(find.text('Enviados'), findsNothing);
  });

  testWidgets('en modo selección, tocar la tarjeta entera la marca',
      (tester) async {
    final container = await pumpScreen(tester, [bus('A-1'), bus('A-2')]);
    arm(container, 'A-1');
    arm(container, 'A-2');
    await tester.pump();
    final ruta =
        find.descendant(of: aviso('A-1'), matching: find.text('Ruta 1'));

    // Fuera del modo selección tocar la tarjeta no hace nada.
    await tester.tap(ruta);
    await tester.pump();
    expect(find.text('Borrar 1'), findsNothing);

    await tester.tap(find.text('Seleccionar'));
    await tester.pump(const Duration(milliseconds: 300));
    // El círculo es un blanco chico a la derecha; tocar el nombre de la
    // ruta, que es donde el dedo va, también marca.
    await tester.tap(ruta);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Borrar 1'), findsOneWidget);

    await tester.tap(ruta);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Selecciona avisos'), findsOneWidget);
    expect(container.read(activeAlertsProvider), {'A-1', 'A-2'});
  });

  // «Haz que en avisos, si se deja presionado un aviso, se seleccione»
  // (dueño, 2026-10-18): como en Fotos o Mail, la pulsación larga abre la
  // selección con ese aviso ya marcado.
  testWidgets('dejar presionado un aviso lo selecciona', (tester) async {
    final container = await pumpScreen(tester, [bus('A-1'), bus('A-2')]);
    arm(container, 'A-1');
    arm(container, 'A-2');
    await tester.pump();
    final ruta =
        find.descendant(of: aviso('A-2'), matching: find.text('Ruta 1'));

    await tester.longPress(ruta);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Borrar 1'), findsOneWidget);
    expect(find.text('Cancelar'), findsOneWidget);
    await tester.tap(find.text('Borrar 1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Borrar'));
    await tester.pumpAndSettle();
    expect(container.read(activeAlertsProvider), {'A-1'});

    // Ya seleccionando, la pulsación larga marca y desmarca como el toque.
    await tester.tap(find.text('Seleccionar'));
    await tester.pump(const Duration(milliseconds: 300));
    final otra =
        find.descendant(of: aviso('A-1'), matching: find.text('Ruta 1'));
    await tester.longPress(otra);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Borrar 1'), findsOneWidget);
    await tester.longPress(otra);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Selecciona avisos'), findsOneWidget);
  });

  // «Vuélvele a colocar el texto de antes, pero pones algo como gestiona,
  // borra, desactiva tus avisos aquí, con su icono» (dueño, 2026-10-18):
  // la tarjeta de la nota vuelve arriba, ahora en los dos teléfonos.
  testWidgets('arriba, la nota de qué se hace aquí, con su icono',
      (tester) async {
    final container = await pumpScreen(tester, [bus('A-1')]);
    const texto = 'Gestiona, borra o desactiva tus avisos aquí.';
    // Sin avisos, el estado vacío ya dice cómo armar uno.
    expect(find.text(texto), findsNothing);

    arm(container, 'A-1');
    await tester.pump();
    expect(find.text(texto), findsOneWidget);
    final nota = find.ancestor(
        of: find.text(texto),
        matching: find.byKey(const ValueKey('nota-avisos')));
    expect(
        find.descendant(
            of: nota, matching: find.byIcon(Icons.edit_notifications_outlined)),
        findsOneWidget);
    // Arriba de la lista.
    expect(tester.getRect(nota).bottom,
        lessThanOrEqualTo(tester.getRect(aviso('A-1')).top));
  });

  testWidgets('la campana del estado vacío pasa el 3:1 sobre su medallón',
      (tester) async {
    await pumpScreen(tester, const []);
    // Iba en el verde de relleno sobre su propio tinte, por debajo de lo
    // que la norma pide hasta para un icono.
    final campana =
        tester.widget<Icon>(find.byIcon(Icons.notifications_none_outlined));
    expect(campana.color, AppColors.primaryAccessible);
  });

  // Clase de frontend del dueño (2026-10-02): borrar no preguntaba ni se
  // podía deshacer. Borrar varios o todos pregunta antes; cualquier borrado
  // —también «Desactivar»— se puede deshacer desde la tarjeta de abajo.
  testWidgets('borrar pide confirmación y «Cancelar» no borra nada',
      (tester) async {
    final container = await pumpScreen(tester, [bus('A-1')]);
    arm(container, 'A-1');
    await tester.pump();

    await tester.tap(find.text('Seleccionar'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Borrar todas'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('¿Borrar este aviso?'), findsOneWidget);
    // El «Cancelar» del diálogo, no el de la barra.
    await tester.tap(find.descendant(
        of: find.byType(Dialogo), matching: find.text('Cancelar')));
    await tester.pump(const Duration(milliseconds: 500));

    expectAviso('A-1');
    expect(container.read(activeAlertsProvider), {'A-1'});
    expect(find.text('Deshacer'), findsNothing);
  });

  testWidgets('deshacer «Desactivar» devuelve el aviso armado y con su fecha',
      (tester) async {
    // El bus está encima, pero nadie mide hasta después de deshacer.
    final container = await pumpScreen(tester, [bus('A-1')]);
    arm(container, 'A-1');
    await tester.pump();
    final antes = container.read(alertHistoryProvider).single;

    await tester.tap(find.text('Desactivar'));
    await asentar(tester);
    expect(aviso('A-1'), findsNothing);
    expect(find.text('Aviso desactivado'), findsOneWidget);

    await deshacer(tester);

    expectAviso('A-1');
    expect(container.read(activeAlertsProvider), {'A-1'});
    final despues = container.read(alertHistoryProvider).single;
    // La misma fecha: es la que dice cuándo vence el aviso.
    expect(despues.createdAt, antes.createdAt);
    // Y vuelve a vigilar: con el bus encima, suena.
    await container.read(proximityAlertsProvider.notifier).check();
    expect(container.read(alertHistoryProvider).single.sent, isTrue);
  });

  testWidgets('deshacer «Borrar todas» devuelve enviados y activos en su sitio',
      (tester) async {
    // A-1 encima: suena. A-2 lejos: sigue esperando.
    final container =
        await pumpScreen(tester, [bus('A-1'), bus('A-2', lat: userLat + 0.05)]);
    arm(container, 'A-1');
    arm(container, 'A-2');
    await tester.pump();
    await container.read(proximityAlertsProvider.notifier).check();
    await tester.pump();
    final antes = container.read(alertHistoryProvider);

    await tester.tap(find.text('Seleccionar'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Borrar todas'));
    await tester.pump(const Duration(milliseconds: 500));
    await confirmar(tester, '¿Borrar los 2 avisos?');
    expect(find.text('No tienes avisos activos'), findsOneWidget);
    expect(find.text('2 avisos borrados'), findsOneWidget);

    await deshacer(tester);

    expect(container.read(alertHistoryProvider).map((e) => e.toJson()),
        antes.map((e) => e.toJson()));
    expect(container.read(activeAlertsProvider), {'A-2'});
    expectAviso('A-1');
    expectAviso('A-2');
  });

  testWidgets('deshacer no pasa del tope de 2 avisos activos', (tester) async {
    final container = await pumpScreen(tester, const []);
    arm(container, 'A-1');
    await tester.pump();

    await tester.tap(find.text('Desactivar'));
    await tester.pump();
    // Mientras tanto se armaron otros dos: ya no cabe.
    arm(container, 'A-2');
    arm(container, 'A-3');
    await deshacer(tester);

    expect(container.read(activeAlertsProvider), {'A-2', 'A-3'});
    expect(container.read(alertHistoryProvider).map((e) => e.busId).toSet(),
        {'A-2', 'A-3'});
    // Primero se va la tarjeta del «Deshacer», luego entra la del tope.
    await tester.pump(const Duration(milliseconds: 750));
    expect(find.textContaining('Ya tienes 2 avisos activos'), findsOneWidget);
  });

  testWidgets('la campana de un aviso enviado va en verde', (tester) async {
    final container = await pumpScreen(tester, [bus('A-1')]);
    arm(container, 'A-1');
    await tester.pump();
    await container.read(proximityAlertsProvider.notifier).check();
    await tester.pump();

    final campana =
        tester.widget<Icon>(find.byIcon(Icons.notifications_active_outlined));
    expect(campana.color, AppColors.primaryAccessible);
  });

  testWidgets('el bus que ya sonó y se volvió a armar sale en los dos grupos',
      (tester) async {
    final container = await pumpScreen(tester, [bus('A-1')]);
    arm(container, 'A-1');
    await tester.pump();
    await container.read(proximityAlertsProvider.notifier).check();
    arm(container, 'A-1');
    await tester.pump(const Duration(milliseconds: 500));

    expect(aviso('A-1'), findsNWidgets(2));
    expect(find.text('Esperando'), findsOneWidget);
    expect(find.text('Enviados'), findsOneWidget);

    // Desactivar el que espera deja el que sonó.
    await tester.tap(find.text('Desactivar'));
    await asentar(tester);
    expect(aviso('A-1'), findsOneWidget);
    expect(container.read(alertHistoryProvider).single.sent, isTrue);
  });

  // Dueño (2026-10-02): al entrar en «Seleccionar» no había cómo salir sin
  // borrar, y la selección seguía puesta al volver a la pantalla.
  testWidgets('«Cancelar» sale de la selección sin borrar', (tester) async {
    final container = await pumpScreen(tester, [bus('A-1')]);
    arm(container, 'A-1');
    await tester.pump();

    await tester.tap(find.text('Seleccionar'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(aviso('A-1'));
    await tester.pump();
    await tester.tap(find.text('Cancelar'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Seleccionar'), findsOneWidget);
    expect(find.text('Borrar todas'), findsNothing);
    // Avisos es una pestaña: al salir de la selección no queda flecha.
    expect(find.byTooltip('Volver'), findsNothing);
    expectAviso('A-1');
  });

  testWidgets('salir de avisos y volver no deja la selección puesta',
      (tester) async {
    final container = await pumpScreen(tester, [bus('A-1')]);
    arm(container, 'A-1');
    await tester.pump();
    await tester.tap(find.text('Seleccionar'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Borrar todas'), findsOneWidget);

    Future<void> mostrar(Widget pantalla) => tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(home: pantalla),
          ),
        );
    await mostrar(const SizedBox());
    await tester.pump();
    await mostrar(const NotificationsScreen());
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Seleccionar'), findsOneWidget);
    expect(find.text('Borrar todas'), findsNothing);
  });

  // Dueño (2026-10-02): «la animación de desactivar o borrar no me gusta
  // nada». La tarjeta desaparecía de golpe y lo de abajo saltaba a su
  // sitio. Ahora se despide —se corre, se apaga y su hueco se cierra— y
  // mientras tanto no se puede tocar ni la lee el lector.
  testWidgets('al desactivar, la tarjeta se despide antes de irse',
      (tester) async {
    final container = await pumpScreen(tester, [bus('A-1'), bus('A-2')]);
    arm(container, 'A-1');
    arm(container, 'A-2');
    await tester.pump(const Duration(milliseconds: 800));
    final abajo = tester.getTopLeft(aviso('A-2')).dy;

    await tester.tap(find.text('Desactivar').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    expect(aviso('A-1'), findsOneWidget, reason: 'aún se está yendo');
    expect(container.read(alertHistoryProvider).map((e) => e.busId), ['A-2']);
    expect(find.text('Desactivar'), findsNWidgets(2));
    final opacidad = tester
        .widgetList<FadeTransition>(find.ancestor(
            of: aviso('A-1'), matching: find.byType(FadeTransition)))
        .map((f) => f.opacity.value)
        .reduce((a, b) => a * b);
    expect(opacidad, lessThan(1));
    // El de abajo sube sin salto: a medio camino todavía no llegó.
    await tester.pump(const Duration(milliseconds: 180));
    final medio = tester.getTopLeft(aviso('A-2')).dy;
    expect(medio, lessThanOrEqualTo(abajo));

    await tester.pump(const Duration(milliseconds: 400));
    expect(aviso('A-1'), findsNothing);
    expect(tester.getTopLeft(aviso('A-2')).dy, lessThan(medio));
  });

  // Dueño (2026-10-02): «no me gusta cómo se seleccionan ni el chulito».
  // Era la casilla de Material y un borde grueso. Ahora, en el mismo sitio
  // a la derecha («donde estaba antes»), un círculo como el de Mail o Fotos
  // que, marcado, se llena con el chulito blanco; el lector lo anuncia como
  // casilla.
  testWidgets('seleccionar usa el círculo propio, no la casilla de Material',
      (tester) async {
    final semantica = tester.ensureSemantics();
    final container = await pumpScreen(tester, [bus('A-1')]);
    arm(container, 'A-1');
    await tester.pump();
    expect(circulo('A-1'), findsNothing);

    await tester.tap(find.text('Seleccionar'));
    await asentar(tester);
    expect(find.byType(Checkbox), findsNothing);
    expect(circulo('A-1'), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsNothing);
    final x = tester.getTopLeft(circulo('A-1')).dx;
    expect(x, greaterThan(tester.getCenter(aviso('A-1')).dx));

    await tester.tap(circulo('A-1'));
    await asentar(tester);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    expect(
      tester.getSemantics(circulo('A-1')),
      matchesSemantics(
        label: 'Ruta 1, bus A-1',
        hasCheckedState: true,
        isChecked: true,
        hasTapAction: true,
      ),
    );

    await tester.tap(find.text('Cancelar'));
    await asentar(tester);
    expect(circulo('A-1'), findsNothing);
    semantica.dispose();
  });

  testWidgets('la lista se funde bajo la barra al subir', (tester) async {
    final container = await pumpScreen(tester, [bus('A-1')]);
    arm(container, 'A-1');
    await tester.pump();

    exigeBordeDesvanecido(tester, find.text('Esperando'));
  });
}
