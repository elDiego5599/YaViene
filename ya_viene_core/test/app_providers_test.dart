import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ya_viene_core/ya_viene_core.dart';

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

  test('selectedRoute persiste aunque nadie lo mire (no autoDispose)', () async {
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
}
