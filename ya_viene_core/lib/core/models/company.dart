import 'package:equatable/equatable.dart';

/// Empresa transportadora. Corresponde a la entidad [Empresa] del modelo
/// de datos en Plan.md, Sección 3.
class Company extends Equatable {
  final String id;
  final String name;

  const Company({required this.id, required this.name});

  @override
  List<Object?> get props => [id, name];
}
