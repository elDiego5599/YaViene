import 'dart:async';

import 'package:flutter/material.dart';

/// La hora y la fecha de la barra del panel.
///
/// Cada latido cae en el cambio de segundo del equipo: con un
/// `Timer.periodic` armado al abrir, el segundo salía hasta uno tarde y se
/// corría con el tiempo. Y pinta en su propia capa: sin ella, cada segundo
/// se volvía a pintar la barra entera y lo que comparte capa con ella.
class ClockWidget extends StatefulWidget {
  const ClockWidget({
    super.key,
    this.timeColor = Colors.white,
    this.dateColor = Colors.white70,
    this.reloj = DateTime.now,
  });

  final Color timeColor;
  final Color dateColor;

  /// De dónde sale la hora. Es un parámetro para que las pruebas la fijen.
  final DateTime Function() reloj;

  @override
  State<ClockWidget> createState() => _ClockWidgetState();
}

class _ClockWidgetState extends State<ClockWidget> {
  static const _weekdays = [
    'lunes',
    'martes',
    'miércoles',
    'jueves',
    'viernes',
    'sábado',
    'domingo',
  ];
  static const _months = [
    'enero',
    'febrero',
    'marzo',
    'abril',
    'mayo',
    'junio',
    'julio',
    'agosto',
    'septiembre',
    'octubre',
    'noviembre',
    'diciembre',
  ];

  Timer? _timer;
  late DateTime _now;

  @override
  void initState() {
    super.initState();
    _now = widget.reloj();
    _programar();
  }

  /// Arma el próximo latido para cuando cambie el segundo. Se rearma en cada
  /// uno, así un latido que llega unos milisegundos tarde no arrastra al
  /// siguiente.
  void _programar() {
    final falta = 1000 - _now.millisecond;
    _timer = Timer(Duration(milliseconds: falta), () {
      setState(() => _now = widget.reloj());
      _programar();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _two(int v) => v.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    final date =
        '${_weekdays[_now.weekday - 1]}, ${_now.day} de ${_months[_now.month - 1]} de ${_now.year}';
    return RepaintBoundary(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${_two(_now.hour)}:${_two(_now.minute)}:${_two(_now.second)}',
            style: TextStyle(
              color: widget.timeColor,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          Text(date, style: TextStyle(color: widget.dateColor, fontSize: 12)),
        ],
      ),
    );
  }
}
