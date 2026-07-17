# MODIFICACIONES — Ya Viene

## Estructura del Monorepo

```
YaViene/
├── ya_viene_core/          ← Paquete compartido (modelos, theme, providers)
├── app_pasajero/           ← App del pasajero (Flutter)
├── app_conductor/          ← App del conductor (Flutter)
├── Plan.md
├── README.md
└── modificaciones.md
```

---

## Paquete `ya_viene_core` (Core Compartido)

### Refinamiento 2026-07-11 — Rendimiento + UI Premium

- Streams mock de GPS/tick ajustados a 3s para reducir presión de CPU.
- `MapWidget` queda sin `ref.watch` ni `setState` en el flujo de posición del bus.
- El bus se actualiza exclusivamente con `ref.listenManual(movingBusProvider)` + `MapLibreMapController.setGeoJsonSource()`.
- Ícono de bus 2.5D/isométrico embebido como PNG base64 y cargado una sola vez con `addImage()` en `onStyleLoaded`.
- Rotación del bus delegada a MapLibre con `iconRotate: ['get', 'heading']`, aprovechando GPU.
- Theme light reescrito con paleta cívica premium: fondos cálidos, texto pizarra, azul institucional profundo y verde esmeralda.
- Nuevos componentes premium: `AnimatedSelectionChip`, `ModernDropDown` e `EtaBottomSheet` animado con CTA pill.
- `flutter analyze` pasa sin issues en `ya_viene_core` y `app_pasajero`.

### Dependencias
- `flutter_riverpod: ^2.5.1` — State management
- `equatable: ^2.0.5` — Comparación por valor
- `intl: ^0.19.0` — Internacionalización

### Modelos

| Archivo | Clase | Campos clave |
|---|---|---|
| `models/bus_position.dart` | `BusPosition` | busId, routeId, lat, lon, heading, speedKmh, timestamp, isGhostBus |
| `models/bus_stop.dart` | `BusStop`, `BusStopType` | id, name, tipo (fija/informal), lat, lon, radioInfluenciaM |
| `models/company.dart` | `Company` | id, name |
| `models/route_info.dart` | `RouteInfo` | id, name, companyId |
| `models/route_trajectory.dart` | `RouteTrajectory`, `GeoPoint` | routeId, routeName, points; método toGeoJson() |

### Providers

| Provider | Tipo | Descripción |
|---|---|---|
| `realtimeTickProvider` | `StreamProvider<int>` | Tick cada 3s (debug, mide rendimiento sin quemar CPU) |
| `busPositionsProvider` | `StreamProvider.family<List<BusPosition>, String>` | 3 buses simulados cada 3s |
| `companiesProvider` | `FutureProvider<List<Company>>` | Catálogo: Coolitoral, Metrocaribe, Transcaribe |
| `selectedCompanyProvider` | `StateNotifierProvider<Company?>` | Empresa seleccionada |
| `routesByCompanyProvider` | `FutureProvider.family<List<RouteInfo>, String>` | Rutas por empresa |
| `selectedRouteProvider` | `StateNotifierProvider<RouteInfo?>` | Ruta seleccionada |
| `selectedSentidoProvider` | `StateProvider<RouteSentido>` | Sentido: ida/vuelta (default: ida) |
| `proximityAlertProvider` | `StateProvider<bool>` | Alerta de proximidad |
| `routeTrajectoryProvider` | `FutureProvider.family<RouteTrajectory, String>` | 10 puntos simulados (Soledad→Centro) |
| `busStopsProvider` | `FutureProvider.family<List<BusStop>, String>` | 4 paradas (2 fijas + 2 informales) |
| `movingBusProvider` | `StreamProvider<BusPosition>` | Bus móvil cada 3s, heading calculado, ghost en tick 15 |

### Theme (`app_theme.dart`)

| Clase | Contenido |
|---|---|
| `AppColors` | primary (#2563EB), primaryDeep (#1E40AF), primarySoft, primaryTint, accent (#059669), background (#F6F7F9), surface, surfaceMuted, textPrimary (#0F172A), textSecondary (#475569), divider, error, success |
| `AppSpacing` | xs=4, sm=8, md=16, lg=24, xl=32, xxl=48 |
| `AppRadius` | sm=8, md=12, lg=16, card=18, sheet=28, pill=999 |
| `AppShadows` | soft (0,8, blur 18), floating (doble sombra difusa de baja opacidad) |
| `AppTextStyles` | h1 (24/700), h2 (20/600), h3 (16/600), bodyLarge (16/400), body (14/400), labelLarge (15/600), label (12/600), etaNumber (66/200, primaryDeep) |
| `AppTheme` | `lightTheme` — Material 3 completo, light mode estricto, sin negro puro |

### Shared Widgets

| Widget | Props | Estados |
|---|---|---|
| `ModernDropDown<T>` | label, hint, icon, items, selectedItem, itemLabel, onChanged, isLoading, errorMessage, onRetry | loading (skeleton), error (con retry), data, focus/expanded animado |
| `InstitutionalDropDown<T>` | Alias compatible de `ModernDropDown<T>` | mismos estados |
| `PrimaryButton` | label, onPressed, isLoading, isDestructive, icon, colorOverride, textColorOverride | normal, loading, disabled, destructive |
| `SelectionChip` | label, icon, isSelected, onTap | selected, unselected |
| `AnimatedSelectionChip<T>` | options, selectedValue, onChanged | indicador deslizante, color/icon/text animados |

Los widgets se exportan desde `ya_viene_core` y son reutilizados por ambas apps. En `app_pasajero/lib/shared/widgets`, `selection_chip.dart` e `institutional_dropdown.dart` son re-exports para evitar duplicación.

---

## App `app_pasajero`

### Dependencias clave

| Paquete | Versión | Uso |
|---|---|---|
| `ya_viene_core` | path: ../ya_viene_core | Core compartido |
| `maplibre_gl` | ^0.26.1 | **Mapa nativo MapLibre GL (Open Source, sin API key)** |
| `flutter_riverpod` | ^2.5.1 | State management |
| `go_router` | ^14.2.0 | Navegación |
| `socket_io_client` | ^2.0.3+1 | WebSocket (lectura) |
| `dio` | ^5.4.3+1 | HTTP REST |
| `shared_preferences` | ^2.3.1 | Almacenamiento local |
| `sqflite` | ^2.3.3+1 | SQLite local |
| `cached_network_image` | ^3.3.1 | Imágenes con caché |
| `permission_handler` | ^11.3.1 | Permisos nativos |

### Migración Mapbox → MapLibre

- **Antes:** `mapbox_maps_flutter: ^2.23.1` (requería API key, propietario)
- **Ahora:** `maplibre_gl: ^0.26.1` (Open Source BSD-3, sin llaves)
- **Widget de mapa:** `MapLibreMap` con controlador `MapLibreMapController`
- **Estilo:** `https://basemaps.cartocdn.com/gl/positron-gl-style/style.json`
- **Íconos de bus:** PNG 2.5D/isométrico embebido en código y cargado una sola vez con `MapLibreMapController.addImage()`
- **Rotación del bus:** `iconRotate: ['get', 'heading']`; MapLibre rota el asset en GPU según el `heading` del GeoJSON.
- **Nota web:** `maplibre_gl_web` crashea al inicializar en navegador. En web se usa un `Container` de color como placeholder. En Android/iOS/macOS funciona con mapa real.

### Archivos de `lib/`

#### `main.dart`
- `ProviderScope` → `YaVieneApp`
- `MaterialApp.router` con GoRouter
- Light mode forzado
- Orientación vertical forzada
- Tema: `AppTheme.lightTheme`

#### `core/router/app_router.dart`
- `appRouterProvider` → `Provider<GoRouter>`
- Rutas: `/` → `MapScreen`, `/route/:routeId` (planeada), `/alerts` (planeada)
- Provider de Riverpod para inyectar dependencias (ej. auth) en el futuro

#### `features/map/presentation/screens/map_screen.dart`
- Stack de 4 capas: AppBar + FilterPanel + MapWidget + EtaBottomSheet
- Badge de debug que muestra el tick del WebSocket (solo visible en debug)

#### `features/map/presentation/widgets/map_widget.dart`
- En web: retorna `Container` color background (placeholder por bug de `maplibre_gl_web`)
- En mobile: `MapLibreMap` con estilo Carto Positron, capas de ruta, paradas y bus animado
- Íconos de bus 2.5D cargados una sola vez en `onStyleLoaded` con `addImage`
- Capas: route line (fill+line), fixed stops (circle), informal stops (fill halo), bus marker (symbol)
- Bus marker usa `iconImage`/`iconRotate` con expresiones para data-driven rotation y ghost state
- Cero `ref.watch` en el widget del mapa; cambios de ruta entran por `didUpdateWidget`
- Movimiento del bus aislado con `ref.listenManual(movingBusProvider)` y `setGeoJsonSource`
- Maneja ciclo de vida con `WidgetsBindingObserver`

#### `features/map/presentation/widgets/filter_panel.dart`
- Dropdown de Empresa (`InstitutionalDropDown`)
- Dropdown de Ruta (`InstitutionalDropDown`)
- Selector de Sentido (Ida/Vuelta con `AnimatedSelectionChip`)

#### `features/map/presentation/widgets/eta_bottom_sheet.dart`
- Bottom sheet premium con `AnimatedSize` para expandir/contraer
- Drag handle animado + icono bus + destino (Centro/Soledad según sentido)
- ETA gigante: "3" con 66sp y peso w200
- Detalle de ruta visible al expandir
- Botón pill "Avisarme cuando esté cerca" con `AnimatedScale`, cambio elegante de color e ícono según `proximityAlertProvider`

#### `features/map/presentation/widgets/map_placeholder.dart`
- Placeholder legacy con cuadrícula (ya no se usa en producción)

### Assets

| Directorio | Estado |
|---|---|
| `assets/fonts/` | Vacío (solo .gitkeep) |
| `assets/icons/` | Vacío (el bus 2.5D está embebido como PNG base64 en `map_widget.dart`) |
| `assets/images/` | Vacío (solo .gitkeep) |
| `assets/icon/` | `ya_viene_logo.svg` (icono final), `foreground.svg` (capa frontal para Android adaptive icon) |

La sección `assets:` en pubspec.yaml está comentada. Las fuentes Inter se usan en el tema pero no están cargadas físicamente.

### App Icon

- **Diseño final:** Círculo verde (`#00A859`) con ondas de conectividad blancas + bus azul marino (`#14274E`) con parabrisas blanco y faros amarillos.
- **Android Adaptive Icon:** Configurado con 2 capas:
  - Background: `@color/ic_launcher_background` → `#00A859`
  - Foreground: `@mipmap/ic_launcher_foreground` (solo bus + ondas, fondo transparente, optimizado para safe zone 66%)
- **PNGs generados** con `rsvg-convert` para todas las densidades (mdpi a xxxhdpi), tanto para `ic_launcher.png` (icono completo) como `ic_launcher_foreground.png` (solo foreground).

### Plataformas

| Plataforma | Estado |
|---|---|
| Android | ✅ Configurado |
| iOS | ✅ Configurado |
| macOS | ✅ Configurado |
| Web | ✅ Configurado (con bug de MapLibre) |

---

## App `app_conductor`

### Archivos

| Archivo | Descripción |
|---|---|
| `main.dart` | Punto de entrada, orientación vertical, background service, tema light |
| `features/tracking/background_service_config.dart` | Foreground Service Android + iOS, punto de entrada del Isolate |
| `features/tracking/gps_manager.dart` | GPS con anti-fraude (detecta isMocked), guarda en buffer offline |
| `features/turn/login_screen.dart` | Login con cédula y PIN de 4 dígitos |
| `features/turn/turn_assignment_screen.dart` | Selección de bus y ruta |
| `features/turn/active_turn_dashboard.dart` | Dashboard con cronómetro, estado GPS, botón cerrar turno |
| `features/turn/fraud_blocker_screen.dart` | Pantalla de bloqueo por GPS falso |
| `core/offline/offline_buffer_repository.dart` | Buffer SQLite de posiciones para sincronización offline |

### Permisos Android
`INTERNET`, `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`, `ACCESS_BACKGROUND_LOCATION`, `FOREGROUND_SERVICE*`, `WAKE_LOCK`, `RECEIVE_BOOT_COMPLETED`

### Dependencias
- `ya_viene_core` (path) — modelos, theme, shared widgets
- `flutter_riverpod`, `geolocator`, `permission_handler`, `flutter_background_service`, `mqtt_client`, `sqflite`, `logger`, `equatable`

### Plataformas soportadas
Solo Android.

---

## Cómo ejecutar

### app_pasajero
```bash
cd app_pasajero
flutter run -d android      # Emulador Android
flutter run -d ios           # Simulador iOS (requiere Xcode)
flutter run -d macos         # macOS desktop (requiere Xcode)
flutter run -d chrome        # Web (navegador, mapa no funciona)
```

### app_conductor
```bash
cd app_conductor
flutter run -d android       # Solo Android
```

### Hot Reload
Con la app corriendo, presioná `r` en la terminal para ver cambios al instante. `R` para hot restart.

---

## Commit history importante

| Commit | Mensaje | Descripción |
|---|---|---|
| `69091a1` | Plan de projecto con los MVP incluidos | Primer commit con plan |
| `796ccbc` | primeras vistas y logica basica | Vistas iniciales |
| `6623547` | migracion a maplibre | Migración Mapbox → MapLibre, creación de `ya_viene_core`, `app_conductor` |
| `d7a2057` | arreglo mapa que no salia y mejoras UI UX | Fix mapa, shared widgets movidos a core, imports |
| `c1f795a` | nuevo logo para la app | Primer icono (oscuro con radar neón) |
| `114eafa` | cambio de icono | Icono final verde con bus azul, adaptive icon, foreground separado, safe zone corregido |
| `65e0911` | gitignore y limpieza de archivos generados | `.gitignore`, limpieza de `.dart_tool/`, `.DS_Store`
