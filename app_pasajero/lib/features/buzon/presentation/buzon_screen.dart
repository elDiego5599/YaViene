import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ya_viene_core/ya_viene_core.dart';

import '../../../core/router/app_router.dart';
import '../../../core/widgets/barra_vidrio.dart';
import '../../../core/widgets/cabecera_degradada.dart';
import '../../../core/widgets/fondo_texturizado.dart';
import '../../../core/widgets/tamano_animado.dart';
import '../../../core/widgets/titulo_seccion.dart';
import '../../map/presentation/providers/user_location_provider.dart';
import '../data/buzon.dart';
import 'queja.dart';

/// El buzón del pasajero: un problema o una sugerencia, escrito en un
/// campo y mandado al equipo (D14 del backend), o una queja sobre un bus,
/// con su motivo y, si se quiere, la ruta, el bus, la hora y la zona (D18).
///
/// Pantalla entera y no una ventana: hay un teclado abierto y un texto de
/// hasta mil caracteres, y en una ventana sobre el mapa el teclado se come
/// la mitad. La barra es la de Avisos, el fondo el gris agrupado de
/// Avisos con tarjetas blancas planas, y el botón el verde lleno de la
/// entrada.
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

  // Lo que solo lleva la queja. Sin hora elegida va la de ahora.
  MotivoQueja? _motivo;
  RouteInfo? _ruta;
  String? _bus;
  DateTime? _hora;
  bool _compartir = false;

  bool get _esQueja => _tipo == TipoReporte.queja;

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

  /// La queja se manda con su motivo y nada más; si se escribe algo, que
  /// sea un mensaje y no dos letras.
  bool get _listo {
    if (_enviando) return false;
    final letras = _texto.text.trim().runes.length;
    if (_esQueja) {
      return _motivo != null && (letras == 0 || letras >= Buzon.minimo);
    }
    return letras >= Buzon.minimo;
  }

  DatosQueja? _datosQueja() {
    final motivo = _motivo;
    if (!_esQueja || motivo == null) return null;
    final punto = ref.read(userLocationProvider);
    return DatosQueja(
      motivo: motivo,
      routeId: _ruta?.id,
      busId: _bus,
      hora: _hora ?? DateTime.now(),
      ubicacion: switch ((punto.lat, punto.lon)) {
        (final lat?, final lon?) => (lat: lat, lng: lon),
        _ => null,
      },
      compartirLugar: _compartir,
    );
  }

  void _elegirTipo(TipoReporte tipo) {
    setState(() {
      _tipo = tipo;
      // La ruta que se está viendo en el mapa es casi siempre la de la queja.
      if (tipo == TipoReporte.queja) _ruta ??= ref.read(selectedRouteProvider);
    });
  }

  Future<void> _enviar() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _enviando = true;
      _fallo = null;
    });
    final resultado = await ref
        .read(buzonProvider)
        .enviar(_tipo, _texto.text, queja: _datosQueja());
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
      _motivo = null;
      _ruta = null;
      _bus = null;
      _hora = null;
      _compartir = false;
    });
    context.go(AppRoutes.map);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Blanco como Avisos, con las tarjetas partidas por el filo azul
      // noche de la app y sin sombras (dueño, 2026-10-19).
      backgroundColor: AppColors.surface,
      // El formulario pasa por debajo de la barra, que es de vidrio (dueño,
      // 2026-10-18).
      extendBodyBehindAppBar: true,
      appBar: barraVidrio(
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
        child: Stack(
          children: [
            // El grano de la bienvenida en la parte blanca; la cabecera,
            // opaca, lo tapa arriba (dueño, 2026-10-27).
            const Positioned.fill(child: Grano(key: ValueKey('buzon-grano'))),
            // El degradado de la cabecera con su raya: bajo el título, hasta
            // donde termina la barra (el relleno de arriba del cuerpo ya la
            // suma).
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Builder(
                builder: (context) => SizedBox(
                  height: MediaQuery.paddingOf(context).top,
                  child:
                      const CabeceraDegradada(key: ValueKey('buzon-cabecera')),
                ),
              ),
            ),
            AnimatedSwitcher(
              duration: AppMotion.duracion(context, AppMotion.normal),
              switchInCurve: AppMotion.curvaEntrada,
              switchOutCurve: AppMotion.curvaSalida,
              child: _recibido
                  ? _Gracias(
                      key: const ValueKey('buzon_gracias'),
                      alVolver: _volver,
                    )
                  // Bajo el Scaffold, que suma la barra al relleno de arriba.
                  : Builder(
                      key: const ValueKey('buzon_formulario'),
                      builder: _formulario,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// El formulario arriba, que se desplaza, y el botón abajo, fijo: con el
  /// teclado abierto el botón sube con él y sigue a la mano, y con la
  /// pantalla vacía no flota a media altura.
  Widget _formulario(BuildContext context) {
    final hayPunto = ref.watch(userLocationProvider).hasPosition;
    return Column(
      children: [
        Expanded(
          // Al subir, el formulario pasa por debajo de la barra de vidrio;
          // en reposo empieza bajo ella, con el aire que tenía.
          child: ListView(
            padding: EdgeInsets.fromLTRB(
                AppSpacing.lg,
                MediaQuery.paddingOf(context).top + AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.lg),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            // Una sola columna, entera: con hijos perezosos, lo que queda
            // bajo el teclado no existe y el lector de pantalla no lo alcanza.
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _Encabezado(),
                  // Bloques con su título, como Salud del iPhone (dueño,
                  // 2026-10-18: «separaciones entre títulos»).
                  const TituloSeccion('Tipo de mensaje'),
                  // Tres en columna y no en fila: con la queja (D18), de lado
                  // cada una quedaba en 100 pt y su línea de detalle se partía.
                  _Opcion(
                    key: const ValueKey('buzon_problema'),
                    icono: Icons.report_gmailerrorred_outlined,
                    texto: 'Un problema',
                    detalle: 'Algo no funciona bien',
                    tinta: AppColors.coralAccessible,
                    tinte: AppColors.coralLight,
                    elegida: _tipo == TipoReporte.problema,
                    alPulsar: () => _elegirTipo(TipoReporte.problema),
                  ),
                  const SizedBox(height: 12),
                  _Opcion(
                    key: const ValueKey('buzon_queja'),
                    icono: Icons.directions_bus_outlined,
                    texto: 'Una queja',
                    detalle: 'Sobre un bus o su conductor',
                    tinta: AppColors.acento,
                    tinte: _tinteQueja,
                    elegida: _esQueja,
                    alPulsar: () => _elegirTipo(TipoReporte.queja),
                  ),
                  const SizedBox(height: 12),
                  _Opcion(
                    key: const ValueKey('buzon_sugerencia'),
                    icono: Icons.lightbulb_outline_rounded,
                    texto: 'Una sugerencia',
                    detalle: 'Una idea para mejorar',
                    tinta: AppColors.warningAccessible,
                    tinte: AppColors.warningLight,
                    elegida: _tipo == TipoReporte.sugerencia,
                    alPulsar: () => _elegirTipo(TipoReporte.sugerencia),
                  ),
                  // Los campos de la queja abren y cierran el hueco con el
                  // resorte de la app, sin empujar de golpe el mensaje.
                  TamanoAnimado(
                    duracion: AppMotion.normal,
                    alineacion: Alignment.topCenter,
                    child: _esQueja
                        ? CamposQueja(
                            motivo: _motivo,
                            ruta: _ruta,
                            bus: _bus,
                            hora: _hora,
                            compartir: _compartir,
                            hayPunto: hayPunto,
                            alElegirMotivo: (motivo) =>
                                setState(() => _motivo = motivo),
                            // El bus es de su ruta: con otra ruta, se suelta.
                            alElegirRuta: (ruta) => setState(() {
                              if (ruta.id != _ruta?.id) _bus = null;
                              _ruta = ruta;
                            }),
                            alElegirBus: (bus) => setState(() => _bus = bus),
                            alElegirHora: (hora) =>
                                setState(() => _hora = hora),
                            alCompartir: (compartir) =>
                                setState(() => _compartir = compartir),
                          )
                        : const SizedBox(width: double.infinity),
                  ),
                  const TituloSeccion('Tu mensaje'),
                  // Con el filo de la app, como las opciones, y verde mientras
                  // se escribe. Sin raya dentro (dueño, 2026-10-19: no gustó):
                  // la nota de privacidad va fuera, bajo el campo.
                  DecoratedBox(
                    key: const ValueKey('buzon_tarjeta'),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppRadius.card),
                    ),
                    child: TextField(
                      key: const ValueKey('buzon_texto'),
                      controller: _texto,
                      enabled: !_enviando,
                      minLines: _esQueja ? 4 : 7,
                      maxLines: 12,
                      maxLength: Buzon.maximo,
                      textCapitalization: TextCapitalization.sentences,
                      style: AppTextStyles.cuerpo
                          .copyWith(color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        hintText: switch (_tipo) {
                          TipoReporte.problema =>
                            'Qué pasó, en qué ruta y más o menos a qué hora.',
                          TipoReporte.queja => 'Cuéntanos qué pasó (opcional).',
                          TipoReporte.sugerencia =>
                            'Qué mejorarías o qué te gustaría ver en la app.',
                        },
                        hintStyle: AppTextStyles.cuerpo
                            .copyWith(color: AppColors.textSecondary),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.fromLTRB(
                            20, 18, 20, AppSpacing.md),
                        counterStyle: AppTextStyles.pie
                            .copyWith(color: AppColors.textSecondary),
                        enabledBorder: _filo(AppColors.filo, 1),
                        disabledBorder: _filo(AppColors.filo, 1),
                        focusedBorder: _filo(AppColors.primaryAccessible, 2),
                      ),
                    ),
                  ),
                  // La queja con ruta la ve también su empresa (D18): se dice
                  // antes de mandarla.
                  _NotaPrivacidad(_esQueja && _ruta != null
                      ? 'La leen el equipo de Ya Viene y la empresa de la '
                          'ruta. No incluyas datos personales.'
                      : 'Lo lee el equipo de Ya Viene. '
                          'No incluyas datos personales.'),
                ],
              ),
            ],
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
                      foregroundColor: AppColors.textPrimary,
                      disabledBackgroundColor:
                          _enviando ? AppColors.primary : null,
                      disabledForegroundColor:
                          _enviando ? AppColors.textPrimary : null,
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
                  Positioned(
                    left: 28,
                    right: 28,
                    bottom: 0,
                    child: ExcludeSemantics(
                      child: LinearProgressIndicator(
                        minHeight: 2,
                        color: AppColors.textPrimary,
                        backgroundColor:
                            AppColors.textPrimary.withValues(alpha: 0.24),
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

/// El candado y la nota, bajo la tarjeta del mensaje: se ve, pero no
/// compite con el campo.
class _NotaPrivacidad extends StatelessWidget {
  const _NotaPrivacidad(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      // A la par del texto del campo (20 por lado).
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
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
              texto,
              style: AppTextStyles.pie.copyWith(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

/// El azul de botón, en claro, para la queja: da 6,1:1 con [AppColors.acento].
const _tinteQueja = Color(0xFFE5EDF8);

/// Una de las tres opciones: tarjeta blanca y plana, ícono en su círculo, y
/// a su lado el nombre y una línea que lo explica. Cada una tiene su color
/// también sin elegir, el problema en coral y la sugerencia en ámbar (dueño,
/// 2026-10-18: «todo parece igual y del mismo color»): el círculo va en su
/// tinte claro con el ícono en su tinta. La elegida llena el círculo, toma
/// el tinte y el filo de su color y una marca a la derecha; el cambio se
/// anima (y no, con «Reducir movimiento»).
class _Opcion extends StatelessWidget {
  const _Opcion({
    super.key,
    required this.icono,
    required this.texto,
    required this.detalle,
    required this.elegida,
    required this.alPulsar,
    required this.tinta,
    required this.tinte,
  });

  final IconData icono;
  final String texto;
  final String detalle;
  final bool elegida;
  final VoidCallback alPulsar;

  /// El color de la opción, que da 3:1 con [tinte] y con el blanco.
  final Color tinta;

  /// Su versión clara, de fondo.
  final Color tinte;

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
          color: elegida ? tinte : Colors.white,
          borderRadius: radio,
          // El filo mide 1 siempre, para que el contenido no salte al
          // elegir; la elegida suma por fuera otro de su color, que no
          // ocupa sitio, y queda de 2.
          border: Border.all(color: elegida ? tinta : AppColors.filo),
          boxShadow:
              elegida ? [BoxShadow(color: tinta, spreadRadius: 1)] : null,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: alPulsar,
            borderRadius: radio,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: duracion,
                    curve: AppMotion.curvaCambio,
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: elegida ? tinta : tinte,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icono,
                        size: 22, color: elegida ? Colors.white : tinta),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          texto,
                          style: AppTextStyles.cuerpoFuerte
                              .copyWith(color: AppColors.textPrimary),
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
                  const SizedBox(width: AppSpacing.sm),
                  AnimatedScale(
                    scale: elegida ? 1 : 0,
                    duration: duracion,
                    curve: AppMotion.curvaEntrada,
                    child: Icon(Icons.check_circle_rounded,
                        size: 22, color: tinta),
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

/// El reporte llegó: lo dice y deja volver al mapa.
class _Gracias extends StatelessWidget {
  const _Gracias({super.key, required this.alVolver});

  final VoidCallback alVolver;

  @override
  Widget build(BuildContext context) {
    // Centrado en lo que queda bajo la barra, no en la pantalla entera.
    return Padding(
      padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top),
      child: Center(
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
                    foregroundColor: AppColors.textPrimary,
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
      ),
    );
  }
}
