# Ya Viene — Ficha técnica (demo)

**Qué es:** el pasajero ve sus buses en vivo en el mapa, selecciona el suyo y
recibe una **notificación a 1 km** (con la app en segundo plano). Un operador
controla la flota en tiempo real desde un panel de escritorio.

## Arquitectura

```
CONDUCTOR (Android) ──MQTT──▶ ┌───────────────────────────────────────┐
 (tel. real o simulador)       │  Backend Node.js (un proceso)        │
                               │  • Broker MQTT (aedes)               │
PASAJERO (Android) ──socket.io─│  • API REST + validación de física   │
 (MapLibre, notificaciones)    │  • SQLite (WAL, single-writer)       │
                               │  • Cola de eventos de ciclo de vida  │
PANEL DE CONTROL (macOS) ─socket└──────────┬──────────────────────────┘
 (Flutter, mapa + flota)                   │
                                           ▼
                                   Túnel ngrok → URL pública
```

## Protocolo y candados

- Posición por MQTT autenticado (JWT): lat/lon, rumbo, velocidad, `sequence`,
  `capturedAt` (reloj del dispositivo), sentido.
- **Candado de física:** velocidad reportada y *calculada* ≤ 120 km/h,
  reloj ±30 s (futuro) y −15 min (buffer offline), secuencia monótona.
- Sesión única por conductor (el segundo teléfono expulsa al primero).
- **"Sin señal" (ghost):** si un bus no publica en 5 min, NO desaparece del
  mapa: pasa a estado fantasma y se registra el evento (visible en el panel).
- Deduplicación y orden por `sequence`; eventos `bus:left/hidden/visible/
  removed` difundidos en vivo por socket.

## Seguridad

- PIN hasheado (scrypt + sal), JWT con secret forzado al arranque.
- Rate limits por IP en login/admin; `x-admin-key` para endpoints de operación.
- Payloads malformados y físicamente imposibles: rechazados, nunca crashean.
- *Pasajero sin autenticación:* decisión deliberada para la demo; la
  privacidad de ubicación (ID anónimo/OTP) es el siguiente paso del piloto.

## Pruebas — 50 en verde

| Suite                | Cant. | Qué cubre                                         |
| :------------------- | :---- | :------------------------------------------------ |
| Backend (unit/seg.)  | 6     | PIN, JWT, rate limits, protocolo de flota, E2E    |
| Backend (propiedades)| 9     | ~1.700 casos generados: física, haversine, límites|
| Backend (caos)       | 5     | Basura MQTT, payloads corruptos, reinicio en vivo,|
|                      |       | tormenta de suscripciones, DAST-lite (SQLi/XSS)   |
| Pasajero             | 27    | Aviso a 1 km, posiciones, máquina de estados,     |
|                      |       | chip de conexión, batch malformado                |
| Panel de control     | 3     | Socket, flota, sesión                             |

## Resiliencia (probada, no prometida)

- Reconexión infinita: pasajero, panel y simuladores se recuperan solos.
- El beat de caos de la demo **mata el backend en vivo y el stack se
  arregla solo** (los buses reaparecen moviéndose en < 30 s).
- Respaldos WAL diarios con verificación de integridad.
- Pre-vuelo `check-demo.sh`: túnel, buses publicando y DB fresca en 20 s.

## Datos

- Rutas reales de Barranquilla (R-101…R-106) convertidas de KMZ oficial;
  red de 60 km con terminales y cambio de sentido.

## Próximos pasos (piloto)

1. Piloto con un operador real y rutas verdaderas.
2. Autenticación anónima del pasajero + privacidad de ubicación.
3. Postgres y despliegue contenerizado cuando el piloto corra en un
   servidor que no sea el de desarrollo.