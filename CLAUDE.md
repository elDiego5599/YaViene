# YaViene — CLAUDE

Este proyecto usa las skills de `mattpocock/skills` para estandarizar el flujo con Claude.

## Skills activas
- `grill-me` — interroga casos borde antes de codear. Invoca con `/grill-me` al planificar una feature grande.
- `to-spec` / `to-tickets` — planifica features complejas (spec → tickets).
- `code-review` — audita calidad y rendimiento.

## Flujo
1. Para feature grande de **YA VIENE**, inicia con `/grill-me`.
2. Luego usa `to-spec` y `to-tickets` para planificar.
3. Implementa y cierra con `code-review`.

Skills instaladas en `.claude/skills/` (copia de `mattpocock/skills`). Ver `npx skills list` para todas.

## Vara de calidad (decisión del dueño, 2026-09-27)
Calidad de producción siempre. Que el entorno sea de prueba (ramas `prueba`,
flota simulada, ngrok, pitch) no rebaja ninguna tarea, no justifica atajos y
no deja nada a medias: cada tarea se cierra entera, con su prueba roja→verde,
o no se marca ☑. El plan usa `[YA]`, `[BLOQUEADA: X]`, `[DUEÑO]`,
`[FECHA: pitch]` y `[CONTINUO]` (ver su §0.4). Lo honesto se queda: la
etiqueta «Simulación», la flota demo y `empty-pick-bus`.

## Estado (al 2026-10-01)

**Tres documentos en la raíz del workspace (fuera de los repos), los tres
para leer al arrancar en frío**: `/Users/diegoangarita/YaViene/plan-remediacion.md`
(el plan de remediación: tablero en su §0.6, qué hacer en su §15),
`reporte-auditoria-2026-09-25.md` (la auditoría que ordena el plan; la
revisión del 2026-09-27 está en `reporte-auditoria-2026-09-27.md` y su
lista de re-verificación por lotes en `reverificacion-lotes.md`) e
`inventario-estados.md` (los estados vacíos/error de los 3 productos,
T6.7). La evidencia congelada de tareas cerradas y los prompts de proceso
(prompt de la auditoría, inventario J) viven en `archivo/`. El estado
diario y las reglas de trabajo están en `AGENTS.md`.

- **NO es monorepo**: `YaViene/YaViene` (Flutter, rama `diseno-21st`),
  `YaVieneBackend` (rama `prueba`), `YaVieneWeb` (rama `diseno-21st`). Remotos
  `elDiego5599/*`. Nunca usar el backend duplicado
  `/Users/diegoangarita/YaVieneBackend`.
- **`main` al día en el remoto** (2026-10-01): app `05c5d79`, web `6e7f63d`
  y backend `ad5254a` (más el commit de este `CLAUDE.md` encima), los tres
  por avance rápido desde `diseno-21st` / `prueba`. Traen T5.6 (texto
  grande y giro), T6.8 (glosario), T7.7 (Lighthouse móvil en presupuesto,
  web), T7.1 en su parte web y con los números del backend, T10.5 b y d
  (simulacros contra un backend temporal, `tool/simulacros.sh`, y
  `zonaSocket()` en core) y T10.3 (`check-demo.sh` por grupos). Antes
  (2026-09-29, tarde): app `ed52e56`, web `572be9c` y backend `f62d3b1`,
  con la revisión del 2026-09-29 (`reporte-revision-2026-09-29.md`): P1-2 sin
  falso verde y la suite inmune a `YA_VIENE_EXPUESTO`/`NODE_ENV` (backend),
  `start-test.sh` borrado, responsable y derechos de la Ley 1581 en la
  privacidad (web y app, sin subir `kLegalVersion`) con la autorización
  del formulario de empresas, ACC-01 (el lector anuncia la ruta) y las dos
  E2E inestables arregladas. Antes, la misma mañana: app `74bf864`, web
  `33338f9` y backend `1171b57` (ronda «auditoría 2026-09» de la nube y
  privacidad v3). Antes (2026-09-28): app `99c0a07`, web `6acb895` y backend `a1fc70f`. Los 21 archivos sueltos del backend eran
  T3.4 + T9.3 y las pruebas R-05/06/07 del lote 3, cerradas en el plan pero
  nunca commiteadas: revisadas (200/200, también con la siembra en 0; 8
  rojas con el `src` viejo) y subidas (`83a93f1`, `1055885`, `a1fc70f`).
  Este `CLAUDE.md` vuelve a estar versionado en `main` (dueño,
  2026-09-29) para que las sesiones en la nube lean las reglas; no lleva
  secretos ni valores de cuentas, y así se queda.
- **Verificación (2026-10-02)**: **1.567 pruebas** en total
  (1.534 pasan + 33 saltadas: 29 de Playwright y los 3 simulacros, que
  corren con `tool/simulacros.sh`), contando las 11 de `ya_viene_pruebas`; aparte,
  las 50 de `npm run test:aforo` (Python; 6 se saltan sin torch). Web:
  `npm run typecheck` limpio (3 configs), **301 en Vitest** y el trinquete de
  cobertura 98 / 90 / 100 / 99 (`vite.config.ts`) **en verde** con
  98,8 / 92,1 / 100 / 99,9 (estuvo en rojo desde `33338f9` hasta el
  2026-09-30: `npm test` no lo mide, `npm run test:cobertura` sí); Playwright **153 pasadas + 29 saltadas**
  (estables: `movimiento.spec.ts` y `isla.spec.ts` pasaron 40 de 40 con 5
  hilos); presupuestos dist
  770,4/797 (**97 %**), JavaScript 59,1/66 (90 %), CSS 117,8/121 (**97 %**) y
  primera visita 463,4/560 (83 %) — dist y CSS casi sin margen: todo cambio web
  mide antes de sumar. Antes de correr Playwright, matar el puerto:
  `lsof -ti tcp:4174 | xargs -r kill -9` — un servidor viejo sirve una
  build vieja y las pruebas mienten.
- **Lighthouse móvil** (T7.7, 2026-10-01, a mano: `@lhci/cli` no entra
  al repo, falla `npm audit`): portada LCP 2,26–2,41 s, empresas 2,18,
  privacidad y términos 1,65; CLS 0, TBT ≤ 35 ms. `e2e/vitales.spec.ts`
  vigila el marcado que lo hace posible.
- **Backend**: 245 pruebas en verde (2026-10-01; también con `YA_VIENE_SEED_DEMO=0`, `YA_VIENE_EXPUESTO=1` o `NODE_ENV=production` en el entorno: `tests/entorno.ts` fija la siembra y borra las dos guardias) con `npm test`, `npx tsc --noEmit`
  limpio. Las pruebas usan bases temporales y puertos propios; el backend
  vivo y ngrok no se tocan.
- **Documentación del backend** en `YaVieneBackend/docs/`: `arquitectura.md`
  (por dónde pasa una posición), `integracion-gps.md` (el contrato del equipo
  del bus), `runbook.md` (qué hacer cuando algo se cae) y `decisiones/` (D1–D12
  con índice). `tests/doc_gps.test.ts` y `tests/docs_enlaces.test.ts` las atan
  al código: si el código cambia y el documento no, la suite lo dice.
- Objeciones solo con código real (tgrep/import antes de afirmar).

- **CI**: cuota de Actions agotada (2026-09-19); GitHub no arranca jobs hasta
  que se renueve. La CI corre solo en `main` (+ a mano); en YaViene
  `compilar-apple` es solo a mano y Android/Windows a mano y los martes. La
  verificación local es la evidencia mientras tanto.
- **Rama `diseno-21st`** (2026-09-27, app y web, sin push): cifra viva en la
  distancia de la hoja, filas del selector escalonadas (app + espejo web),
  reloj en el segundo, «Último reporte» y velocidad en grande en la ficha
  del bus (control), cinta de empresas con logos nítidos y filos blancos
  (portada + empresas), cabecera de la app en los tres teléfonos de los
  pasos (web `9529625`), «Agregar ruta» junto a las rutas y pestañas de
  estado segmentadas en el panel (sin desbordes de 1600 a 1200, `747ba8d`),
  terminales de la ruta activa enteros en el menú (`07c6cf3`), la hoja
  del selector conserva su alto y la fila de empresa/ruta mide como la
  tarjeta del paso (app `a301675`, web `7954242`); panel sin conductor ni
  chip de ruta, mapa acotado (60 km, zoom ≥ 11) y login partido con
  «¿Olvidaste tu contraseña?» → WhatsApp del equipo (app `eeb75ec`), con el
  filo de la referencia y el degradado del 404 #17325F→#00A859 (`f219c2d`); en el panel el azul pasa de
  tinta a #17325F e INGRESAR va verde (prueba del dueño, `bc78100`);
  el eléctrico #2563EB se probó y no gustó (`a28e448`): los botones llenos
  van en #1E56A8 (`AppColors.acento` / `boton`, opción D) y nada más;
  íconos y texto siguen en su azul (`8f542c1`); también el filtro y la
  pestaña activos del panel (`ecc135b`) y en la web `--azul-boton`: botón
  del teléfono y panel dibujado (`031a14a`); «Qué resuelve» volvió a su
  rojo, términos y privacidad llevan la isla y el pie del sitio con título
  «Ya Viene Términos/Privacidad», y la ruta del mapa va verde sobre orla
  blanca como «El producto» en el teléfono de la web (`4af2267`) y en el
  pasajero (`EstiloRuta`, app `0c7cf4d`); los pasos de «Cómo funciona»
  ruedan en vertical al bajar (≥1024 px, sin GSAP: `--paso-giro` en
  pasos.css, web `6acb895`; la órbita `a0b77d4` no gustó; tope CSS 117→121);
  retoque visual del panel (app `b275c7f`): filas planas, carril de
  estados, barra de flota de 48, mapa redondeado, «Agregar bus» de 36 y
  ventana mínima 1200×700 (`ventanaMinima`, `estilo_panel_test.dart`); «Recordar contraseña» en la entrada del panel
  (Llavero clásico: con la firma «ad hoc» el de protección de datos da
  -34018 y no guardaba ni la sesión; `f8345f6`, `ef50aaa`); aviso del
  pasajero anclado donde se armó (no sigue al pin), «Escoge empresa y ruta»
  tocable → selector, y ventanas propias en todo: `Dialogo`/`AvisoTarjeta`
  (pasajero), `Ventana`/`AvisoPanel`/`confirmarBorrado` (panel,
  `core/widgets/ventana.dart`), globos de ayuda con tema; guardas en
  `avisos_propios_test.dart` y `ventanas_propias_test.dart` prohíben
  `AlertDialog`/`showDialog`/`SnackBar` de fábrica (`a63771c`, en `main`);
  el ícono de «Escoge empresa y ruta» sigue gris: el verde no gustó
  (`99c0a07`).
- **Flutter** (2026-10-02): core 85, panel 258 + 3 saltadas, pasajero 481 + 1, pruebas 11. Analyze: línea
  base **0 infos** con `flutter analyze --fatal-infos lib test` en los tres
  (T8.3, `2b0a192`; las «40 infos» de `AGENTS.md` son historia). Contrato con el backend: `tool/sincronizar-contrato.sh` (y
  `--comprobar`) tras `npm run contrato:actualizar` en el backend. El
  backend vivo corre bajo launchd (`com.yaviene.backend`): tras cambiarlo,
  `npm run build` y `launchctl kickstart -k gui/$UID/com.yaviene.backend`.

## Reglas del usuario (no negociables, resumen)
1. Logo intocable. 2. GPS = hardware en buses; frase a preservar: `empresas.html:110-111` (el GPS va en el bus; no hay app de conductor y no se propone ninguna). 3. ngrok primario (`occupy-shed-squatter.ngrok-free.dev`); Fly solo respaldo, no desplegar hasta un día antes de presentar; nada de cloudflared (`start-test.sh` se borró; `build-demo.sh` quedó en `archivo/`). 4. `app_control` solo macOS+Windows. 5. Sin modo oscuro; mapa CARTO Voyager; distancia, no ETA. 6. Solo móviles (bloqueo vertical se queda). 7. Cambios en app → build Android **e** iOS con `--dart-define=BACKEND_URL=...` (sin el define la APK explota: `config.dart` lanza StateError). 8. Solape hero congelado (`--lado: tel*0.93`, `--solape: lado*0.16`, trío 360px, sangrado 0.14). 9. La cuenta de prueba de flota (usuario y contraseña se piden, no se escriben): nunca en GUI ni API desde aquí; no mandar correos de recuperación. 10. Gitignore: `google-services.json`, `key.properties`, `upload-keystore.jks`. 11. Tono corto; al terminar solo «listo». Respuestas con la menor cantidad de texto posible, salvo que el usuario pida detalle. 12. Aviso landing SIN placa («Tu bus está cerca de ti»); app CON ruta+placa — no unificar. 13. Mockups web espejan Dart con comentarios que justifican cada número; cambio nuevo trae su comentario. 14. Estado vacío `empty-pick-bus` es intencional, no "arreglar".

## Verificación web (tras cada cambio)
`npm run typecheck` + `npm test` (**301**) + `npm run test:cobertura` + Playwright sin pageerror (**153 + 29 saltadas**, última corrida 2026-10-01) + `node scripts/presupuesto.mjs`. Dev: `npm run dev` en puerto **8091**. E2E corre contra build propia en 4174.

## Búsqueda de código
- **`grep` está aliasado a `ugrep`: no usarlo.** Usar `tgrep "patrón" <ruta> --no-index` (instalado en `~/.cargo/bin`, v1.0.5, en PATH).

## Trampas del entorno
- Bash reinicia `cwd` si el comando trae `cd`: encadenar en una línea. `sleep` en primer plano bloqueado (usar `python3 -c "import time;time.sleep(N)"`). Timeouts: `flutter test` ≥300s, APK ~900s, iOS ~1800s.
- Panel del navegador oculto congela animaciones CSS (leer computado con `transition='none'`). La landing intercepta scroll (`scrollTo`/`scrollIntoView` no mueven `scrollY` en el panel; en Playwright sí sirven). `preview_start` con `name:` falla (levanta Vite a mano). `computer zoom` no sirve; usar `read_page`/texto/`getBoundingClientRect`.
