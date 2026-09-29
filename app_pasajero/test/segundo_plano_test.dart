// El servicio de fondo de Android solo vive mientras hay un aviso armado
// (auditoría 2026-09, H1).
//
// Arrancaba al abrir el mapa, con o sin aviso, y solo se paraba en el
// arranque en frío siguiente: la notificación fija «Seguimiento de buses»
// se quedaba puesta sin nada que seguir, y el socket seguía bajando
// posiciones con la app en el fondo. Ahora lo manda la lista de avisos
// activos: el primero lo enciende y el último, al quitarse o al sonar, lo
// apaga. Cerrar la app también lo apaga.
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/tracking_providers.dart';
import 'package:ya_viene_pasajero/features/notifications/presentation/providers/proximity_alerts_provider.dart';

import 'helpers/mapa.dart';

void main() {
  /// Arma el aviso de [busId] como lo hace el botón de la hoja.
  void armar(MapaDePrueba mapa, String busId) {
    mapa.container.read(activeAlertsProvider.notifier).toggleAlert(busId);
    mapa.container
        .read(proximityAlertsProvider.notifier)
        .armAlert(busId, rutaDePrueba.id);
  }

  void quitar(MapaDePrueba mapa, String busId) {
    mapa.container.read(activeAlertsProvider.notifier).deactivateAlert(busId);
    mapa.container.read(proximityAlertsProvider.notifier).disarmAlert(busId);
  }

  testWidgets('abrir el mapa sin avisos no enciende el servicio',
      (tester) async {
    final mapa = await MapaDePrueba.montar(tester);
    await tester.pump(const Duration(seconds: 1));

    expect(mapa.servicio.pedidos, isEmpty);
    await mapa.desmontar(tester);
  });

  testWidgets('el primer aviso lo enciende y quitar el último lo apaga',
      (tester) async {
    final mapa = await MapaDePrueba.montar(tester);
    mapa.repo.foto([10.95, 10.94]);
    await tester.pump(const Duration(milliseconds: 300));

    armar(mapa, 'BUS-SQA220');
    await tester.pump();
    expect(mapa.servicio.pedidos, ['encender']);

    armar(mapa, 'BUS-SQA221');
    quitar(mapa, 'BUS-SQA220');
    await tester.pump();
    expect(mapa.servicio.pedidos, ['encender'],
        reason: 'queda un aviso armado: el servicio sigue');

    quitar(mapa, 'BUS-SQA221');
    await tester.pump();
    expect(mapa.servicio.pedidos, ['encender', 'apagar']);
    await mapa.desmontar(tester);
  });

  testWidgets('si el último aviso suena, el servicio se apaga', (tester) async {
    final mapa = await MapaDePrueba.montar(tester);
    // A unos 110 m del punto de espera: dentro del radio.
    mapa.repo.foto([10.991]);
    await tester.pump(const Duration(milliseconds: 300));
    armar(mapa, 'BUS-SQA220');
    await tester.pump();

    await tester.runAsync(
        () => mapa.container.read(proximityAlertsProvider.notifier).check());
    await tester.pump();

    expect(mapa.avisados, ['BUS-SQA220']);
    expect(mapa.servicio.pedidos, ['encender', 'apagar']);
    await mapa.desmontar(tester);
  });

  testWidgets('cerrar la app lo apaga; volver con el aviso lo enciende',
      (tester) async {
    final mapa = await MapaDePrueba.montar(tester);
    mapa.repo.foto([10.95]);
    await tester.pump(const Duration(milliseconds: 300));
    armar(mapa, 'BUS-SQA220');
    await tester.pump();

    for (final estado in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(estado);
    }
    expect(mapa.servicio.pedidos, ['encender'],
        reason: 'pasar a otra app no lo apaga: para eso existe');

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.detached);
    expect(mapa.servicio.pedidos, ['encender', 'apagar']);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    expect(mapa.servicio.pedidos, ['encender', 'apagar', 'encender']);
    await mapa.desmontar(tester);
  });

  testWidgets('mientras está encendido, la app le da señales de vida',
      (tester) async {
    final mapa = await MapaDePrueba.montar(tester);
    mapa.repo.foto([10.95]);
    await tester.pump(const Duration(milliseconds: 300));
    armar(mapa, 'BUS-SQA220');
    await tester.pump();

    await tester.pump(const Duration(seconds: 61));
    expect(mapa.servicio.latidos, greaterThanOrEqualTo(3));

    quitar(mapa, 'BUS-SQA220');
    await tester.pump();
    final alApagar = mapa.servicio.latidos;
    await tester.pump(const Duration(seconds: 61));
    expect(mapa.servicio.latidos, alApagar, reason: 'apagado no late');
    await mapa.desmontar(tester);
  });

  test('el manifiesto para el servicio al quitar la app de recientes', () {
    // Con `stopWithTask="false"` el servicio seguía vivo después de
    // deslizar la app, sin el motor que lleva el socket y los avisos.
    final manifiesto =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    expect(manifiesto, contains('android:stopWithTask="true"'));
    expect(manifiesto, isNot(contains('android:stopWithTask="false"')));
  });
}
