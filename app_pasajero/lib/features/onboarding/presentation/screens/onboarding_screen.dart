import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import '../../../../core/widgets/entrance.dart';
import '../../../../core/widgets/ink_hero.dart';
import '../../../../core/widgets/live_route_backdrop.dart';
import '../../../map/presentation/providers/user_location_provider.dart';
import '../../onboarding_flow.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  bool _requesting = false;

  Future<void> _allowLocation() async {
    setState(() => _requesting = true);
    // useGps pide el permiso sí o sí: el usuario tocó "Permitir ubicación".
    await ref.read(userLocationProvider.notifier).useGps();
    if (!mounted) return;
    setState(() => _requesting = false);
    await markOnboardingSeen();
    if (!mounted) return;
    unawaited(goToHome(context));
  }

  Future<void> _skip() async {
    await markOnboardingSeen();
    if (!mounted) return;
    unawaited(goToHome(context));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ink,
      body: LiveRouteBackdrop(
        // La pantalla pide la ubicación: el fondo la enseña. El punto azul
        // es dónde espera el usuario y el bus se le va acercando.
        showUser: true,
        child: SafeArea(
          bottom: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: ScreenEntrance(
                      builder: (context, entra) => Column(
                        children: [
                          Expanded(
                            child: Center(
                              child: entra(
                                const InkHero(),
                                begin: const Offset(0, 0.05),
                              ),
                            ),
                          ),
                          entra(
                            Container(
                              width: double.infinity,
                              // Sin relleno inferior propio: el que hay va
                              // en el SafeArea de abajo. Los dos sumaban 68
                              // px de nada debajo de "Ahora no" —el bloque
                              // vacío más grande de la pantalla— y dejaban
                              // el contenido apelmazado arriba.
                              padding: const EdgeInsets.fromLTRB(28, 30, 28, 0),
                              // Misma superficie que la hoja del login y que
                              // las del mapa: arena. Las dos pantallas van
                              // seguidas y el salto de blanco a arena se veía.
                              decoration: const BoxDecoration(
                                // El pliegue por donde la hoja se separa de
                                // la noche recoge la luz: blanco cálido que
                                // cae a arena en el primer quinto. Con el
                                // relleno plano, ese borde era una línea
                                // muerta y la hoja parecía pegada encima.
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Color(0xFFFFFDF8),
                                    AppColors.arena,
                                  ],
                                  stops: [0.0, 0.20],
                                ),
                                borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(36),
                                  topRight: Radius.circular(36),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Color(0x3305080F),
                                    blurRadius: 44,
                                    offset: Offset(0, -16),
                                  ),
                                ],
                              ),
                              child: SafeArea(
                                top: false,
                                // En pantallas sin indicador de inicio el
                                // inset es 0 y el último control quedaría
                                // pegado al filo.
                                minimum: const EdgeInsets.only(bottom: 16),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Activa tu ubicación',
                                      style: TextStyle(
                                        fontSize: 23,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.textPrimary,
                                        letterSpacing: -0.6,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    const Text(
                                      'Así sabemos qué buses vienen hacia ti '
                                      'y te avisamos antes de que llegue '
                                      'el tuyo.',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: AppColors.textSecondary,
                                        height: 1.4,
                                      ),
                                    ),
                                    const SizedBox(height: 28),
                                    // Los tres beneficios se revelan uno detrás
                                    // de otro, y solo con fundido: la hoja ya
                                    // sube entera, y dos movimientos encajados
                                    // se leen como un temblor.
                                    entra(
                                      const _BenefitRow(
                                        icon:
                                            Icons.directions_bus_filled_rounded,
                                        title: 'Buses en vivo',
                                        detail: 'Ves dónde va el tuyo, no '
                                            'dónde debería ir',
                                      ),
                                      start: 0.34,
                                      begin: Offset.zero,
                                    ),
                                    const SizedBox(height: 22),
                                    entra(
                                      const _BenefitRow(
                                        icon: Icons.timer_outlined,
                                        title: 'Cuánto falta',
                                        detail: 'Calculado con la posición '
                                            'real del bus',
                                      ),
                                      start: 0.42,
                                      begin: Offset.zero,
                                    ),
                                    const SizedBox(height: 22),
                                    entra(
                                      const _BenefitRow(
                                        icon:
                                            Icons.notifications_active_outlined,
                                        title: 'Aviso antes de que llegue',
                                        detail: 'Suena cuando se acerca a tu '
                                            'punto de espera',
                                      ),
                                      start: 0.5,
                                      begin: Offset.zero,
                                    ),
                                    const SizedBox(height: 30),
                                    SizedBox(
                                      width: double.infinity,
                                      height: 56,
                                      child: ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.primary,
                                          foregroundColor: Colors.white,
                                          elevation: 0,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(999),
                                          ),
                                        ),
                                        onPressed:
                                            _requesting ? null : _allowLocation,
                                        child: _requesting
                                            ? const SizedBox(
                                                width: 22,
                                                height: 22,
                                                child:
                                                    CircularProgressIndicator(
                                                  strokeWidth: 2.5,
                                                  color: Colors.white,
                                                ),
                                              )
                                            : const Text(
                                                'Permitir ubicación',
                                                style: TextStyle(
                                                  fontSize: 17,
                                                  fontWeight: FontWeight.w800,
                                                  letterSpacing: -0.3,
                                                ),
                                              ),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    SizedBox(
                                      width: double.infinity,
                                      child: TextButton(
                                        onPressed: _skip,
                                        child: const Text(
                                          'Ahora no',
                                          style: TextStyle(
                                            color: AppColors.textSecondary,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            start: 0.14,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Una razón para dar el permiso: glifo, promesa y su letra chica.
///
/// Antes era un cuadrado verde de 56 con el icono dentro y tres palabras
/// al lado. Tres cuadrados apilados pesaban más que lo que decían —y lo
/// que decían no bastaba: "Esperas exactas" promete una exactitud que
/// nadie puede dar. Ahora el glifo va suelto, como en las pantallas de
/// permiso de iOS, y cada fila explica en una línea qué gana el usuario
/// y de dónde sale el dato.
class _BenefitRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String detail;

  const _BenefitRow({
    required this.icon,
    required this.title,
    required this.detail,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Ancho fijo para que los tres títulos arranquen en la misma
        // columna aunque los glifos midan distinto.
        SizedBox(
          width: 30,
          child: Icon(icon, color: AppColors.primary, size: 26),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                detail,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
