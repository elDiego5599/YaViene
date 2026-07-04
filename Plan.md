# YA VIENE

## Novedades en esta versión

- Convención de nombres multi-tenant aplicada a **MQTT y WebSocket**, no solo a Postgres.
- Regla de expiración automática de "bus fantasma" mejorada con UX para zonas muertas.
- Modelo de datos mínimo, entidad por entidad.
- Esquema canónico de posición, agnóstico a si el dato viene de un celular (BYOD) o de un GPS dedicado (IoT).
- Geofencing y ETA con tráfico real ubicados en el MVP correcto.
- Buffer offline en la app del conductor.
- **Nueva Sección 9:** Políticas estrictas de Ciberseguridad y Prevención de Fraude.

---

## 1. Estrategia general del producto

El proyecto elimina la incertidumbre del transporte público en Barranquilla con un modelo de transición en dos fases:

- **Fase inicial — Plan A (BYOD):** El celular del conductor envía el GPS. Sirve para validar software, adopción y modelo de negocio con inversión mínima.
- **Fase de escalamiento — Plan B (IoT):** Se migra a dispositivos GPS dedicados (Teltonika/Coban) instalados en la batería del bus, para garantizar estabilidad 24/7 independiente del celular. La app del conductor pasa a ser solo un "control remoto" para iniciar/cerrar turno.

La condición para que esta transición no duela: **el resto del sistema (Redis, WebSocket, PostGIS) nunca debe saber si un dato de posición viene de un celular o de un GPS dedicado.**

---

## 2. Stack tecnológico definitivo

| Capa | Tecnología | Rol |
|---|---|---|
| Apps móviles | Flutter (Dart) + Mapbox SDK | Un solo código base para conductor y pasajero |
| Backend | Node.js | Procesamiento asíncrono de alta concurrencia |
| Ingesta GPS | MQTT | Bajo consumo, resiliente a redes inestables |
| Emisión en tiempo real | WebSockets (Socket.io, con *rooms*) | Evita saturar la red con broadcast global |
| Base de datos principal | PostgreSQL + PostGIS | Rutas, paradas, consultas geoespaciales por radio |
| Caché en memoria | Redis | Posiciones "vivas" segundo a segundo, con TTL |
| Notificaciones push | FCM (Android) + APNs (iOS) | Alertas de "bus cerca". Requiere configurar credenciales tempranas. |
| Fase 2 (Plan B) | GPS dedicado + Gateway | Traduce el protocolo del hardware (TCP) al esquema canónico interno. |

---

## 3. Modelo de datos mínimo

Todo lo que tiene relación con una empresa transportadora lleva `empresa_id`, incluso hoy que solo existe una empresa. 

| Entidad | Campos clave |
|---|---|
| **Empresa** | id, nombre, nit, estado |
| **Bus** | id, empresa_id, placa, capacidad, fuente_gps (`byod` \| `iot`) |
| **Conductor** | id, empresa_id, cédula, pin_hash, estado |
| **Ruta** | id, empresa_id, nombre, sentido (`ida` \| `vuelta`), trazado (PostGIS LineString) |
| **Parada** | id, ruta_id, nombre, ubicación (PostGIS Point), orden |
| **Turno** | id, conductor_id, bus_id, ruta_id, fecha, hora_inicio, hora_fin, estado |
| **Posición** (Redis) | empresa_id, bus_id, lat, lon, heading, velocidad, timestamp, fuente |
| **Posición histórica** | igual a la anterior + turno_id — para analítica en MVP 2 |
| **Suscripción de alerta**| id, dispositivo/usuario, bus_id, radio_m, estado (activa/disparada) |

---

## 4. Convenciones de nombres multi-tenant (clave)

El día que dos empresas tengan una ruta con el mismo nombre, sus buses no deben mezclarse en el mismo canal de comunicación. La lógica de la base de datos se replica en los canales:

| Canal | Convención | Ejemplo |
|---|---|---|
| Topic MQTT (conductor → backend) | `empresa/{empresa_id}/bus/{bus_id}/posicion` | `empresa/7/bus/040/posicion` |
| Key Redis (posición viva) | `pos:{empresa_id}:{bus_id}` | `pos:7:040` |
| Room WebSocket (backend → pasajero)| `{empresa_id}:{ruta_id}:{sentido}` | `7:101:ida` |

---

## 5. Lógica core y reglas de negocio

### A. Asignación dinámica (Triangulación)
El conductor se identifica (cédula + PIN), elige el bus que maneja hoy y la ruta que cubre. 
**Manejo de conflictos:** Si un segundo conductor intenta tomar un bus que ya tiene un turno activo, el sistema rechaza el intento con un mensaje ("Bus ya asignado"). El turno se libera automáticamente si expira por inactividad o cierre manual.

### B. Expiración, Zonas Muertas y "Bus Fantasma"
Si un bus entra a un túnel (pierde 4G) o el conductor se lleva el celular a su casa sin cerrar turno, el sistema se autolimpia usando el TTL (Time To Live) nativo de Redis:
- Cada posición se guarda en Redis con un **TTL de 4 a 5 minutos**.
- **Regla de UX (Frontend):** Si la última posición recibida tiene más de 90 segundos de antigüedad, el mapa del pasajero cambia el ícono del bus a **color gris** (indicando "Señal débil").
- Si pasan los 5 minutos sin un nuevo ping, la key expira sola en Redis y el bus desaparece del mapa sin necesidad de usar CRON Jobs.

### C. Manejo de dirección (Ida/Vuelta)
- Cada ruta física se modela como dos registros: Ruta 101 (Ida) y Ruta 102 (Vuelta).
- El frontend lee la variable `heading` (0-360°) para rotar el ícono del bus en el mapa.

### D. Alertas inteligentes
El pasajero filtra ruta y sentido. El pasajero toca un bus específico y activa "Avísame cuando esté cerca". El backend dispara un Push cuando PostGIS detecta que el bus entró en el radio de 2km (Distancia euclidiana en MVP 1; distancias por vías reales en MVP 2).

### E. Geofencing de zonas muertas (Nevadas/Terminales)
Se dibujan cercas virtuales alrededor de las terminales. Si un bus entra a la nevada, se oculta automáticamente del mapa público. **(Asignado al MVP 2)**.

### F. Esquema canónico de posición
Toda posición (BYOD o IoT) se normaliza al mismo esquema interno antes de entrar al pipeline: `{ empresa_id, bus_id, lat, lon, heading, velocidad, timestamp, fuente }`.

### G. Foreground Service (Android)
La app del conductor debe correr como servicio en primer plano para evitar que el sistema operativo apague el GPS cuando se apaga la pantalla. 

### H. Resiliencia Offline (Buffer local)
En el MVP 1, la app del conductor contará con una base de datos local (SQLite). Si el celular pierde conectividad de datos móviles, las coordenadas generadas se encolan con su timestamp original. Al recuperar el 4G, se envían en ráfaga (burst) al broker MQTT.

---

## 6. Infraestructura y escala

- **Arquitectura Lean:** Para 50 buses iniciales, una instancia gestionada de Postgres (RDS/Cloud SQL), Redis gestionado y un broker MQTT en un solo contenedor es suficiente. Kubernetes es sobre-ingeniería para la fase piloto.
- **Cálculo de ETA:** El ETA se calcula periódicamente por bus y se cachea en Redis. Jamás se calcula bajo demanda por cada pasajero que abre el mapa.
- **Privacidad:** El tracking continuo del celular personal del conductor requiere consentimiento explícito (Ley 1581 de 2012 — Habeas Data en Colombia).

---

## 7. Consideraciones de Seguridad y Prevención de Fraude (Blindaje)

El ecosistema opera bajo el principio de "Zero Trust" (Cero Confianza). El backend no confía ciegamente en las aplicaciones clientes.

**A. Prevención de GPS Spoofing (App Conductor)**
- *Riesgo:* Conductor usando apps de "Fake GPS" para simular que está trabajando.
- *Solución:* Flutter verificará la bandera `isMockLocation` nativa del SO. Si detecta simulación, bloquea la transmisión de inmediato y lanza una bandera roja de fraude al panel de despacho.

**B. Autorización Estricta en MQTT (Ingesta)**
- *Riesgo:* Inyección masiva de coordenadas falsas adivinando los topics MQTT.
- *Solución:* El broker MQTT (ej. EMQX) utilizará ACLs (Access Control Lists) alimentadas por JWT. El token de un conductor únicamente le otorga permiso de `PUBLISH` sobre el topic específico del bus que acaba de asignarse.

**C. Prevención de IDOR (Panel B2B)**
- *Riesgo:* Un operador de una empresa consultando datos de la competencia manipulando parámetros en la URL.
- *Solución:* El backend extrae el `empresa_id` directamente del token criptográfico de sesión del usuario, ignorando cualquier `empresa_id` enviado en el body o query param.

**D. Rate Limiting y Abuso de WebSockets**
- *Riesgo:* Ataques DDoS de múltiples conexiones al servidor de WebSockets.
- *Solución:* Los WebSockets hacia los pasajeros son estrictamente de *Solo Lectura* (Read-Only). Si un cliente conectado intenta inyectar datos por WebSocket hacia el backend, la conexión se cierra permanentemente.

---

## 8. Hoja de ruta de desarrollo (4 MVPs)

### MVP 0 — Prueba de estrés técnico (≈2 semanas)
**Qué construir:** Script Node.js básico, broker MQTT, app Flutter cruda (un botón). Sin base de datos.
**Objetivo:** Confirmar que el Foreground Service en Android aguanta 8 horas enviando MQTT con la pantalla apagada. Criterio de éxito: Medición de consumo real de batería en un Android de gama económica.

### MVP 1 — Piloto de campo (1 a 3 rutas, una empresa ancla)
**Qué construir:** Apps completas; Postgres con `empresa_id`; TTL + Íconos grises (z. muertas); Buffer Offline; Alertas Push. 
**Objetivo:** Pasajeros reales usando la app.

### MVP 2 — Operación completa para la empresa ancla (~50 buses)
**Qué construir:** Panel web de despacho; Geofencing en nevadas; ETA con tráfico real.
**Objetivo:** Operación sin interrupciones y dashboard comercial para ofrecer a la siguiente empresa.

### MVP 3 — Escalamiento y SaaS (multiempresa + Plan B)
**Qué construir:** Multi-tenant total en UI; Gateway TCP a MQTT para los primeros equipos IoT instalados en los buses.
**Objetivo:** Onboarding de nuevas empresas en horas.

---

## 9. Próximo paso inmediato

Arrancar exclusivamente con el **MVP 0**. Levantar servidor MQTT local, programar captura GPS en background en Flutter, instalar en un teléfono Android económico y realizar trabajo de campo trazando rutas por Barranquilla. Validar batería y latencia de ingesta antes de avanzar con interfaces gráficas.
