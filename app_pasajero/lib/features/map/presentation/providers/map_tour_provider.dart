import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Momentos de la primera guía. El orden es deliberado: cada paso se
/// completa con una acción real del usuario, no con un tap arbitrario sobre
/// el velo.
enum MapGuideStep {
  location,
  search,
  company,
  route,
  launchBuses,
  buses,
  eta,
  alert,
  background,
}

class MapGuideState {
  const MapGuideState({
    this.step,
    this.initialized = false,
    this.skipped = false,
    this.completed = false,
  });

  final MapGuideStep? step;
  final bool initialized;
  final bool skipped;
  final bool completed;

  bool get isActive => step != null;
}

/// Estado persistente de la guía completa de primer uso.
///
/// La versión evita que los flags del coach mark anterior (`map_tour_seen` y
/// `map_tour_bus_seen`) oculten esta guía nueva a usuarios que ya actualizaron
/// la aplicación.
class MapGuideNotifier extends StateNotifier<MapGuideState> {
  MapGuideNotifier() : super(const MapGuideState());

  static const _version = 2;
  static const _kVersion = 'map_guide_version';
  static const _kStep = 'map_guide_step';
  static const _kStatus = 'map_guide_status';

  Future<void> initialize({
    required bool hasLocation,
    required bool locationSettled,
    required bool hasRoute,
    required bool hasSelectedBus,
    required bool hasActiveAlert,
  }) async {
    if (state.initialized || !locationSettled) return;

    final prefs = await SharedPreferences.getInstance();
    final storedVersion = prefs.getInt(_kVersion);
    if (storedVersion != _version) {
      await prefs.setInt(_kVersion, _version);
      await prefs.remove(_kStep);
      await prefs.remove(_kStatus);
    }

    final status = prefs.getString(_kStatus);
    if (status == 'skipped' || status == 'completed') {
      state = MapGuideState(
        initialized: true,
        skipped: status == 'skipped',
        completed: status == 'completed',
      );
      return;
    }

    final storedIndex = prefs.getInt(_kStep);
    var step = storedIndex == null
        ? (hasLocation ? MapGuideStep.search : MapGuideStep.location)
        : _stepFromIndex(storedIndex);
    step = _normalizeResumeStep(
      step,
      hasLocation: hasLocation,
      hasRoute: hasRoute,
      hasSelectedBus: hasSelectedBus,
      hasActiveAlert: hasActiveAlert,
    );
    await prefs.setInt(_kStep, step.index);
    state = MapGuideState(step: step, initialized: true);
  }

  /// Completa únicamente el paso que está visible. Así una acción antigua o
  /// un callback tardío no puede saltarse pasos de la guía.
  Future<void> complete(MapGuideStep expected) async {
    if (state.step != expected) return;

    final prefs = await SharedPreferences.getInstance();
    final nextIndex = expected.index + 1;
    if (nextIndex >= MapGuideStep.values.length) {
      await prefs.remove(_kStep);
      await prefs.setString(_kStatus, 'completed');
      state = const MapGuideState(initialized: true, completed: true);
      return;
    }

    await prefs.setInt(_kStep, nextIndex);
    state = MapGuideState(
      step: MapGuideStep.values[nextIndex],
      initialized: true,
    );
  }

  Future<void> skip() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kStep);
    await prefs.setString(_kStatus, 'skipped');
    state = const MapGuideState(initialized: true, skipped: true);
  }

  Future<void> restart({
    required bool hasLocation,
    required bool locationSettled,
  }) async {
    if (!locationSettled) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kStatus);
    final step = hasLocation ? MapGuideStep.search : MapGuideStep.location;
    await prefs.setInt(_kStep, step.index);
    state = MapGuideState(step: step, initialized: true);
  }

  MapGuideStep _stepFromIndex(int index) {
    if (index < 0 || index >= MapGuideStep.values.length) {
      return MapGuideStep.location;
    }
    return MapGuideStep.values[index];
  }

  MapGuideStep _normalizeResumeStep(
    MapGuideStep step, {
    required bool hasLocation,
    required bool hasRoute,
    required bool hasSelectedBus,
    required bool hasActiveAlert,
  }) {
    if (!hasLocation && step.index > MapGuideStep.location.index) {
      return MapGuideStep.location;
    }
    if (!hasRoute && step.index >= MapGuideStep.company.index) {
      return MapGuideStep.search;
    }
    if (hasRoute && !hasSelectedBus && step.index >= MapGuideStep.eta.index) {
      return MapGuideStep.buses;
    }
    if (!hasActiveAlert && step == MapGuideStep.background) {
      return MapGuideStep.alert;
    }
    return step;
  }
}

final mapGuideProvider =
    StateNotifierProvider<MapGuideNotifier, MapGuideState>(
        (ref) => MapGuideNotifier());
