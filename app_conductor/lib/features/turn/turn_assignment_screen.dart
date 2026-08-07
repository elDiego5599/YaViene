import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import '../../config.dart';
import 'active_turn_dashboard.dart';

class TurnAssignmentScreen extends StatefulWidget {
  final String? phoneNumber;
  final String? pin;

  const TurnAssignmentScreen({super.key, this.phoneNumber, this.pin});

  @override
  State<TurnAssignmentScreen> createState() => _TurnAssignmentScreenState();
}

class _TurnAssignmentScreenState extends State<TurnAssignmentScreen> {
  String? _selectedBus;
  String? _selectedRoute;
  bool _loading = false;
  bool _dataLoading = true;
  String? _loadError;
  List<Map<String, dynamic>> _routes = [];
  List<Map<String, dynamic>> _buses = [];

  @override
  void initState() {
    super.initState();
    if (AppConfig.demoMode) _loadDemoData();
  }

  Future<void> _loadDemoData() async {
    setState(() {
      _dataLoading = true;
      _loadError = null;
    });

    final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
    try {
      final base = '${AppConfig.backendUrl}/api/companies/${AppConfig.demoCompanyId}';

      final routesReq = await client.getUrl(Uri.parse('$base/routes'));
      final routesRes = await routesReq.close();
      final routesBody = await routesRes.transform(utf8.decoder).join();
      if (routesRes.statusCode != 200) {
        throw HttpException('Error cargando rutas (${routesRes.statusCode})');
      }
      final routes = (jsonDecode(routesBody) as List)
          .cast<Map<String, dynamic>>();

      final busesReq = await client.getUrl(Uri.parse('$base/buses'));
      final busesRes = await busesReq.close();
      final busesBody = await busesRes.transform(utf8.decoder).join();
      if (busesRes.statusCode != 200) {
        throw HttpException('Error cargando buses (${busesRes.statusCode})');
      }
      final buses = (jsonDecode(busesBody) as List)
          .cast<Map<String, dynamic>>()
          .where((b) => b['routeId'] != null && (b['routeId'] as String).isNotEmpty)
          .toList();

      if (!mounted) return;
      setState(() {
        _routes = routes;
        _buses = buses;
        _dataLoading = false;
        _selectedRoute = routes.isNotEmpty ? routes.first['id'] as String : null;
        _selectedBus = buses.isNotEmpty ? buses.first['busId'] as String : null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _dataLoading = false;
        _loadError = 'No se pudieron cargar buses y rutas.\n$e';
      });
    } finally {
      client.close(force: true);
    }
  }

  Future<void> _startTurn() async {
    if (_selectedBus == null || _selectedRoute == null) return;

    setState(() => _loading = true);

    final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
    try {
      final (uri, payload) = AppConfig.demoMode
          ? (
              Uri.parse('${AppConfig.backendUrl}/api/demo/session'),
              {
                'companyId': AppConfig.demoCompanyId,
                'busId': _selectedBus,
                'routeId': _selectedRoute,
              },
            )
          : (
              Uri.parse('${AppConfig.backendUrl}/api/auth/login'),
              {
                'phoneNumber': widget.phoneNumber,
                'pin': widget.pin,
                'busId': _selectedBus,
                'routeId': _selectedRoute,
              },
            );

      final request = await client.postUrl(uri);
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(payload));

      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      final data = jsonDecode(body) as Map<String, dynamic>;
      if (response.statusCode != 200) {
        throw HttpException('Autenticación rechazada (${response.statusCode})');
      }
      final token = data['token'] as String?;
      final driver = data['driver'] as Map<String, dynamic>?;
      final companyId = driver?['companyId'] as String?;
      if (token == null || companyId == null || companyId.isEmpty) {
        throw const FormatException('Respuesta de autenticación incompleta');
      }

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ActiveTurnDashboard(
            empresaId: companyId,
            busId: _selectedBus!,
            routeId: _selectedRoute!,
            phoneNumber: AppConfig.demoMode
                ? 'demo:$_selectedBus'
                : widget.phoneNumber!,
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
    } finally {
      client.close(force: true);
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
              AppConfig.demoMode
                  ? 'Modo demo — selecciona bus y ruta para transmitir'
                  : 'Selecciona los datos operativos del día',
              style:
                  AppTextStyles.body.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.xl),
            if (_dataLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.xl),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_loadError != null)
              Column(
                children: [
                  Text(
                    _loadError!,
                    style: AppTextStyles.body
                        .copyWith(color: AppColors.error),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  OutlinedButton.icon(
                    onPressed: _loadDemoData,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Reintentar'),
                  ),
                ],
              )
            else ...[
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Bus asignado'),
                initialValue: _selectedBus,
                items: [
                  for (final bus in _buses)
                    DropdownMenuItem(
                      value: bus['busId'] as String,
                      child: Text(
                        '${bus['interno'] ?? ''} - Placa ${bus['placa'] ?? bus['busId']}',
                      ),
                    ),
                ],
                onChanged: (v) => setState(() => _selectedBus = v),
              ),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Ruta a cubrir'),
                initialValue: _selectedRoute,
                items: [
                  for (final route in _routes)
                    DropdownMenuItem(
                      value: route['id'] as String,
                      child: Text('${route['name']} (${route['id']})'),
                    ),
                ],
                onChanged: (v) => setState(() => _selectedRoute = v),
              ),
              const Spacer(),
              PrimaryButton(
                label: _loading ? 'CONECTANDO...' : 'INICIAR TRANSMISIÓN',
                icon: _loading
                    ? Icons.hourglass_top_rounded
                    : Icons.cell_tower_rounded,
                onPressed: _selectedBus != null &&
                        _selectedRoute != null &&
                        !_loading
                    ? _startTurn
                    : null,
              ),
              const SizedBox(height: AppSpacing.md),
            ],
          ],
        ),
      ),
    );
  }
}
