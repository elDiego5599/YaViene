// Tocar un aviso deja el mapa como estaba cuando sonó: su empresa, su ruta
// y su bus, con la cámara encima del bus. Antes abría la app sin más y había
// que volver a escoger empresa y ruta para ver el bus (dueño, 2026-10-02).
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import 'package:ya_viene_pasajero/core/services/bus_notification_service.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/map_view_state.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/selected_buses_provider.dart';
import 'package:ya_viene_pasajero/features/notifications/presentation/providers/abrir_aviso_provider.dart';

const _sobusa = Company(id: 'sobusa', name: 'Sobusa');
const _coolitoral = Company(id: 'coolitoral', name: 'Coolitoral');
const _r106 = RouteInfo(id: 'r106', name: 'Ruta 106', companyId: 'coolitoral');
const _c11 = RouteInfo(id: 'c11', name: 'C11', companyId: 'sobusa');

ProviderContainer _contenedor({List<String>? pedidas}) {
  final c = ProviderContainer(overrides: [
    backendUrlProvider.overrideWith(() => BackendUrl.fija('http://x')),
    companiesProvider.overrideWith((ref) async => [_sobusa, _coolitoral]),
    routesByCompanyProvider.overrideWith((ref, companyId) async {
      pedidas?.add(companyId);
      return switch (companyId) {
        'sobusa' => [_c11],
        'coolitoral' => [_r106],
        _ => <RouteInfo>[],
      };
    }),
  ]);
  addTearDown(c.dispose);
  return c;
}

void main() {
  group('la carga del aviso', () {
    test('la URL de la actividad acepta solo yaviene://aviso con bus y ruta',
        () {
      expect(
        BusNotificationService.leerUrlActividad(
            'yaviene://aviso?busId=BUS-SQA223&routeId=r106'),
        (busId: 'BUS-SQA223', routeId: 'r106'),
      );
      for (final mala in [
        null,
        'https://aviso?busId=A&routeId=R',
        'yaviene://otro?busId=A&routeId=R',
        'yaviene://aviso?busId=&routeId=R',
        'yaviene://aviso?busId=A&routeId=',
        'yaviene://aviso?busId=${List.filled(257, 'A').join()}&routeId=R',
      ]) {
        expect(BusNotificationService.leerUrlActividad(mala), isNull,
            reason: mala);
      }
    });

    test('lleva el bus y la ruta, y se lee igual', () {
      final carga = BusNotificationService.carga('BUS-SQA223', 'r106');
      expect(BusNotificationService.leerCarga(carga),
          (busId: 'BUS-SQA223', routeId: 'r106'));
    });

    test('lo que no es un bus con su ruta no abre nada', () {
      for (final mala in [
        null,
        '',
        'no es json',
        '[1,2]',
        '{"busId":"BUS-SQA223"}',
        '{"busId":"","routeId":"r106"}',
        '{"busId":3,"routeId":"r106"}',
      ]) {
        expect(BusNotificationService.leerCarga(mala), isNull, reason: mala);
      }
    });
  });

  group('abrir un aviso', () {
    test('escoge su empresa, su ruta y su bus, y pide la cámara encima',
        () async {
      final c = _contenedor();
      final abierto = await c
          .read(abrirAvisoProvider)((busId: 'BUS-SQA223', routeId: 'r106'));

      expect(abierto, isTrue);
      expect(c.read(selectedCompanyProvider), _coolitoral);
      expect(c.read(selectedRouteProvider), _r106);
      expect(c.read(selectedBusesProvider), {'BUS-SQA223'});
      expect(
          c.read(enfoqueDeBusProvider), (busId: 'BUS-SQA223', routeId: 'r106'));
    });

    test('con su ruta ya escogida no pregunta nada y no suelta el bus',
        () async {
      final pedidas = <String>[];
      final c = _contenedor(pedidas: pedidas);
      c.read(selectedCompanyProvider.notifier).select(_coolitoral);
      c.read(selectedRouteProvider.notifier).select(_r106);
      c.read(selectedBusesProvider.notifier).toggleBus('BUS-SQA223');

      await c.read(abrirAvisoProvider)((busId: 'BUS-SQA223', routeId: 'r106'));

      expect(pedidas, isEmpty);
      // `toggleBus` sobre el mismo bus lo soltaría: tocar el aviso dos
      // veces no puede dejar el mapa sin bus.
      expect(c.read(selectedBusesProvider), {'BUS-SQA223'});
    });

    test('mira primero la empresa ya escogida', () async {
      final pedidas = <String>[];
      final c = _contenedor(pedidas: pedidas);
      c.read(selectedCompanyProvider.notifier).select(_coolitoral);

      await c.read(abrirAvisoProvider)((busId: 'BUS-SQA223', routeId: 'r106'));

      expect(pedidas, ['coolitoral']);
    });

    test('una ruta que ya no existe no toca lo escogido', () async {
      final c = _contenedor();
      c.read(selectedCompanyProvider.notifier).select(_sobusa);
      c.read(selectedRouteProvider.notifier).select(_c11);

      final abierto = await c
          .read(abrirAvisoProvider)((busId: 'BUS-X', routeId: 'borrada'));

      expect(abierto, isFalse);
      expect(c.read(selectedCompanyProvider), _sobusa);
      expect(c.read(selectedRouteProvider), _c11);
      expect(c.read(enfoqueDeBusProvider), isNull);
    });

    test('sin red no toca lo escogido', () async {
      final c = ProviderContainer(overrides: [
        backendUrlProvider.overrideWith(() => BackendUrl.fija('http://x')),
        companiesProvider.overrideWith((ref) async => throw Exception('red')),
      ]);
      addTearDown(c.dispose);

      final abierto = await c
          .read(abrirAvisoProvider)((busId: 'BUS-SQA223', routeId: 'r106'));

      expect(abierto, isFalse);
      expect(c.read(selectedRouteProvider), isNull);
    });

    test('cambiar de ruta después olvida la cámara pedida', () async {
      final c = _contenedor();
      await c.read(abrirAvisoProvider)((busId: 'BUS-SQA223', routeId: 'r106'));

      c.read(selectedRouteProvider.notifier).select(_c11);

      expect(c.read(enfoqueDeBusProvider), isNull);
    });
  });

  // El mapa nativo no corre en pruebas: estas guardas atan el cableado que
  // no se puede ejercitar sin él.
  test('el mapa atiende el aviso tocado, con la app viva o cerrada', () {
    final pantalla =
        File('lib/features/map/presentation/screens/map_screen.dart')
            .readAsStringSync();
    expect(pantalla, contains('BusNotificationService.tocados.listen('));
    expect(pantalla, contains('BusNotificationService.tocadoAlAbrir()'));
    expect(pantalla, contains('abrirAvisoProvider'));

    final actividad =
        File('ios/AvisoEnVivo/AvisoEnVivo.swift').readAsStringSync();
    expect(actividad, contains('.widgetURL(urlAviso('));
    final url = File('ios/AvisoEnVivo/Vistas.swift').readAsStringSync();
    expect(url, contains('URLComponents()'));
    final escenas = File('ios/Runner/SceneDelegate.swift').readAsStringSync();
    expect(escenas, contains('connectionOptions.urlContexts'));
    expect(escenas, contains('openURLContexts'));
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    expect(plist, contains('<string>yaviene</string>'));
    expect(plist, contains('<key>FlutterDeepLinkingEnabled</key>'));
    expect(plist, contains('<false/>'));

    final mapa = File('lib/features/map/presentation/widgets/map_widget.dart')
        .readAsStringSync();
    expect(mapa, contains('ref.listenManual(enfoqueDeBusProvider'));
    // Los buses llegan después de escoger la ruta: cada lote vuelve a mirar
    // si el pedido ya se puede cumplir.
    final lote = mapa.substring(mapa.indexOf('void _updateBusSourceData('));
    expect(lote.substring(0, lote.indexOf('\n  }\n')),
        contains('_enfocarBusPedido();'));
  });
}
