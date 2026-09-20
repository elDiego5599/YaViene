import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/observability/medidor_latencia.dart';

/// Lo que mide [MedidorLatencia], enseñado encima de la pantalla (T7.6).
///
/// Es una herramienta de desarrollo: en release no se dibuja nada. Quien usa
/// la app no tiene por qué ver números de red, y lo medido no sale del
/// teléfono ni en depuración.
///
/// No recibe toques: va encima del mapa y taparía un bus si los interceptara.
class RecuadroLatencia extends StatefulWidget {
  const RecuadroLatencia({
    super.key,
    this.medidor,
    this.cada = const Duration(seconds: 1),
  });

  /// De dónde salen los números. Por omisión el de toda la app.
  final MedidorLatencia? medidor;

  /// Cada cuánto se refresca. Los números se miran, no se leen al vuelo.
  final Duration cada;

  @override
  State<RecuadroLatencia> createState() => _RecuadroLatenciaState();
}

class _RecuadroLatenciaState extends State<RecuadroLatencia> {
  Timer? _reloj;

  @override
  void initState() {
    super.initState();
    if (kDebugMode) {
      _reloj = Timer.periodic(widget.cada, (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _reloj?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) return const SizedBox.shrink();
    final resumen = (widget.medidor ?? MedidorLatencia.compartido).resumen;
    return IgnorePointer(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'latencia (depuración)',
              style: TextStyle(color: Colors.white, fontSize: 11),
            ),
            if (!resumen.hayDatos)
              const Text(
                'sin datos todavía',
                style: TextStyle(color: Colors.white70, fontSize: 11),
              )
            else ...[
              _Linea(
                nombre: 'emisión',
                p50: resumen.emisionP50,
                p95: resumen.emisionP95,
                n: resumen.muestrasEmision,
              ),
              _Linea(
                nombre: 'captura',
                p50: resumen.capturaP50,
                p95: resumen.capturaP95,
                n: resumen.muestrasCaptura,
              ),
              Text(
                'desfase ${resumen.desfaseMs ?? '—'} ms',
                style: const TextStyle(color: Colors.white70, fontSize: 11),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Linea extends StatelessWidget {
  const _Linea({
    required this.nombre,
    required this.p50,
    required this.p95,
    required this.n,
  });

  final String nombre;
  final int? p50;
  final int? p95;
  final int n;

  @override
  Widget build(BuildContext context) {
    return Text(
      '$nombre p50 ${p50 ?? '—'} ms · p95 ${p95 ?? '—'} ms · n $n',
      style: const TextStyle(color: Colors.white, fontSize: 11),
    );
  }
}
