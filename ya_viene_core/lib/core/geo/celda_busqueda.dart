/// Centro de celda de búsqueda. Debe coincidir con
/// `YaVieneBackend/src/data/busquedas.ts`: latitud redondeada a 0.00135 y
/// longitud a 0.00137. El backend valida el centro con tolerancia 1e-7.
({double lat, double lng}) centroCeldaBusqueda(double lat, double lng) => (
      // Se conserva el redondeo final a ocho decimales que espera el contrato.
      lat: _redondeoServidor(_redondeoServidor(lat / 0.00135) * 0.00135 * 1e8) /
          1e8,
      lng: _redondeoServidor(_redondeoServidor(lng / 0.00137) * 0.00137 * 1e8) /
          1e8,
    );

/// JavaScript Math.round equivale a floor(x + 0.5), también para negativos.
int _redondeoServidor(double valor) => (valor + 0.5).floor();
