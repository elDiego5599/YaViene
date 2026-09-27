import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import '../../../../core/widgets/entrance.dart';
import '../../../../core/widgets/ink_hero.dart';
import '../../../../core/widgets/live_route_backdrop.dart';
import '../../../legal/legal_acceptance.dart';
import '../../../legal/legal_docs.dart';
import '../../../map/presentation/providers/user_location_provider.dart';
import '../../onboarding_flow.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  bool _requesting = false;

  /// Si el usuario ya dijo que sí a la privacidad y a los términos.
  ///
  /// Empieza en falso siempre, también para quien ya aceptó una versión
  /// anterior: si la app lo trajo hasta aquí es porque falta su sí, y una
  /// casilla que sale marcada sola no es un sí de nadie.
  bool _accepted = false;

  Future<void> _allowLocation() async {
    setState(() => _requesting = true);
    // useGps pide el permiso sí o sí: el usuario tocó "Permitir ubicación".
    await ref.read(userLocationProvider.notifier).useGps();
    if (!mounted) return;
    setState(() => _requesting = false);
    await _guardarPaso();
    if (!mounted) return;
    unawaited(goToHome(context));
  }

  Future<void> _skip() async {
    await _guardarPaso();
    if (!mounted) return;
    unawaited(goToHome(context));
  }

  /// La aceptación se guarda ANTES de la marca de "bienvenida vista": si el
  /// teléfono se apaga entre las dos, lo que queda escrito es un sí sin
  /// pantalla vista —vuelve a salir la bienvenida— y no una pantalla vista
  /// sin sí, que dejaría pasar al mapa sin haber aceptado nada.
  Future<void> _guardarPaso() async {
    await acceptLegal();
    await markOnboardingSeen();
  }

  void _abrir(LegalDoc doc) => context.push('/legal/${doc.id}');

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
                              padding: const EdgeInsets.fromLTRB(28, 24, 28, 0),
                              // Misma superficie que las hojas del mapa:
                              // arena. La bienvenida va justo antes del mapa
                              // y el salto de blanco a arena se veía. Sin
                              // `const` en la decoración: la sombra del
                              // sistema es `final` (los hijos sí van const).
                              decoration: BoxDecoration(
                                // El pliegue por donde la hoja se separa de
                                // la noche recoge la luz: blanco cálido que
                                // cae a arena en el primer quinto. Con el
                                // relleno plano, ese borde era una línea
                                // muerta y la hoja parecía pegada encima.
                                gradient: const LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    AppColors.arenaAlta,
                                    AppColors.arena,
                                  ],
                                  stops: [0.0, 0.20],
                                ),
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(AppRadius.sheet),
                                  topRight: Radius.circular(AppRadius.sheet),
                                ),
                                // Sombra del sistema (tinta al 8 %/4 %) en vez
                                // del negro al 20 %: el labio flota igual sin
                                // el pegote oscuro sobre la arena.
                                boxShadow: AppShadows.floating,
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
                                    const SizedBox(height: 22),
                                    // Los tres beneficios se revelan uno detrás
                                    // de otro, y solo con fundido: la hoja ya
                                    // sube entera, y dos movimientos encajados
                                    // se leen como un temblor.
                                    entra(
                                      const _BenefitRow(
                                        icon: Icons
                                            .directions_bus_filled_outlined,
                                        title: 'Buses en vivo',
                                        detail: 'Ves dónde va el tuyo, no '
                                            'dónde debería ir',
                                      ),
                                      start: 0.34,
                                      begin: Offset.zero,
                                    ),
                                    const SizedBox(height: 12),
                                    entra(
                                      const _BenefitRow(
                                        // El recorrido, no el cronómetro: lo
                                        // que la app entrega son metros, no
                                        // minutos. «Cuánto falta» se lee como
                                        // tiempo y prometía justo lo que la
                                        // app no calcula.
                                        icon: Icons.route_outlined,
                                        title: 'A qué distancia viene',
                                        detail: 'Calculado con la posición '
                                            'real del bus',
                                      ),
                                      start: 0.42,
                                      begin: Offset.zero,
                                    ),
                                    const SizedBox(height: 12),
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
                                    const SizedBox(height: 18),
                                    entra(
                                      _AceptaLegales(
                                        aceptado: _accepted,
                                        onCambia: (valor) =>
                                            setState(() => _accepted = valor),
                                        onAbrir: _abrir,
                                      ),
                                      start: 0.58,
                                      begin: Offset.zero,
                                    ),
                                    const SizedBox(height: 14),
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
                                        // Los dos botones salen apagados
                                        // hasta que la casilla se marque:
                                        // el sí es un toque del usuario, no
                                        // una letra chica que dice "al
                                        // continuar aceptas".
                                        onPressed: _requesting || !_accepted
                                            ? null
                                            : _allowLocation,
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
                                        onPressed: _accepted ? _skip : null,
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

/// La casilla del sí, con los dos documentos a un toque.
///
/// La casilla y su frase van juntas para quien no ve la pantalla: leída
/// suelta, «casilla sin marcar» no dice qué se acepta. Los dos documentos
/// se anuncian aparte, cada uno como botón con su nombre, porque hay que
/// poder leerlos ANTES de aceptar y esta pantalla es la única puerta: el
/// menú donde también están queda al otro lado.
class _AceptaLegales extends StatelessWidget {
  final bool aceptado;
  final ValueChanged<bool> onCambia;
  final void Function(LegalDoc doc) onAbrir;

  const _AceptaLegales({
    required this.aceptado,
    required this.onCambia,
    required this.onAbrir,
  });

  @override
  Widget build(BuildContext context) {
    final letra = AppTextStyles.pie.copyWith(color: AppColors.textSecondary);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          checked: aceptado,
          label: 'He leído y acepto la privacidad y los términos de uso',
          onTap: () => onCambia(!aceptado),
          excludeSemantics: true,
          child: GestureDetector(
            onTap: () => onCambia(!aceptado),
            behavior: HitTestBehavior.opaque,
          child: Padding(
            // El blanco alrededor de la casilla es lo que le da tamaño de
            // dedo: 24 de casilla dentro de 48 (T6.6; antes era 34 y la
            // guía de Android lo marcaba). Solo crece el área que se toca.
            padding: const EdgeInsets.only(right: 24, bottom: 24),
              child: SizedBox(
                width: 24,
                height: 24,
                child: Checkbox(
                  key: const ValueKey('legal_accept'),
                  value: aceptado,
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  activeColor: AppColors.primary,
                  side: BorderSide(
                    color: AppColors.textSecondary.withValues(alpha: 0.6),
                    width: 1.5,
                  ),
                  onChanged: (valor) => onCambia(valor ?? false),
                ),
              ),
            ),
          ),
        ),
        Expanded(
          // La frase se escribe en trozos y no como un párrafo con enlaces
          // dentro: un `TextSpan` tocable no se anuncia como botón y no
          // tiene blanco propio donde caiga el dedo.
          child: Wrap(
            spacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('He leído y acepto la', style: letra),
              _Enlace(
                key: const ValueKey('legal_link_privacidad'),
                texto: 'privacidad',
                onTap: () => onAbrir(legalPrivacidad),
              ),
              Text('y los', style: letra),
              _Enlace(
                key: const ValueKey('legal_link_terminos'),
                texto: 'términos de uso',
                onTap: () => onAbrir(legalTerminos),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Un documento, a un toque. Verde y subrayado: en una hoja de puro texto
/// gris, el color solo no basta para decir que algo se toca.
class _Enlace extends StatelessWidget {
  final String texto;
  final VoidCallback onTap;

  const _Enlace({super.key, required this.texto, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      // Enlace y no botón: abre un documento, y las guías de tamaño eximen
      // a los enlaces dentro de un párrafo (T6.6; medían 22 de alto y la
      // guía de Android los marcaba). El lector lo anuncia como enlace.
      link: true,
      label: texto,
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          // Poco blanco vertical: el enlace va dentro de la frase y un
          // relleno mayor separaría las líneas del párrafo.
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Text(
            texto,
            style: AppTextStyles.pie.copyWith(
              color: AppColors.primaryAccessible,
              fontWeight: FontWeight.w600,
              decoration: TextDecoration.underline,
              decorationColor: AppColors.primaryAccessible,
            ),
          ),
        ),
      ),
    );
  }
}
