import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/fleet_api.dart';
import '../../data/fleet_socket_service.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/fleet_bus.dart';

enum FleetConnection { connecting, connected, disconnected }

class FleetState {
  const FleetState({
    this.connection = FleetConnection.connecting,
    this.buses = const <String, FleetBus>{},
    this.error,
    this.updating = const <String>{},
    this.selectedBusId,
  });

  final FleetConnection connection;
  final Map<String, FleetBus> buses;
  final String? error;
  final Set<String> updating;
  final String? selectedBusId;

  FleetBus? get selectedBus {
    final id = selectedBusId;
    return id == null ? null : buses[id];
  }

  List<FleetBus> get fleetList {
    final list = buses.values.toList()
      ..sort((a, b) => a.busId.compareTo(b.busId));
    return list;
  }

  FleetState copyWith({
    FleetConnection? connection,
    Map<String, FleetBus>? buses,
    String? error,
    Set<String>? updating,
    String? Function()? selectedBusId,
    bool clearError = false,
  }) {
    return FleetState(
      connection: connection ?? this.connection,
      buses: buses ?? this.buses,
      error: clearError ? null : error ?? this.error,
      updating: updating ?? this.updating,
      selectedBusId: selectedBusId != null ? selectedBusId() : this.selectedBusId,
    );
  }
}

class FleetNotifier extends StateNotifier<FleetState> {
  FleetNotifier(this._ref) : super(const FleetState());

  final Ref _ref;
  FleetSocketService? _socket;

  String? get _token => _ref.read(authProvider).session?.token;

  void start() {
    final token = _token;
    if (token == null) return;
    _socket?.dispose();
    final socket = FleetSocketService(token: token);
    _socket = socket;
    socket.connectionStream.listen((connected) {
      state = state.copyWith(
        connection: connected ? FleetConnection.connected : FleetConnection.disconnected,
      );
    });
    socket.busBatchStream.listen((buses) {
      final map = <String, FleetBus>{for (final b in buses) b.busId: b};
      state = state.copyWith(buses: map, clearError: true);
    });
    socket.busPositionStream.listen((bus) {
      final previous = state.buses[bus.busId];
      state = state.copyWith(buses: {
        ...state.buses,
        bus.busId: bus.copyWith(
          online: true,
          visible: previous?.visible ?? bus.visible,
        ),
      });
    });
    socket.busHiddenStream.listen((busId) {
      final previous = state.buses[busId];
      if (previous == null) return;
      state = state.copyWith(buses: {
        ...state.buses,
        busId: previous.copyWith(visible: false),
      });
    });
    socket.busVisibleStream.listen((bus) {
      final previous = state.buses[bus.busId];
      state = state.copyWith(buses: {
        ...state.buses,
        bus.busId: bus.copyWith(
          visible: true,
          online: previous?.online ?? true,
        ),
      });
    });
    socket.busLeftStream.listen((busId) {
      final previous = state.buses[busId];
      if (previous == null) return;
      state = state.copyWith(buses: {
        ...state.buses,
        busId: previous.copyWith(online: false, clearPosition: true),
      });
    });
    socket.connect();
  }

  Future<void> refresh() async {
    final token = _token;
    if (token == null) return;
    try {
      final buses = await FleetApi().fetchPositions(token);
      state = state.copyWith(
        buses: {for (final b in buses) b.busId: b},
        clearError: true,
      );
    } catch (_) {
      state = state.copyWith(error: 'No se pudo actualizar la flota.');
    }
  }

  void selectBus(String? busId) {
    state = state.copyWith(selectedBusId: () => busId);
  }

  Future<void> toggleVisibility(String busId, bool visible) async {
    final token = _token;
    if (token == null) return;
    state = state.copyWith(updating: {...state.updating, busId});
    try {
      await FleetApi().setVisibility(token, busId, visible);
    } catch (_) {
      state = state.copyWith(
        error: visible ? 'No se pudo mostrar el bus $busId.' : 'No se pudo ocultar el bus $busId.',
      );
    } finally {
      state = state.copyWith(
        updating: {...state.updating}..remove(busId),
      );
    }
  }

  @override
  void dispose() {
    _socket?.dispose();
    super.dispose();
  }
}

final fleetProvider = StateNotifierProvider<FleetNotifier, FleetState>((ref) {
  return FleetNotifier(ref);
});
