import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import '../../config.dart';
import 'active_turn_dashboard.dart';

class TurnAssignmentScreen extends StatefulWidget {
  final String phoneNumber;
  const TurnAssignmentScreen({super.key, required this.phoneNumber});

  @override
  State<TurnAssignmentScreen> createState() => _TurnAssignmentScreenState();
}

class _TurnAssignmentScreenState extends State<TurnAssignmentScreen> {
  String? _selectedBus;
  String? _selectedRoute;
  bool _loading = false;

  Future<void> _startTurn() async {
    if (_selectedBus == null || _selectedRoute == null) return;

    setState(() => _loading = true);

    try {
      final uri = Uri.parse('${AppConfig.backendUrl}/api/drivers/register');
      final client = HttpClient();
      final request = await client.postUrl(uri);
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode({
        'phoneNumber': widget.phoneNumber,
        'busId': _selectedBus,
        'routeId': _selectedRoute,
        'empresaId': 'EMP-01',
      }));

      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      final data = jsonDecode(body) as Map<String, dynamic>;
      final token = data['token'] as String;

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ActiveTurnDashboard(
            empresaId: 'EMP-01',
            busId: _selectedBus!,
            routeId: _selectedRoute!,
            phoneNumber: widget.phoneNumber,
            jwtToken: token,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error de conexión: $e')),
      );
      setState(() => _loading = false);
    }
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
              label: _loading ? 'CONECTANDO...' : 'INICIAR TRANSMISIÓN',
              icon: _loading ? Icons.hourglass_top_rounded : Icons.cell_tower_rounded,
              onPressed: _selectedBus != null && _selectedRoute != null && !_loading
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
