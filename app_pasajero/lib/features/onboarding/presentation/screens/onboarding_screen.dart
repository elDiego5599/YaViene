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
                              // Misma superficie que las hojas del mapa:
                              // arena. La bienvenida va justo antes del mapa
                              // y el salto de blanco a arena se veía.
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
                                    AppColors.arenaAlta,
                                    AppColors.arena,
                                  ],
                                  stops: [0.0, 0.20],
                                ),
                                borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(AppRadius.sheet),
                                  topRight: Radius.circular(AppRadius.sheet),
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
                                minimum: const EdgeInsets.only(
                                  bottom: AppSpacing.md,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Activa tu ubicación',
                                      style: AppTextStyles.titulo,
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Así sabemos qué buses vienen hacia ti '
                                      'y te avisamos antes de que llegue '
                                      'el tuyo.',
                                      style: AppTextStyles.cuerpo.copyWith(
                                        color: AppColors.textSecondary,
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
                                        // El recorrido, no el cronómetro: lo
                                        // que la app entrega son metros, no
                                        // minutos. «Cuánto falta» se lee como
                                        // tiempo y prometía justo lo que la
                                        // app no calcula.
                                        icon: Icons.route_rounded,
                                        title: 'A qué distancia viene',
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
                                            Icons.notifications_active_rounded,
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
                                            borderRadius: BorderRadius.circular(
                                                AppRadius.pill),
                                          ),
                                        ),
                                        onPressed:
                                            _requesting ? null : _allowLocation,
                                        child: _requesting
                                            ? const IndicadorCarga(
                                                color: Colors.white,
                                                // El botón se queda sin
                                                // texto mientras el
                                                // sistema pregunta.
                                                semanticsLabel:
                                                    'Pidiendo el permiso',
                                              )
                                            : Text(
                                                'Permitir ubicación',
                                                style: AppTextStyles.boton,
                                              ),
                                      ),
                                    ),
                                    const SizedBox(height: AppSpacing.xs),
                                    SizedBox(
                                      width: double.infinity,
                                      child: TextButton(
                                        onPressed: _skip,
                                        child: Text(
                                          'Ahora no',
                                          style: AppTextStyles.etiqueta,
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
    return Semantics(
      // Promesa y letra chica son una sola cosa: separadas hay que pasar
      // dos veces por cada fila, y la segunda mitad —de dónde sale el
      // dato— llega suelta, sin saber de qué promesa habla.
      label: '$title. $detail',
      excludeSemantics: true,
      child: Row(
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
                  style: AppTextStyles.cuerpoFuerte,
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  style: AppTextStyles.pie,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
