
import 'package:equatable/equatable.dart';


class BusPosition extends Equatable {
  final String busId;
  final String routeId;
  final double lat;
  final double lon;
  final double heading;
  final double speedKmh;
  final DateTime timestamp;
  final bool isGhostBus;

  const BusPosition({
    required this.busId,
    required this.routeId,
    required this.lat,
    required this.lon,
    required this.heading,
    required this.speedKmh,
    required this.timestamp,
    required this.isGhostBus,
  });

  int get secondsSinceUpdate =>
      DateTime.now().difference(timestamp).inSeconds;

  bool get shouldShowAsGhost => secondsSinceUpdate > 90;

  @override
  List<Object?> get props => [busId, routeId, lat, lon, heading, timestamp];
}
