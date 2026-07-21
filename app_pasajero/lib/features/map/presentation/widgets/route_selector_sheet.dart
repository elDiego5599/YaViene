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
    final selectedDirection = ref.watch(selectedSentidoProvider);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
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

              // Title
              const Text(
                'Elige tu ruta',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 24),

              // Segmented Control (iOS Style)
              Container(
                height: 48,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9), // Slate 100
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    _Segment(
                      title: 'Ida',
                      isSelected: selectedDirection == RouteSentido.ida,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        ref.read(selectedSentidoProvider.notifier).state = RouteSentido.ida;
                      },
                    ),
                    _Segment(
                      title: 'Vuelta',
                      isSelected: selectedDirection == RouteSentido.vuelta,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        ref.read(selectedSentidoProvider.notifier).state = RouteSentido.vuelta;
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Select Company (Premium ListTile)
              const Text(
                'EMPRESA',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF64748B),
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 12),
              companiesAsync.when(
                data: (companies) => _PremiumSelectorTile(
                  title: selectedCompany?.name ?? 'Selecciona una empresa',
                  icon: Icons.business_rounded,
                  isActive: selectedCompany != null,
                  onTap: () => _showCompanySelector(context, ref, companies),
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => const Text('Error'),
              ),

              const SizedBox(height: 24),

              // Select Route (Premium ListTile)
              const Text(
                'RUTA',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF64748B),
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 12),
              routesAsync.when(
                data: (routes) => _PremiumSelectorTile(
                  title: selectedRoute?.name ?? 'Selecciona una ruta',
                  icon: Icons.alt_route_rounded,
                  isActive: selectedRoute != null,
                  onTap: selectedCompany == null
                      ? null
                      : () => _showRouteSelector(context, ref, routes),
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => const SizedBox.shrink(),
              ),

              const SizedBox(height: 32),
              
              // Confirm Button
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
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Confirmar',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
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
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: companies.map((c) => ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              title: Text(
                c.name,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
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
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: routes.map((r) => ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              title: Text(
                r.name,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
              onTap: () {
                HapticFeedback.selectionClick();
                ref.read(selectedRouteProvider.notifier).select(r);
                Navigator.pop(context);
              },
            )).toList(),
          ),
        ),
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  const _Segment({
    required this.title,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    )
                  ]
                : [],
          ),
          alignment: Alignment.center,
          child: Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
              color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF64748B),
            ),
          ),
        ),
      ),
    );
  }
}

class _PremiumSelectorTile extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isActive;
  final VoidCallback? onTap;

  const _PremiumSelectorTile({
    required this.title,
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
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: const Color(0xFF14274E), size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isActive ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                ),
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFFCBD5E1)),
          ],
        ),
      ),
    );
  }
}
