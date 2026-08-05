# Ya Viene: Fase 10, carga y backpressure

Fecha: 2026-08-04
Estado: implementada con carga reproducible inicial

## Cambios

- Coalescing backend de posiciones Socket.io por ruta y bus cada 200 ms.
- Si llegan varias posiciones del mismo bus durante la ventana, solo se emite
  la ultima al pasajero.
- `bus:left` elimina primero la posicion pendiente para no emitir un estado
  viejo despues de la salida.
- Se contabilizan posiciones coalescidas y emitidas.
- Nuevo `scripts/load-test.mjs` para levantar multiples simuladores MQTT.

## Uso Del Load Test

Con el backend levantado:

```bash
LOAD_BUSES=10 \
LOAD_DURATION_MS=10000 \
BACKEND_URL=http://localhost:3000 \
ADMIN_API_KEY=CLAVE_ADMIN \
node scripts/load-test.mjs
```

## Ejecucion Realizada

Perfil:

- 5 buses.
- 8 segundos.
- 1 publicacion cada 2 segundos por simulador.
- Capturas historicas separadas 10 segundos.

Resultado:

```json
{
  "mqtt.auth.accepted": 5,
  "mqtt.subscribe.accepted": 5,
  "mqtt.publish.authorized": 15,
  "mqtt.messages.received": 15,
  "position.accepted": 9,
  "position.rejected": 6,
  "mqtt.ack.published": 15,
  "socket.position.emitted": 9,
  "socket.bus_left.emitted": 5
}
```

No se observaron logs de `authorizePublish` ni `publish event` con debug
desactivado.

## Limitaciones

- Esta no es aun una prueba de 100 buses/500 pasajeros.
- No se midio P95/P99 de latencia.
- El coalescing backend requiere pruebas con clientes Socket.io reales.
- El mapa todavia reconstruye el GeoJSON completo en cada emision coalescida.
- No se agregaron trayectorias ni paradas.

## Criterio De Salida

La fase queda implementada porque existe backpressure basico, una prueba de
carga reproducible y metricas para observar el resultado.
