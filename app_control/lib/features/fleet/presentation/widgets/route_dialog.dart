import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/fleet_route.dart';
import '../providers/fleet_providers.dart';

class RouteDialog extends ConsumerStatefulWidget {
  const RouteDialog({super.key});

  @override
  ConsumerState<RouteDialog> createState() => _RouteDialogState();
}

class _RouteDialogState extends ConsumerState<RouteDialog> {
  final _nameController = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Escribe un nombre para la ruta.');
      return;
    }
    final routes = ref.read(fleetProvider).routes;
    final exists = routes.any(
      (r) => r.name.toLowerCase() == name.toLowerCase(),
    );
    if (exists) {
      setState(() => _error = 'Ya existe una ruta con ese nombre.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(fleetProvider.notifier).addRoute(name: name);
      _nameController.clear();
      if (mounted) {
        setState(() => _saving = false);
        FocusScope.of(context).unfocus();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = e is Exception
              ? e.toString().replaceFirst('Exception: ', '')
              : 'No se pudo crear la ruta.';
        });
      }
    }
  }

  Future<void> _rename(FleetRoute route) async {
    final controller = TextEditingController(text: route.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
        title: Text(
          'Renombrar ruta',
          style: AppType.ui(
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: TextField(
          controller: controller,
          autocorrect: false,
          autofocus: true,
          style: AppType.ui(fontSize: 14),
          decoration: const InputDecoration(
            hintText: 'Nuevo nombre',
          ),
          onSubmitted: (value) {
            if (value.trim().isNotEmpty) Navigator.of(dialogContext).pop(value);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) Navigator.of(dialogContext).pop(value);
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.online,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              textStyle: AppType.ui(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
            child: const Text('GUARDAR'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (newName == null || newName == route.name) return;
    final routes = ref.read(fleetProvider).routes;
    final exists = routes.any(
      (r) => r.name.toLowerCase() == newName.toLowerCase(),
    );
    if (exists) {
      setState(() => _error = 'Ya existe una ruta con ese nombre.');
      return;
    }
    try {
      await ref.read(fleetProvider.notifier).renameRoute(route.routeId, name: newName);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'No se pudo renombrar la ruta.');
      }
    }
  }

  Future<void> _confirmDelete(FleetRoute route) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
        title: Text(
          'Eliminar ruta',
          style: AppType.ui(
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: Text(
          '¿Eliminar "${route.name}" del catálogo? Los buses que tengan esta '
          'ruta asignada pasarán a la primera ruta restante.',
          style: AppType.ui(fontSize: 13.5, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              textStyle: AppType.ui(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
            child: const Text('ELIMINAR'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await ref.read(fleetProvider.notifier).removeRoute(route.routeId);
      } catch (_) {
        if (mounted) {
          setState(() => _error = 'No se pudo eliminar la ruta.');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final fleet = ref.watch(fleetProvider);
    final sortedRoutes = [...fleet.routes]
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
      title: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.navy.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: const Icon(Icons.route_outlined, size: 18, color: AppColors.navy),
          ),
          const SizedBox(width: 12),
          Text(
            'Rutas',
            style: AppType.ui(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'NUEVA RUTA',
              style: AppType.ui(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    autocorrect: false,
                    style: AppType.ui(fontSize: 14),
                    decoration: const InputDecoration(
                      hintText: 'Ej. Vivero Paraíso',
                    ),
                    onSubmitted: (_) => _save(),
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.online,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    textStyle: AppType.ui(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('CREAR'),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: AppType.ui(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.danger,
                ),
              ),
            ],
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Text(
              'CATÁLOGO (${sortedRoutes.length})',
              style: AppType.ui(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 230),
              child: sortedRoutes.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      child: Center(
                        child: Text(
                          'Sin rutas. Crea la primera arriba.',
                          style: AppType.ui(
                            fontSize: 12.5,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: sortedRoutes.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final route = sortedRoutes[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  route.name,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppType.ui(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.navy.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(AppRadius.pill),
                                ),
                                child: Text(
                                  '${route.total}',
                                  style: AppType.ui(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.navy,
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: () => _rename(route),
                                icon: const Icon(
                                  Icons.edit_outlined,
                                  size: 17,
                                  color: AppColors.textSecondary,
                                ),
                                tooltip: 'Renombrar ruta',
                                visualDensity: VisualDensity.compact,
                              ),
                              IconButton(
                                onPressed: () => _confirmDelete(route),
                                icon: const Icon(
                                  Icons.delete_outline,
                                  size: 17,
                                  color: AppColors.danger,
                                ),
                                tooltip: 'Eliminar ruta',
                                visualDensity: VisualDensity.compact,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }
}
