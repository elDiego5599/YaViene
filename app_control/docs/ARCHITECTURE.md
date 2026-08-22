# Arquitectura de Ya Viene Control

El panel de control (`ya_viene_control`) es una aplicación de escritorio diseñada con **Flutter 3.x**, **Riverpod 2.x**, **GoRouter**, **Flutter Map** (OpenStreetMap + MapLibre tiles) y **Socket.IO Client** para el monitoreo y gestión de flotas de transporte público.

---

## 1. Módulos Principales

* **`features/auth`**:
  * `AuthApi`: Login y validación de tokens administrativos vía REST (`/api/admin/login`, `/api/fleet/routes`).
  * `AuthNotifier`: Manejo del ciclo de vida de la sesión administrativa persistida en `SharedPreferences`.

* **`features/fleet`**:
  * `FleetSocketService`: Conexión WebSocket con Socket.IO al backend para suscripción a eventos de flota (`fleet:batch`, `bus:position`, `bus:visible`, `bus:hidden`, `bus:left`, `bus:removed`, `session:kicked`).
  * `FleetApi`: Endpoints REST para operaciones CRUD de catálogo (creación/edición/eliminación de buses y rutas) y control de visibilidad.
  * `FleetNotifier`: Estado global de flota reactivo que combina datos en vivo del socket con catálogos REST.
  * `DashboardScreen`: Interfaz principal con lista de buses, filtros por ruta y estado (En línea, Sin señal, Oculto), control de visibilidad masiva y mapa de calor/posiciones.
  * `ControlMap`: Renderizado de buses en tiempo real sobre OpenStreetMap usando marcadores con rotación de rumbo (heading) y estado cromático (verde en línea, gris sin señal, rojizo oculto).

---

## 2. Flujo de Datos

```
[ Backend YaViene / Socket.IO ] ──(WebSockets)──> [ FleetSocketService ]
                                                          │
                                                (StreamSubscription)
                                                          ▼
[ Backend REST API ] <───(Dio / Bearer Token)───> [ FleetNotifier ]
                                                          │
                                                    (StateNotifier)
                                                          ▼
                                                 [ DashboardScreen ]
                                                ├── [ ControlMap ]
                                                ├── [ FleetListTile ]
                                                └── [ Bus / Route Dialogs ]
```

---

## 3. Pruebas y Linter

* Linter configurado con reglas estrictas en `analysis_options.yaml`.
* Pruebas de integración socket y renderizado de dashboard en `test/`.
