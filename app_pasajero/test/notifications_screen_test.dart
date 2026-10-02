import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import 'package:ya_viene_pasajero/core/utils/distancia.dart';
import 'package:ya_viene_pasajero/core/widgets/placa_bus.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/tracking_providers.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/user_location_provider.dart';
import 'package:ya_viene_pasajero/features/notifications/presentation/providers/alert_history_provider.dart';
import 'package:ya_viene_pasajero/features/notifications/presentation/providers/proximity_alerts_provider.dart';
import 'package:ya_viene_pasajero/features/notifications/presentation/screens/notifications_screen.dart';

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

  Future<ProviderContainer> pumpScreen(
      WidgetTester tester, List<BusPosition> buses) async {
    final container = ProviderContainer(overrides: [
      userLocationProvider.overrideWith((ref) => _TestUserLocation()),
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
      const UserLocationState(
        mode: UserLocationMode.manual,
        lat: userLat,
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

  /// La tarjeta de un aviso. La ruta va escrita y la placa en su lámina
  /// blanca (`PlacaBus`), como en la hoja de distancia: ya no van las dos
  /// juntas en una sola línea con guion.
  Finder aviso(String busId) => find.byKey(ValueKey('aviso-$busId'));

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
      find.text('Esperando señal del bus · el aviso sigue hasta las $hora'),
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
    expect(find.textContaining('Notificación enviada'), findsOneWidget);
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
    // Selecciona solo A-1 (el checkbox de su fila).
    await tester.tap(find.byType(Checkbox).first);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Borrar 1'));
    await tester.pump(const Duration(milliseconds: 500));
    await confirmar(tester, '¿Borrar este aviso?');

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

  // D4-a: en iPhone el aviso solo suena con la app abierta (la app no
  // declara `UIBackgroundModes` y no hay push). La pantalla de avisos lo
  // dice, con avisos o sin ellos.
  const soloConLaAppAbierta = 'En iPhone el aviso suena con la app abierta.';

  testWidgets('en iPhone dice que el aviso suena con la app abierta',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      final container = await pumpScreen(tester, [bus('A-1')]);
      expect(find.text(soloConLaAppAbierta), findsOneWidget);

      arm(container, 'A-1');
      await tester.pump();
      expectAviso('A-1');
      expect(find.text(soloConLaAppAbierta), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('en Android no lo dice', (tester) async {
    final container = await pumpScreen(tester, [bus('A-1')]);
    expect(find.text(soloConLaAppAbierta), findsNothing);

    arm(container, 'A-1');
    await tester.pump();
    expect(find.text(soloConLaAppAbierta), findsNothing);
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
    expect(find.byType(Checkbox), findsNothing);

    await tester.tap(find.text('Seleccionar'));
    await tester.pump(const Duration(milliseconds: 300));
    // La casilla es un blanco de 48 a la derecha; tocar el nombre de la
    // ruta, que es donde el dedo va, también marca.
    await tester.tap(ruta);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Borrar 1'), findsOneWidget);

    await tester.tap(ruta);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Selecciona avisos'), findsOneWidget);
    expect(container.read(activeAlertsProvider), {'A-1', 'A-2'});
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
    await tester.tap(find.text('Cancelar'));
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
    await tester.pump();
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
}
