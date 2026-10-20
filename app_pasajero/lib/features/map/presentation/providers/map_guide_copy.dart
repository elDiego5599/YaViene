import 'package:flutter/foundation.dart';
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
// activo, límite de seguimiento, ruta que no pasa cerca, o bloqueado por señal/
// cercanía). Antes vivía en map_screen.dart; ahora está junto al resto de
// copias para encontrarlo.
MapGuideCopy guideCopyFor(
  MapGuideStep step, {
  required bool hasActiveAlert,
  required bool limitReached,
  required bool isBlocked,
  bool routeTooFar = false,
  bool eligiendoDistancia = false,
  TargetPlatform? plataforma,
}) {
  if (step == MapGuideStep.alert) {
    // Con la rueda abierta la guía ilumina solo la tarjeta del bus: se
    // sigue con «Guardar» de la rueda, no con un botón de la guía.
    if (eligiendoDistancia) {
      return const MapGuideCopy(
        title: 'Elige a qué distancia',
        message: 'Gira la rueda hasta la distancia a la que quieres el '
            'aviso y toca Guardar.',
        icon: Icons.straighten_outlined,
      );
    }
    if (hasActiveAlert) {
      return const MapGuideCopy(
        title: 'Aviso ya activado',
        message: 'Este bus ya tiene un aviso activo: te avisaremos cuando '
            'esté cerca.',
        icon: Icons.notifications_active_outlined,
        primaryLabel: 'Continuar',
      );
    }
    if (limitReached) {
      return const MapGuideCopy(
        title: 'Ya sigues un bus',
        message: 'Quita su aviso o espera a que suene para seguir otro.',
        icon: Icons.notifications_off_outlined,
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
        icon: Icons.wrong_location_outlined,
        primaryLabel: 'Continuar',
      );
    }
    if (isBlocked) {
      return const MapGuideCopy(
        title: 'Elige otro bus',
        message: 'Este bus no admite un aviso porque no tiene señal o ya está '
            'demasiado cerca. Selecciona otro bus en el mapa.',
        icon: Icons.swap_horiz_outlined,
        primaryLabel: 'Elegir otro bus',
      );
    }
  }
  return mapGuideCopy(step, plataforma: plataforma);
}

/// [plataforma] decide el último paso (iPhone no avisa con la app en el
/// fondo); por defecto, la del teléfono.
MapGuideCopy mapGuideCopy(MapGuideStep step, {TargetPlatform? plataforma}) {
  switch (step) {
    case MapGuideStep.location:
      return const MapGuideCopy(
        title: 'Fija tu punto de espera',
        message: 'La app necesita saber desde dónde esperas. Toca el mapa para '
            'poner un punto; también puedes usar el GPS.',
        icon: Icons.location_on_outlined,
      );
    case MapGuideStep.search:
      return const MapGuideCopy(
        title: 'Empieza aquí',
        message: 'Toca la barra blanca de arriba para buscar una empresa y una '
            'ruta.',
        icon: Icons.search_outlined,
      );
    case MapGuideStep.company:
      return const MapGuideCopy(
        title: 'Elige una empresa',
        message: 'Primero selecciona la empresa de transporte que buscas.',
        icon: Icons.business_outlined,
      );
    case MapGuideStep.route:
      return const MapGuideCopy(
        title: 'Elige tu ruta',
        message: 'Después selecciona la ruta y revisa sus terminales.',
        icon: Icons.alt_route_outlined,
      );
    case MapGuideStep.launchBuses:
      return const MapGuideCopy(
        title: 'Muestra los buses',
        message:
            'Cuando la ruta esté lista, pulsa este botón para ver sus buses '
            'en el mapa.',
        icon: Icons.play_arrow_outlined,
      );
    case MapGuideStep.buses:
      return const MapGuideCopy(
        title: 'Mira los buses',
        // «Cuánto falta» se leía como minutos; lo que abre el toque es la
        // distancia en metros, igual que el paso siguiente. El mapa va al
        // más cercano (dueño, 2026-10-16): el trozo iluminado salía sin
        // buses si el más cercano iba lejos.
        message: 'Te mostramos el bus más cercano; mueve el mapa para buscar '
            'otro. Toca uno para ver a qué distancia está.',
        icon: Icons.directions_bus_outlined,
      );
    case MapGuideStep.distance:
      return const MapGuideCopy(
        title: 'Mira la distancia',
        message:
            'Aquí verás a qué distancia está el bus de tu punto de espera.',
        // El paso se llama "Mira la distancia" y el texto habla de metros:
        // el cronómetro que había aquí prometía minutos.
        icon: Icons.route_outlined,
        primaryLabel: 'Continuar',
      );
    case MapGuideStep.alert:
      return const MapGuideCopy(
        title: 'Activa el aviso',
        // "Si Android te pide permiso" se leía tal cual en un iPhone. Quien
        // ve el aviso del sistema no necesita que le digan qué sistema es.
        message: 'Pulsa este botón para recibir una notificación cuando el bus '
            'esté cerca. Si el teléfono te pide permiso, elige Permitir.',
        icon: Icons.notifications_active_outlined,
      );
    case MapGuideStep.background:
      // En iPhone el aviso solo suena con la app abierta: la app no declara
      // `UIBackgroundModes` y no hay push, así que iOS la suspende al
      // cambiar de app o bloquear el teléfono. Prometer que «seguirá
      // pendiente» hacía perder el bus (auditoría 2026-09, H3). Lo mismo
      // dicen Notificaciones y la privacidad.
      if ((plataforma ?? defaultTargetPlatform) == TargetPlatform.iOS) {
        return const MapGuideCopy(
          title: 'Deja Ya Viene abierta',
          message: 'En iPhone el aviso solo suena con Ya Viene abierta y la '
              'pantalla encendida. Si cambias de aplicación o bloqueas el '
              'teléfono, no te llegará.',
          icon: Icons.smartphone_outlined,
          primaryLabel: 'Finalizar guía',
        );
      }
      return const MapGuideCopy(
        title: 'Sigue con lo tuyo',
        message: 'Puedes cambiar de aplicación y hacer otra cosa: Ya Viene '
            'seguirá pendiente del bus. Lo único que lo corta es cerrar la '
            'app del todo.',
        icon: Icons.smartphone_outlined,
        primaryLabel: 'Finalizar guía',
      );
  }
}
