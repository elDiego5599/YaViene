import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/fleet_bus.dart';
import '../../domain/fleet_route.dart';
import '../providers/fleet_providers.dart';

class BusEditResult {
  const BusEditResult({required this.placa, this.routeId});

  final String placa;
  final String? routeId;
}

class BusDialog extends ConsumerStatefulWidget {
  const BusDialog({super.key, this.bus});

  final FleetBus? bus;

  @override
  ConsumerState<BusDialog> createState() => _BusDialogState();
}

class _BusDialogState extends ConsumerState<BusDialog> {
  late final TextEditingController _placaController;
  String? _routeId;
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.bus != null;

  @override
  void initState() {
    super.initState();
    _placaController = TextEditingController(text: widget.bus?.placa ?? '');
    _routeId = widget.bus?.routeId;
  }

  @override
  void dispose() {
    _placaController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final placa = _placaController.text.trim();
    if (!RegExp(r'^[A-Z0-9]{4,10}$').hasMatch(placa.toUpperCase())) {
      setState(() => _error = 'Placa inválida. Ejemplo: ABC123');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (_isEdit) {
        await ref.read(fleetProvider.notifier).editBus(
              widget.bus!.busId,
              placa: placa,
              routeId: _routeId,
            );
      } else {
        await ref.read(fleetProvider.notifier).addBus(
              placa: placa,
              routeId: _routeId,
            );
      }
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'No se pudo guardar el bus. Intenta de nuevo.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final routes = ref.watch(fleetProvider).routes;
    final sortedRoutes = [...routes]
      ..sort((a, b) => a.routeId.compareTo(b.routeId));

    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.navy.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              _isEdit ? Icons.edit_outlined : Icons.directions_bus,
              size: 18,
              color: AppColors.navy,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            _isEdit ? 'Editar bus' : 'Nuevo bus',
            style: GoogleFonts.inter(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'PLACA',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _placaController,
              textCapitalization: TextCapitalization.characters,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
              ),
              decoration: const InputDecoration(hintText: 'ABC123'),
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 18),
            Text(
              'RUTA',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String?>(
              initialValue: _routeId,
              isExpanded: true,
              decoration: const InputDecoration(),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Sin ruta asignada'),
                ),
                ...sortedRoutes.map(
                  (FleetRoute route) => DropdownMenuItem<String?>(
                    value: route.routeId,
                    child: Text('${route.routeId} · ${route.name}'),
                  ),
                ),
              ],
              onChanged: (value) => setState(() => _routeId = value),
            ),
            if (_error != null) ...[
              const SizedBox(height: 14),
              Text(
                _error!,
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.danger,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.online,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: GoogleFonts.inter(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(_isEdit ? 'GUARDAR' : 'AGREGAR'),
        ),
      ],
    );
  }
}
