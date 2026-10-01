import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/ventana.dart';
import '../../domain/fleet_bus.dart';
import '../../domain/fleet_route.dart';
import '../providers/fleet_providers.dart';

class BusDialog extends ConsumerStatefulWidget {
  const BusDialog({super.key, this.bus, this.onDelete});

  final FleetBus? bus;
  final VoidCallback? onDelete;

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
    final routes = ref.read(fleetProvider).routes;
    if (_routeId == null || !routes.any((r) => r.routeId == _routeId)) {
      if (routes.isNotEmpty) {
        final sorted = [
          ...routes,
        ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        _routeId = sorted.first.routeId;
      }
    }
  }

  @override
  void dispose() {
    _placaController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final placa = _placaController.text.trim();
    if (!RegExp(r'^[A-Z]{3}[0-9]{3}$').hasMatch(placa.toUpperCase())) {
      setState(() => _error = 'Placa inválida. Ejemplo: ABC123');
      return;
    }
    final routes = ref.read(fleetProvider).routes;
    final effectiveRouteId = routes.any((r) => r.routeId == _routeId)
        ? _routeId
        : (routes.isNotEmpty ? routes.first.routeId : null);
    if (effectiveRouteId == null) {
      setState(() => _error = 'Selecciona una ruta para el bus.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (_isEdit) {
        await ref
            .read(fleetProvider.notifier)
            .editBus(
              widget.bus!.busId,
              placa: placa,
              routeId: effectiveRouteId,
            );
      } else {
        await ref
            .read(fleetProvider.notifier)
            .addBus(placa: placa, routeId: effectiveRouteId);
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

  Future<void> _confirmDelete() async {
    final bus = widget.bus!;
    final confirmed = await confirmarBorrado(
      context,
      titulo: 'Eliminar bus',
      mensaje:
          '¿Eliminar ${bus.placa.isEmpty ? bus.busId : bus.placa} de la '
          'flota? Los pasajeros dejarán de verlo de inmediato. Esta acción no '
          'se puede deshacer.',
    );
    if (confirmed && mounted) {
      Navigator.of(context).pop();
      widget.onDelete?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final routes = ref.watch(fleetProvider).routes;
    final sortedRoutes = [...routes]
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final selectedRouteId = sortedRoutes.any((r) => r.routeId == _routeId)
        ? _routeId
        : (sortedRoutes.isNotEmpty ? sortedRoutes.first.routeId : null);

    return Ventana(
      icono: _isEdit ? Icons.edit_outlined : Icons.directions_bus,
      titulo: _isEdit ? 'Editar bus' : 'Nuevo bus',
      secundaria: VentanaAccion(
        'Cancelar',
        _saving ? null : () => Navigator.of(context).pop(),
      ),
      principal: VentanaAccion(
        _isEdit ? 'GUARDAR' : 'AGREGAR',
        _save,
        cargando: _saving,
      ),
      contenido: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PLACA',
            style: AppType.ui(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            // Al abrir, el foco va a la placa: con teclado o lector de
            // pantalla se empieza a escribir sin buscar el campo.
            autofocus: true,
            controller: _placaController,
            textCapitalization: TextCapitalization.characters,
            style: AppType.mono(
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
            style: AppType.ui(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String?>(
            initialValue: selectedRouteId,
            isExpanded: true,
            decoration: const InputDecoration(),
            // El menú que se despliega era el de fábrica: gris azulado del
            // tema semilla y esquinas de 4. Va en el blanco y el radio de
            // los campos, que es lo que es: la lista del campo abierta.
            dropdownColor: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            items: sortedRoutes.isEmpty
                ? null
                : [
                    ...sortedRoutes.map(
                      (FleetRoute route) => DropdownMenuItem<String?>(
                        value: route.routeId,
                        child: Text(route.name),
                      ),
                    ),
                  ],
            onChanged: (value) => setState(() => _routeId = value),
          ),
          if (sortedRoutes.isEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'No hay rutas. Crea una primero con "Agregar ruta".',
              style: AppType.ui(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.danger,
              ),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 14),
            Text(
              _error!,
              style: AppType.ui(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppColors.danger,
              ),
            ),
          ],
          if (_isEdit) ...[
            const SizedBox(height: 20),
            const Divider(height: 1),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _saving ? null : _confirmDelete,
                icon: const Icon(Icons.delete_outline, size: 17),
                label: const Text('Eliminar bus de la flota'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.danger,
                  side: BorderSide(
                    color: AppColors.danger.withValues(alpha: 0.5),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  textStyle: AppType.ui(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
