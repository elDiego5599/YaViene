import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_pasajero/features/map/presentation/utils/decision_camara.dart';

void main() {
  test('un encuadre del pin en cola no pisa el viaje al bus del aviso', () {
    final decision = DecisionCamara();

    // El estilo o el GPS ya habían programado centrar el pin, pero la cola de
    // margen de MapLibre aún no ejecutaba ese movimiento.
    expect(decision.permiteEncuadreAutomatico, isTrue);
    bool aplicarPinEncolado() => decision.permiteEncuadreAutomatico;
    decision.pedirFocoDeAviso();

    // Entra el primer lote: el bus pedido ya está disponible y su viaje gana.
    expect(decision.enfocarBusDisponible(), isTrue);

    // El callback tardío del pin y cualquier encuadre de lote/estilo/GPS
    // consultan la misma decisión al ejecutarse, no al quedar encolados.
    expect(aplicarPinEncolado(), isFalse);
    expect(decision.permiteEncuadreAutomatico, isFalse);
    expect(decision.enfocarBusDisponible(), isFalse);
  });

  test('al cambiar de ruta se libera la cámara si no hay otro aviso', () {
    final decision = DecisionCamara(hayPedidoDeAviso: true);
    expect(decision.permiteEncuadreAutomatico, isFalse);

    decision.cambioDeRuta();

    expect(decision.permiteEncuadreAutomatico, isTrue);
  });
}
