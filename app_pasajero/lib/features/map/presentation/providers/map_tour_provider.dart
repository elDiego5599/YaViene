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
  distance,
  alert,
  background,
}

class MapGuideState {
  const MapGuideState({
    this.step,
    this.initialized = false,
    this.skipped = false,
    this.completed = false,
    this.includesLocation = true,
  });

  final MapGuideStep? step;
  final bool initialized;
  final bool skipped;
  final bool completed;
  final bool includesLocation;

  bool get isActive => step != null;
}

int mapGuideStepIndex(MapGuideState state, MapGuideStep step) {
  return state.includesLocation ? step.index : step.index - 1;
}

int mapGuideStepCount(MapGuideState state) {
  return state.includesLocation
      ? MapGuideStep.values.length
      : MapGuideStep.values.length - 1;
}

/// Estado persistente de la guía completa de primer uso.
///
/// La versión evita que los flags del coach mark anterior (`map_tour_seen` y
/// `map_tour_bus_seen`) oculten esta guía nueva a usuarios que ya actualizaron
/// la aplicación.
class MapGuideNotifier extends StateNotifier<MapGuideState> {
  MapGuideNotifier() : super(const MapGuideState());

  static const _disabledForTest =
      bool.fromEnvironment('DISABLE_MAP_GUIDE', defaultValue: false);
  static const _version = 2;
  static const _kVersion = 'map_guide_version';
  static const _kStep = 'map_guide_step';
  static const _kStatus = 'map_guide_status';
  static const _kIncludesLocation = 'map_guide_includes_location';
  static const _kUser = 'map_guide_user';
  static const _kEligible = 'map_guide_eligible';

  String? _activeUserId;

  Future<void> initialize({
    required String? userId,
    required bool isNewUser,
    required bool hasLocation,
    required bool locationSettled,
    required bool hasRoute,
    required bool hasSelectedBus,
    required bool hasActiveAlert,
  }) async {
    if (!locationSettled) return;
    if (_disabledForTest) {
      state = const MapGuideState(initialized: true, skipped: true);
      return;
    }
    if (_activeUserId != userId) {
      _activeUserId = userId;
      state = const MapGuideState();
    }
    if (state.initialized) return;

    if (userId == null) {
      state = const MapGuideState(initialized: true);
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final storedUser = prefs.getString(_kUser);
    final sameUser = storedUser == userId;
    if (!sameUser && !isNewUser) {
      // Una cuenta que ya existía en otro dispositivo no tiene derecho a la
      // guía automática: solo la puede pedir explícitamente desde el drawer.
      state = const MapGuideState(initialized: true);
      return;
    }
    if (!sameUser && isNewUser) {
      await prefs.setString(_kUser, userId);
      await prefs.setBool(_kEligible, true);
      await prefs.remove(_kStep);
      await prefs.remove(_kStatus);
      await prefs.remove(_kIncludesLocation);
    }
    if (isNewUser) await prefs.setBool(_kEligible, true);
    final eligible = prefs.getBool(_kEligible) ?? false;
    if (!eligible) {
      state = const MapGuideState(initialized: true);
      return;
    }

    final storedVersion = prefs.getInt(_kVersion);
    if (storedVersion != _version) {
      await prefs.setInt(_kVersion, _version);
      await prefs.remove(_kStep);
      await prefs.remove(_kStatus);
      await prefs.remove(_kIncludesLocation);
    }

    final status = prefs.getString(_kStatus);
    if (status == 'skipped' || status == 'completed') {
      state = MapGuideState(
        initialized: true,
        skipped: status == 'skipped',
        completed: status == 'completed',
        includesLocation: prefs.getBool(_kIncludesLocation) ?? !hasLocation,
      );
      return;
    }

    final storedIndex = prefs.getInt(_kStep);
    // Una guía a medias de una sesión anterior NO se reanuda sola: si el
    // usuario activó la guía pero salió de la app y volvió, la guía no salta.
    // La repite cuando quiera desde el drawer ("Ver guía de uso").
    if (storedIndex != null) {
      state = const MapGuideState(initialized: true);
      return;
    }

    final includesLocation = !hasLocation;
    final step = hasLocation ? MapGuideStep.search : MapGuideStep.location;
    await prefs.setInt(_kStep, step.index);
    await prefs.setBool(_kIncludesLocation, includesLocation);
    state = MapGuideState(
      step: step,
      initialized: true,
      includesLocation: includesLocation,
    );
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
      includesLocation: state.includesLocation,
    );
  }

  Future<void> skip() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kStep);
    await prefs.setString(_kStatus, 'skipped');
    state = const MapGuideState(initialized: true, skipped: true);
  }

  Future<void> moveTo(MapGuideStep step) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kStatus);
    await prefs.setInt(_kStep, step.index);
    state = MapGuideState(
      step: step,
      initialized: true,
      includesLocation: state.includesLocation,
    );
  }

  Future<void> restart({
    required String? userId,
    required bool hasLocation,
    required bool locationSettled,
  }) async {
    if (!locationSettled || userId == null) return;
    _activeUserId = userId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kUser, userId);
    await prefs.setBool(_kEligible, true);
    await prefs.setInt(_kVersion, _version);
    await prefs.remove(_kStatus);
    final step = hasLocation ? MapGuideStep.search : MapGuideStep.location;
    await prefs.setInt(_kStep, step.index);
    await prefs.setBool(_kIncludesLocation, !hasLocation);
    state = MapGuideState(
      step: step,
      initialized: true,
      includesLocation: !hasLocation,
    );
  }
}

final mapGuideProvider = StateNotifierProvider<MapGuideNotifier, MapGuideState>(
    (ref) => MapGuideNotifier());
