import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ya_viene_core/ya_viene_core.dart';

import '../providers/red_provider.dart';
import 'tamano_animado.dart';

/// Una carga que falló, dicha con su causa y con un «Reintentar» que se ve
/// trabajar.
///
/// Antes era «Error al cargar empresas» y un botón de texto. Tocarlo no
/// cambiaba nada en pantalla: Riverpod deja el error puesto mientras vuelve
/// a pedir, y sin red el segundo intento falla en milisegundos, así que el
/// botón parecía muerto (dueño, 2026-09-30). Ahora el intento dura al menos
/// un [AppMotion.pulso] con los puntos de espera a la vista, y si vuelve a
/// fallar la tarjeta se sacude y lo dice. Tampoco culpa a nadie a ciegas:
/// sin red dice «Sin conexión», con el servidor caído dice que no es la
/// conexión del pasajero.
class AvisoFallo extends ConsumerStatefulWidget {
  const AvisoFallo({
    super.key,
    required this.error,
    required this.que,
    required this.onReintentar,
    this.compacto = false,
  });

  /// Lo que lanzó la carga. Decide la causa que se cuenta.
  final Object error;

  /// Lo que no cargó, con su artículo: «las empresas», «las rutas».
  final String que;

  /// Vuelve a pedir. El futuro falla si la carga vuelve a fallar.
  final Future<void> Function() onReintentar;

  /// En el hueco de una fila del selector (78 de alto) en vez de en el de
  /// una lista entera.
  final bool compacto;

  @override
  ConsumerState<AvisoFallo> createState() => _AvisoFalloState();
}

typedef _Causa = ({
  IconData icono,
  Color color,
  Color tinte,
  String titulo,
  String detalle,
});

/// Qué se dice de cada causa. El ámbar es «revisa lo tuyo» y el coral «no
/// depende de ti»: los mismos dos tonos que ya separan en la píldora de
/// ubicación lo que el pasajero arregla de lo que no.
_Causa _causa(FalloRed fallo) => switch (fallo) {
      FalloRed.sinConexion => (
          icono: Icons.wifi_off_outlined,
          color: AppColors.warningAccessible,
          tinte: AppColors.warningLight,
          titulo: 'Sin conexión',
          detalle: 'Revisa tus datos o el wifi.',
        ),
      FalloRed.lento => (
          icono: Icons.schedule_outlined,
          color: AppColors.warningAccessible,
          tinte: AppColors.warningLight,
          titulo: 'El servidor no responde',
          detalle: 'Está tardando más de lo normal.',
        ),
      FalloRed.servidor => (
          icono: Icons.cloud_off_outlined,
          color: AppColors.coralAccessible,
          tinte: AppColors.coralLight,
          titulo: 'Falla en el servidor',
          detalle: 'No es tu conexión. Intenta en un momento.',
        ),
    };

class _AvisoFalloState extends ConsumerState<AvisoFallo>
    with SingleTickerProviderStateMixin {
  bool _reintentando = false;

  /// La espera mínima del intento. Se cancela si el aviso se va: cuando la
  /// carga sale bien, la lista lo reemplaza antes de que se cumpla.
  Timer? _minimo;

  late final AnimationController _sacudida = AnimationController(
    vsync: this,
    duration: AppMotion.entrada,
  );

  @override
  void dispose() {
    _minimo?.cancel();
    _sacudida.dispose();
    super.dispose();
  }

  Future<void> _reintentar({bool solo = false}) async {
    if (_reintentando) return;
    if (!solo) HapticFeedback.lightImpact();
    setState(() => _reintentando = true);
    // Si la carga sale bien, el selector cambia este aviso por la lista y
    // el estado se desmonta; si falla, el futuro falla. No se puede mirar
    // `mounted` para saberlo: la lista entra en el cuadro siguiente.
    // Sin red el intento falla al instante y la espera no se llegaba a
    // ver: un pulso entero es lo mínimo que se lee como «lo intentó».
    final espera = Completer<void>();
    _minimo = Timer(AppMotion.pulso, espera.complete);
    final fallo = await Future.wait([
      Future.sync(widget.onReintentar),
      espera.future,
    ]).then((_) => false, onError: (Object _) => true);
    if (!mounted) return;
    setState(() => _reintentando = false);
    if (fallo) _negar();
  }

  /// Volvió a fallar: lo dice la tarjeta, el pulgar y el lector.
  void _negar() {
    HapticFeedback.mediumImpact();
    _sacudida.forward(from: 0);
    final causa = _causa(_fallo());
    SemanticsService.sendAnnouncement(
      View.of(context),
      'Sigue sin cargar. ${causa.titulo}',
      TextDirection.ltr,
    );
  }

  /// La causa que se cuenta. Si el teléfono sabe que no tiene red, manda
  /// sobre lo que diga el error: un túnel que no contesta sin wifi es el
  /// wifi, no el túnel.
  FalloRed _fallo() => ref.read(hayRedProvider).valueOrNull == false
      ? FalloRed.sinConexion
      : clasificarFallo(widget.error);

  @override
  Widget build(BuildContext context) {
    ref.watch(hayRedProvider);
    // La red volvió: se vuelve a pedir sin esperar a que lo pidan.
    ref.listen<AsyncValue<bool>>(hayRedProvider, (antes, ahora) {
      if (antes?.valueOrNull == false && ahora.valueOrNull == true) {
        _reintentar(solo: true);
      }
    });
    final causa = _causa(_fallo());
    final amplitud = AppMotion.reducido(context) ? 0.0 : 6.0;

    return AnimatedBuilder(
      animation: _sacudida,
      builder: (context, child) {
        final t = _sacudida.value;
        // El mismo seno amortiguado que sacude la fila del selector cuando
        // falta la empresa: tres idas y vueltas que se apagan solas.
        final dx = t == 0 || t == 1
            ? 0.0
            : math.sin(t * math.pi * 6) * (1 - t) * amplitud;
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
      child: widget.compacto ? _compacto(causa) : _completo(causa),
    );
  }

  /// En el hueco de la fila de empresa: la misma silueta que la fila, con
  /// la causa donde iba el nombre y el botón donde iba la flecha. La fila
  /// entera reintenta; el círculo solo dice dónde.
  Widget _compacto(_Causa causa) {
    final sub = _reintentando ? 'Reintentando…' : 'No cargaron ${widget.que}';
    return Semantics(
      button: true,
      enabled: !_reintentando,
      liveRegion: true,
      label: _reintentando
          ? 'Reintentando'
          : '${causa.titulo}. No cargaron ${widget.que}. ${causa.detalle} '
              'Reintentar',
      onTap: _reintentando ? null : _reintentar,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _reintentando ? null : _reintentar,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Row(
            children: [
              _medallon(causa, lado: 44, icono: 22, aro: 0),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      causa.titulo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.subtitulo
                          .copyWith(color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      sub,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.pie,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              // 40 y no 44: la fila entera es el blanco del dedo; el
              // círculo es la señal, y a 44 tocaba el filo de la fila.
              AnimatedContainer(
                duration: AppMotion.rapido,
                curve: AppMotion.curvaEntrada,
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color:
                      _reintentando ? AppColors.surfaceMuted : AppColors.acento,
                  shape: BoxShape.circle,
                ),
                child: _icono(tamano: 20, lleno: !_reintentando),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// En el sitio de una lista: una tarjeta plana con su filo, como las de
  /// Avisos y el buzón, el medallón con su aro de la causa y un botón lleno
  /// del azul de los botones. Antes iba suelto sobre el fondo, con un cuadro
  /// de color y una píldora tenue: se veía pobre (dueño, 2026-10-27).
  Widget _completo(_Causa causa) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: AppColors.filo),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.md + 4,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(
                liveRegion: true,
                container: true,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _medallon(causa, lado: 56, icono: 26, aro: 10),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      causa.titulo,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.subtitulo
                          .copyWith(color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'No cargaron ${widget.que}. ${causa.detalle}',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.cuerpo
                          .copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Semantics(
                button: true,
                enabled: !_reintentando,
                label: _reintentando ? 'Reintentando' : 'Reintentar',
                onTap: _reintentando ? null : _reintentar,
                excludeSemantics: true,
                // Blanco sobre [AppColors.acento] da 7,1:1; mientras
                // intenta se apaga a gris y los puntos van en verde.
                child: AnimatedContainer(
                  duration: AppMotion.rapido,
                  curve: AppMotion.curvaCambio,
                  decoration: BoxDecoration(
                    color: _reintentando
                        ? AppColors.surfaceMuted
                        : AppColors.acento,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Material(
                    type: MaterialType.transparency,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      onTap: _reintentando ? null : _reintentar,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          minHeight: 48,
                          minWidth: double.infinity,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _icono(tamano: 18, lleno: !_reintentando),
                              const SizedBox(width: AppSpacing.sm),
                              // El ancho cambia con el texto; que lo haga
                              // deslizando y no a saltos.
                              TamanoAnimado(
                                duracion: AppMotion.rapido,
                                child: Text(
                                  _reintentando
                                      ? 'Reintentando…'
                                      : 'Reintentar',
                                  style: AppTextStyles.boton.copyWith(
                                    color: _reintentando
                                        ? AppColors.textSecondary
                                        : AppColors.surface,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// El ícono de la causa en un círculo de su tinte y, con [aro], un halo
  /// del mismo tinte a media fuerza alrededor: se lee como un estado, no
  /// como un botón cuadrado.
  Widget _medallon(
    _Causa causa, {
    required double lado,
    required double icono,
    required double aro,
  }) {
    return AnimatedContainer(
      duration: AppMotion.rapido,
      curve: AppMotion.curvaEntrada,
      width: lado + aro * 2,
      height: lado + aro * 2,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: causa.tinte.withValues(alpha: aro > 0 ? 0.5 : 0),
        shape: BoxShape.circle,
      ),
      child: AnimatedContainer(
        duration: AppMotion.rapido,
        curve: AppMotion.curvaEntrada,
        width: lado,
        height: lado,
        decoration: BoxDecoration(color: causa.tinte, shape: BoxShape.circle),
        child: Icon(causa.icono, size: icono, color: causa.color),
      ),
    );
  }

  /// La flecha de reintentar o, mientras se intenta, los puntos de espera
  /// de toda la app. Se cruzan en vez de saltar.
  Widget _icono({required double tamano, bool lleno = false}) {
    return AnimatedSwitcher(
      duration: AppMotion.duracion(context, AppMotion.rapido),
      switchInCurve: AppMotion.curvaEntrada,
      switchOutCurve: AppMotion.curvaSalida,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(scale: animation, child: child),
      ),
      child: _reintentando
          ? IndicadorCarga(
              key: const ValueKey('ocupado'),
              size: tamano + 4,
              color: AppColors.primaryAccessible,
            )
          : Icon(
              Icons.refresh_rounded,
              key: const ValueKey('listo'),
              size: tamano,
              color: lleno ? AppColors.surface : AppColors.primaryAccessible,
            ),
    );
  }
}
