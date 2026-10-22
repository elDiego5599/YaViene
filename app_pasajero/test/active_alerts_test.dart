import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/active_alerts_provider.dart';

void main() {
  // Activar es idempotente: la hoja, el historial y «Deshacer» pueden
  // activar el mismo bus otra vez. Con el cupo lleno eso no puede contestar
  // «no hay cupo» por un aviso que ya está puesto.
  test('activar otra vez un aviso ya activo, con el cupo lleno, sigue bien',
      () {
    final avisos = ActiveAlertsNotifier();
    addTearDown(avisos.dispose);

    expect(avisos.activateAlert('A-1'), isTrue);
    expect(avisos.activateAlert('A-2'), isFalse);
    expect(avisos.activateAlert('A-1'), isTrue);
    expect(avisos.activateAlert('A-3'), isFalse);
    expect(avisos.state, {'A-1'});
  });

  test('sustituir un aviso cambia el bus en una sola transición', () {
    final avisos = ActiveAlertsNotifier();
    addTearDown(avisos.dispose);
    final estados = <Set<String>>[];
    avisos.addListener((estado) => estados.add(estado));

    expect(avisos.activateAlert('A-1'), isTrue);
    estados.clear();
    expect(avisos.replaceAlert('A-1', 'B-1'), isTrue);

    expect(estados, [
      <String>{'B-1'}
    ]);
    expect(avisos.state, {'B-1'});
    expect(avisos.replaceAlert('A-1', 'C-1'), isFalse);
    expect(avisos.state, {'B-1'});
  });
}
