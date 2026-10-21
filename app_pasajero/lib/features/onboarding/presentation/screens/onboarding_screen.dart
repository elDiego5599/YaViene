import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import '../../../../core/widgets/entrance.dart';
import '../../../../core/widgets/fondo_matizado.dart';
import '../../../../core/widgets/ink_hero.dart';
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
      backgroundColor: AppColors.surface,
      body: _FondoBienvenida(
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
                              // blanca (dueño, 2026-10-16). La bienvenida va
                              // justo antes del mapa y un salto de tono se
                              // vería. Sin `const` en la decoración: la
                              // sombra del sistema es `final` (los hijos sí
                              // van const).
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(AppRadius.sheet),
                                  topRight: Radius.circular(AppRadius.sheet),
                                ),
                                // Hacia arriba: la hoja está abajo y la sombra
                                // que la despega cae sobre el matizado.
                                // `AppShadows.floating` es la de una tarjeta
                                // sobre el suelo —hacia abajo— y aquí se
                                // perdía bajo el filo de la pantalla (R-14).
                                // Tinta al 8 %, como la del sistema, y no el
                                // negro al 20 % de antes: sin pegote oscuro.
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primaryDeep
                                        .withValues(alpha: 0.08),
                                    blurRadius: 32,
                                    offset: const Offset(0, -12),
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
                                    // Pocas palabras y grandes (el dueño,
                                    // 2026-09-27: «mucho texto y todo se ve
                                    // pequeño»). Se fueron el subtítulo y la
                                    // letra chica de cada razón: decían otra
                                    // vez lo que el título y las razones ya
                                    // dicen, y para que cupiera todo, todo
                                    // iba a 12 y 15.
                                    Text(
                                      'Activa tu ubicación',
                                      style: AppTextStyles.display,
                                    ),
                                    const SizedBox(height: 24),
                                    // Las tres razones se revelan una detrás
                                    // de otra, y solo con fundido: la hoja ya
                                    // sube entera, y dos movimientos encajados
                                    // se leen como un temblor.
                                    entra(
                                      const _BenefitRow(
                                        icon: Icons
                                            .directions_bus_filled_outlined,
                                        title: 'Buses en vivo',
                                      ),
                                      start: 0.34,
                                      begin: Offset.zero,
                                    ),
                                    const SizedBox(height: 18),
                                    entra(
                                      const _BenefitRow(
                                        // El recorrido, no el cronómetro: lo
                                        // que la app entrega son metros, no
                                        // minutos. «Cuánto falta» se lee como
                                        // tiempo y prometía justo lo que la
                                        // app no calcula.
                                        icon: Icons.route_outlined,
                                        title: 'A qué distancia viene',
                                      ),
                                      start: 0.42,
                                      begin: Offset.zero,
                                    ),
                                    const SizedBox(height: 18),
                                    entra(
                                      const _BenefitRow(
                                        icon:
                                            Icons.notifications_active_outlined,
                                        title: 'Aviso antes de que llegue',
                                      ),
                                      start: 0.5,
                                      begin: Offset.zero,
                                    ),
                                    const SizedBox(height: 28),
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
                                    const SizedBox(height: 18),
                                    SizedBox(
                                      width: double.infinity,
                                      height: 56,
                                      child: ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.primary,
                                          foregroundColor:
                                              AppColors.textPrimary,
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
                                                color: AppColors.textPrimary,
                                                // El botón se queda sin
                                                // texto mientras el
                                                // sistema pregunta.
                                                semanticsLabel:
                                                    'Pidiendo el permiso',
                                              )
                                            : Text(
                                                'Permitir ubicación',
                                                style: AppTextStyles.boton
                                                    .copyWith(
                                                  color: AppColors.textPrimary,
                                                ),
                                              ),
                                      ),
                                    ),
                                    const SizedBox(height: AppSpacing.xs),
                                    SizedBox(
                                      width: double.infinity,
                                      child: TextButton(
                                        onPressed: _accepted ? _skip : null,
                                        // A la medida del cuerpo y no de una
                                        // etiqueta: es la otra salida de la
                                        // pantalla, no una nota al margen.
                                        child: Text(
                                          'Ahora no',
                                          style: AppTextStyles.cuerpoFuerte
                                              .copyWith(
                                            color: AppColors.textSecondary,
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

/// El matizado azul y verde detrás del logo de bienvenida. Claro: la hora
/// y la batería del sistema van en oscuro.
class _FondoBienvenida extends StatelessWidget {
  final Widget child;

  const _FondoBienvenida({required this.child});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Stack(
        fit: StackFit.expand,
        children: [const FondoMatizado(), child],
      ),
    );
  }
}

/// Una razón para dar el permiso: el glifo y la promesa, en una línea.
///
/// Empezó como un cuadrado verde de 56 con tres palabras al lado; luego el
/// glifo quedó suelto, como en las pantallas de permiso de iOS, con una
/// línea de letra chica debajo. Esa letra chica sobraba: la promesa ya se
/// entiende sola y, con ella, la fila tenía que ir a 15 y 12 para caber.
/// Sin ella, la promesa va a la medida de un encabezado de fila.
///
/// Sin `Semantics` propio: el glifo es decorado —`Icon` sin
/// `semanticLabel` no se anuncia— y el lector lee la promesa y nada más.
class _BenefitRow extends StatelessWidget {
  final IconData icon;
  final String title;

  const _BenefitRow({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Ancho fijo para que los tres títulos arranquen en la misma
        // columna aunque los glifos midan distinto. 28 de glifo junto a
        // 18 de letra: el icono llega a la altura de la línea sin pasarla.
        SizedBox(
          width: 32,
          child: Icon(icon, color: AppColors.primary, size: 28),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(title, style: AppTextStyles.subtitulo),
        ),
      ],
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
    // A la medida del cuerpo, no de la letra chica: es lo único que la
    // pantalla pide leer antes de dejar pasar, y a 12 se leía como un pie
    // de página que se salta.
    final letra = AppTextStyles.cuerpo.copyWith(color: AppColors.textSecondary);

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
            // La misma medida que la frase en la que va.
            style: AppTextStyles.cuerpo.copyWith(
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
