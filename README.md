# YaViene — Transporte público en tiempo real

Sistema de monitoreo de buses en tiempo real para ciudades como Barranquilla.
El GPS va instalado en el bus y publica su posición; el pasajero ve los buses
en un mapa y recibe un aviso cuando el suyo se acerca a su parada.

## Componentes

| Carpeta | Qué es |
|---|---|
| `YaVieneBackend` | Backend Node.js + TypeScript: recibe el GPS del bus por MQTT, lo difunde al pasajero por WebSockets, guarda rutas y posiciones en SQLite. |
| `app_pasajero` | App Flutter del pasajero: mapa con los buses en vivo, pin del usuario (GPS o toque manual), detalle de proximidad y aviso a 1 km con notificación local. |
| `app_control` | Panel de control de escritorio (macOS y Windows): ve el estado de la flota y administra las empresas. |
| `ya_viene_core` | Lógica compartida entre las apps (tipos, distancia, utilidades). |
| `build-demo.sh` | Compila e instala las apps de la demo con un solo comando. |
| `check-demo.sh` | Comprueba en 20 segundos que la demo esté viva antes de presentar. |

## Cómo funciona

1. **Bus**: el GPS instalado en el vehículo captura latitud, longitud, rumbo y
   velocidad, y las publica por MQTT.
2. **Backend**: recibe las posiciones, las guarda, y las difunde por WebSockets
   a todos los pasajeros suscritos a la ruta. Si un bus deja de reportar más de
   5 minutos, se marca como "sin señal".
3. **Pasajero**: ve los buses moviéndose en el mapa, toca uno para ver qué tan
   lejos está de su ubicación, y puede activar un aviso: cuando el bus esté a
   1 km, la app le notifica (la notificación funciona con la app en segundo
   plano). ETA (tiempo de llegada) está pendiente: por ahora se muestra
   distancia y estado.

## Stack

- **Mobile**: Flutter / Dart · Mapas con **MapLibre GL**.
- **Backend**: Node.js + TypeScript · **MQTT** (broker aedes) para ingesta GPS ·
  **WebSockets** (socket.io) para el tiempo real · **SQLite** para datos.
- **Demo en vivo**: el simulador `YaVieneBackend/scripts/simulate-bus.mjs`
  mueve buses sobre la geometría real de la ruta R-106 (Sobusa Barranquilla).

## Cómo correr la demo

Con el backend ya corriendo (Fly, o local detrás de un túnel):

```bash
./build-demo.sh --backend-url=https://donde-esté-el-backend
```

Compila la APK del pasajero y el panel de escritorio con esa URL grabada, y los
instala: la APK en el teléfono conectado (queda además en
`~/Desktop/APKs/YaViene-Pasajero.apk`) y el panel en `/Applications`.

`BACKEND_URL` es constante de compilación, así que **si la URL cambia hay que
volver a correr el script y reinstalar**. Por eso el script comprueba primero
que el backend responda y aborta si no: compilar contra una URL muerta da unas
apps que se ven perfectas y no funcionan.

Los buses simulados se arrancan **en la misma máquina que el backend** (el
broker MQTT solo escucha en loopback, a propósito):

```bash
cd YaVieneBackend && bash scripts/demo-buses.sh --fondo
```

Pone **dos buses en cada una de las seis rutas**, en extremos opuestos del
recorrido, para que cualquier ruta que se abra —en el panel o en el
pasajero— tenga buses moviéndose sin ir a arrancar nada. En R-106, la de la
demo, van más rápido: **B-042 al 80 %** del recorrido (ya pasó por la
parada) y **B-055 al 15 %** (viene llegando). Si el backend está desplegado
en Fly, es el mismo comando dentro de `fly ssh console`.
`RUTAS_DEMO="R-106"` recorta la lista si la máquina se ahoga con doce
simuladores.

Con `--fondo` quedan vigilados: sobreviven al cierre de la terminal y, si un
simulador se cae, se vuelve a levantar en 5 s. Importa porque un bus que deja
de publicar **no desaparece del mapa**: se queda quieto y a los cinco minutos
sale «sin señal» en las dos apps, sin ningún aviso de que el problema es que
el proceso se murió. `--estado` dice si están corriendo y `--detener` los
para. Sin `--fondo` corren en primer plano y se paran con Ctrl+C.

## Estado actual

- [x] Backend completo: ingesta MQTT, difusión WebSocket, SQLite, fantasmas
  ("sin señal").
- [x] App pasajero: mapa en vivo, pin por GPS o manual, selección de bus,
  aviso a 1 km con la app en segundo plano, panel inferior con estado del bus.
- [x] Panel de control (macOS y Windows).
- [x] Pruebas: 116 en `app_pasajero`, 29 en `app_control`, 3 en `ya_viene_core`,
  28 en el backend.

## Pendiente

- ETA (tiempo estimado de llegada).
- Publicar las apps en tiendas (Android/iOS).
- Lanzamiento piloto con una empresa transportadora.
