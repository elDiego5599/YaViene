# Ya Viene: Fases 4 a 6

Fecha: 2026-08-04
Estado: implementadas con validacion automatizada y limites de campo

## Fase 4: Identidad Y Asignaciones

Se agregaron mediante migracion no destructiva:

- `buses`.
- `turn_assignments`.
- Indice de una asignacion activa por bus.
- Indice de una asignacion activa por conductor.
- Indice por ruta y estado.

El provisionamiento ahora:

- Conserva `driverId` estable para un telefono existente.
- Crea o actualiza el bus asociado.
- Cierra asignaciones activas anteriores.
- Crea una asignacion operativa nueva.

El cierre de turno finaliza la asignacion correspondiente.

No se agregaron trayectorias ni paradas.

La semantica `ida/vuelta` no se inventa desde una coordenada aislada. El GPS
conserva rumbo, velocidad, captura y secuencia; una clasificacion futura debe
permitir `unknown` cuando no exista suficiente evidencia.

## Fase 5: Campo Y Resiliencia

La infraestructura de background, ACK y outbox ya fue validada en emulador:

- Foreground service activo.
- Notification channel valido.
- Permisos de notificacion y ubicacion.
- Servicio permanece activo al enviar app a background.
- APK debug y release compilados.

La validacion con GPS real durante horas y cambio de red en telefono fisico
queda como prueba de campo, no como simulacion automatica.

## Fase 6: Pasajero Y MapLibre

- Manejo explicito de `connect_error` y `error` de Socket.io.
- Filtrado por ruta.
- Resuscripcion despues de reconexion.
- Coalescing visual de 200 ms.
- Ghost proveniente exclusivamente del backend.
- Sin dependencia de trayectorias o paradas dinamicas.

## Verificaciones

- Backend build: PASS.
- Backend E2E: PASS.
- Backend tests: PASS.
- Conductor analyzer/test: PASS.
- Pasajero analyzer: PASS.
- Core analyzer/test: PASS.

## Limites Declarados

- El GPS no puede afirmar `ida/vuelta` con certeza sin una politica de
  inferencia y evidencia suficiente.
- Los datos estaticos de presentacion no son autoridad de validacion del bus.
- La prueba de campo fisica sigue siendo obligatoria antes del piloto.
