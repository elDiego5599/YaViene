# Ya Viene: Fase 5, tiempo de captura y sanity check

Fecha: 2026-08-04
Estado: implementada y verificada con replay controlado

## Objetivo

Evitar que el backend calcule velocidades usando el intervalo entre paquetes
recibidos cuando los paquetes representan posiciones capturadas anteriormente.

## Modelo Temporal

Cada posicion conserva:

| Campo | Significado |
|---|---|
| `capturedAt` | Momento en que el telefono obtuvo el GPS |
| `receivedAt` | Momento en que el backend recibio el mensaje |
| `sequence` | Orden dentro de la sesion |
| `timestamp` | Campo legacy equivalente a `receivedAt` |

El sanity check usa `capturedAt` para calcular la velocidad. `receivedAt` se
usa para el ciclo de vida del bus y para diagnostico.

## Reglas Aplicadas

- Capturas mas de 30 segundos en el futuro se rechazan.
- Velocidades reportadas negativas o superiores a 120 km/h se rechazan.
- Coordenadas fuera de rango se rechazan.
- Una secuencia menor o igual a la ultima de la misma sesion se considera
  duplicada.
- Una captura anterior a la captura aceptada anterior se rechaza.
- Una sesion nueva puede comenzar su secuencia desde uno.
- Las capturas de sesiones distintas no se comparan como si fueran la misma
  trayectoria.
- Los rechazos producen ACK con una razon estable.

## Razones De ACK

| Razon | Significado |
|---|---|
| `DUPLICATE` | Secuencia ya procesada |
| `FUTURE_CAPTURE_TIME` | Reloj del dispositivo demasiado adelantado |
| `OUT_OF_ORDER_CAPTURE` | Captura anterior a la ultima aceptada |
| `NO_CAPTURE_TIME_DELTA` | No existe intervalo temporal valido |
| `INVALID_REPORTED_SPEED` | Velocidad negativa o mayor al limite |
| `INVALID_COORDINATES` | Latitud o longitud fuera de rango |
| `SANITY_REJECTED` | Velocidad calculada fisicamente imposible |
| `INVALID_SEQUENCE` | Secuencia ausente o invalida |
| `INVALID_CAPTURE_TIME` | Captura ausente o invalida |
| `UNSUPPORTED_PROTOCOL_VERSION` | Version de protocolo no soportada |

## Pruebas Ejecutadas

### Replay Historico Valido

El simulador envio paquetes fisicamente cada 2 segundos, pero con capturas
separadas 10 segundos y retrasadas 60 segundos.

Resultado:

- Posicion 1: `accepted: true`.
- Posicion 2: `accepted: true`.
- No se genero rechazo de sanity.
- La posicion publica mostro `capturedAt`, `receivedAt` y `sequence`.

### Reloj Futuro

El simulador envio capturas 60 segundos adelantadas.

Resultado:

```text
accepted: false
reason: FUTURE_CAPTURE_TIME
```

### Captura Fuera De Orden

El simulador envio una segunda captura anterior a la primera.

Resultado:

```text
accepted: false
reason: OUT_OF_ORDER_CAPTURE
```

## Limitaciones Pendientes

- La politica de edad maxima de una captura historica aun no esta definida.
- El sanity check no usa aun precision GPS ni accuracy horizontal.
- No se ha agregado una prueba automatizada de unidad para todas las razones.
- El dispositivo real debe probarse con reloj incorrecto y replay prolongado.
- La frecuencia GPS sigue usando `distanceFilter: 0`.

## Criterio De Salida

La fase se considera implementada porque el intervalo de recepcion ya no
determina la velocidad del replay y el backend diferencia duplicados,
capturas futuras y capturas fuera de orden.

La siguiente fase debe centrarse en el servicio GPS real en background y en la
durabilidad del outbox durante apagado, suspensión y reinicio del proceso.
