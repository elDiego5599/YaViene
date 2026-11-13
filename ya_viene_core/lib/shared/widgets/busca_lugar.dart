import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/lugares/buscador_de_lugares.dart';
import '../../core/lugares/lugar.dart';
import '../../core/lugares/recientes_de_lugares.dart';
import '../../core/models/route_trajectory.dart';
import '../../core/network/fallo_red.dart';
import '../../core/theme/app_motion.dart';
import '../../core/theme/app_theme.dart';
import 'carga_fantasma.dart';

/// El buscador de lugares: un campo y, debajo, lo que toca según lo escrito
/// (D25). Como en Apple Maps y Citymapper, sin escribir nada ofrece tu
/// ubicación, elegir en el mapa y los recientes; al escribir, sugerencias
/// con su ícono, su nombre y su contexto en gris.
///
/// No sabe de GPS ni de mapas: [alUsarUbicacion] y [alElegirEnMapa] los
/// resuelve quien lo pone. Lo que devuelve [alElegir] siempre es un
/// [Lugar] con `origen: sitio` y su nombre. Los recientes se guardan en el
/// teléfono ([RecientesDeLugares]) y nunca salen de él.
class BuscaLugar extends StatefulWidget {
  const BuscaLugar({
    super.key,
    required this.buscador,
    required this.recientes,
    required this.alElegir,
    this.alUsarUbicacion,
    this.alElegirEnMapa,
    this.sesgo,
    this.pista = 'Barrio, calle o sitio',
    this.autofocus = false,
  });

  final BuscadorDeLugares buscador;
  final RecientesDeLugares recientes;
  final ValueChanged<Lugar> alElegir;

  /// Sin él no se ofrece «Tu ubicación» (sin permiso, o el GPS ya es el
  /// otro extremo del viaje).
  final VoidCallback? alUsarUbicacion;
  final VoidCallback? alElegirEnMapa;

  /// Dónde está la persona o el mapa: entre dos igual de buenas, sale
  /// primero la más cerca.
  final GeoPoint? sesgo;
  final String pista;
  final bool autofocus;

  @override
  State<BuscaLugar> createState() => _BuscaLugarState();
}

/// En qué va la búsqueda; decide qué se ve bajo el campo.
enum _Fase { inicio, buscando, resultados, sinResultados, fallo }

class _BuscaLugarState extends State<BuscaLugar> {
  /// Cuánto se espera tras la última tecla antes de buscar. Lo justo para
  /// no buscar cada letra de una palabra escrita de corrido, y por debajo
  /// de lo que se nota como retraso.
  static const _pausaAlEscribir = Duration(milliseconds: 120);

  final _campo = TextEditingController();
  Timer? _espera;

  /// Cada búsqueda lleva su número: la respuesta de una vieja que llega
  /// tarde no pisa la de la última.
  int _turno = 0;

  var _fase = _Fase.inicio;
  List<Sugerencia> _sugerencias = const [];
  List<Sugerencia> _recientes = const [];
  FalloRed? _fallo;

  @override
  void initState() {
    super.initState();
    _cargarRecientes();
  }

  @override
  void didUpdateWidget(BuscaLugar viejo) {
    super.didUpdateWidget(viejo);
    if (viejo.buscador != widget.buscador || viejo.sesgo != widget.sesgo) {
      if (_campo.text.trim().isNotEmpty) _buscar();
    }
    if (viejo.recientes != widget.recientes) _cargarRecientes();
  }

  @override
  void dispose() {
    _espera?.cancel();
    _campo.dispose();
    super.dispose();
  }

  Future<void> _cargarRecientes() async {
    final lista = await widget.recientes.lista();
    if (mounted) setState(() => _recientes = lista);
  }

  void _alEscribir(String texto) {
    _espera?.cancel();
    if (texto.trim().isEmpty) {
      _turno++;
      setState(() {
        _fase = _Fase.inicio;
        _sugerencias = const [];
      });
      return;
    }
    _espera = Timer(_pausaAlEscribir, _buscar);
  }

  Future<void> _buscar() async {
    final turno = ++_turno;
    setState(() => _fase = _Fase.buscando);
    try {
      final halladas = await widget.buscador.buscar(
        _campo.text,
        sesgo: widget.sesgo,
      );
      if (!mounted || turno != _turno) return;
      setState(() {
        _sugerencias = halladas;
        _fase = halladas.isEmpty ? _Fase.sinResultados : _Fase.resultados;
      });
    } on Object catch (error) {
      if (!mounted || turno != _turno) return;
      setState(() {
        _fallo = clasificarFallo(error);
        _fase = _Fase.fallo;
      });
    }
  }

  void _limpiar() {
    _campo.clear();
    _alEscribir('');
  }

  Future<void> _elegir(Sugerencia sugerencia) async {
    widget.alElegir(sugerencia.lugar);
    await widget.recientes.guardar(sugerencia);
    await _cargarRecientes();
  }

  Future<void> _quitarReciente(Sugerencia sugerencia) async {
    await widget.recientes.borrar(sugerencia);
    await _cargarRecientes();
  }

  Future<void> _borrarRecientes() async {
    await widget.recientes.borrarTodos();
    await _cargarRecientes();
  }

  @override
  Widget build(BuildContext context) {
    final duracion = AppMotion.duracion(context, AppMotion.rapido);
    final desliz = 8 * AppMotion.desplazamiento(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.sm,
          ),
          child: _CampoDeBusqueda(
            controlador: _campo,
            pista: widget.pista,
            autofocus: widget.autofocus,
            alEscribir: _alEscribir,
            alLimpiar: _limpiar,
            alEnviar: () {
              if (_fase == _Fase.resultados) _elegir(_sugerencias.first);
            },
          ),
        ),
        Expanded(
          child: AnimatedSwitcher(
            duration: duracion,
            switchInCurve: AppMotion.curvaCambio,
            switchOutCurve: AppMotion.curvaSalida,
            layoutBuilder: (actual, previos) => Stack(
              alignment: Alignment.topCenter,
              children: [...previos, if (actual != null) actual],
            ),
            transitionBuilder: (hijo, animacion) => FadeTransition(
              opacity: animacion,
              child: AnimatedBuilder(
                animation: animacion,
                builder: (context, hijo) => Transform.translate(
                  offset: Offset(0, (1 - animacion.value) * desliz),
                  child: hijo,
                ),
                child: hijo,
              ),
            ),
            child: KeyedSubtree(
              // Cambia de vista al cambiar de fase, no con cada letra: las
              // sugerencias se actualizan en su sitio, como en Apple Maps.
              key: ValueKey(_vistaDe(_fase)),
              child: _cuerpo(context),
            ),
          ),
        ),
      ],
    );
  }

  /// Buscando con algo ya en pantalla, sigue la misma vista: lo de antes se
  /// queda hasta que llegue lo nuevo, sin parpadeo.
  _Fase _vistaDe(_Fase fase) => fase == _Fase.buscando
      ? (_sugerencias.isEmpty ? _Fase.buscando : _Fase.resultados)
      : fase;

  Widget _cuerpo(BuildContext context) => switch (_vistaDe(_fase)) {
        _Fase.inicio => _lista([
            if (widget.alUsarUbicacion case final usar?)
              _Fila(
                icono: const _Disco.lleno(Icons.near_me_rounded),
                titulo: 'Tu ubicación',
                alTocar: usar,
              ),
            if (widget.alElegirEnMapa case final mapa?)
              _Fila(
                icono: const _Disco(Icons.map_outlined),
                titulo: 'Elegir en el mapa',
                alTocar: mapa,
              ),
            _Recientes(
              lista: _recientes,
              alElegir: _elegir,
              alQuitar: _quitarReciente,
              alBorrarTodos: _borrarRecientes,
            ),
          ]),
        _Fase.buscando => const _FilasFantasma(),
        _Fase.resultados => _lista([
            for (final s in _sugerencias)
              _Fila(
                icono: _Disco(_iconoDe(s.tipo)),
                titulo: s.nombre,
                contexto: s.contexto,
                alTocar: () => _elegir(s),
              ),
            if (widget.alElegirEnMapa case final mapa?)
              _Fila(
                icono: const _Disco(Icons.map_outlined),
                titulo: 'Elegir en el mapa',
                alTocar: mapa,
              ),
            _Atribucion(widget.buscador.atribucion),
          ]),
        _Fase.sinResultados => _lista([
            const _Mensaje(
              icono: Icons.search_off_rounded,
              titulo: 'No encontramos ese lugar',
              cuerpo: 'Prueba con el barrio, una calle como Calle 72 con 46 '
                  'o un sitio conocido.',
            ),
            if (widget.alElegirEnMapa case final mapa?)
              _Fila(
                icono: const _Disco(Icons.map_outlined),
                titulo: 'Elegir en el mapa',
                alTocar: mapa,
              ),
          ]),
        _Fase.fallo => _lista([
            _Mensaje(
              icono: _fallo == FalloRed.sinConexion
                  ? Icons.wifi_off_rounded
                  : Icons.error_outline_rounded,
              titulo: _fallo == FalloRed.sinConexion
                  ? 'Sin conexión'
                  : 'No pudimos buscar',
              cuerpo: _fallo == FalloRed.sinConexion
                  ? 'Revisa tus datos o el wifi y vuelve a intentar.'
                  : 'Algo falló de nuestro lado. Vuelve a intentar en un '
                      'momento.',
              // Sin red no es culpa de nadie: gris, como Apple Maps. El
              // rojo queda para cuando fallamos nosotros.
              alerta: _fallo != FalloRed.sinConexion,
              accion: ('Reintentar', _buscar),
            ),
            if (widget.alElegirEnMapa case final mapa?)
              _Fila(
                icono: const _Disco(Icons.map_outlined),
                titulo: 'Elegir en el mapa',
                alTocar: mapa,
              ),
          ]),
      };

  Widget _lista(List<Widget> filas) => ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.xl),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: filas,
      );
}

IconData _iconoDe(TipoLugar tipo) => switch (tipo) {
      TipoLugar.barrio => Icons.location_city_rounded,
      TipoLugar.via => Icons.route_rounded,
      TipoLugar.cruce => Icons.signpost_rounded,
      TipoLugar.sitio => Icons.place_rounded,
    };

class _CampoDeBusqueda extends StatelessWidget {
  const _CampoDeBusqueda({
    required this.controlador,
    required this.pista,
    required this.autofocus,
    required this.alEscribir,
    required this.alLimpiar,
    required this.alEnviar,
  });

  final TextEditingController controlador;
  final String pista;
  final bool autofocus;
  final ValueChanged<String> alEscribir;
  final VoidCallback alLimpiar;
  final VoidCallback alEnviar;

  /// El alto de un campo de búsqueda de iOS, que además es el mínimo de un
  /// blanco táctil.
  static const _alto = 44.0;

  @override
  Widget build(BuildContext context) {
    final duracion = AppMotion.duracion(context, AppMotion.instante);
    return SizedBox(
      height: _alto,
      child: TextField(
        controller: controlador,
        autofocus: autofocus,
        onChanged: alEscribir,
        onSubmitted: (_) => alEnviar(),
        textInputAction: TextInputAction.search,
        textCapitalization: TextCapitalization.words,
        // Lo que se busca dice dónde vive alguien: que el teclado no lo
        // aprenda ni lo proponga después en otra app.
        enableSuggestions: false,
        autocorrect: false,
        cursorColor: AppColors.acento,
        style: AppTextStyles.cuerpo.copyWith(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary,
          height: 1.25,
        ),
        decoration: InputDecoration(
          isDense: true,
          filled: true,
          fillColor: AppColors.surfaceMuted,
          hintText: pista,
          hintStyle: AppTextStyles.cuerpo.copyWith(
            fontSize: 16,
            color: AppColors.textSecondary,
            height: 1.25,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          prefixIcon: const Icon(
            Icons.search_rounded,
            size: 20,
            color: AppColors.textSecondary,
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 40),
          suffixIcon: ValueListenableBuilder(
            valueListenable: controlador,
            builder: (context, valor, _) => AnimatedOpacity(
              opacity: valor.text.isEmpty ? 0 : 1,
              duration: duracion,
              curve: AppMotion.curvaCambio,
              child: valor.text.isEmpty
                  ? const SizedBox.shrink()
                  : Semantics(
                      button: true,
                      label: 'Borrar lo escrito',
                      excludeSemantics: true,
                      child: IconButton(
                        onPressed: alLimpiar,
                        icon: const Icon(
                          Icons.cancel_rounded,
                          size: 18,
                          color: AppColors.textDisabled,
                        ),
                      ),
                    ),
            ),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

/// El disco del ícono de cada fila. Gris para los lugares; lleno en el azul
/// de botón para «Tu ubicación», que es la acción más corta.
class _Disco extends StatelessWidget {
  const _Disco(this.icono) : lleno = false;
  const _Disco.lleno(this.icono) : lleno = true;

  final IconData icono;
  final bool lleno;

  static const lado = 36.0;

  @override
  Widget build(BuildContext context) => Container(
        width: lado,
        height: lado,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: lleno ? AppColors.acento : AppColors.surfaceMuted,
        ),
        // Blanco sobre #1E56A8 da 7,1:1; #475569 sobre #F1F5F9, 6,9:1.
        child: Icon(
          icono,
          size: 18,
          color: lleno ? Colors.white : AppColors.textBody,
        ),
      );
}

class _Fila extends StatelessWidget {
  const _Fila({
    super.key,
    required this.icono,
    required this.titulo,
    required this.alTocar,
    this.contexto,
    this.final_,
  });

  final Widget icono;
  final String titulo;
  final String? contexto;
  final VoidCallback alTocar;
  final Widget? final_;

  /// Donde arranca el texto: la raya entre filas empieza ahí, como en iOS.
  static const sangria = AppSpacing.md + _Disco.lado + 12;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        InkWell(
          onTap: alTocar,
          splashFactory: NoSplash.splashFactory,
          highlightColor: AppColors.surfaceMuted,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 60),
            child: Padding(
              padding: EdgeInsets.only(
                left: AppSpacing.md,
                // Con la X al final se le deja su blanco de 48 libre.
                right: final_ == null ? AppSpacing.md : 52,
                top: 10,
                bottom: 10,
              ),
              child: Row(
                children: [
                  icono,
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          titulo,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.cuerpoFuerte.copyWith(
                            fontSize: 16,
                            color: AppColors.textPrimary,
                            height: 1.3,
                          ),
                        ),
                        if (contexto case final c?) ...[
                          const SizedBox(height: 2),
                          Text(
                            c,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            // #5E6B82 sobre blanco: 5,3:1.
                            style: AppTextStyles.cuerpo.copyWith(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // La X va encima de la fila, no dentro de su toque: dos botones
        // anidados se leen como uno en el lector de pantalla.
        if (final_ case final f?)
          Positioned(
            right: AppSpacing.xs,
            top: 0,
            bottom: 0,
            child: Center(child: f),
          ),
        const Positioned(
          left: sangria,
          right: 0,
          bottom: 0,
          child: Divider(height: 0.5, thickness: 0.5, color: AppColors.filo),
        ),
      ],
    );
  }
}

class _Recientes extends StatelessWidget {
  const _Recientes({
    required this.lista,
    required this.alElegir,
    required this.alQuitar,
    required this.alBorrarTodos,
  });

  final List<Sugerencia> lista;
  final ValueChanged<Sugerencia> alElegir;
  final ValueChanged<Sugerencia> alQuitar;
  final VoidCallback alBorrarTodos;

  @override
  Widget build(BuildContext context) {
    final contenido = lista.isEmpty
        ? const SizedBox(width: double.infinity)
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.lg,
                  AppSpacing.xs,
                  AppSpacing.xs,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(
                          'Recientes',
                          style: AppTextStyles.cuerpoFuerte.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: alBorrarTodos,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.acento,
                        minimumSize: const Size(44, 44),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                        ),
                        textStyle: AppTextStyles.cuerpoFuerte,
                      ),
                      child: const Text('Borrar'),
                    ),
                  ],
                ),
              ),
              for (final s in lista)
                _Fila(
                  key: ValueKey(s.lugar),
                  icono: const _Disco(Icons.history_rounded),
                  titulo: s.nombre,
                  contexto: s.contexto,
                  alTocar: () => alElegir(s),
                  final_: Semantics(
                    button: true,
                    label: 'Quitar ${s.nombre} de recientes',
                    excludeSemantics: true,
                    child: IconButton(
                      onPressed: () => alQuitar(s),
                      icon: const Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
            ],
          );
    // Al quitar uno, la lista se cierra con resorte en vez de saltar. Con
    // movimiento reducido no se envuelve: `AnimatedSize` a cero se vuelve a
    // ensuciar mientras se mide (ver `AppMotion.duracion`).
    if (AppMotion.reducido(context)) return contenido;
    return AnimatedSize(
      duration: AppMotion.pausado,
      curve: AppMotion.curvaCambio,
      alignment: Alignment.topCenter,
      child: contenido,
    );
  }
}

class _Mensaje extends StatelessWidget {
  const _Mensaje({
    required this.icono,
    required this.titulo,
    required this.cuerpo,
    this.alerta = false,
    this.accion,
  });

  final IconData icono;
  final String titulo;
  final String cuerpo;
  final bool alerta;
  final (String, VoidCallback)? accion;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.xl,
          AppSpacing.xl,
          AppSpacing.lg,
        ),
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: alerta ? AppColors.errorLight : AppColors.surfaceMuted,
              ),
              // #C0392B sobre #FEE2E2: 4,6:1; #475569 sobre #F1F5F9: 6,9:1.
              child: Icon(
                icono,
                size: 26,
                color: alerta ? AppColors.coralAccessible : AppColors.textBody,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              titulo,
              textAlign: TextAlign.center,
              style: AppTextStyles.subtitulo.copyWith(
                fontSize: 17,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              cuerpo,
              textAlign: TextAlign.center,
              style: AppTextStyles.cuerpo.copyWith(
                fontSize: 14,
                color: AppColors.textBody,
              ),
            ),
            if (accion case (final rotulo, final alTocar)) ...[
              const SizedBox(height: AppSpacing.md),
              FilledButton(
                onPressed: alTocar,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.acento,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  shape: const StadiumBorder(),
                  textStyle: AppTextStyles.cuerpoFuerte,
                ),
                child: Text(rotulo),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// La espera de la primera respuesta, con la forma de tres filas.
class _FilasFantasma extends StatelessWidget {
  const _FilasFantasma();

  @override
  Widget build(BuildContext context) {
    Widget barra(double ancho, double alto) => Container(
          width: ancho,
          height: alto,
          decoration: BoxDecoration(
            color: AppColors.surfaceMuted,
            borderRadius: BorderRadius.circular(AppRadius.xs),
          ),
        );
    return CargaFantasma(
      semanticsLabel: 'Buscando',
      child: Column(
        children: [
          for (final ancho in const [180.0, 140.0, 200.0])
            SizedBox(
              height: 60,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Row(
                  children: [
                    Container(
                      width: _Disco.lado,
                      height: _Disco.lado,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.surfaceMuted,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        barra(ancho, 12),
                        const SizedBox(height: 8),
                        barra(ancho * 0.6, 10),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Lo que piden las licencias de los datos: decir de dónde salen, cerca de
/// donde se usan.
class _Atribucion extends StatelessWidget {
  const _Atribucion(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
          0,
        ),
        child: Text(
          texto,
          style: AppTextStyles.pie.copyWith(
            fontSize: 11,
            color: AppColors.textSecondary,
          ),
        ),
      );
}
