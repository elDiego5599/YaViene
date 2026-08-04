# Ya Viene: Fase 0, linea base tecnica

Fecha de corte: 2026-08-04

## Proposito

Este documento congela el estado conocido del proyecto antes de comenzar las
correcciones de seguridad, confiabilidad, ciclo de vida, background y
rendimiento. No representa que el sistema este listo para produccion.

La linea base sirve para comparar cada fase posterior contra resultados
reproducibles y evitar mezclar regresiones con problemas preexistentes.

## Repositorios

El proyecto esta dividido en dos repositorios Git:

| Repositorio | Rama | Remoto |
|---|---|---|
| YaViene | main | `https://github.com/elDiego5599/YaViene.git` |
| YaVieneBackend | main | `https://github.com/elDiego5599/YaVieneBackend.git` |

El repositorio principal estaba alineado con `origin/main` antes de agregar
este documento.

El backend tambien estaba alineado con `origin/main`, pero tenia cambios
locales previos de SQLite y dependencias pendientes de publicar. Esos cambios
se auditan y se publican por separado del checkpoint documental de Fase 0.

## Entorno Verificado

| Herramienta | Version |
|---|---|
| Node.js | `v22.20.0` |
| npm | `10.9.3` |
| Flutter | `3.44.4 stable` |
| Dart | `3.12.2` |
| Plataforma | macOS arm64 |

## Estructura Confirmada

| Componente | Ubicacion |
|---|---|
| App conductor | `app_conductor/` |
| App pasajero | `app_pasajero/` |
| Core compartido | `ya_viene_core/` |
| Backend | `../YaVieneBackend/` |
| Simulador MQTT | `YaVieneBackend/scripts/simulate-bus.mjs` |

## Puertos Y Configuracion

| Servicio | Direccion local | Funcion |
|---|---|---|
| HTTP REST | `0.0.0.0:3000` | Registro, consultas y comandos |
| Socket.io | `0.0.0.0:3000/ws` | Posiciones para pasajeros |
| MQTT TCP | `0.0.0.0:8883` | GPS de conductores |

Para pruebas en telefono fisico, `BACKEND_URL` debe apuntar a la IP WiFi del
Mac. Para el emulador Android se utiliza `10.0.2.2`.

## Validaciones Estaticas

| Componente | Comando | Resultado |
|---|---|---|
| Backend | `npm run build` | PASS |
| Backend | `npx tsc --noEmit` | PASS |
| Conductor | `flutter analyze lib` | PASS, 0 issues |
| Pasajero | `flutter analyze lib` | PASS, 0 issues |
| Core | `flutter analyze lib` | PASS, 0 issues |
| Conductor | `flutter test` | PASS, 1 test |
| Core | `flutter test` | No existe directorio `test/` |
| Backend | Tests automatizados | No existen |
| Pasajero | Tests automatizados | No existe una suite significativa |

El comando `flutter analyze` completo del pasajero tambien inspecciona
artefactos generados bajo `build/macos` y reporta miles de errores externos.
El analisis de `lib/` queda limpio; la higiene de artefactos generados debe
corregirse en una fase posterior.

## Smoke Test Ejecutado

El backend fue iniciado desde cero y se verifico el siguiente flujo:

1. `GET /api/health` respondio `200` con estado `ok`.
2. `POST /api/drivers/register` creo un conductor de prueba y devolvio JWT.
3. `POST /api/gps` inserto una posicion.
4. `GET /api/buses/B-PHASE0` devolvio la posicion persistida.
5. `scripts/simulate-bus.mjs` se registro por HTTP.
6. El simulador se autentico en MQTT con JWT.
7. MQTT autorizo el topic `empresa/EMP-01/bus/B-042/posicion`.
8. El backend guardo la posicion MQTT y la hizo consultable por REST.
9. Al desconectar MQTT, el backend elimino `B-042`.
10. La consulta posterior devolvio `404`, confirmando la remocion.

## Resultado De La Linea MQTT

Se observaron estos eventos esperados:

```text
[MQTT] Auth OK: 3000000000 (bus B-042)
[MQTT] authorizePublish: ... expected=empresa/EMP-01/bus/B-042/posicion
[MQTT] publish event: ... topic=empresa/EMP-01/bus/B-042/posicion
[MQTT] Disconnect: 3000000000 (bus B-042)
[MQTT] Bus B-042 removido por desconexion
```

La primera posicion MQTT fue aceptada. El simulador completo no se considera
una prueba de trayectoria valida porque sus waypoints estan demasiado
separados para el intervalo de publicacion de dos segundos y el sanity check
rechaza velocidades imposibles.

## Base De Datos Observada

El backend usa SQLite con:

- `better-sqlite3`.
- Timestamps INTEGER en epoch milisegundos.
- `journal_mode = WAL`.
- Tabla `drivers`.
- Tabla `positions`.
- Indice por `timestamp`.
- Indice por `route_id`.
- Upsert por `bus_id`.
- `DELETE ... RETURNING` para obtener buses removidos.

La Fase 0 no certifica aun que las foreign keys esten activas, que existan
migraciones, que el sweep sea transaccional o que el buffer offline sea
durable de extremo a extremo. Esos puntos forman parte de fases posteriores.

## Hallazgos Confirmados Que Se Conservan Como Riesgos

Estos riesgos no se corrigen dentro de Fase 0 para mantener el checkpoint
limpio:

- Rutas mutables HTTP sin una capa completa de autorizacion.
- El handler MQTT usa datos de identidad enviados en el payload.
- El buffer offline guarda posiciones online y puede reproducirlas en rafaga.
- La sincronizacion offline puede limpiar filas nuevas y no espera ACK real.
- El servicio background esta configurado, pero no contiene el pipeline GPS/MQTT.
- El pasajero no restaura automaticamente sus rooms despues de reconectar.
- Las rutas, empresas, trayectorias y paradas siguen siendo parcialmente mock.
- Los timeouts de ghost y removal tienen multiples fuentes de verdad.
- La UI del mapa calcula ghost localmente en vez de respetar completamente el
  estado enviado por backend.
- No hay suite automatizada del backend, pasajero ni core.
- `npm audit --omit=dev` reporta 7 vulnerabilidades productivas: 3 altas,
  3 moderadas y 1 baja.

## Lo Que No Se Verifico En Esta Fase

- Prueba real de Firebase Phone Auth con SMS.
- Tracking con pantalla bloqueada durante un periodo prolongado.
- Reinicio del proceso Android durante una transmision.
- Cambio de WiFi a datos moviles.
- Carga con multiples buses y pasajeros.
- Recuperacion ante corrupcion de SQLite.
- Restauracion desde backup.
- Seguridad contra ataques de payload, replay o suplantacion.
- Despliegue con HTTPS, WSS o MQTTS.
- Recepcion real de Socket.io en un APK pasajero durante este checkpoint.

## Criterio Para Comenzar Fase 1

La Fase 0 queda cerrada cuando:

- Este documento esta versionado.
- El resultado de los analizadores esta registrado.
- El smoke test es reproducible.
- Los riesgos conocidos estan enumerados.
- No se confunde compilacion exitosa con seguridad o produccion.

La siguiente fase debe ser Fase 1: contratos, identidad y reglas formales del
sistema. No se debe comenzar optimizacion ni agregar nueva infraestructura
antes de cerrar autenticacion y entrega confiable de posiciones.
