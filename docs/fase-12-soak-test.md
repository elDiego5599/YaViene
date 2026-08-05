# Ya Viene: Fase 12, soak test

Fecha: 2026-08-04
Estado: ejecutada con 20 buses

## Perfil

- 20 simuladores MQTT.
- 20 segundos.
- Publicacion cada 2 segundos por bus.
- Capturas historicas separadas 10 segundos.
- ACK habilitado.
- Backend en proceso unico.

## Resultado

```json
{
  "mqtt.auth.accepted": 20,
  "mqtt.subscribe.accepted": 20,
  "mqtt.publish.authorized": 180,
  "mqtt.messages.received": 180,
  "position.accepted": 67,
  "position.rejected": 113,
  "mqtt.ack.published": 180,
  "socket.position.emitted": 67,
  "socket.bus_left.emitted": 20
}
```

Las posiciones rechazadas correspondieron a movimientos imposibles del
simulador. No se observaron fallos de autenticacion, ACK ni apagado del
runner.

Durante esta prueba tambien se detecto y corrigio un problema del rate limit:
el presupuesto de login no podia ser solo por IP porque todos los conductores
de una misma red comparten IP. Ahora la clave combina IP y conductor.

## Limitaciones

- No representa aun 100 buses y 500 pasajeros.
- No se midieron P95/P99 ni consumo de CPU formalmente.
- El load test no crea clientes Socket.io masivos.
- No se probo larga duracion de horas.

## Criterio De Salida

El soak test es reproducible, produce metricas y no deja procesos simuladores
activos al finalizar.
