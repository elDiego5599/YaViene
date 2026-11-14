import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ya_viene_core/ya_viene_core.dart';

import '../../../core/widgets/barra_vidrio.dart';
import '../../../core/widgets/cabecera_degradada.dart';
import '../../../core/widgets/cifra_viva.dart';
import '../../../core/widgets/dialogo.dart';
import '../domain/recarga.dart';
import '../domain/saldo.dart';
import '../domain/tarjeta.dart';
import 'tarjeta_providers.dart';
import 'tarjeta_visual.dart';

/// El saldo y la recarga de la tarjeta SIBUS (D22, D23): la tercera pestaña
/// de la barra de abajo, donde antes estaba el buzón (dueño, 2026-11-14).
///
/// Arriba la tarjeta, como en Apple Wallet: el pasajero reconoce lo que
/// lleva en el bolsillo antes de leer una cifra. Debajo, el saldo como
/// cifra principal y la hora a la que se consultó, que es lo que hace
/// honesta a la cifra (Nequi y Revolut la dan igual). Cada estado dice qué
/// pasó y qué hacer, sin culpar al pasajero de lo que es del sistema.
class TarjetaScreen extends ConsumerWidget {
  const TarjetaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final simulado = ref.watch(proveedorSaldoProvider).simulado;
    final tarjeta = ref.watch(tarjetaProvider);
    return BackdropGroup(
      child: Scaffold(
        backgroundColor: AppColors.surface,
        extendBodyBehindAppBar: true,
        appBar: barraVidrio(
          title: MediaQuery.withClampedTextScaling(
            maxScaleFactor: 1.3,
            child: const Text('Tarjeta SIBUS'),
          ),
          // Es una pestaña de la barra de abajo: sin flecha de volver.
          automaticallyImplyLeading: false,
          // D8: mientras el saldo sea inventado se dice, siempre y arriba,
          // no en una nota que se pueda pasar por alto.
          actions: [
            if (simulado)
              const Padding(
                padding: EdgeInsets.only(right: AppSpacing.md),
                child: Center(child: EtiquetaSimulacion()),
              ),
          ],
        ),
        // La cabecera degradada con su raya sutil, como la de Avisos: cubre
        // la barra y termina donde empieza el cuerpo.
        body: Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Builder(
                builder: (context) => SizedBox(
                  height: MediaQuery.paddingOf(context).top,
                  child: const CabeceraDegradada(
                    key: ValueKey('tarjeta-cabecera'),
                  ),
                ),
              ),
            ),
            Builder(
              builder: (context) => SafeArea(
                top: false,
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    MediaQuery.paddingOf(context).top + AppSpacing.md,
                    AppSpacing.lg,
                    AppSpacing.xl,
                  ),
                  child: AnimatedSwitcher(
                    duration: AppMotion.duracion(context, AppMotion.normal),
                    switchInCurve: AppMotion.curvaEntrada,
                    switchOutCurve: AppMotion.curvaSalida,
                    layoutBuilder: (actual, previos) => Stack(
                      alignment: Alignment.topCenter,
                      children: [...previos, if (actual != null) actual],
                    ),
                    child: switch (tarjeta) {
                      AsyncData(value: final numero?) =>
                        _ConTarjeta(key: const ValueKey('con'), numero: numero),
                      AsyncData() ||
                      AsyncError() =>
                        const _SinTarjeta(key: ValueKey('sin')),
                      _ => const SizedBox(key: ValueKey('leyendo'), height: 1),
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// La etiqueta que dice que el saldo no es real (D8). Ámbar claro con la
/// letra en su tono accesible: 5,89:1, pasa AA para texto de 13 pt.
class EtiquetaSimulacion extends StatelessWidget {
  const EtiquetaSimulacion({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.warningLight,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.3,
        child: Text(
          'Simulación',
          style: AppTextStyles.etiqueta
              .copyWith(color: AppColors.warningAccessible),
        ),
      ),
    );
  }
}

// ── Sin tarjeta ────────────────────────────────────────────────────────────

class _SinTarjeta extends ConsumerStatefulWidget {
  const _SinTarjeta({super.key});

  @override
  ConsumerState<_SinTarjeta> createState() => _SinTarjetaState();
}

class _SinTarjetaState extends ConsumerState<_SinTarjeta> {
  final _campo = TextEditingController();
  FalloNumero? _fallo;
  bool _guardando = false;

  @override
  void dispose() {
    _campo.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    switch (NumeroTarjeta.leer(_campo.text)) {
      case NumeroInvalido(:final fallo):
        setState(() => _fallo = fallo);
      case NumeroValido(:final numero):
        setState(() => _guardando = true);
        await ref.read(tarjetaProvider.notifier).guardar(numero);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _campo,
          builder: (context, valor, _) {
            final cifras = valor.text.replaceAll(RegExp(r'\D'), '');
            return TarjetaVisual(
              ultimos4: cifras.length >= 4
                  ? cifras.substring(cifras.length - 4)
                  : null,
            );
          },
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('Consulta tu saldo', style: AppTextStyles.titulo),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Escribe el número que trae tu tarjeta SIBUS.',
          style: AppTextStyles.cuerpo.copyWith(color: AppColors.textBody),
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _campo,
          enabled: !_guardando,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          // Ni autocorrector ni sugerencias: el teclado no tiene por qué
          // aprenderse el número.
          autocorrect: false,
          enableSuggestions: false,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(NumeroTarjeta.maximo),
          ],
          onChanged: (_) {
            if (_fallo != null) setState(() => _fallo = null);
          },
          onSubmitted: (_) => _guardar(),
          style: AppTextStyles.subtitulo.copyWith(
            color: AppColors.textPrimary,
            letterSpacing: 1.2,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
          decoration: InputDecoration(
            labelText: 'Número de la tarjeta',
            labelStyle:
                AppTextStyles.cuerpo.copyWith(color: AppColors.textSecondary),
            floatingLabelStyle: AppTextStyles.etiqueta
                .copyWith(color: AppColors.primaryAccessible),
            errorText: _fallo == null ? null : _mensajeDe(_fallo!),
            errorStyle:
                AppTextStyles.pie.copyWith(color: AppColors.coralAccessible),
            errorMaxLines: 2,
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
            enabledBorder: _filo(AppColors.filo, 1),
            disabledBorder: _filo(AppColors.filo, 1),
            focusedBorder: _filo(AppColors.primaryAccessible, 2),
            errorBorder: _filo(AppColors.coralAccessible, 1),
            focusedErrorBorder: _filo(AppColors.coralAccessible, 2),
          ),
        ),
        const _NotaPrivacidad(),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          height: 56,
          child: FilledButton(
            onPressed: _guardando ? null : _guardar,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.textPrimary,
              disabledBackgroundColor: AppColors.primary,
              disabledForegroundColor: AppColors.textPrimary,
              textStyle: AppTextStyles.boton,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
            child: const Text('Guardar tarjeta'),
          ),
        ),
      ],
    );
  }

  static String _mensajeDe(FalloNumero fallo) => switch (fallo) {
        FalloNumero.vacio => 'Escribe el número de la tarjeta.',
        FalloNumero.soloDigitos => 'Solo números, sin letras ni signos.',
        FalloNumero.muyCorto =>
          'El número tiene al menos ${NumeroTarjeta.minimo} cifras.',
        FalloNumero.muyLargo =>
          'El número tiene como mucho ${NumeroTarjeta.maximo} cifras.',
      };

  static OutlineInputBorder _filo(Color color, double ancho) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        borderSide: BorderSide(color: color, width: ancho),
      );
}

// ── Con tarjeta ────────────────────────────────────────────────────────────

class _ConTarjeta extends ConsumerWidget {
  const _ConTarjeta({super.key, required this.numero});

  final NumeroTarjeta numero;

  Future<void> _quitar(BuildContext context, WidgetRef ref) async {
    final quitar = await mostrarDialogo<bool>(
      context,
      (ctx) => Dialogo(
        icono: Icons.credit_card_off_outlined,
        titulo: 'Quitar tarjeta',
        mensaje: 'El número se borra de este teléfono. Puedes volver a '
            'escribirlo cuando quieras.',
        delicado: true,
        principal: DialogoAccion(
          'Quitar',
          () => Navigator.of(ctx).pop(true),
        ),
        secundaria: DialogoAccion(
          'Cancelar',
          () => Navigator.of(ctx).pop(false),
        ),
      ),
    );
    if (quitar ?? false) await ref.read(tarjetaProvider.notifier).quitar();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final consulta = ref.watch(saldoProvider);
    final consultando = consulta.isLoading;
    void consultar() => ref.invalidate(saldoProvider);

    final Widget estado = switch (consulta.valueOrNull) {
      _ when consultando && !consulta.hasValue => const _Consultando(),
      final SaldoConsultado saldo =>
        _Saldo(saldo: saldo, consultando: consultando, alConsultar: consultar),
      SaldoSinRed() => _Aviso(
          icono: Icons.wifi_off_rounded,
          tono: _Tono.espera,
          titulo: 'Sin internet',
          texto: 'Conéctate y vuelve a consultar.',
          accion: 'Consultar de nuevo',
          consultando: consultando,
          alPulsar: consultar,
        ),
      TarjetaNoEncontrada() => _Aviso(
          icono: Icons.search_off_rounded,
          titulo: 'No encontramos esta tarjeta',
          texto: 'Revisa que el número sea el que trae tu tarjeta.',
          accion: 'Cambiar el número',
          iconoAccion: Icons.edit_outlined,
          alPulsar: () => ref.read(tarjetaProvider.notifier).quitar(),
        ),
      // Lo que el proveedor no supo responder y cualquier fallo inesperado
      // se dicen igual: es del sistema, no del pasajero.
      SaldoNoDisponible() || null => _Aviso(
          icono: Icons.schedule_rounded,
          tono: _Tono.espera,
          titulo: 'El saldo no está disponible ahora',
          texto: 'No es tu tarjeta, es el sistema. Mientras tanto, el '
              'validador azul del bus te lo muestra al pasarla.',
          accion: 'Consultar de nuevo',
          consultando: consultando,
          alPulsar: consultar,
        ),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TarjetaVisual(ultimos4: numero.ultimos4),
        const SizedBox(height: AppSpacing.lg),
        _Panel(
          child: AnimatedSwitcher(
            duration: AppMotion.duracion(context, AppMotion.normal),
            switchInCurve: AppMotion.curvaEntrada,
            switchOutCurve: AppMotion.curvaSalida,
            layoutBuilder: (actual, previos) => Stack(
              alignment: Alignment.topLeft,
              children: [...previos, if (actual != null) actual],
            ),
            child:
                KeyedSubtree(key: ValueKey(estado.runtimeType), child: estado),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        _Panel(child: _Recarga(numero: numero)),
        const _NotaPrivacidad(),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => _quitar(context, ref),
            icon: const Icon(Icons.delete_outline_rounded, size: 20),
            label: const Text('Quitar tarjeta'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.coralAccessible,
              textStyle: AppTextStyles.cuerpoFuerte,
              minimumSize: const Size(0, 44),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Recarga (D23) ──────────────────────────────────────────────────────────

/// Recargar sale de la app: se abre la página del operador o del banco y se
/// vuelve por un enlace. Aquí solo se muestra lo que el proveedor contesta;
/// nunca un formulario de tarjeta ni una cifra a cobrar.
class _Recarga extends ConsumerWidget {
  const _Recarga({required this.numero});

  final NumeroTarjeta numero;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificador = ref.read(recargaProvider.notifier);
    void recargar() => notificador.recargar(numero);

    final Widget cuerpo = switch (ref.watch(recargaProvider)) {
      null => _RecargaInicio(alPulsar: recargar),
      RecargaPendiente() => _Aviso(
          icono: Icons.hourglass_top_rounded,
          tono: _Tono.espera,
          titulo: 'Esperando tu pago',
          texto: 'Termina el pago en la página que se abrió. Cuando vuelvas '
              'aquí lo confirmamos.',
          accion: 'Comprobar',
          alPulsar: notificador.comprobar,
        ),
      RecargaAprobada(:final valor) => _Aviso(
          icono: Icons.check_circle_outline_rounded,
          tono: _Tono.bien,
          titulo: 'Recarga aprobada',
          texto: valor == null
              ? 'El operador confirmó tu pago. El saldo puede tardar un '
                  'momento en actualizarse.'
              : 'El operador confirmó tu pago de ${pesos(valor)}. El saldo '
                  'puede tardar un momento en actualizarse.',
          accion: 'Listo',
          iconoAccion: Icons.check_rounded,
          alPulsar: notificador.descartar,
        ),
      RecargaRechazada() => _Aviso(
          icono: Icons.block_rounded,
          tono: _Tono.fallo,
          titulo: 'El pago no se completó',
          texto: 'El operador no lo aprobó. Puedes intentarlo de nuevo.',
          accion: 'Intentar de nuevo',
          alPulsar: recargar,
        ),
      RecargaDesconocida() => _Aviso(
          icono: Icons.search_off_rounded,
          titulo: 'No encontramos esta recarga',
          texto: 'Si pagaste, el operador te la confirma por su propio '
              'canal.',
          accion: 'Listo',
          iconoAccion: Icons.check_rounded,
          alPulsar: notificador.descartar,
        ),
      RecargaSinRed() => _Aviso(
          icono: Icons.wifi_off_rounded,
          tono: _Tono.espera,
          titulo: 'Sin internet',
          texto: 'Conéctate y comprobamos tu recarga.',
          accion: 'Comprobar',
          alPulsar: notificador.comprobar,
        ),
      RecargaNoAbierta() => _Aviso(
          icono: Icons.link_off_rounded,
          tono: _Tono.fallo,
          titulo: 'No pudimos abrir el pago',
          texto: 'No se cobró nada. Inténtalo de nuevo en un momento.',
          accion: 'Intentar de nuevo',
          alPulsar: recargar,
        ),
    };

    return AnimatedSwitcher(
      duration: AppMotion.duracion(context, AppMotion.normal),
      switchInCurve: AppMotion.curvaEntrada,
      switchOutCurve: AppMotion.curvaSalida,
      layoutBuilder: (actual, previos) => Stack(
        alignment: Alignment.topLeft,
        children: [...previos, if (actual != null) actual],
      ),
      child: KeyedSubtree(
        key: ValueKey(cuerpo is _Aviso ? cuerpo.titulo : 'inicio'),
        child: cuerpo,
      ),
    );
  }
}

/// El punto de partida: un solo botón lleno y la promesa de qué no hace Ya
/// Viene con el dinero.
class _RecargaInicio extends StatelessWidget {
  const _RecargaInicio({required this.alPulsar});

  final VoidCallback alPulsar;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Recargar', style: AppTextStyles.subtitulo),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Pagas en la página de tu banco o del operador. Ya Viene no ve '
          'tu tarjeta bancaria ni cobra nada.',
          style: AppTextStyles.cuerpo.copyWith(color: AppColors.textBody),
        ),
        const SizedBox(height: AppSpacing.lg),
        SizedBox(
          height: 48,
          child: FilledButton.icon(
            onPressed: alPulsar,
            icon: const Icon(Icons.add_card_rounded, size: 20),
            label: const Text('Recargar'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.acento,
              foregroundColor: Colors.white,
              textStyle: AppTextStyles.boton,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// La cifra del saldo, la hora a la que se consultó y cómo volver a pedirla.
class _Saldo extends StatelessWidget {
  const _Saldo({
    required this.saldo,
    required this.consultando,
    required this.alConsultar,
  });

  final SaldoConsultado saldo;
  final bool consultando;
  final VoidCallback alConsultar;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Saldo disponible',
          style:
              AppTextStyles.etiqueta.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.xs),
        // La cifra es lo único grande de la pantalla, como el saldo de
        // Wallet o de Nequi: el rol `dato`, el mismo de la distancia en la
        // hoja del bus, y gira como ella cuando cambia.
        CifraViva(
          pesos(saldo.valor),
          valor: saldo.valor.toDouble(),
          style: AppTextStyles.dato,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Consultado a las ${hora(saldo.consultado)}',
          style: AppTextStyles.pie.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.lg),
        _BotonConsultar(
          texto: 'Consultar de nuevo',
          consultando: consultando,
          alPulsar: alConsultar,
        ),
      ],
    );
  }
}

/// Una lámina blanca con su filo, como las tarjetas de Avisos: agrupa un
/// bloque (el saldo, la recarga) sin sombra que compita con la tarjeta.
class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.filo),
      ),
      child: child,
    );
  }
}

/// El color de la insignia de un [_Aviso]: dice de un vistazo si es algo
/// que esperar, algo que falló, algo que salió bien o solo un dato.
enum _Tono {
  neutro(AppColors.surfaceMuted, AppColors.textBody),
  espera(AppColors.warningLight, AppColors.warningAccessible),
  fallo(AppColors.coralLight, AppColors.coralAccessible),
  bien(AppColors.successLight, AppColors.primaryAccessible);

  const _Tono(this.fondo, this.tinta);
  final Color fondo;
  final Color tinta;
}

/// Un estado sin saldo: ícono en su círculo, qué pasó y qué hacer.
class _Aviso extends StatelessWidget {
  const _Aviso({
    required this.icono,
    required this.titulo,
    required this.texto,
    required this.accion,
    required this.alPulsar,
    this.iconoAccion = Icons.refresh_rounded,
    this.consultando = false,
    this.tono = _Tono.neutro,
  });

  final _Tono tono;
  final IconData icono;
  final IconData iconoAccion;
  final String titulo;
  final String texto;
  final String accion;
  final VoidCallback alPulsar;
  final bool consultando;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExcludeSemantics(
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: tono.fondo,
              shape: BoxShape.circle,
            ),
            child: Icon(icono, size: 22, color: tono.tinta),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(titulo, style: AppTextStyles.subtitulo),
        const SizedBox(height: AppSpacing.xs),
        Text(
          texto,
          style: AppTextStyles.cuerpo.copyWith(color: AppColors.textBody),
        ),
        const SizedBox(height: AppSpacing.lg),
        _BotonConsultar(
          texto: accion,
          icono: iconoAccion,
          consultando: consultando,
          alPulsar: alPulsar,
        ),
      ],
    );
  }
}

/// La primera consulta, sin nada que enseñar todavía: solo la espera.
class _Consultando extends StatelessWidget {
  const _Consultando();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 120,
      child: Align(
        alignment: Alignment.centerLeft,
        child: IndicadorCarga(size: 28, semanticsLabel: 'Consultando el saldo'),
      ),
    );
  }
}

/// Píldora tonal: pide algo secundario sin competir con la cifra. Mientras
/// consulta, los puntos de espera ocupan el lugar del ícono y el texto se
/// queda, para que el botón no cambie de ancho.
class _BotonConsultar extends StatelessWidget {
  const _BotonConsultar({
    required this.texto,
    required this.consultando,
    required this.alPulsar,
    this.icono = Icons.refresh_rounded,
  });

  final String texto;
  final IconData icono;
  final bool consultando;
  final VoidCallback alPulsar;

  @override
  Widget build(BuildContext context) {
    final boton = FilledButton.tonalIcon(
      onPressed: consultando ? null : alPulsar,
      icon: consultando
          ? const IndicadorCarga(size: 18, color: AppColors.textPrimary)
          : Icon(icono, size: 18),
      label: Text(texto),
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.surfaceMuted,
        foregroundColor: AppColors.textPrimary,
        disabledBackgroundColor: AppColors.surfaceMuted,
        disabledForegroundColor: AppColors.textPrimary,
        textStyle: AppTextStyles.cuerpoFuerte,
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 18),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
      ),
    );
    if (!consultando) return boton;
    // Mientras consulta, VoiceOver oye solo eso, y lo oye sin tener que
    // ir al botón: el texto de siempre no se puede pulsar ahora.
    return Semantics(
      label: 'Consultando el saldo',
      liveRegion: true,
      excludeSemantics: true,
      child: boton,
    );
  }
}

/// El candado y la nota: dónde queda el número.
class _NotaPrivacidad extends StatelessWidget {
  const _NotaPrivacidad();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.xs, 12, AppSpacing.xs, AppSpacing.sm),
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
              'El número se guarda solo en este teléfono. Ya Viene no lo '
              'guarda en sus servidores.',
              style: AppTextStyles.pie.copyWith(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Formatos ───────────────────────────────────────────────────────────────

/// Pesos con punto de miles, como se escriben en Colombia: `$12.300`.
String pesos(int valor) {
  final cifras = valor.abs().toString();
  final grupos = <String>[];
  for (var fin = cifras.length; fin > 0; fin -= 3) {
    grupos.insert(0, cifras.substring(fin - 3 < 0 ? 0 : fin - 3, fin));
  }
  return '${valor < 0 ? '-' : ''}\$${grupos.join('.')}';
}

/// La hora en reloj de 12 horas, como la dice el iPhone en Colombia:
/// `7:05 a. m.`.
String hora(DateTime momento) {
  final h = momento.hour % 12 == 0 ? 12 : momento.hour % 12;
  final m = momento.minute.toString().padLeft(2, '0');
  return '$h:$m ${momento.hour < 12 ? 'a. m.' : 'p. m.'}';
}
