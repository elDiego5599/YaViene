import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/ventana.dart';
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
    final newName = await mostrarVentana<String>(
      context,
      (_) => _VentanaRenombrar(nombre: route.name),
    );
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
    final confirmed = await confirmarBorrado(
      context,
      titulo: 'Eliminar ruta',
      mensaje: '¿Eliminar "${route.name}" del catálogo? Los buses que tengan '
          'esta ruta asignada pasarán a la primera ruta restante.',
    );
    if (confirmed) {
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

    return Ventana(
      icono: Icons.route_outlined,
      titulo: 'Rutas',
      ancho: 480,
      secundaria: VentanaAccion('Cerrar', () => Navigator.of(context).pop()),
      contenido: Column(
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
    );
  }
}

/// «Renombrar ruta». Es dueña de su campo: el controlador se desecha cuando
/// la ventana termina de salir, no cuando devuelve el nombre. Antes vivía en
/// `_rename` y se desechaba al volver del `await`, con la ventana todavía
/// encogiéndose en pantalla y el campo pintándose con él.
class _VentanaRenombrar extends StatefulWidget {
  const _VentanaRenombrar({required this.nombre});

  final String nombre;

  @override
  State<_VentanaRenombrar> createState() => _VentanaRenombrarState();
}

class _VentanaRenombrarState extends State<_VentanaRenombrar> {
  late final _controller = TextEditingController(text: widget.nombre);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _guardar() {
    final value = _controller.text.trim();
    if (value.isNotEmpty) Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return Ventana(
      icono: Icons.edit_outlined,
      titulo: 'Renombrar ruta',
      // 400: la ventana de un solo campo, más angosta que el catálogo que
      // queda detrás para que se lea encima y no como su reemplazo.
      ancho: 400,
      contenido: TextField(
        controller: _controller,
        autocorrect: false,
        autofocus: true,
        style: AppType.ui(fontSize: 14),
        decoration: const InputDecoration(hintText: 'Nuevo nombre'),
        onSubmitted: (_) => _guardar(),
      ),
      secundaria: VentanaAccion(
        'Cancelar',
        () => Navigator.of(context).pop(),
      ),
      principal: VentanaAccion('GUARDAR', _guardar),
    );
  }
}
