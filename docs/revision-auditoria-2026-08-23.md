# Ya Viene: revisión de la auditoría externa

Fecha: 2026-08-23
Alcance: los tres repos —`YaVieneBackend`, `YaViene` (monorepo Flutter) y
`YaVieneWeb` (landing)— contrastados contra el informe recibido.

## Resumen

El informe acierta en casi todo lo que señala del backend y del pasajero,
y las notas altas están bien puestas. Falla en tres cosas que sí se
pueden comprobar en el repo y que le bajan valor al resto: dice que no
hay pipeline de Flutter (lo hay), que faltan READMEs (están los cuatro) y
que `widget_test.dart` vacío significa que la app no tiene pruebas
(tiene 18 archivos y 2.893 líneas de test). También da por muertas unas
dependencias que sí se usan.

Con eso corregido, la nota global 7,6 se queda corta en proceso y sobra
un poco en la landing. Lo de abajo es punto por punto, con archivo y
línea, y al final el orden en que conviene atacarlo.

---

## 1. Backend — el informe da 8,5

### Lo que confirma el código

**El limitador de peticiones no vacía nunca su mapa.**
`src/security/rate_limiter.ts:9` — `entries` es un `Map` que sólo crece:
`allow()` escribe una entrada por clave y no hay ningún barrido. Las
claves son `ip:sufijo`, así que el techo es «direcciones distintas que
hayan intentado entrar desde que arrancó el proceso». No revienta en una
tarde, pero en un proceso de semanas es memoria que no vuelve.

**Y es de ventana fija, con el doble de ráfaga en el borde.**
Mismo archivo, `allow()` reinicia la ventana entera cuando pasa
`windowMs`. Con 5 intentos por minuto, quien pida 5 en el segundo 59 y 5
en el 61 mete 10 en dos segundos. Para el login de la app da igual; para
`adminRateLimiter` (20/min, `routes.ts:201`, `583`, `663`) ya no tanto.

**El outbox reintenta sin techo.**
`src/data/lifecycle_events.ts:73-91` — `dispatchLifecycleEvents` marca
`claimed_at = NULL` y guarda `last_error` cuando el `emit` falla, y ahí
se acaba. `attempts` se incrementa (`:56`) pero nadie lo lee para
rendirse. Un evento que falle siempre —payload corrupto, ruta que ya no
existe— se reclama, falla y vuelve a la cola, en bucle, ocupando sitio en
los 100 que se reclaman por vuelta. Falta un máximo de intentos y una
tabla de muertos.

**CORS abierto en dos sitios.**
`src/index.ts:61` (`Access-Control-Allow-Origin: *`) y
`src/socket/handler.ts:81` (`cors: { origin: '*' }`). Dos declaraciones
distintas del mismo permiso, las dos en `*`, y ninguna de las dos apunta
a un origen concreto.

**Las lecturas públicas no pasan por el limitador.**
En `src/api/routes.ts` el limitador aparece 10 veces y todas son sobre
escrituras o logins (`:201`, `:243`, `:302`, `:395`, `:445`, `:482`,
`:583`, `:611`, `:663`). Los GET que sirven buses y rutas —los que va a
llamar la app cada pocos segundos y los que están abiertos a internet—
no tienen nada delante.

**`any` en el broker.**
`src/mqtt/broker.ts:110` (`const broker: any = new aedes()`), y con él
`:43`, `:79` y los dos callbacks de `:26` y `:30`. Es el único módulo del
backend donde el tipado se rinde del todo.

**`buses.ts` con 939 líneas.**
Confirmado: es el archivo más grande del backend con diferencia
(`routes.ts` va segundo con 788; el resto no pasa de 476).

**Métricas en memoria.**
`src/observability/metrics.ts` son dos `Map` de módulo. Al reiniciar el
proceso se pierde todo y con más de una instancia cada una cuenta la
suya. Para el piloto vale; para hablar de disponibilidad con una empresa,
no.

### Donde el informe se pasa de frenada

**«`routeNameMap` duplicado 3 veces».** No: está definido una vez
(`src/data/buses.ts:366`) y usado como respaldo en dos sitios (`:426` y
`:482`). Es un respaldo repetido, no un mapa duplicado. Merece
extraerse, pero no es lo que dice el informe.

### Lo que el informe no mira y sí importa

- **La confianza en `X-Forwarded-For` está bien resuelta**
  (`rate_limiter.ts:36-47`): sólo se hace caso a la cabecera si la
  conexión TCP viene de loopback, y se toma el último salto. Es
  exactamente lo que hay que hacer y el informe no lo menciona.
- Hay CI de backend con `npm audit --audit-level=high` en cada push
  (`.github/workflows/ci.yml`), y cinco suites de test —`chaos`,
  `security`, `e2e`, `fleet`, `property`—. El informe lo da por bueno de
  pasada; es de lo mejor que tiene el proyecto.

**Nota justa: 8,5.** Coincido.

---

## 2. App del pasajero — el informe da 7,0

### Lo que confirma el código

**Los tres archivos gordos, tal cual los cuenta.**
`map_widget.dart` 1.037, `route_selector_sheet.dart` 958,
`eta_bottom_sheet.dart` 808. Detrás vienen `login_screen.dart` (759) y
`premium_drawer.dart` (624). De 10.060 líneas de `lib`, casi la tercera
parte está en tres widgets.

**Firma de release con las llaves de depuración.**
`android/app/build.gradle.kts:31-34`, con el TODO de la plantilla intacto.
Un APK así no se puede subir a Play y, si se reparte a mano, cualquiera
puede firmar una actualización.

**`applicationId = "com.example.ya_viene_pasajero"`.**
Misma plantilla, `build.gradle.kts:21`. Cambiarlo después de publicar es
imposible: es la identidad de la app en la tienda.

**`usesCleartextTraffic="true"` global.**
`android/app/src/main/AndroidManifest.xml:13`. Habilita HTTP sin cifrar
para toda la app, no sólo para el backend local. Se arregla con un
`network_security_config.xml` que permita el claro sólo en desarrollo.

**El respaldo silencioso a localhost.**
`lib/config.dart:2-5` — si nadie pasa `BACKEND_URL`, la app compila
apuntando a `http://localhost:3000` y falla en el teléfono sin decir por
qué. Una compilación de release debería negarse a construirse sin esa
variable.

### Donde el informe se equivoca

**«`widget_test.dart` vacío» no es «no hay pruebas».**
Es verdad que `test/widget_test.dart` tiene 6 líneas y el cuerpo del
`testWidgets` está vacío —hay que borrarlo o llenarlo—. Pero al lado hay
18 archivos de prueba y 2.893 líneas: `proximity_alerts_test.dart` (291),
`realtime_state_test.dart` (274), `eta_bottom_sheet_test.dart` (237),
`map_tour_test.dart` (407)… Justo las partes que el informe elogia están
cubiertas. Presentarlo como un vacío de pruebas es el error más grave del
documento.

**Las dependencias muertas no son las que dice.**
Buscadas en `lib/`: `sqflite` 0 usos, `cached_network_image` 0, `logger`
0 → ésas sí sobran. Pero `dio` aparece en 7 archivos y `path` en 2: están
vivas. Y `riverpod_generator`/`build_runner` son de desarrollo, no de
producción; sobran igual si no hay anotaciones que generar, pero no pesan
en el APK.

**`flutter_lints ^4`** con SDK `>=3.3.0` (`pubspec.yaml:7`, `:64`): la
observación es correcta, pero es una línea de mantenimiento, no un
defecto de calidad.

### Lo que el informe acierta al elogiar

La histéresis documentada de las alertas (`alertReArmMeters` 1500 sobre
`alertRadiusMeters` 1000), el `BusNearNotifier` inyectable, el
`disconnect()` que no es `dispose()` y la reconexión en dos capas. Eso es
código pensado, no código escrito rápido.

**Nota justa: 7,0**, pero por los archivos gordos y por el empaquetado de
Android, no por falta de pruebas.

---

## 3. Landing — el informe da 7,5

### Lo que confirma el repo

**Cero pruebas y cero CI.** `YaVieneWeb` no tiene `.github/`, y
`package.json` sólo trae `dev`, `build`, `preview`, `typecheck` y
`mapa`. La única red es `tsc --noEmit` dentro de `build`. Es el repo con
menos red de los tres, y encima es el único que ve un cliente antes de
firmar.

**La landing vieja sigue versionada.** `YaViene/landing/` está en git
(`landing/index.html`, `landing/js/`, `landing/css/`) y es la versión
anterior a Vite. Dos landings en dos repos: la que se despliega y una
copia muerta que confunde a cualquiera que llegue.

**El número de WhatsApp, a mano en todas partes.** 7 apariciones de
`573004438626` en 5 archivos (`index.html`, `404.html`,
`privacidad.html`, `terminos.html`, `src/contact-form.ts`). En HTML
estático no hay forma limpia de tener una constante sin plantillas, pero
sí de generar los cuatro HTML desde el mismo dato.

**Sin analítica.** Cierto. Y sin ella no se sabe cuánta gente llega al
formulario ni cuánta se cae en el camino, que es justo lo que hay que
saber para vender.

### Donde matizo

El informe elogia la modularización y la honestidad de `contact-form.ts`
—endpoint real o `wa.me`, ventana bloqueada contemplada, doble envío
bloqueado, `finally`—, y tiene razón. Pero le da 7,5 a una pieza sin una
sola prueba automática. Con lo que se le exige al backend, la landing
está por debajo: **7,0** es más justo.

---

## 4. Proceso — el informe da 6,5

Aquí el informe se equivoca dos veces seguidas:

**«No hay pipeline de Flutter».** Sí lo hay:
`.github/workflows/ci.yml` en el monorepo corre en cada push y PR a
`main` y hace `flutter analyze` + `flutter test` sobre `ya_viene_core`,
`app_conductor`, `app_pasajero` (con `analyze lib test`) y `app_control`.

**«Falta README».** Están los cuatro: `app_conductor/README.md`,
`app_control/README.md`, `app_pasajero/README.md` y
`ya_viene_core/README.md`, más el del monorepo.

Lo que sí es verdad:

- **`AGENTS.md` pesa 40 KB.** Un documento que nadie lee entero es un
  documento que no existe. Debería quedarse en lo que no está en el
  código y repartir el resto por los repos.
- **Factor bus = 1.** Con `docs/` en 18 fases y los READMEs puestos, el
  riesgo es menor de lo que parece, pero sigue siendo un solo par de
  manos.

**Nota justa: 7,5.** Con CI en dos repos, 18 documentos de fase, cinco
suites en el backend y 18 archivos de test en el pasajero, un 6,5 no se
sostiene.

---

## 5. Nota global

| Área | Informe | Revisada | Por qué |
|---|---|---|---|
| Backend | 8,5 | 8,5 | Coincide |
| App pasajero | 7,0 | 7,0 | Coincide la nota, no el motivo |
| Landing | 7,5 | 7,0 | Sin pruebas ni CI |
| Proceso | 6,5 | 7,5 | Sí hay CI de Flutter y sí hay READMEs |
| **Global** | **7,6** | **7,6** | Se compensan |

Mismo número, distinto reparto. Y el reparto es lo que dice qué tocar.

---

## 6. Qué hacer, en orden

**Antes de enseñarle esto a una empresa**

1. Firmar el release del pasajero con una llave propia y cambiar el
   `applicationId` (`build.gradle.kts:21`, `:31-34`). Después de publicar
   ya no se puede.
2. Quitar `usesCleartextTraffic` global y dejarlo sólo en desarrollo con
   un `network_security_config.xml`.
3. Que una compilación de release sin `BACKEND_URL` falle en vez de
   apuntar a localhost (`config.dart:2-5`).

**La semana siguiente**

4. Barrer el mapa del limitador y pasarlo a ventana deslizante
   (`rate_limiter.ts`).
5. Máximo de intentos y tabla de muertos en el outbox
   (`lifecycle_events.ts:73-91`).
6. Un origen concreto en los dos CORS (`index.ts:61`,
   `socket/handler.ts:81`) y limitador también en las lecturas públicas.
7. Borrar `YaViene/landing/`. Una landing, un repo.

**Cuando haya aire**

8. Partir `map_widget.dart`, `route_selector_sheet.dart` y
   `eta_bottom_sheet.dart`: sacar la orquestación del `State` a
   providers, que es donde ya está el resto.
9. Quitar `sqflite`, `cached_network_image` y `logger` del `pubspec`, y
   borrar o llenar `test/widget_test.dart`.
10. CI para la landing: `tsc --noEmit`, `vite build` y cuatro pruebas de
    humo sobre `contact-form.ts`.
11. Tipar el broker (`broker.ts`) y partir `buses.ts`.
12. Analítica en la landing y métricas persistidas en el backend.
