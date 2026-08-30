import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import '../../../../core/widgets/entrance.dart';
import '../../../../core/widgets/ink_hero.dart';
import '../../../../core/widgets/map_pattern_painter.dart';
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
      body: CustomPaint(
        painter: const MapPatternPainter(),
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
                              padding:
                                  const EdgeInsets.fromLTRB(28, 28, 28, 34),
                              // Misma superficie que la hoja del login y que
                              // las del mapa: arena. Las dos pantallas van
                              // seguidas y el salto de blanco a arena se veía.
                              decoration: const BoxDecoration(
                                color: AppColors.arena,
                                borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(36),
                                  topRight: Radius.circular(36),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Color(0x1A14274E),
                                    blurRadius: 32,
                                    offset: Offset(0, -10),
                                  ),
                                ],
                              ),
                              child: SafeArea(
                                top: false,
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
                                      'Así sabemos qué buses vienen hacia ti y te avisamos antes de que llegue el tuyo.',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: AppColors.textSecondary,
                                        height: 1.4,
                                      ),
                                    ),
                                    const SizedBox(height: 22),
                                    // Los tres beneficios se revelan uno detrás
                                    // de otro, y solo con fundido: la hoja ya
                                    // sube entera, y dos movimientos encajados
                                    // se leen como un temblor.
                                    entra(
                                      const _BenefitRow(
                                        icon:
                                            Icons.directions_bus_filled_rounded,
                                        title: 'Buses cerca de ti',
                                      ),
                                      start: 0.34,
                                      begin: Offset.zero,
                                    ),
                                    const SizedBox(height: 16),
                                    entra(
                                      const _BenefitRow(
                                        icon: Icons.timer_outlined,
                                        title: 'Esperas exactas',
                                      ),
                                      start: 0.42,
                                      begin: Offset.zero,
                                    ),
                                    const SizedBox(height: 16),
                                    entra(
                                      const _BenefitRow(
                                        icon:
                                            Icons.notifications_active_outlined,
                                        title: 'Avisos antes de tu bus',
                                      ),
                                      start: 0.5,
                                      begin: Offset.zero,
                                    ),
                                    const SizedBox(height: 24),
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

class _BenefitRow extends StatelessWidget {
  final IconData icon;
  final String title;

  const _BenefitRow({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Icon(icon, color: AppColors.primary, size: 24),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
