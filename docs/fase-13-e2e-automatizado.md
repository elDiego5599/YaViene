# Ya Viene: Fase 13, E2E automatizado

Fecha: 2026-08-04
Estado: implementada

## Cobertura

El test `YaVieneBackend/tests/e2e.test.ts` levanta un backend real en puertos
aislados y verifica el flujo completo:

```text
provisionamiento admin
  -> login y JWT
  -> Socket.io subscribe:route
  -> simulador MQTT autenticado
  -> bus:position
  -> payload publico sin driverPhone
  -> desconexion MQTT
  -> bus:left
```

## Verificaciones

- Backend listo mediante `/api/ready`.
- Provisionamiento `201`.
- Conexion Socket.io WebSocket.
- Suscripcion a `R-101`.
- Publicacion MQTT con JWT.
- Recepcion de `bus:position`.
- `busId` y `routeId` correctos.
- `sequence` numerico.
- `capturedAt` numerico.
- `driverPhone` ausente del payload publico.
- Desconexion del simulador.
- Recepcion de `bus:left`.
- Limpieza de procesos al terminar.

## Comando

```bash
npm test
```

Resultado actual:

```text
4 tests passed
```

## CI

El test E2E queda incluido en el workflow del backend junto con:

- `npm ci`.
- `npm run build`.
- `npm test`.

## Limitaciones

- No se ejecuta aun contra un telefono Android real.
- No incluye Firebase Phone Auth.
- No incluye cambio de red durante el test.
- No incluye soak Socket.io masivo.
- No incluye certificados TLS reales.

## Criterio De Salida

El flujo critico de backend, MQTT y Socket.io ya tiene una prueba automatizada
reproducible, independiente de ejecucion manual.
