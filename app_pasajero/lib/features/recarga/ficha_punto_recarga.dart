import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ya_viene_core/ya_viene_core.dart';

import '../../core/services/abrir_enlace.dart';
import '../../core/utils/distancia.dart';
import '../../core/widgets/pildora_navegacion.dart';
import '../map/presentation/providers/user_location_provider.dart';
import 'marcador_recarga.dart';
import 'recarga_providers.dart';

/// La ficha del punto de recarga tocado en el mapa.
///
/// Como la de un lugar en Apple Maps: el nombre arriba, qué es y a cuánto
/// en una línea gris, y debajo lo que hace falta para llegar (la dirección,
/// el horario si la fuente lo da) y de dónde sale el dato, con su fecha. La
/// única acción llena es «Cómo llegar», como en Citymapper; cerrar es una X
/// discreta arriba a la derecha.
///
/// Se apoya sobre la píldora de pestañas, a su ancho: la hoja de los buses se
/// aparta mientras la ficha está, y en ningún momento hay dos tarjetas
/// apiladas.
class FichaPuntoRecarga extends ConsumerWidget {
  const FichaPuntoRecarga({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final punto = ref.watch(puntoRecargaElegidoProvider);
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: EdgeInsets.only(
          left: PildoraNavegacion.lado,
          right: PildoraNavegacion.lado,
          // Encima de la píldora de pestañas, con su respiro de 8: la hoja
          // de los buses la lleva dentro, pero la ficha es una tarjeta suelta.
          bottom: PildoraNavegacion.hueco(MediaQuery.viewPaddingOf(context)) +
              PildoraNavegacion.alto +
              AppSpacing.sm,
        ),
        child: AnimatedSwitcher(
          duration: AppMotion.duracion(context, AppMotion.normal),
          switchInCurve: AppMotion.curvaEntrada,
          switchOutCurve: AppMotion.curvaSalida,
          // Sube un palmo desde abajo mientras se enciende, como sube la
          // hoja; al cambiar de punto la vieja baja y la nueva sube.
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.25),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          ),
          layoutBuilder: (actual, anteriores) => Stack(
            alignment: Alignment.bottomCenter,
            children: [...anteriores, if (actual != null) actual],
          ),
          child: punto == null
              ? const SizedBox.shrink(key: ValueKey('sin-ficha-recarga'))
              : _Ficha(key: ValueKey(punto.id), punto: punto),
        ),
      ),
    );
  }
}

class _Ficha extends ConsumerWidget {
  const _Ficha({super.key, required this.punto});

  final PuntoDeRecarga punto;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ubicacion = ref.watch(userLocationProvider);
    final (lat, lon) = (ubicacion.lat, ubicacion.lon);
    final metros = ubicacion.hasPosition && lat != null && lon != null
        ? haversineMeters(lat, lon, punto.lat, punto.lon).round()
        : null;
    // La fuente escribe las direcciones en mayúsculas: igual que los
    // nombres, se leen mejor como se escriben (CLL y CRA se quedan).
    final calle = nombreDelPunto(punto.direccion);
    final direccion =
        punto.municipio == null ? calle : '$calle, ${punto.municipio}';

    return MediaQuery.withClampedTextScaling(
      // El mismo techo que la hoja de los buses (WCAG 1.4.4, el doble).
      maxScaleFactor: 2.0,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: AppColors.filo),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryDeep.withValues(alpha: 0.10),
              blurRadius: 32,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.md, AppSpacing.md, AppSpacing.sm, AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Cabecera(punto: punto, metros: metros),
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: AppSpacing.md),
                  // Los datos van juntos en un panel tenue, como la lista de
                  // datos de una ficha de Apple Maps: lo que se lee queda
                  // aparte de lo que se toca.
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md - 4, vertical: AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceMuted,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Linea(
                          icono: Icons.place_outlined,
                          texto: direccion,
                          estilo: AppTextStyles.cuerpo
                              .copyWith(color: AppColors.textPrimary),
                        ),
                        if (punto.horario case final horario?) ...[
                          const _Separador(),
                          _Linea(
                            icono: Icons.schedule_outlined,
                            texto: 'Horario: $horario',
                            estilo: AppTextStyles.cuerpo
                                .copyWith(color: AppColors.textPrimary),
                          ),
                        ],
                        const _Separador(),
                        _Procedencia(fuente: punto.fuente),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _ComoLlegar(punto: punto),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Medallón, nombre, qué es y a cuánto, y la X.
class _Cabecera extends ConsumerWidget {
  const _Cabecera({required this.punto, required this.metros});

  final PuntoDeRecarga punto;
  final int? metros;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // El medallón es el mismo marcador morado del mapa: la ficha se lee
        // como la de ese punto y no como otra cosa.
        const SizedBox(
          width: 48,
          height: 48,
          child: CustomPaint(painter: MarcadorRecargaPainter(sombra: false)),
        ),
        const SizedBox(width: AppSpacing.md - 4),
        Expanded(
          child: Padding(
            // Centra el título de 18 con el medallón de 48.
            padding: const EdgeInsets.only(top: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nombreDelPunto(punto.nombre),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.subtitulo
                      .copyWith(color: AppColors.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  metros == null
                      ? 'Punto de recarga'
                      : 'Punto de recarga a ${distanciaAviso(metros!)} '
                          'de tu punto',
                  style: AppTextStyles.etiqueta.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (punto.esEjemplo) ...[
                  const SizedBox(height: AppSpacing.sm),
                  const _InsigniaEjemplo(),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        _Cerrar(
          onTap: () =>
              ref.read(puntoRecargaElegidoProvider.notifier).state = null,
        ),
      ],
    );
  }
}

/// La X de Apple Maps: un círculo gris de 30 dentro de un toque de 44.
class _Cerrar extends StatelessWidget {
  const _Cerrar({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Cerrar',
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Align(
            alignment: Alignment.topCenter,
            child: Container(
              width: 30,
              height: 30,
              decoration: const BoxDecoration(
                color: AppColors.surfaceMuted,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close_rounded,
                size: 18,
                color: AppColors.textBody,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Raya fina entre dos líneas del panel, alineada con el texto.
class _Separador extends StatelessWidget {
  const _Separador();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Divider(height: 1, thickness: 1, color: AppColors.filo),
      );
}

class _InsigniaEjemplo extends StatelessWidget {
  const _InsigniaEjemplo();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.warningLight,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      // warningAccessible sobre warningLight: 5,3:1.
      child: Text(
        'Ejemplo',
        style: AppTextStyles.pie.copyWith(
          color: AppColors.warningAccessible,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Una línea de la ficha con su glifo gris delante, alineado a la primera
/// línea del texto.
class _Linea extends StatelessWidget {
  const _Linea(
      {required this.icono, required this.texto, required this.estilo});

  final IconData icono;
  final String texto;
  final TextStyle estilo;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icono, size: 18, color: AppColors.textSecondary),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: Text(texto, style: estilo)),
      ],
    );
  }
}

/// De dónde sale el punto: la fuente con su fecha, o que es de ejemplo.
class _Procedencia extends StatelessWidget {
  const _Procedencia({required this.fuente});

  final Fuente fuente;

  @override
  Widget build(BuildContext context) {
    final estilo = AppTextStyles.pie.copyWith(color: AppColors.textSecondary);
    return switch (fuente) {
      FuenteCitada(:final nombre, :final fecha) => _Linea(
          icono: Icons.info_outline,
          texto: 'Fuente: $nombre, consultada el ${fechaDeLaFuente(fecha)}',
          estilo: estilo,
        ),
      FuenteEjemplo() => _Linea(
          icono: Icons.info_outline,
          texto: 'Punto de ejemplo, sin fuente: no es un lugar real',
          estilo: estilo.copyWith(color: AppColors.warningAccessible),
        ),
    };
  }
}

class _ComoLlegar extends ConsumerWidget {
  const _ComoLlegar({required this.punto});

  final PuntoDeRecarga punto;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Letra blanca sobre el azul de los botones: 7,1:1.
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: () => ref
            .read(abrirEnlaceProvider)
            .call(enlaceComoLlegar(punto, defaultTargetPlatform)),
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.acento,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(48),
          shape: const StadiumBorder(),
          textStyle: AppTextStyles.cuerpoFuerte,
        ),
        icon: const Icon(Icons.directions_walk_rounded, size: 20),
        label: const Text('Cómo llegar'),
      ),
    );
  }
}
