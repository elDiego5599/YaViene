import 'package:flutter/material.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import 'active_turn_dashboard.dart';

class TurnAssignmentScreen extends StatefulWidget {
  const TurnAssignmentScreen({super.key});

  @override
  State<TurnAssignmentScreen> createState() => _TurnAssignmentScreenState();
}

class _TurnAssignmentScreenState extends State<TurnAssignmentScreen> {
  String? _selectedBus;
  String? _selectedRoute;

  void _startTurn() {
    if (_selectedBus == null || _selectedRoute == null) return;
    
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ActiveTurnDashboard(
          empresaId: 'EMP-01',
          busId: _selectedBus!,
          routeId: _selectedRoute!,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Asignación de Turno'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Selecciona los datos operativos del día',
              style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.xl),
            
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Bus asignado'),
              items: const [
                DropdownMenuItem(value: 'B-042', child: Text('Bus 042 - Placa XYZ123')),
                DropdownMenuItem(value: 'B-015', child: Text('Bus 015 - Placa ABC987')),
              ],
              onChanged: (v) => setState(() => _selectedBus = v),
            ),
            
            const SizedBox(height: AppSpacing.md),
            
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Ruta a cubrir'),
              items: const [
                DropdownMenuItem(value: 'R-101', child: Text('Ruta 1 - Centro/Soledad')),
                DropdownMenuItem(value: 'R-102', child: Text('Ruta 2 - Murillo')),
              ],
              onChanged: (v) => setState(() => _selectedRoute = v),
            ),
            
            const Spacer(),
            
            PrimaryButton(
              label: 'INICIAR TRANSMISIÓN',
              icon: Icons.cell_tower_rounded,
              onPressed: _selectedBus != null && _selectedRoute != null
                  ? _startTurn
                  : null,
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }
}
