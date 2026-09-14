import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_core/ya_viene_core.dart';

const _principal = 'https://tunel.ngrok-free.dev';
const _respaldo = 'https://ya-viene-backend.fly.dev';

void main() {
  test('selectedCompany persiste hasta clear', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(selectedCompanyProvider), isNull);
    container.read(selectedCompanyProvider.notifier).select(
          const Company(id: 'C1', name: 'Test'),
        );
    expect(container.read(selectedCompanyProvider)?.id, 'C1');
    container.read(selectedCompanyProvider.notifier).clear();
    expect(container.read(selectedCompanyProvider), isNull);
  });

  test('selectedRoute persiste aunque nadie lo mire (no autoDispose)',
      () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(selectedRouteProvider.notifier).select(
          const RouteInfo(id: 'R1', name: 'Ruta 1', companyId: 'C1'),
        );
    expect(container.read(selectedRouteProvider)?.id, 'R1');
    // Simula que nadie lo escucha un frame: con autoDispose se borraría
    await Future.delayed(Duration.zero);
    expect(container.read(selectedRouteProvider)?.id, 'R1',
        reason: 'no debe borrarse solo');
    container.read(selectedRouteProvider.notifier).clear();
    expect(container.read(selectedRouteProvider), isNull);
  });

  group('enRespaldoProvider', () {
    ProviderContainer app(BackendUrl Function() backend) {
      final container = ProviderContainer(
        overrides: [backendUrlProvider.overrideWith(backend)],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('en el principal no está en el respaldo', () {
      final c = app(() => BackendUrl(
            _principal,
            principal: _principal,
            respaldo: _respaldo,
          ));
      expect(c.read(enRespaldoProvider), isFalse);
    });

    test('en el respaldo sí', () {
      final c = app(() => BackendUrl(
            _respaldo,
            principal: _principal,
            respaldo: _respaldo,
          ));
      expect(c.read(enRespaldoProvider), isTrue);
    });

    test('pasa a sí cuando la app se muda al respaldo estando abierta',
        () async {
      final c = app(() => BackendUrl(
            _principal,
            principal: _principal,
            respaldo: _respaldo,
            sonda: (url, espera) async => url == _respaldo,
          ));
      final vistos = <bool>[];
      c.listen<bool>(enRespaldoProvider, (_, enRespaldo) {
        vistos.add(enRespaldo);
      }, fireImmediately: true);

      await c.read(backendUrlProvider.notifier).reResolver();

      expect(c.read(enRespaldoProvider), isTrue);
      expect(vistos, [false, true]);
    });

    test('una URL fija, o un respaldo igual al principal, nunca lo está', () {
      expect(app(() => BackendUrl.fija(_respaldo)).read(enRespaldoProvider),
          isFalse);
      expect(
        app(() => BackendUrl(
              _principal,
              principal: _principal,
              respaldo: _principal,
            )).read(enRespaldoProvider),
        isFalse,
      );
    });
  });
}
