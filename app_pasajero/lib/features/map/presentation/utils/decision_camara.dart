/// Decide si un encuadre automático todavía puede mover la cámara.
///
/// El foco de un aviso se conserva hasta que cambia la ruta. Así, un
/// `fitLiveViewport` que ya estaba esperando el margen de MapLibre tampoco
/// puede ejecutar después de que el viaje al bus haya empezado.
class DecisionCamara {
  DecisionCamara({bool hayPedidoDeAviso = false})
      : _avisoPendiente = hayPedidoDeAviso,
        _avisoActivo = hayPedidoDeAviso;

  bool _avisoPendiente;
  bool _avisoActivo;

  bool get permiteEncuadreAutomatico => !_avisoActivo;

  void pedirFocoDeAviso() {
    _avisoPendiente = true;
    _avisoActivo = true;
  }

  /// Devuelve true solo para el bus del aviso pendiente y reserva la cámara
  /// para ese viaje, aunque el proveedor del pedido se limpie enseguida.
  bool enfocarBusDisponible() {
    if (!_avisoPendiente) return false;
    _avisoPendiente = false;
    _avisoActivo = true;
    return true;
  }

  /// El usuario eligió otra ruta: los encuadres automáticos vuelven a estar
  /// permitidos salvo que el nuevo pedido ya haya llegado.
  void cambioDeRuta({bool hayPedidoDeAviso = false}) {
    _avisoPendiente = hayPedidoDeAviso;
    _avisoActivo = hayPedidoDeAviso;
  }
}
