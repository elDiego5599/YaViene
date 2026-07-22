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

  @override
  List<Object?> get props => [id, name, companyId];
}
