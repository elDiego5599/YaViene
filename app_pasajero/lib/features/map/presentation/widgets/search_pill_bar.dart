import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'route_selector_sheet.dart';

class SearchPillBar extends StatelessWidget {
  const SearchPillBar({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (context) => const RouteSelectorSheet(),
            );
          },
          child: Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(999), // Forma de píldora
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF14274E).withValues(alpha: 0.08), // Sombra premium
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                )
              ],
            ),
            child: Row(
              children: [
                // Ícono izquierdo
                const Icon(Icons.directions_bus_rounded, color: Color(0xFF0F172A), size: 24),
                const SizedBox(width: 12),
                
                // Texto Principal
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "¿Qué bus esperas?",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                          letterSpacing: -0.3,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Botón Acción derecho (Estilo filtro)
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF1F5F9), // Gris clarito
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.tune_rounded, color: Color(0xFF14274E), size: 20),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
