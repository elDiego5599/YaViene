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

// Pasos que viven en el mapa (no en el selector).
bool isMapGuideStep(MapGuideStep? step) {
  return step == MapGuideStep.location ||
      step == MapGuideStep.search ||
      step == MapGuideStep.buses ||
      step == MapGuideStep.distance ||
      step == MapGuideStep.alert ||
      step == MapGuideStep.background;
}

// Copia final por paso, con overrides para el paso de alerta (aviso ya
// activo, límite de 2, ruta que no pasa cerca, o bloqueado por señal/
// cercanía). Antes vivía en map_screen.dart; ahora está junto al resto de
// copias para encontrarlo.
MapGuideCopy guideCopyFor(
  MapGuideStep step, {
  required bool hasActiveAlert,
  required bool limitReached,
  required bool isBlocked,
  bool routeTooFar = false,
}) {
  if (step == MapGuideStep.alert) {
    if (hasActiveAlert) {
      return const MapGuideCopy(
        title: 'Aviso ya activado',
        message: 'Este bus ya tiene un aviso activo: te avisaremos cuando '
            'esté cerca.',
        icon: Icons.notifications_active_rounded,
        primaryLabel: 'Continuar',
      );
    }
    if (limitReached) {
      return const MapGuideCopy(
        title: 'Ya tienes 2 avisos activos',
        message: 'Desactiva uno o espera a que termine para activar otro. '
            'Recuerda no cerrar la aplicación ni salirte de la guía.',
        icon: Icons.notifications_off_rounded,
        primaryLabel: 'Continuar',
      );
    }
    // Va antes que [isBlocked]: cuando la ruta no pasa cerca, cambiar de bus
    // no arregla nada —ninguno de esa ruta va a acercarse— y mandar al
    // usuario a "elegir otro bus" lo dejaría dando vueltas en la guía.
    if (routeTooFar) {
      return const MapGuideCopy(
        title: 'Esta ruta no pasa cerca de ti',
        message: 'Ningún bus de esta ruta se acercará a tu punto de espera, '
            'así que el aviso no sonaría. Mueve tu punto o elige otra ruta '
            'cuando termines la guía.',
        icon: Icons.wrong_location_rounded,
        primaryLabel: 'Continuar',
      );
    }
    if (isBlocked) {
      return const MapGuideCopy(
        title: 'Elige otro bus',
        message: 'Este bus no admite un aviso porque no tiene señal o ya está '
            'demasiado cerca. Selecciona otro bus en el mapa.',
        icon: Icons.swap_horiz_rounded,
        primaryLabel: 'Elegir otro bus',
      );
    }
  }
  return mapGuideCopy(step);
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
        // «Cuánto falta» se leía como minutos; lo que abre el toque es la
        // distancia en metros, igual que el paso siguiente.
        message:
            'Estos iconos representan los buses en vivo. Toca uno para ver '
            'a qué distancia está.',
        icon: Icons.directions_bus_rounded,
      );
    case MapGuideStep.distance:
      return const MapGuideCopy(
        title: 'Mira la distancia',
        message:
            'Aquí verás a qué distancia está el bus de tu punto de espera.',
        // El paso se llama "Mira la distancia" y el texto habla de metros:
        // el cronómetro que había aquí prometía minutos.
        icon: Icons.route_rounded,
        primaryLabel: 'Continuar',
      );
    case MapGuideStep.alert:
      return const MapGuideCopy(
        title: 'Activa el aviso',
        // "Si Android te pide permiso" se leía tal cual en un iPhone. Quien
        // ve el aviso del sistema no necesita que le digan qué sistema es.
        message: 'Pulsa este botón para recibir una notificación cuando el bus '
            'esté cerca. Si el teléfono te pide permiso, elige Permitir.',
        icon: Icons.notifications_active_rounded,
      );
    case MapGuideStep.background:
      return const MapGuideCopy(
        title: 'Sigue con lo tuyo',
        message: 'Puedes cambiar de aplicación y hacer otra cosa: Ya Viene '
            'seguirá pendiente del bus. Lo único que lo corta es cerrar la '
            'app del todo.',
        icon: Icons.smartphone_rounded,
        primaryLabel: 'Finalizar guía',
      );
  }
}
