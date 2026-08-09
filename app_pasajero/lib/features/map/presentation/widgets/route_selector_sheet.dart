import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ya_viene_core/ya_viene_core.dart';

class RouteSelectorSheet extends ConsumerWidget {
  const RouteSelectorSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final companiesAsync = ref.watch(companiesProvider);
    final selectedCompany = ref.watch(selectedCompanyProvider);
    final routesAsync =
        ref.watch(routesByCompanyProvider(selectedCompany?.id ?? ''));
    final selectedRoute = ref.watch(selectedRouteProvider);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              Center(
                child: Container(
                  width: 48,
                  height: 6,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Elige tu ruta',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.5,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE6F7F0),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.bolt_rounded, size: 14, color: Color(0xFF00A859)),
                        SizedBox(width: 4),
                        Text(
                          'Tiempo real',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF00A859),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              const Text(
                'EMPRESA',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF64748B),
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 12),
              companiesAsync.when(
                data: (companies) => _PremiumSelectorTile(
                  title: selectedCompany?.name ?? 'Selecciona una empresa',
                  subtitle: selectedCompany != null ? 'Empresa de transporte masivo' : null,
                  icon: Icons.business_rounded,
                  isActive: selectedCompany != null,
                  onTap: () => _showCompanySelector(context, ref, companies),
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => const Text('Error al cargar empresas'),
              ),

              const SizedBox(height: 20),

              const Text(
                'RUTA',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF64748B),
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 12),
              if (selectedCompany == null)
                _PremiumSelectorTile(
                  title: selectedRoute?.name ?? 'Selecciona una ruta',
                  subtitle: _routeSubtitle(selectedRoute),
                  icon: Icons.alt_route_rounded,
                  isActive: selectedRoute != null,
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Primero selecciona una empresa'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                )
              else
                routesAsync.when(
                  data: (routes) => _PremiumSelectorTile(
                    title: selectedRoute?.name ?? 'Selecciona una ruta',
                    subtitle: _routeSubtitle(selectedRoute),
                    icon: Icons.alt_route_rounded,
                    isActive: selectedRoute != null,
                    onTap: () => _showRouteSelector(context, ref, routes),
                  ),
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (_, __) => const SizedBox.shrink(),
                ),

              const SizedBox(height: 32),

              ElevatedButton(
                onPressed: selectedRoute != null
                    ? () {
                        HapticFeedback.mediumImpact();
                        Navigator.pop(context);
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF14274E),
                  disabledBackgroundColor: const Color(0xFFE2E8F0),
                  foregroundColor: Colors.white,
                  disabledForegroundColor: const Color(0xFF94A3B8),
                  minimumSize: const Size(double.infinity, 58),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  selectedRoute != null ? 'Ver buses en vivo' : 'Selecciona una ruta para continuar',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    color: selectedRoute != null ? Colors.white : const Color(0xFF94A3B8),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
    );
  }

  void _showCompanySelector(BuildContext context, WidgetRef ref, List<Company> companies) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (_) => SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: companies.map((c) => ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.business_rounded, color: Color(0xFF14274E), size: 20),
              ),
              title: Text(
                c.name,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.4,
                ),
              ),
              trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFFCBD5E1)),
              onTap: () {
                HapticFeedback.selectionClick();
                ref.read(selectedCompanyProvider.notifier).select(c);
                ref.read(selectedRouteProvider.notifier).clear();
                Navigator.pop(context);
              },
            )).toList(),
          ),
        ),
      ),
    ),
    );
  }

  void _showRouteSelector(BuildContext context, WidgetRef ref, List<RouteInfo> routes) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (_) => SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: routes.map((r) => ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE6F7F0),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.alt_route_rounded, color: Color(0xFF00A859), size: 20),
                ),
                title: Text(
                  r.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.4,
                  ),
                ),
                subtitle: Text(
                  _routeSubtitle(r) ?? 'Tiempo real',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF64748B),
                  ),
                ),
                trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFFCBD5E1)),
                onTap: () {
                  HapticFeedback.selectionClick();
                  ref.read(selectedRouteProvider.notifier).select(r);
                  Navigator.pop(context);
                },
              )).toList(),
            ),
          ),
        ),
      ),
    );
  }
}

String? _routeSubtitle(RouteInfo? route) {
  if (route == null) return null;
  final a = route.terminalA ?? '';
  final b = route.terminalB ?? '';
  if (a.isEmpty && b.isEmpty) return null;
  return '$a ↔ $b';
}

class _PremiumSelectorTile extends StatelessWidget {  final String title;
  final String? subtitle;
  final IconData icon;
  final bool isActive;
  final VoidCallback? onTap;

  const _PremiumSelectorTile({
    required this.title,
    this.subtitle,
    required this.icon,
    required this.isActive,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? const Color(0xFF14274E).withValues(alpha: 0.2) : const Color(0xFFE2E8F0),
            width: isActive ? 1.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF14274E).withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isActive ? const Color(0xFFE6F7F0) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                icon,
                color: isActive ? const Color(0xFF00A859) : const Color(0xFF94A3B8),
                size: 22,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                      color: isActive ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFFCBD5E1)),
          ],
        ),
      ),
    );
  }
}
