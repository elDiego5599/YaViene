library;

// --- Geometría ---
export 'core/geo/distancia.dart';
export 'core/geo/por_ruta.dart';

// --- Lugares (buscador de origen y destino, D25) ---
export 'core/lugares/buscador_de_lugares.dart';
export 'core/lugares/buscador_falso.dart';
export 'core/lugares/buscador_local.dart';
export 'core/lugares/lugar.dart';
export 'core/lugares/recientes_de_lugares.dart';

// --- Models (capa de datos) ---
export 'core/models/bus_motion.dart';
export 'core/models/bus_position.dart';
export 'core/models/bus_stop.dart';
export 'core/models/company.dart';
export 'core/models/connection_status.dart';
export 'core/models/motivo_queja.dart';
export 'core/models/route_info.dart';
export 'core/models/route_trajectory.dart';

// --- Red ---
export 'core/network/backend_resolver.dart';
export 'core/network/backend_supervisor.dart';
export 'core/network/fallo_red.dart';
export 'core/network/url_segura.dart';
export 'core/network/zona_socket.dart';

// --- Observabilidad ---
export 'core/observability/medidor_latencia.dart';

// --- Ocupación ---
export 'core/ocupacion/ocupacion_simulada.dart';

// --- Providers (capa de estado) ---
export 'core/providers/app_providers.dart';
export 'core/providers/map_providers.dart';
export 'core/providers/providers.dart';

// --- Puntos de recarga (D21) ---
export 'core/recarga/puntos_recarga.dart';

// --- Theme ---
export 'core/theme/app_motion.dart';
export 'core/theme/app_theme.dart';
export 'core/theme/escala_calor.dart';
export 'core/theme/estilo_mapa.dart';
export 'core/theme/estilo_retocado.dart';
export 'core/theme/estilo_ruta.dart';

// --- Viaje de puerta a puerta (docs/viaje-completo.md) ---
export 'core/viaje/bus_que_viene.dart';
export 'core/viaje/planear.dart';
export 'core/viaje/red_de_rutas.dart';
export 'core/viaje/viaje.dart';

// --- Widgets compartidos ---
export 'shared/widgets/widgets.dart';
