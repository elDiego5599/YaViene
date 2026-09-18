import 'package:equatable/equatable.dart';

class RouteInfo extends Equatable {
  final String id;
  final String name;
  final String companyId;
  final String? terminalA;
  final String? terminalB;

  const RouteInfo({
    required this.id,
    required this.name,
    required this.companyId,
    this.terminalA,
    this.terminalB,
  });

  /// El backend manda el identificador como `routeId`, el nombre que usa el
  /// resto del contrato, y lo repite como `id` para las apps ya instaladas.
  /// Se lee `routeId` primero y se cae a `id` para seguir entendiendo a un
  /// backend anterior; también es la clave que deja [toJson].
  factory RouteInfo.fromJson(Map<String, dynamic> json) {
    return RouteInfo(
      id: json['routeId'] as String? ?? json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      companyId: json['companyId'] as String? ?? '',
      terminalA: json['terminalA'] as String?,
      terminalB: json['terminalB'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'companyId': companyId,
      'terminalA': terminalA,
      'terminalB': terminalB,
    };
  }

  RouteInfo copyWith({
    String? id,
    String? name,
    String? companyId,
    String? terminalA,
    String? terminalB,
  }) {
    return RouteInfo(
      id: id ?? this.id,
      name: name ?? this.name,
      companyId: companyId ?? this.companyId,
      terminalA: terminalA ?? this.terminalA,
      terminalB: terminalB ?? this.terminalB,
    );
  }

  @override
  List<Object?> get props => [id, name, companyId, terminalA, terminalB];
}
