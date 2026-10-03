import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ya_viene_core/ya_viene_core.dart';

import '../data/buzon.dart';

/// El buzón del pasajero: un problema o una sugerencia, escrito en un
/// campo y mandado al equipo (D14 del backend).
///
/// Pantalla entera y no una ventana: hay un teclado abierto y un texto de
/// hasta mil caracteres, y en una ventana sobre el mapa el teclado se come
/// la mitad. La barra es la de Avisos, el fondo arena de las pantallas
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.arena,
      appBar: AppBar(
        backgroundColor: AppColors.arena,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        // El techo de texto grande de la barra de Avisos, por lo mismo: la
        // barra mide 56 y no se estira.
        title: MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.3,
          child: const Text('Problemas y sugerencias'),
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_outlined,
            size: 20,
            semanticLabel: 'Volver',
          ),
          tooltip: 'Volver',
          color: AppColors.textPrimary,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        top: false,
        child: AnimatedSwitcher(
          duration: AppMotion.duracion(context, AppMotion.normal),
          switchInCurve: AppMotion.curvaEntrada,
          switchOutCurve: AppMotion.curvaSalida,
          child: _recibido
              ? const _Gracias(key: ValueKey('buzon_gracias'))
              : _formulario(),
        ),
      ),
    );
  }

  Widget _formulario() {
    final problema = _tipo == TipoReporte.problema;
    return ListView(
      key: const ValueKey('buzon_formulario'),
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.lg),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        Semantics(
          header: true,
          child: Text('¿Qué nos quieres contar?', style: AppTextStyles.titulo),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: _Opcion(
                key: const ValueKey('buzon_problema'),
                icono: Icons.report_gmailerrorred_outlined,
                texto: 'Un problema',
                elegida: problema,
                alPulsar: () => setState(() => _tipo = TipoReporte.problema),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _Opcion(
                key: const ValueKey('buzon_sugerencia'),
                icono: Icons.lightbulb_outline_rounded,
                texto: 'Una sugerencia',
                elegida: !problema,
                alPulsar: () => setState(() => _tipo = TipoReporte.sugerencia),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          key: const ValueKey('buzon_texto'),
          controller: _texto,
          enabled: !_enviando,
          minLines: 6,
          maxLines: 12,
          maxLength: Buzon.maximo,
          textCapitalization: TextCapitalization.sentences,
          style: AppTextStyles.cuerpo.copyWith(color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: problema
                ? 'Qué pasó, en qué ruta y más o menos a qué hora.'
                : 'Qué mejorarías o qué te gustaría ver en la app.',
            hintStyle:
                AppTextStyles.cuerpo.copyWith(color: AppColors.textSecondary),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.all(AppSpacing.md),
            counterStyle:
                AppTextStyles.pie.copyWith(color: AppColors.textSecondary),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              borderSide: const BorderSide(color: AppColors.hairline),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              borderSide: const BorderSide(color: AppColors.hairline),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              borderSide: const BorderSide(
                  color: AppColors.primaryAccessible, width: 2),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ExcludeSemantics(
              child: Padding(
                padding: EdgeInsets.only(top: 1),
                child: Icon(Icons.lock_outline_rounded,
                    size: 16, color: AppColors.textSecondary),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Lo lee el equipo de Ya Viene. No incluyas datos personales.',
                style:
                    AppTextStyles.pie.copyWith(color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
        if (_fallo case final fallo?) ...[
          const SizedBox(height: AppSpacing.md),
          _Fallo(fallo),
        ],
        const SizedBox(height: AppSpacing.lg),
        SizedBox(
          height: 56,
          child: FilledButton(
            key: const ValueKey('buzon_enviar'),
            onPressed: _listo ? _enviar : null,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              textStyle: AppTextStyles.boton,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
            child: _enviando
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                      semanticsLabel: 'Enviando',
                    ),
                  )
                : Text(_fallo == null ? 'Enviar' : 'Intentar de nuevo'),
          ),
        ),
      ],
    );
  }
}

/// Una de las dos opciones: tarjeta blanca con filo; la elegida, con el
/// tinte y el filo verdes de la ruta activa del menú.
class _Opcion extends StatelessWidget {
  const _Opcion({
    super.key,
    required this.icono,
    required this.texto,
    required this.elegida,
    required this.alPulsar,
  });

  final IconData icono;
  final String texto;
  final bool elegida;
  final VoidCallback alPulsar;

  @override
  Widget build(BuildContext context) {
    final color = elegida ? AppColors.primaryDeep : AppColors.textBody;
    return Semantics(
      button: true,
      selected: elegida,
      label: texto,
      // excludeSemantics se lleva también el toque del InkWell: el lector
      // lo recibe aquí.
      onTap: alPulsar,
      excludeSemantics: true,
      child: Material(
        color:
            elegida ? AppColors.primary.withValues(alpha: 0.10) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(
            color: elegida ? AppColors.primaryAccessible : AppColors.hairline,
            width: elegida ? 2 : 1,
          ),
        ),
        child: InkWell(
          onTap: alPulsar,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icono, size: 20, color: color),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      texto,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.cuerpoFuerte.copyWith(color: color),
                    ),
                  ),
                ],
              ),
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

/// El reporte llegó: lo dice y deja volver.
class _Gracias extends StatelessWidget {
  const _Gracias({super.key});

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
                onPressed: () => Navigator.of(context).pop(),
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
