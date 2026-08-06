class FleetRoute {
  const FleetRoute({
    required this.routeId,
    required this.name,
    required this.total,
    required this.online,
  });

  factory FleetRoute.fromJson(Map<String, dynamic> json) {
    return FleetRoute(
      routeId: json['routeId'] as String,
      name: json['name'] as String? ?? json['routeId'] as String,
      total: (json['total'] as num?)?.toInt() ?? 0,
      online: (json['online'] as num?)?.toInt() ?? 0,
    );
  }

  final String routeId;
  final String name;
  final int total;
  final int online;
}
