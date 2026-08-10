import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../../core/widgets/map_pattern_painter.dart';
import '../../onboarding_flow.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  bool _requesting = false;

  Future<void> _allowLocation() async {
    setState(() => _requesting = true);
    await Permission.location.request();
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
      backgroundColor: const Color(0xFF14274E),
      body: CustomPaint(
        painter: const MapPatternPainter(),
        child: SafeArea(
          bottom: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints:
                      BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Column(
                      children: [
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF00A859)
                                          .withValues(alpha: 0.35),
                                      blurRadius: 50,
                                      spreadRadius: 10,
                                    ),
                                  ],
                                ),
                                child: SvgPicture.asset(
                                  'assets/icon/ya_viene_logo.svg',
                                  width: 76,
                                  height: 76,
                                ),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Ya Viene',
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: -1.2,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Tu ciudad en tiempo real.',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white.withValues(alpha: 0.75),
                                  letterSpacing: -0.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(26, 24, 26, 26),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(32),
                              topRight: Radius.circular(32),
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
                                    fontSize: 21,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0F172A),
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Así sabemos qué buses vienen hacia ti y te avisamos antes de que llegue el tuyo.',
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF64748B),
                                    height: 1.35,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                const _BenefitRow(
                                  icon: Icons.directions_bus_filled_rounded,
                                  title: 'Buses cerca de ti',
                                ),
                                const SizedBox(height: 10),
                                const _BenefitRow(
                                  icon: Icons.timer_outlined,
                                  title: 'Esperas exactas',
                                ),
                                const SizedBox(height: 10),
                                const _BenefitRow(
                                  icon: Icons.notifications_active_outlined,
                                  title: 'Avisos antes de tu bus',
                                ),
                                const SizedBox(height: 20),
                                SizedBox(
                                  width: double.infinity,
                                  height: 54,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF00A859),
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
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.5,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Text(
                                            'Permitir ubicación',
                                            style: TextStyle(
                                              fontSize: 16,
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
                                        color: Color(0xFF64748B),
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
                      ],
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
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFF00A859).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: const Color(0xFF00A859), size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
        ),
      ],
    );
  }
}
