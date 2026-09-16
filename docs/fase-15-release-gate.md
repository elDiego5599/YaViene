# Ya Viene: Fase 15, release gate

Fecha: 2026-08-04
Estado: checklist ejecutado localmente

## Checks De Codigo

- Backend `npm run build`: PASS.
- Backend `npm test`: PASS, 4 tests.
- Backend `npm audit --omit=dev --audit-level=high`: PASS.
- Pasajero `flutter analyze lib`: PASS.
- Core `flutter analyze lib`: PASS.
- Core `flutter test`: PASS.

## Checks De Sistema

- Provisionamiento protegido: PASS.
- Login y JWT: PASS.
- Sesion MQTT: PASS.
- ACK de posicion: PASS.
- Replay historico: PASS.
- Dedupe y orden temporal: PASS.
- Ghost y bus:left: PASS.
- Socket.io E2E: PASS.
- Soak de 20 buses: PASS.
- Readiness: PASS.
- Backup: PASS.
- Shutdown graceful: PASS.
- Foreground service Android: PASS en emulador.

## Checks No Certificados

- Firebase Phone Auth con SMS real.
- GPS continuo en telefono fisico durante horas.
- Cambio de WiFi a datos moviles.
- Reinicio abrupto del proceso Android con outbox pendiente.
- Certificados TLS de produccion.
- Soak de 100 buses y 500 pasajeros.

## Criterio De Release

El sistema queda apto para una beta controlada en red confiable, no para
exposicion publica sin activar TLS, revisar firewall, configurar backups y
validar los checks de dispositivo fisico pendientes.

Los datos de rutas, trayectorias y paradas permanecen fuera de este alcance.
