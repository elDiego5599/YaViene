import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ya_viene_core/ya_viene_core.dart';

import '../../../core/router/app_router.dart';
import '../../../core/widgets/borde_desvanecido.dart';
import '../data/buzon.dart';

/// El buzón del pasajero: un problema o una sugerencia, escrito en un
/// campo y mandado al equipo (D14 del backend).
///
/// Pantalla entera y no una ventana: hay un teclado abierto y un texto de
/// hasta mil caracteres, y en una ventana sobre el mapa el teclado se come
/// la mitad. La barra es la de Avisos, el fondo blanco de las pantallas
/// claras y el botón el verde lleno de la entrada.
///
/// Sin campo de contacto a propósito (Ley 1581): el equipo no contesta por
/// aquí, y la nota de abajo pide que no se escriban datos personales.
class BuzonScreen extends ConsumerStatefulWidget {
  const BuzonScreen({super.key});

  @override
  ConsumerState<BuzonScreen> createState() => _BuzonScreenState();
}

class _BuzonScreenState extends ConsumerState<BuzonScreen> {
  final _texto = TextEditingController();
  TipoReporte _tipo = TipoReporte.problema;
  bool _enviando = false;
  bool _recibido = false;
  EnvioReporte? _fallo;

  @override
  void initState() {
    super.initState();
    // El botón se enciende y se apaga mientras se escribe.
    _texto.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _texto.dispose();
    super.dispose();
  }

  bool get _listo =>
      !_enviando && _texto.text.trim().runes.length >= Buzon.minimo;

  Future<void> _enviar() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _enviando = true;
      _fallo = null;
    });
    final resultado = await ref.read(buzonProvider).enviar(_tipo, _texto.text);
    if (!mounted) return;
    setState(() {
      _enviando = false;
      _recibido = resultado == EnvioReporte.recibido;
      // Si falla, el texto se queda: se reintenta con el mismo botón.
      _fallo = _recibido ? null : resultado;
    });
  }

  /// De vuelta al mapa, con el buzón limpio para la próxima vez: la
  /// pestaña sigue viva detrás de la barra y, sin esto, al volver a ella
  /// seguiría dando las gracias por lo de antes.
  void _volver() {
    _texto.clear();
    setState(() {
      _recibido = false;
      _tipo = TipoReporte.problema;
    });
    context.go(AppRoutes.map);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        // Lo que pasa debajo se funde (`BordeDesvanecido`): la barra no se
        // oscurece ni se separa con sombra.
        scrolledUnderElevation: 0,
        centerTitle: true,
        // El techo de texto grande de la barra de Avisos, por lo mismo: la
        // barra mide 56 y no se estira.
        title: MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.3,
          child: const Text('¿Qué nos quieres contar?'),
        ),
        // Sin flecha: el buzón es una pestaña de la barra de abajo.
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        top: false,
        child: AnimatedSwitcher(
          duration: AppMotion.duracion(context, AppMotion.normal),
          switchInCurve: AppMotion.curvaEntrada,
          switchOutCurve: AppMotion.curvaSalida,
          child: _recibido
              ? _Gracias(
                  key: const ValueKey('buzon_gracias'),
                  alVolver: _volver,
                )
              : _formulario(),
        ),
      ),
    );
  }

  /// El formulario arriba, que se desplaza, y el botón abajo, fijo: con el
  /// teclado abierto el botón sube con él y sigue a la mano, y con la
  /// pantalla vacía no flota a media altura.
  Widget _formulario() {
    final problema = _tipo == TipoReporte.problema;
    return Column(
      key: const ValueKey('buzon_formulario'),
      children: [
        Expanded(
          child: BordeDesvanecido(
            // Al subir, el formulario se disuelve bajo la barra en vez de
            // cortarse en seco contra ella (dueño, 2026-10-16).
            child: ListView(
              // Arriba, lo que se funde: en reposo el encabezado queda
              // entero.
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg,
                  BordeDesvanecido.alto, AppSpacing.lg, AppSpacing.lg),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              children: [
                const _Encabezado(),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _Opcion(
                        key: const ValueKey('buzon_problema'),
                        icono: Icons.report_gmailerrorred_outlined,
                        texto: 'Un problema',
                        detalle: 'Algo no funciona bien',
                        elegida: problema,
                        alPulsar: () =>
                            setState(() => _tipo = TipoReporte.problema),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _Opcion(
                        key: const ValueKey('buzon_sugerencia'),
                        icono: Icons.lightbulb_outline_rounded,
                        texto: 'Una sugerencia',
                        detalle: 'Una idea para mejorar',
                        elegida: !problema,
                        alPulsar: () =>
                            setState(() => _tipo = TipoReporte.sugerencia),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Tarjeta blanca con sombra suave, como las opciones: el filo
                // solo aparece, verde, mientras se escribe.
                DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    boxShadow: AppShadows.soft,
                  ),
                  child: TextField(
                    key: const ValueKey('buzon_texto'),
                    controller: _texto,
                    enabled: !_enviando,
                    minLines: 7,
                    maxLines: 12,
                    maxLength: Buzon.maximo,
                    textCapitalization: TextCapitalization.sentences,
                    style: AppTextStyles.cuerpo
                        .copyWith(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: problema
                          ? 'Qué pasó, en qué ruta y más o menos a qué hora.'
                          : 'Qué mejorarías o qué te gustaría ver en la app.',
                      hintStyle: AppTextStyles.cuerpo
                          .copyWith(color: AppColors.textSecondary),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding:
                          const EdgeInsets.fromLTRB(20, 18, 20, AppSpacing.md),
                      counterStyle: AppTextStyles.pie
                          .copyWith(color: AppColors.textSecondary),
                      enabledBorder: _filo(AppColors.hairline, 1),
                      disabledBorder: _filo(AppColors.hairline, 1),
                      focusedBorder: _filo(AppColors.primaryAccessible, 2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const _NotaPrivacidad(),
              ],
            ),
          ),
        ),
        // El fallo va pegado al botón fijo y no al final de la lista: así
        // se ve siempre, también con el campo lleno o en un teléfono bajo.
        if (_fallo case final fallo?)
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 0),
            child: _Fallo(fallo),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.md),
          // Mientras viaja, el botón dice lo que hace y sigue verde (no se
          // apaga: no falta nada, solo esperar) y una barra de 2 px corre
          // por el tramo recto de su filo de abajo, 28 por lado (el radio
          // de la píldora de 56), como el aviso de la web.
          child: SizedBox(
            height: 56,
            width: double.infinity,
            child: Stack(
              children: [
                Positioned.fill(
                  child: FilledButton(
                    key: const ValueKey('buzon_enviar'),
                    onPressed: _listo ? _enviar : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                          _enviando ? AppColors.primary : null,
                      disabledForegroundColor: _enviando ? Colors.white : null,
                      textStyle: AppTextStyles.boton,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                    ),
                    child: _enviando
                        ? const Text('Enviando…')
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(_fallo == null
                                  ? 'Enviar'
                                  : 'Intentar de nuevo'),
                              const SizedBox(width: AppSpacing.sm),
                              const ExcludeSemantics(
                                child: Icon(Icons.send_rounded, size: 18),
                              ),
                            ],
                          ),
                  ),
                ),
                if (_enviando)
                  const Positioned(
                    left: 28,
                    right: 28,
                    bottom: 0,
                    child: ExcludeSemantics(
                      child: LinearProgressIndicator(
                        minHeight: 2,
                        color: Colors.white,
                        backgroundColor: Colors.white24,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  OutlineInputBorder _filo(Color color, double ancho) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        borderSide: BorderSide(color: color, width: ancho),
      );
}

/// Bajo la pregunta del título, una línea que dice para qué sirve el
/// buzón. El ícono y la pregunta repetida se fueron: la pregunta es el
/// título de la página (dueño, 2026-10-05).
class _Encabezado extends StatelessWidget {
  const _Encabezado();

  @override
  Widget build(BuildContext context) {
    return Text(
      'Lo leemos todo y nos ayuda a mejorar Ya Viene.',
      style: AppTextStyles.cuerpo.copyWith(color: AppColors.textBody),
    );
  }
}

/// El candado y la nota en una pastilla arena oscura: se ve, pero no
/// compite con el campo.
class _NotaPrivacidad extends StatelessWidget {
  const _NotaPrivacidad();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primaryDeep.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ExcludeSemantics(
            child: Padding(
              padding: EdgeInsets.only(top: 1),
              child: Icon(Icons.lock_outline_rounded,
                  size: 16, color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Lo lee el equipo de Ya Viene. No incluyas datos personales.',
              style: AppTextStyles.pie.copyWith(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

/// Una de las dos opciones: tarjeta blanca con sombra suave, ícono en su
/// círculo, nombre y una línea que lo explica. La elegida toma el tinte y
/// el filo verdes de la ruta activa del menú y una marca en la esquina; el
/// cambio se anima (y no, con «Reducir movimiento»).
class _Opcion extends StatelessWidget {
  const _Opcion({
    super.key,
    required this.icono,
    required this.texto,
    required this.detalle,
    required this.elegida,
    required this.alPulsar,
  });

  final IconData icono;
  final String texto;
  final String detalle;
  final bool elegida;
  final VoidCallback alPulsar;

  @override
  Widget build(BuildContext context) {
    final duracion = AppMotion.duracion(context, AppMotion.rapido);
    final radio = BorderRadius.circular(AppRadius.card - 4);
    return Semantics(
      button: true,
      selected: elegida,
      label: texto,
      hint: detalle,
      // excludeSemantics se lleva también el toque del InkWell: el lector
      // lo recibe aquí.
      onTap: alPulsar,
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: duracion,
        curve: AppMotion.curvaEntrada,
        decoration: BoxDecoration(
          color: elegida ? AppColors.primaryTint : Colors.white,
          borderRadius: radio,
          border: Border.all(
            color: elegida ? AppColors.primaryAccessible : AppColors.hairline,
            width: elegida ? 2 : 1,
          ),
          boxShadow: elegida ? null : AppShadows.soft,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: alPulsar,
            borderRadius: radio,
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AnimatedContainer(
                        duration: duracion,
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: elegida
                              ? AppColors.primary
                              : AppColors.primaryDeep.withValues(alpha: 0.06),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icono,
                            size: 22,
                            color: elegida ? Colors.white : AppColors.textBody),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        texto,
                        style: AppTextStyles.cuerpoFuerte.copyWith(
                          color: elegida
                              ? AppColors.primaryDeep
                              : AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        detalle,
                        style: AppTextStyles.pie
                            .copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: AnimatedScale(
                    scale: elegida ? 1 : 0,
                    duration: duracion,
                    curve: AppMotion.curvaEntrada,
                    child: const Icon(Icons.check_circle_rounded,
                        size: 22, color: AppColors.primaryAccessible),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Por qué no salió, dicho junto al botón que lo reintenta.
class _Fallo extends StatelessWidget {
  const _Fallo(this.fallo);

  final EnvioReporte fallo;

  @override
  Widget build(BuildContext context) {
    final mensaje = switch (fallo) {
      EnvioReporte.muchos =>
        'Ya enviaste varios hace poco. Inténtalo de nuevo en unos minutos.',
      EnvioReporte.noDisponible =>
        'El buzón no está disponible ahora. Inténtalo más tarde.',
      _ => 'No se pudo enviar. Revisa tu conexión e inténtalo de nuevo.',
    };
    return Semantics(
      liveRegion: true,
      child: Container(
        key: const ValueKey('buzon_fallo'),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.errorLight,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ExcludeSemantics(
              child: Icon(Icons.error_outline_rounded,
                  size: 20, color: AppColors.error),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                mensaje,
                style:
                    AppTextStyles.cuerpo.copyWith(color: AppColors.textPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// El reporte llegó: lo dice y deja volver al mapa.
class _Gracias extends StatelessWidget {
  const _Gracias({super.key, required this.alVolver});

  final VoidCallback alVolver;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: ExcludeSemantics(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_rounded,
                      size: 40, color: AppColors.primaryAccessible),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Semantics(
              header: true,
              liveRegion: true,
              child: Text(
                'Gracias, lo recibimos',
                style: AppTextStyles.titulo,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'El equipo de Ya Viene lo va a leer.',
              style: AppTextStyles.cuerpo.copyWith(color: AppColors.textBody),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            SizedBox(
              height: 56,
              child: FilledButton(
                key: const ValueKey('buzon_volver'),
                onPressed: alVolver,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  textStyle: AppTextStyles.boton,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                ),
                child: const Text('Volver'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
