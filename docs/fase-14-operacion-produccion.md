# Ya Viene: Fase 14, operacion y produccion

Fecha: 2026-08-04
Estado: implementada y validada localmente

## Cambios Operativos

- Shutdown graceful para SIGTERM y SIGINT.
- Cierre ordenado de Socket.io, broker MQTT, HTTP y SQLite.
- Sweep y limpieza de sesiones cancelables.
- Limpieza periodica de sesiones revocadas antiguas.
- `/api/health` para liveness.
- `/api/ready` para readiness de SQLite y MQTT.
- Migraciones SQLite versionadas en `schema_migrations`.
- Backup SQLite mediante `npm run backup -- /ruta/backup.db`.
- Soporte configurable para HTTPS, WSS y MQTTS.
- Rate limiting de login y provisionamiento.
- Auditoria npm sin vulnerabilidades reportadas.

## Backup

```bash
npm run backup -- /var/backups/yaviene-$(date +%s).db
```

El backup debe copiarse fuera del host y probarse con restauraciones reales.

## TLS

El backend activa TLS cuando se configuran simultaneamente:

```text
HTTP_TLS_CERT_PATH
HTTP_TLS_KEY_PATH
MQTT_TLS_CERT_PATH
MQTT_TLS_KEY_PATH
```

El modo local continua siendo HTTP/MQTT sin TLS. Produccion no debe arrancar
sin certificados y secretos provistos por el entorno.

## Validaciones

- Readiness con DB y broker: `200`.
- Backup creado y abierto correctamente por SQLite.
- Shutdown reporta `Shutting down from SIGTERM`.
- Migraciones aplicadas sin perder registros existentes.
- `npm audit --omit=dev --audit-level=high`: PASS.
- E2E: PASS.
- Tests unitarios: PASS.

## Limitaciones

- No se desplego aun en un servidor publico.
- No se validaron certificados de una CA real.
- No existe alta disponibilidad.
- SQLite sigue siendo single-node.
- Los backups requieren automatizacion externa y politica de retencion.

## Alcance Excluido

No se agregan trayectorias, paradas ni catalogos dinamicos.
