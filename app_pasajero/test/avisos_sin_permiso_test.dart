// Un aviso con las notificaciones apagadas no se da por enviado
// (auditoría 2026-09, H2).
//
// Ni Android ni iOS lanzan un error al mostrar una notificación sin
// permiso: el sistema la descarta callado. `show` terminaba bien,
// `notifyBusNear` devolvía `true` y el barrido marcaba el aviso como
// enviado y lo desarmaba sin que el teléfono hubiera enseñado nada. Aquí se
// simula el canal nativo del plugin tal como responde con el permiso
// negado o el canal «Alertas de buses» apagado.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import 'package:ya_viene_pasajero/core/services/bus_notification_service.dart';
import 'package:ya_viene_pasajero/core/widgets/aviso.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/tracking_providers.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/user_location_provider.dart';
import 'package:ya_viene_pasajero/features/map/presentation/widgets/eta_bottom_sheet.dart';
import 'package:ya_viene_pasajero/features/notifications/presentation/providers/alert_history_provider.dart';
import 'package:ya_viene_pasajero/features/notifications/presentation/providers/proximity_alerts_provider.dart';

const _canal = MethodChannel('dexterous.com/flutter/local_notifications');

/// Lo que el canal nativo recibe, y cómo contesta.
class _Nativo {
  _Nativo({this.permiso = true, this.importanciaDelCanal});

  bool permiso;

  /// `null` = el canal «Alertas de buses» no aparece en la lista.
  int? importanciaDelCanal;
  final llamadas = <String>[];

  void instalar() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_canal, (call) async {
      llamadas.add(call.method);
      switch (call.method) {
        case 'areNotificationsEnabled':
          return permiso;
        case 'getNotificationChannels':
          final importancia = importanciaDelCanal;
          if (importancia == null) return <Map<String, Object?>>[];
          return [
            <String, Object?>{
              'id': 'bus_alerts',
              'name': 'Alertas de buses',
              'description': null,
              'groupId': null,
              'showBadge': true,
              'importance': importancia,
              'bypassDnd': false,
              'playSound': true,
              'enableLights': false,
              'enableVibration': true,
              'vibrationPattern': null,
              'ledColor': 0,
              'audioAttributesUsage': 5,
            },
          ];
      }
      return null;
    });
  }
}

final _bus = BusPosition(
  busId: 'BUS-SQA223',
  routeId: 'R1',
  lat: 10.990,
  lon: -74.800,
  heading: 0,
  speedKmh: 20,
  timestamp: DateTime.now(),
  isGhostBus: false,
);

class _Ubicacion extends UserLocationNotifier {
  void poner(UserLocationState s) => state = s;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // El plugin solo contesta por Android si esta es su implementación.
  AndroidFlutterLocalNotificationsPlugin.registerWith();
  tearDown(() => TestDefaultBinaryMessengerBinding
      .instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_canal, null));

  group('notifyBusNear', () {
    Future<bool> avisar() => BusNotificationService.notifyBusNear(
          busId: 'BUS-SQA223',
          routeName: 'Ruta 106',
          distanceMeters: 800,
        );

    test('sin permiso devuelve false y no intenta mostrar nada', () async {
      final nativo = _Nativo(permiso: false)..instalar();
      expect(await avisar(), isFalse);
      expect(nativo.llamadas, isNot(contains('show')));
    });

    test('con el canal de avisos apagado en Ajustes devuelve false', () async {
      // El permiso general sigue dado: la persona apagó solo la categoría
      // «Alertas de buses». Android la descarta igual, sin error.
      final nativo = _Nativo(importanciaDelCanal: 0)..instalar();
      expect(await avisar(), isFalse);
      expect(nativo.llamadas, isNot(contains('show')));
    });

    test('con permiso y el canal encendido lo muestra y devuelve true',
        () async {
      final nativo = _Nativo(importanciaDelCanal: 4)..instalar();
      expect(await avisar(), isTrue);
      expect(nativo.llamadas, contains('show'));
    });
  });

  group('el barrido y la hoja', () {
    late ProviderContainer container;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      container = ProviderContainer(overrides: [
        userLocationProvider.overrideWith((ref) => _Ubicacion()),
        busPositionsSourceProvider.overrideWith(
          (ref, routeId) => Stream.value([_bus]),
        ),
      ]);
      addTearDown(container.dispose);
    });

    /// Punto de espera a unos 110 m del bus, ruta elegida y aviso armado.
    Future<void> armar() async {
      (container.read(userLocationProvider.notifier) as _Ubicacion).poner(
        const UserLocationState(
          mode: UserLocationMode.manual,
          lat: 10.991,
          lon: -74.800,
        ),
      );
      container.read(selectedRouteProvider.notifier).select(
            const RouteInfo(id: 'R1', name: 'Ruta 106', companyId: 'C1'),
          );
      container.read(activeAlertsProvider.notifier).toggleAlert('BUS-SQA223');
      container
          .read(proximityAlertsProvider.notifier)
          .armAlert('BUS-SQA223', 'R1');
    }

    testWidgets('sin permiso el aviso sigue armado y la hoja lo dice',
        (tester) async {
      final nativo = _Nativo(permiso: false)..instalar();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: Scaffold(body: EtaBottomSheet())),
        ),
      );
      await tester.pumpAndSettle();
      final sub =
          container.listen(busPositionsSourceProvider('R1'), (_, __) {});
      addTearDown(sub.close);
      await armar();
      await tester.pump();

      await tester.runAsync(
          () => container.read(proximityAlertsProvider.notifier).check());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 750));

      expect(nativo.llamadas, isNot(contains('show')));
      expect(container.read(activeAlertsProvider), contains('BUS-SQA223'),
          reason: 'un aviso que no sonó sigue armado');
      final entrada = container
          .read(alertHistoryProvider)
          .singleWhere((e) => e.busId == 'BUS-SQA223');
      expect(entrada.sent, isFalse, reason: 'y no se anota como enviado');

      final tarjeta = find.byType(AvisoTarjeta);
      expect(tarjeta, findsOneWidget);
      expect(
        tester.widget<AvisoTarjeta>(tarjeta).mensaje,
        contains('notificaciones de Ya Viene están apagadas'),
      );

      // El barrido de dentro de cinco segundos vuelve a fallar: la hoja no
      // repite la tarjeta cada vez.
      await tester.pump(const Duration(seconds: 12));
      await tester.runAsync(
          () => container.read(proximityAlertsProvider.notifier).check());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 750));
      expect(find.byType(AvisoTarjeta), findsNothing);
    });

    testWidgets('con permiso suena, se anota y no hay tarjeta', (tester) async {
      final nativo = _Nativo(importanciaDelCanal: 4)..instalar();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: Scaffold(body: EtaBottomSheet())),
        ),
      );
      await tester.pumpAndSettle();
      final sub =
          container.listen(busPositionsSourceProvider('R1'), (_, __) {});
      addTearDown(sub.close);
      await armar();
      await tester.pump();

      await tester.runAsync(
          () => container.read(proximityAlertsProvider.notifier).check());
      await tester.pump();

      expect(nativo.llamadas, contains('show'));
      expect(container.read(activeAlertsProvider), isEmpty);
      expect(find.byType(AvisoTarjeta), findsNothing);
    });
  });
}
