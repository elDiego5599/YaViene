# Ya Viene: Fase 8, rendimiento y observabilidad

Fecha: 2026-08-04
Estado: implementada y validada con smoke de metricas

## Alcance

Esta fase no agrega trayectorias, paradas ni catalogos dinamicos. Se concentra
en medir y reducir el costo del pipeline GPS actual.

## Cambios Backend

- Nuevo modulo de metricas en memoria.
- Nuevo `GET /api/metrics` protegido con `x-admin-key`.
- Contadores de autenticacion MQTT.
- Contadores de suscripciones ACK.
- Contadores de publicaciones autorizadas y rechazadas.
- Contadores de mensajes recibidos.
- Contadores de posiciones aceptadas y rechazadas.
- Contadores de ACK publicados y errores de ACK.
- Logs por paquete MQTT desactivados por defecto.
- Logs detallados disponibles con `MQTT_DEBUG_LOGS=true`.

Ejemplo:

```bash
curl http://localhost:3000/api/metrics \
  -H 'x-admin-key: CLAVE_ADMIN'
```

## Cambios Conductor

El engine Android utiliza:

- `distanceFilter: 5` metros.
- `intervalDuration: 2` segundos.
- ACK y outbox sin cambios de durabilidad.

Esto reduce lecturas GPS redundantes, escrituras SQLite, publicaciones MQTT y
consumo de bateria sin eliminar el control de entrega.

## Cambios Pasajero

El provider agrupa actualizaciones live durante 200 ms antes de emitir al mapa.
El backend puede continuar recibiendo posiciones, pero MapLibre no recibe un
render completo por cada paquete MQTT.

## Pruebas Ejecutadas

- Backend build: PASS.
- TypeScript: PASS.
- Analyzer conductor: PASS.
- Tests conductor: PASS.
- Analyzer pasajero: PASS.
- Simulador MQTT: PASS.
- `/api/metrics` sin admin: `401`.
- `/api/metrics` con admin: `200`.
- Contadores de auth, subscribe, publish, ACK y posiciones: presentes.
- Logs `authorizePublish` por paquete: `0` con debug desactivado.
- Logs `publish event` por paquete: `0` con debug desactivado.

## Metricas Observadas

```json
{
  "mqtt.auth.accepted": 1,
  "mqtt.subscribe.accepted": 1,
  "mqtt.publish.authorized": 2,
  "mqtt.messages.received": 2,
  "position.accepted": 1,
  "position.rejected": 1,
  "mqtt.ack.published": 2
}
```

La posicion rechazada corresponde al sanity check del simulador, no a un
fallo de entrega.

## Limitaciones

- Las metricas son por proceso y se reinician al reiniciar el backend.
- No hay Prometheus, persistencia ni dashboard.
- Todavia no se ha ejecutado una prueba de carga con muchos buses y pasajeros.
- El coalescing visual aun reconstruye el GeoJSON completo cuando vence el
  intervalo.
- El limite de 5 metros debe validarse con conductores reales y consumo de
  bateria.

## Criterio De Salida

La fase se considera implementada porque el pipeline tiene contadores
consultables, logs operativos controlados y limites de frecuencia en conductor
y pasajero. La siguiente fase debe cubrir transporte cifrado, rate limiting y
health/readiness de produccion.
