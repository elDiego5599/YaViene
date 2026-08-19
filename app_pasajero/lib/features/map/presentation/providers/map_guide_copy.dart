import 'package:flutter/material.dart';

import 'map_tour_provider.dart';

class MapGuideCopy {
  const MapGuideCopy({
    required this.title,
    required this.message,
    required this.icon,
    this.primaryLabel,
  });

  final String title;
  final String message;
  final IconData icon;
  final String? primaryLabel;
}

MapGuideCopy mapGuideCopy(MapGuideStep step) {
  switch (step) {
    case MapGuideStep.location:
      return const MapGuideCopy(
        title: 'Fija tu punto de espera',
        message: 'La app necesita saber desde dónde esperas. Toca el mapa para '
            'poner un punto; también puedes usar el GPS.',
        icon: Icons.location_on_rounded,
      );
    case MapGuideStep.search:
      return const MapGuideCopy(
        title: 'Empieza aquí',
        message: 'Toca la barra blanca de arriba para buscar una empresa y una '
            'ruta.',
        icon: Icons.search_rounded,
      );
    case MapGuideStep.company:
      return const MapGuideCopy(
        title: 'Elige una empresa',
        message: 'Primero selecciona la empresa de transporte que buscas.',
        icon: Icons.business_rounded,
      );
    case MapGuideStep.route:
      return const MapGuideCopy(
        title: 'Elige tu ruta',
        message: 'Después selecciona la ruta y revisa sus terminales.',
        icon: Icons.alt_route_rounded,
      );
    case MapGuideStep.launchBuses:
      return const MapGuideCopy(
        title: 'Muestra los buses',
        message:
            'Cuando la ruta esté lista, pulsa este botón para ver sus buses '
            'en el mapa.',
        icon: Icons.play_arrow_rounded,
      );
    case MapGuideStep.buses:
      return const MapGuideCopy(
        title: 'Mira los buses',
        message:
            'Estos iconos representan los buses en vivo. Toca uno para ver '
            'cuánto falta.',
        icon: Icons.directions_bus_rounded,
      );
    case MapGuideStep.distance:
      return const MapGuideCopy(
        title: 'Mira la distancia',
        message:
            'Aquí verás a qué distancia está el bus de tu punto de espera.',
        icon: Icons.timer_outlined,
        primaryLabel: 'Continuar',
      );
    case MapGuideStep.alert:
      return const MapGuideCopy(
        title: 'Activa el aviso',
        message: 'Pulsa este botón para recibir una notificación cuando el bus '
            'esté cerca. Si Android te pide permiso, elige Permitir.',
        icon: Icons.notifications_active_rounded,
      );
    case MapGuideStep.background:
      return const MapGuideCopy(
        title: 'Sigue con lo tuyo',
        message: 'Puedes cambiar de aplicación y hacer otra cosa. En Android, '
            'Ya Viene seguirá pendiente del bus; no cierres la app deslizando '
            'su tarjeta ni la fuerces a detenerse.',
        icon: Icons.phone_android_rounded,
        primaryLabel: 'Finalizar guía',
      );
  }
}
