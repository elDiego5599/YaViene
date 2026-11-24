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
| `ya_viene_pruebas` | Guías de prueba compartidas (contraste); solo como `dev_dependency`. |
| `build-demo.sh` | Compila e instala las apps de la demo con un solo comando. |
| `check-demo.sh` | Comprueba en 20 segundos que la demo esté viva antes de presentar, y en el Mac el tablero del día (launchd, corriente, sueño, copias, logs). |

## Cómo funciona

1. **Bus**: el GPS instalado en el vehículo captura latitud, longitud, rumbo y
   velocidad, y las publica por MQTT.
2. **Backend**: recibe las posiciones, las guarda, y las difunde por WebSockets
   a todos los pasajeros suscritos a la ruta. Si un bus deja de reportar más de
   5 minutos, se marca como "sin señal".
3. **Pasajero**: ve los buses moviéndose en el mapa, toca uno para ver qué tan
   lejos está de su ubicación, y puede activar un aviso: cuando el bus esté a
   1 km, la app le notifica (la notificación funciona con la app en segundo
   plano). La app muestra distancia y estado, no tiempo de llegada: es una
   decisión de producto (una ETA sin datos de tráfico fiables engañaría).

## Stack

- **Mobile**: Flutter / Dart · Mapas con **MapLibre GL**.
- **Backend**: Node.js + TypeScript · **MQTT** (broker aedes) para ingesta GPS ·
  **WebSockets** (socket.io) para el tiempo real · **SQLite** para datos.
- **Demo en vivo**: el simulador `YaVieneBackend/scripts/simulate-bus.mjs`
  mueve buses sobre la geometría real de la ruta R-106 (Sobusa Barranquilla).

## Datos

Cada posición que llega se guarda muestreada en un historial. Lo crudo dura
una semana; cada día se consolida en un resumen por ruta y hora, con un
control de calidad, que sobrevive a la retención. De ahí salen los
indicadores de servicio que mide una empresa de buses:

- **Buses por hora**: cuántos buses distintos andan, en promedio por día.
- **Velocidad en marcha**: el promedio sin las muestras detenidas
  (semáforos, paraderos).
- **Intervalo entre buses** (headway) por sentido: el tiempo entre dos buses
  seguidos al cruzar la mitad de la ruta, con el cruce interpolado entre
  muestras. Se da la **mediana y el p90**, porque el promedio lo esconden
  los buses que se amontonan, que es lo que la empresa quiere ver.
- **Hora pico** y una marca de si lo medido viene de la flota simulada.

El panel lo muestra en Reportes, filtrable por fechas y días de la semana, y
lo exporta a **CSV** listo para Excel en español (punto y coma, coma
decimal) o para Python y R.

## Inteligencia artificial

`YaVieneBackend/prototipo-aforo` es un prototipo de **visión por
computador** que estima la ocupación del bus (vacío, medio o lleno) con las
cámaras del vehículo:

- **EfficientNet-B0** (PyTorch / torchvision) preentrenada en ImageNet y
  afinada a las tres clases; escala a B2 o V2-S si hace falta.
- Decisión conservadora: umbrales sobre la probabilidad acumulada, promedio
  de 5 cuadros y fusión de dos cámaras que se queda con el estado más bajo,
  con su nivel de confianza.
- Umbrales calibrados con un barrido que maximiza el F1 macro con a lo sumo
  5 % de sobreestimación.
- Se entrena en GPU (RTX 5070) y se sirve en CPU, con inferencia en vivo
  sobre video o RTSP. Se descartó YOLO por su licencia AGPL.

Aún no está conectado a las apps: hoy la ocupación que muestran es simulada.

## Infraestructura

- El backend corre en un Mac bajo **launchd** (servidor, túnel, copias de
  respaldo de la base y rotación de logs), y sale a internet por un túnel
  **ngrok** con dominio fijo.
- **Fly.io** es el respaldo en la nube. Las apps conmutan solas: si el
  principal no contesta pasan al respaldo en menos de 55 s, y vuelven al
  principal en menos de 30 s cuando reaparece.
- CI en **GitHub Actions**: Android, iOS, macOS y Windows.

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
  ("sin señal"), historial y consolidación diaria.
- [x] App pasajero: mapa en vivo, distancia medida por la ruta (no en línea
  recta), aviso a la distancia que elige el pasajero, actividad en vivo en
  iOS.
- [x] Panel de control (macOS y Windows) con reportes e indicadores por ruta.
- [x] Más de 1.900 pruebas automáticas entre las apps, el backend y la web,
  con pruebas de mutación.

## Pendiente

- Conectar el estimador de ocupación a las cámaras reales.
- Publicar las apps en tiendas (Android/iOS).
- Lanzamiento piloto con una empresa transportadora.
