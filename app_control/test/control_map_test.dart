import 'package:flutter_test/flutter_test.dart';

import 'package:ya_viene_control/features/fleet/domain/fleet_bus.dart';
import 'package:ya_viene_control/features/fleet/presentation/providers/fleet_providers.dart';

// Replica el filtro de ControlMap._buildMarkers (control_map.dart:39-40):
// entran al mapa todos los buses con posición conocida, ocultos incluidos
// —el operador necesita verlos para poder volver a mostrarlos; se pintan
// en gris (ver _buildMarker: active considera bus.visible).
Iterable<FleetBus> _markerCandidates(FleetState fleet) =>
    fleet.fleetList.where((b) => b.lat != null && b.lon != null);

void main() {
  test(
    'los buses con lat/lon llegan al mapa, visibles u ocultos; sin posición no',
    () {
      const withPosition = FleetBus(
        busId: 'B-1',
        companyId: 'c-1',
        visible: true,
        online: true,
        lat: 10.9,
        lon: -74.8,
      );
      const visibleSinPosicion = FleetBus(
        busId: 'B-2',
        companyId: 'c-1',
        visible: true,
        online: false,
      );
      const ocultoConPosicion = FleetBus(
        busId: 'B-3',
        companyId: 'c-1',
        visible: false,
        online: true,
        lat: 10.9,
        lon: -74.8,
      );

      final state = FleetState(
        buses: {
          for (final b in [withPosition, visibleSinPosicion, ocultoConPosicion])
            b.busId: b,
        },
      );

      final markers = _markerCandidates(state);

      expect(markers.map((b) => b.busId).toSet(), {'B-1', 'B-3'});
    },
  );

  test(
    'un bus que pierde la posición (bus:left) desaparece del mapa aunque siga visible',
    () {
      const visto = FleetBus(
        busId: 'B-1',
        companyId: 'c-1',
        visible: true,
        online: true,
        lat: 10.9,
        lon: -74.8,
      );
      final seFue = visto.copyWith(online: false, clearPosition: true);

      const antes = FleetState(buses: {'B-1': visto});
      final despues = FleetState(buses: {'B-1': seFue});

      expect(_markerCandidates(antes).length, 1);
      expect(_markerCandidates(despues), isEmpty);
    },
  );

  test(
    'el filtro de ruta no afecta a los marcadores directamente, pero sí a fleetList',
    () {
      const enR1 = FleetBus(
        busId: 'B-1',
        companyId: 'c-1',
        routeId: 'R-1',
        visible: true,
        online: true,
        lat: 1,
        lon: 1,
      );
      const enR2 = FleetBus(
        busId: 'B-2',
        companyId: 'c-1',
        routeId: 'R-2',
        visible: true,
        online: true,
        lat: 2,
        lon: 2,
      );
      const state = FleetState(
        buses: {'B-1': enR1, 'B-2': enR2},
        routeFilter: 'R-1',
      );

      expect(_markerCandidates(state).map((b) => b.busId), ['B-1']);
    },
  );
}
