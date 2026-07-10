import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ya_viene_core/ya_viene_core.dart';

final _selectedRouteForMapProvider = Provider((ref) => ref.watch(selectedRouteProvider));

class MapWidget extends ConsumerStatefulWidget {
  final String? routeId;
  const MapWidget({super.key, this.routeId});

  @override
  ConsumerState<MapWidget> createState() => _MapWidgetState();
}

class _MapWidgetState extends ConsumerState<MapWidget> with WidgetsBindingObserver {
  bool _layersReady = false;
  AppLifecycleState _lifecycleState = AppLifecycleState.resumed;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (!kIsWeb) _initMobileMap();
  }

  void _initMobileMap() {
    // Versión nativa: MapLibre GL (Android / iOS / macOS)
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycleState = state;
  }

  @override
  void didUpdateWidget(MapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
  }

  Future<void> _reloadMapData() async {
    if (widget.routeId == null || !mounted) return;
    final trajectoryAsync = ref.read(routeTrajectoryProvider(widget.routeId!));
    final stopsAsync = ref.read(busStopsProvider(widget.routeId!));
  }

  @override
  Widget build(BuildContext context) {
    final selectedRoute = ref.watch(_selectedRouteForMapProvider);

    ref.listen(_selectedRouteForMapProvider, (_, next) {
      if (_layersReady && next != null) {
        _reloadMapData();
      }
    });

    if (kIsWeb) {
      return Container(color: AppColors.background);
    }

    return _buildMobileMap();
  }

  Widget _buildMobileMap() {
    return Container(color: AppColors.background);
  }
}