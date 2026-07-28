import 'package:equatable/equatable.dart';

class RouteInfo extends Equatable {
  final String id;
  final String name;
  final String companyId;

  const RouteInfo({
    required this.id,
    required this.name,
    required this.companyId,
  });

  factory RouteInfo.fromJson(Map<String, dynamic> json) {
    return RouteInfo(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      companyId: json['companyId'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'companyId': companyId,
    };
  }

  RouteInfo copyWith({
    String? id,
    String? name,
    String? companyId,
  }) {
    return RouteInfo(
      id: id ?? this.id,
      name: name ?? this.name,
      companyId: companyId ?? this.companyId,
    );
  }

  @override
  List<Object?> get props => [id, name, companyId];
}
