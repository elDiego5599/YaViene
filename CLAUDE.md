# YaViene — CLAUDE

Ya Viene muestra en vivo los buses urbanos de Barranquilla y a qué
**distancia** vienen. Tres repos, una vara: calidad de producción.

## La regla más importante: Codex hace, Claude revisa (dueño, 2026-10-21)
Todo el código lo escribe **Codex** (agente `codex:codex-rescue`), en
diseño y en todo lo demás. Claude no escribe ni reescribe código a mano:
le pasa el pedido a Codex, revisa lo que hizo, lo verifica (pruebas,
analyze, render, builds, simulador e iPhone) y le devuelve las
correcciones a Codex. Claude sí hace lo que Codex no puede: git, builds,
`dart format`, instalar y los arneses de render en el scratchpad. Esta
regla manda sobre «Sin agentes», más abajo.

## Vara de calidad (decisión del dueño, 2026-09-27)
Calidad de producción siempre. Que el entorno sea de prueba (ramas `prueba`,
flota simulada, ngrok, pitch) no rebaja ninguna tarea, no justifica atajos y
no deja nada a medias: cada tarea se cierra entera, con su prueba roja→verde,
o no se marca ☑. El plan usa `[YA]`, `[BLOQUEADA: X]`, `[DUEÑO]`,
`[FECHA: pitch]` y `[CONTINUO]` (ver su §0.4). Lo honesto se queda: la
etiqueta «Simulación», la flota demo y `empty-pick-bus`.

## Para arrancar en frío
1. **`FALTANTES.md`** (vive en `YaViene/FALTANTES.md`; en la raíz hay un
   enlace): lo que queda, por grupos — espera a terceros, decide el dueño,
   hace el dueño, puedo hacer yo, el día del pitch.
2. Este archivo: reglas, estado y cómo se verifica.
3. El detalle de cada tarea: fichas de `plan-remediacion.md` (raíz, sin
   versionar; tablero en §2, fichas en §4, bloqueos en §15.B). Estados
   vacíos/error de los 3 productos: `inventario-estados.md` (T6.7).
4. `archivo/prompt-revision.md`: el prompt de la auditoría de ojos frescos,
   listo para pegar en una sesión nueva.
5. `AGENTS.md` es **historia** (rondas de agosto y septiembre, gotchas de
   pruebas que siguen valiendo); el estado vivo está aquí y en FALTANTES.

## Cómo se trabaja: skills y herramientas
**Sin agentes (dueño, 2026-10-14):** Claude no usa subagentes, salvo que
el dueño los pida; Codex sí, siempre (la regla más importante, arriba). La delegación del 2026-10-11 se
canceló. Las skills de la tabla de abajo se usan igual (revisar las
disponibles en `.claude/skills/` y `~/.claude/skills/`).

Skills del workspace en `.claude/skills/` (copia de `mattpocock/skills` y
otras) y del usuario en `~/.claude/skills/`. Se invocan con la herramienta
Skill; la tabla dice cuándo. Las que traen `disable-model-invocation: true`
(`grill-me`, `grill-with-docs`, `to-spec`, `to-tickets`, `implement`,
`implement-spec`, `improve-codebase-architecture`, `handoff`,
`claude-handoff`) solo las lanza el dueño con `/nombre`; Claude lee su
`SKILL.md` y sigue el método.

| Cuándo | Skill / herramienta |
|---|---|
| Siempre, en todo lo que se escribe | **`ponytail`** (nivel full): escalera YAGNI — ¿hace falta?, ¿ya existe aquí?, stdlib, plataforma, dependencia instalada, una línea, y solo entonces lo mínimo. **Nunca** recorta validación en fronteras, manejo de errores que evita pérdida de datos, seguridad ni accesibilidad. Bug = causa raíz en la función compartida, no parche por llamador. |
| Feature grande | `grill-me` (o `grill-with-docs`) → `to-spec` → `to-tickets` → `implement` / `implement-spec` |
| Toda lógica nueva o bug | **`tdd`**: la prueba primero, roja, y luego verde. Sin roja no hay ☑ |
| Algo falla y no se sabe por qué | `systematic-debugging` / `diagnosing-bugs`: reproducir, aislar, causa raíz antes de tocar |
| Antes de cerrar un cambio | `code-review` + `ponytail-review` (diff) ; `ponytail-audit` / `ponytail-debt` para pasadas grandes |
| Seguridad (auth, entradas, secretos, CORS, socket, MQTT, permisos) | **`security-and-hardening`**: validar en la frontera, mínimo privilegio, secretos fuera del código y de los logs |
| UI (app, panel, web) | `frontend-design`, `high-end-visual-design`, `redesign-existing-projects`; en Flutter, `flutter-animations` y `flutter-verify`. Todo juicio visual **medido** (contraste WCAG calculado, px/pt, radios), nunca a ojo. `image-to-code` / `imagegen-frontend-mobile` solo para referencias |
| Arquitectura | `codebase-design`, `improve-codebase-architecture`, `domain-modeling` |
| Antes de una build que se entrega | `release-preflight` |
| Pasar a otra sesión | `handoff` / `claude-handoff`, o el prompt de `archivo/prompt-revision.md` para auditar |
| Orientarse en el código | **graphify** (`~/.local/bin/graphify`): `graphify query "pregunta"`, `explain "Nodo"`, `path "A" "B"`, `affected "X"`, `god-nodes`, con `--graph <repo>/graphify-out/graph.json`. Tras cambios grandes: `graphify update <repo>` (sin LLM). Es **brújula, nunca evidencia**: toda afirmación se verifica en el código. `graphify-out/` está ignorado en los 3 repos: no se commitea. No correr `graphify install` |
| Buscar texto en el código | **`tgrep "patrón" <ruta> --no-index`** (ver reglas de trabajo) |

## Reglas de trabajo (no negociables)
1. **Búsquedas solo con `tgrep "patrón" <ruta> --no-index`** (`~/.cargo/bin`,
   v1.0.5). `grep` está aliasado a `ugrep` y está **prohibido**, igual que
   `command grep` y `rg`. `tgrep` no lee de una tubería: para filtrar una
   salida, `python3`.
2. **A `main` solo por lotes, cuando el dueño lo pida** (dueño, 2026-10-05):
   cada push a `main` gasta minutos de Actions. Se trabaja y se sube a
   `diseno-21st` (app, web) y `prueba` (backend); ahí se acumula. La CI de
   una rama de trabajo se lanza a mano («Run workflow»), solo si hace falta.
   Cada vez que el dueño pida subir a `main` (dueño, 2026-10-14): antes de
   empujar, recordarle los minutos de Actions (Pro: 3.000/mes; macOS ×10,
   Windows ×2) y preguntarle si está seguro; solo con su sí se sube.
3. **Secretos**: nunca imprimir `local.env` (solo los nombres de sus
   claves), `key.properties` (no se lee), `google-services.json`,
   `GoogleService-Info.plist`, el keystore, el PIN ni ningún token (ngrok
   incluido). Para comparar: igualdad, longitud o enmascarado. `gitleaks`
   solo con `--redact`. Nunca escribo claves ni contraseñas: los logins los
   hace el dueño.
4. **La cuenta de prueba de flota** (usuario y contraseña se piden, no se
   escriben) no se usa contra la GUI ni la API, no va en scripts ni en la
   CI; no se mandan correos de recuperación.
5. **Nada de despliegues** (ni Fly ni túnel) y **el backend vivo no se
   toca** salvo para aplicar un cambio ya probado: `npm run build` y
   `launchctl kickstart -k gui/$UID/com.yaviene.backend`, y luego
   `curl localhost:3000/api/ready`. Las pruebas usan bases temporales y
   puertos propios (comprobar antes que nadie contesta en ese puerto).
6. No matar el puerto **8091** (dev de la web) ni tocar `~/.zshrc`. **No
   subir `maplibre_gl`**: está fijado a propósito.
7. **`FALTANTES.md` al día** (dueño, 2026-10-02): todo pendiente nuevo entra
   en su grupo y todo lo cerrado sale, **en el mismo commit**. «Lo que
   puedo hacer yo» va primero, hasta vaciarlo.
8. Commits en español, que digan qué cambia y por qué, terminados en
   `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Nada de
   `--no-verify` ni de reescribir historia publicada.
9. **Objeciones solo con código real**: `tgrep` o el import antes de
   afirmar; citar `archivo:línea`.
10. Goldens: si uno falla, se entiende por qué antes de regenerar; un
    `--update-goldens` que tapa una regresión es un defecto.
11. Los 20 literales de UI blindados por pruebas espejo (T6.5) y los estados
    de `inventario-estados.md` no se cambian para «arreglar» una prueba.
12. Mutaciones: la prueba de fuego (abajo) se corre antes de cada lote a
    `main` sobre lo que se tocó; una mutación que sobrevive es una prueba
    roja→verde nueva o código muerto fuera.
13. `dart format` solo en los archivos tocados, nunca en carpetas enteras.
14. Tono corto; al terminar solo «listo». Respuestas con la menor cantidad
    de texto posible, salvo que el dueño pida detalle.

## Reglas del producto (no negociables)
1. Logo intocable.
2. GPS = hardware en el bus; frase a preservar: `empresas.html:110-111`.
   No hay app de conductor y no se propone ninguna.
3. ngrok primario (`occupy-shed-squatter.ngrok-free.dev`); Fly solo
   respaldo, no se despliega hasta un día antes de presentar; nada de
   cloudflared (`start-test.sh` se borró; `build-demo.sh` quedó en
   `archivo/`).
4. `app_control` (panel) solo macOS + Windows.
5. Sin modo oscuro; mapa CARTO Voyager; **distancia, no ETA**.
6. Solo teléfonos; el bloqueo vertical se queda.
7. Cambio en la app → build Android **e** iOS con
   `--dart-define=BACKEND_URL=https://occupy-shed-squatter.ngrok-free.dev`
   (sin el define la APK explota: `config.dart` lanza StateError). Después,
   build y launch en el iOS Simulator para que el dueño lo vea.
8. Solape del hero congelado (`--lado: tel*0.93`, `--solape: lado*0.16`,
   trío 360px, sangrado 0.14).
9. Gitignore: `google-services.json`, `key.properties`,
   `upload-keystore.jks`.
10. Aviso de la landing SIN placa ni ruta («Tu bus está cerca de ti»); app
    CON ruta, sin placa ni distancia («Tu bus de la ruta X está cerca de
    ti», dueño 2026-10-02) — no unificar.
11. Los mockups web espejan Dart con comentarios que justifican cada número;
    cambio nuevo trae su comentario.
12. El estado vacío `empty-pick-bus` es intencional, no se «arregla».
13. D3: el pasajero no tiene cuenta. Firebase en el pasajero existe solo
    para los avisos con la app cerrada (D13, FCM, solo Android).
14. Se sigue un solo bus a la vez (`maxAvisosActivos`); sin estado «va pasando»; la guía no se
    reanuda sola tras un cierre a medias.
15. Las decisiones D1–D14 (`YaVieneBackend/docs/decisiones/`) también son
    reglas. D2 (el equipo GPS) espera la respuesta del AMB a la PQRS.
16. Coolitoral está en la app para que no quede solo Sobusa (dueño,
    2026-10-06): no hay nada pendiente con ellos.

## Estado (al 2026-10-06)
- **NO es monorepo**: `YaViene/YaViene` (Flutter: `app_pasajero`,
  `app_control`, `ya_viene_core`, `ya_viene_pruebas`; rama `diseno-21st`),
  `YaVieneBackend` (Node/TS; rama `prueba`) y `YaVieneWeb` (Vite/TS; rama
  `diseno-21st`). Remotos `elDiego5599/*`. Nunca usar el backend duplicado
  `/Users/diegoangarita/YaVieneBackend`.
- **`main` en el remoto** (2026-10-08, lote de la distancia por la ruta
  —A1, A2 sin «Ya pasó»— y el mapa en vivo de la web por la calle, W1):
  `main` igual a la rama de trabajo en los tres repos (web `96c5557`;
  luego, 2026-10-12, la web sola con el hero en video, las preguntas
  frecuentes, el lienzo con `overflow: clip`, los pasos con su cuadro
  blanco y el menú propio de empresas: `72bc384`; carrusel arrastrable
  de los pasos con sus ideas en rojo y gris: `bfa0085`; la escena
  también en el carrusel y «Elige tu ruta» quieta: `2702b1f`; texto
  y cuadro como una sola lámina, con vuelta y rebote y la sombra del
  teléfono de la ruta, 2026-10-13: `aff98c4`; sin arrastre, con flechas
  fuera de la caja y el mapa a sangre: `81be7fd`;
  backend `d11cc59`; la app en el commit de este párrafo).
- **Verificación (2026-10-08)**: **1.975 pruebas** en total (1.942 pasan +
  33 saltadas: 29 de Playwright y 4 de Flutter, 3 de ellas los simulacros,
  que corren con `tool/simulacros.sh`), contando las 13 de `ya_viene_pruebas`; aparte, las
  50 de `npm run test:aforo` (Python; 6 se saltan sin torch) y las 6 E2E del
  simulador.
- **Flutter** (2026-10-08): core 116, panel 330 + 3 saltadas, pasajero
  680 + 1, pruebas 13. `flutter analyze --fatal-infos lib test` en 0 en los tres (y
  `integration_test` en el panel). Aparte, la E2E del panel de escritorio
  contra un backend temporal: `tool/e2e-panel.sh` (abre una ventana; el
  llavero va en memoria). Contrato con el backend:
  `tool/sincronizar-contrato.sh` (y `--comprobar`) tras
  `npm run contrato:actualizar` en el backend.
- **Backend**: 307 pruebas con `npm test` (también con
  `YA_VIENE_SEED_DEMO=0`, `YA_VIENE_EXPUESTO=1` o `NODE_ENV=production`:
  `tests/entorno.ts` fija la siembra y borra las dos guardias),
  `npx tsc --noEmit` limpio. Corre bajo launchd (`com.yaviene.backend`,
  `com.yaviene.ngrok`, `com.yaviene.respaldo`, `com.yaviene.rotar-logs`).
- **Web** (2026-10-13): `npm run typecheck` limpio (3 configs), **413 en Vitest**,
  cobertura 99,3 / 94,3 / 100 / 99,8 sobre el trinquete 98 / 90 / 100 / 99
  (`vite.config.ts`; `npm test` no la mide, `npm run test:cobertura` sí),
  Playwright **130 + 26 saltadas** al 2026-10-18 (`carrusel-lamina.spec.ts`
  vigila cuadro a cuadro que texto y cuadro no se separen, y espera por
  estado, no por reloj: estable con 12 hilos). Presupuestos: dist
  702,1/797 (88 %), JS 44,7/66, CSS 110,0/121 (91 %), primera visita
  394,6/560 y el video
  del hero 4.941/5.090 (**97 %**, tope propio): todo cambio web se mide
  antes de sumarlo.
- **Lighthouse móvil** (T7.7, 2026-10-01, a mano: `@lhci/cli` no entra al
  repo, falla `npm audit`): portada LCP 2,26–2,41 s, empresas 2,18,
  privacidad y términos 1,65; CLS 0, TBT ≤ 35 ms. `e2e/vitales.spec.ts`
  vigila el marcado que lo hace posible.
- **Prueba de fuego** (mutaciones, 2026-10-05): app
  `dart tool/prueba_de_fuego.dart` (`--solo=n,m`; lista en
  `tool/prueba-de-fuego.json`), web y backend `npm run fuego`. Las tres se
  niegan a correr con lo mutado sin commitear y una prueba de cada suite
  ata su lista al código.
- **E2E del pasajero en el simulador** (2026-10-06, tester-army/e2e): en
  `YaViene/e2e`, `npm run test:e2e` con Node ≥22.22.3 o ≥24.8
  (`PATH=/opt/homebrew/opt/node@24/bin:$PATH`; el Node del sistema es 22.20
  y se queda). Instala `app_pasajero/build/ios/iphonesimulator/Runner.app`
  (compilarla antes con `--simulator` y el define) en el «iPhone 17»
  (`E2E_DEVICE` lo cambia): 5 deterministas sin modelo (bienvenida,
  selector, ruta, menú). La sexta, con agente de GitHub Copilot, queda
  saltada: el dueño decidió no iniciar sesión (2026-10-06). Lee el backend
  de la build, no escribe en él.
- **Documentación del backend** en `YaVieneBackend/docs/`:
  `arquitectura.md`, `integracion-gps.md`, `runbook.md`,
  `contingencia-pitch.md` y `decisiones/` (D1–D14 con índice; D13: avisos
  con la app cerrada por FCM, solo Android; D14: buzón de problemas y
  sugerencias, que llega al Gmail del equipo). `tests/doc_gps.test.ts` y
  `tests/docs_enlaces.test.ts` las atan al código.
- **CI**: la cuota de Actions volvió (2026-10-06). Corre sola solo en `main`; en YaViene
  `compilar-apple` es solo a mano y Android/Windows a mano y los martes. A
  mano con `backend_url`, el panel de Windows queda como artefacto
  `panel-windows`. El APK de la CI compila con un `google-services.json` de
  mentira. Falta `BACKEND_REPO_TOKEN` (del dueño) para el contrato y el
  socket del panel en CI.

## Decisiones de diseño vigentes (rama `diseno-21st`)
- **Color**: botones llenos en #1E56A8 (`AppColors.acento` / `boton`; en la
  web `--azul-boton`); íconos y texto siguen en su azul. El eléctrico
  #2563EB se probó y no gustó (`a28e448`). Degradado del 404 y del login del
  panel #17325F→#00A859. En el panel la tinta es #17325F e INGRESAR va
  verde. El ícono de «Escoge empresa y ruta» va gris (el verde no gustó).
- **Movimiento**: resortes como los de iOS (`Resorte` en `app_motion.dart`,
  dueño, 2026-10-19). `curvaEntrada` y `curvaCambio` amortiguadas del todo
  (sin rebote, arrancan quietas); `curvaRebote` (0,7, se pasa 4,6 %) solo
  para lo que se acaba de marcar. Nada sin curva; nada de `easeOutBack`
  fuera de la escena del arranque y la seña de tocar el bus.
  El bus gira a su rumbo con resorte (`BusMotion.giro`, 800 ms) y deja
  una estela tenue de 200 m que se apaga hacia atrás (`estela.dart`); al
  tocarlo la cámara va a él con resorte (`puntoDelViaje`, 600 ms; el dedo
  la suelta) y el aviso que suena da un doble toque en la mano
  (dueño, 2026-10-19).
- **Ruta y bus**: la ruta del mapa en verde sobre orla blanca
  (`EstiloRuta`) y el bus en su rojo (`AppColors.busActive`); el color por
  ruta, como Transit, se probó y no gustó (dueño, 2026-10-19). La barra de
  avance bajo la cifra de la hoja tampoco gustó (2026-10-19): solo queda en
  la actividad en vivo. Solo la ficha de la ruta del
  aviso (bandeja y tarjeta de Avisos) va en el color de
  su empresa en «Elige empresa» (`colorEmpresa`,
  `app_pasajero/lib/core/utils/color_empresa.dart`; el aviso guarda su
  `companyId`; los de antes, sin empresa, en el azul de botón).
- **Avisos y Buzón** (dueño, 2026-10-19, «divisiones con colores de la
  app»; el gris agrupado del iPhone no gustó): fondo blanco, tarjetas
  planas sin sombra con su filo (`AppColors.filo`, #D0D4DC, la tinta de
  la marca al 20 %, como Stripe o Linear) y una raya del mismo filo en
  cada tarjeta de Avisos; el mensaje del buzón sin raya, con la nota de
  privacidad fuera. Arriba, bajo la barra, una cabecera gris
  (`surfaceMuted`) con una raya sutil (media línea de tinta al 8 %); la nota «Gestiona…» con su cuadro.
  Fondo blanco con trama de puntos (`FondoTexturizado`, tinta al 7 %,
  contraste medido en el archivo) en arranque, bienvenida, Avisos, Buzón
  e Info (dueño, 2026-10-19; el matizado azul y verde se fue).
- **Actividad en vivo** (dueño, 2026-10-19, iOS 16.2+): cada aviso
  armado (se sigue un solo bus a la vez) pone la suya en la pantalla bloqueada y la Dynamic Island
  (extensión `ios/AvisoEnVivo`, canal `yaviene/actividad_en_vivo`,
  `actividad_en_vivo.dart`): fondo negro como Uber, arriba «Está a X de
  ti» solo, sin la ruta ni la placa (dueño, 2026-10-21), el logo de Ya Viene
  cuadradito en vez de la ficha (dueño, 2026-10-21), cifra de la hoja y una pista verde, un poco más abajo, con un bus
  visto de lado, rojo y con el frente hacia tu punto, que solo vive ahí
  (`AutobusDeLado`; el de arriba no gustó, dueño, 2026-10-21), a 54 × 25,4 pt
  (dueño, 2026-10-21), avanza hacia tu punto y hace rodar las ruedas lo que
  avanza, con radio de llanta a escala y sin patinar; título de 25 pt. En la
  isla abierta, rótulos y campana en footnote (13 pt, con Dynamic Type); en
  pantalla bloqueada usan subheadline. La línea tiene margen
  lateral de 12 pt (8 + 4) y los rótulos 14 (8 + 6), 2 pt más para librar las
  esquinas. La pista baja 4 pt con 12 pt de aire arriba (dueño, 2026-10-21),
  con la
  campana donde suena el aviso;
  sin datos nuevos, todo en gris (`Vistas.swift`, puro SwiftUI para
  poder renderizarlo en el Mac). Al sonar dice «Tu bus de la ruta X
  está cerca de ti» y se va a los 10 minutos; sin datos en 2 minutos lo
  dice. Con un aviso armado la app pide la ubicación en segundo plano
  (`mantener_vivo.dart`, flecha azul, sin pedir «Siempre») para que iOS no
  la suspenda con la pantalla bloqueada, y la reenvía cada 30 s; cerrada
  del todo no se pone al día (APNs, FALTANTES). La isla lleva el ícono de
  Ya Viene (`LogoYaViene`, cuadradito como el de la app), cerrada y
  abierta; abierta lleva solo «Está a X de ti», como la pantalla
  bloqueada (dueño, 2026-10-21).
  Tocar la actividad abre el mapa con ese bus, su empresa y su ruta; por bus
  solo queda viva la actividad del bus seguido.
- **Vidrio de las barras**: el fondo usa como máximo cuatro filtros
  agrupados, con progreso sin reconstruir la pantalla completa.
- **Ventanas propias en todo**: `Dialogo` / `AvisoTarjeta` (pasajero),
  `Ventana` / `AvisoPanel` / `confirmarBorrado` (panel,
  `core/widgets/ventana.dart`). `avisos_propios_test.dart` y
  `ventanas_propias_test.dart` prohíben `AlertDialog`, `showDialog` y
  `SnackBar` de fábrica.
- **Pasajero**: cifra viva en la distancia de la hoja; filas del selector
  escalonadas (con espejo en la web); la hoja del selector conserva su alto;
  aviso anclado donde se armó (no sigue al pin); «Escoge empresa y ruta»
  abre el selector. La distancia del aviso la elige el pasajero con una
  rueda como la de la alarma del iPhone (500 m–3 km, de 100 en 100; arranca
  en 1 km; cinco filas a la vista, dos arriba y dos abajo, tres con el texto
  grande): la primera vez la tarjeta del bus cambia su distancia por la
  rueda, con «Guardar» y «Solo esta vez» (sin ventana encima); «Cambiar» la
  trae otra vez y cambia solo el aviso de ese bus («Solo se cambia la
  distancia de este aviso», dueño, 2026-10-07). La rueda solo ofrece lo
  que deja 200 m con el bus (`margenAvisoMetros`; bloquea bajo 700 m) y
  ese tope sigue al bus con la rueda abierta (dueño, 2026-10-07); y
  empieza en lo más cerca que pasa la ruta del punto del aviso
  (`distanciaAvisoDesde`), al activar y en «Cambiar»: si el bus ya pasó
  ese punto, lo dice sin rueda (dueño, 2026-10-07). Solo con el aviso puesto
  se dice la distancia: el iPhone «Te avisamos a X · Cambiar» (dueño,
  2026-10-06; antes pedía dejar la app abierta) y Android su nota con la
  fila «Cambiar». «Cambiar» es una píldora como «Quitar» con letra roja
  (`coralAccessible`, 4,96:1). La web lo espeja en el paso 3 y en el hero.
  La distancia al bus se mide **por la ruta**, no en línea recta (A2,
  2026-10-08; `SeguidorRuta` en `ya_viene_core/lib/core/geo/por_ruta.dart`,
  compartido por `seguidorRutaProvider`): hoja, rueda, validación y aviso.
  Sin estado «Ya pasó» (dueño, 2026-10-08): cuenta hasta el paso más
  cerca, venga o ya haya pasado, y nunca la vuelta entera (dueño,
  2026-10-19: con el bus recién pasado salían 20 km), se mide desde cada
  paso de la ruta por donde está el bus (dos buses lado a lado, uno de
  ida y otro de vuelta, dicen lo mismo; dueño, 2026-10-19: daban 10 y
  29 km), y nunca bloquea el
  aviso por eso; si no se puede medir (bus a más de 60 m de la ruta
  o punto a más de 300 m), cae a la línea recta. El push del servidor
  sigue en recta (FALTANTES). La idea se publica aparte, en inglés, en
  `elDiego5599/alongroute` (`YaViene/alongroute`).
  El aviso lleva la ficha de la ruta (B18, C16; `ficha_ruta.dart`): en
  Android de ícono grande, en iOS de imagen adjunta, y en la tarjeta de
  Avisos en vez del bus, con el nombre sin el código (dueño, 2026-10-19).
  Por la ruta cuentan todos los pasos hasta 300 m más lejos que el más
  cercano, no solo ese (el pin entre dos calles daba 15,6 km; con la otra
  calle a 334 m, 30 km en la C16, dueño, 2026-10-21). La barra de
  vidrio sale al bajar, al paso del dedo, y en reposo no hay nada.
  Con un bus tocado se va la píldora de tu punto y buses cerca.
- **Panel**: tablero con fondo y cabecera blancos (el degradado en la
  cabecera no gustó), filo entre buses centrado en la barra y sombras
  realzadas en tinta (`sombraCabecera` / `sombraTarjeta` /
  `sombraFlotante`; la maqueta web no las copia, por el presupuesto)
  (dueño, 2026-10-07); los buses se deslizan entre fijaciones lo que
  tardó la fijación (1–15 s, AUD16-05) como en el pasajero (`BusMotion` en el core, 2026-10-07) y la ruta elegida
  lleva su recorrido como en el pasajero (`rutas.json` vive en el core,
  `kRutasAsset`); sin conductor ni chip de ruta; mapa acotado (60 km, zoom ≥ 11);
  login partido con «¿Olvidaste tu contraseña?» → WhatsApp del equipo;
  filas planas, carril de estados, barra de flota de 48, «Agregar bus» de
  36, ventana mínima 1200×700 (`ventanaMinima`); «Recordar contraseña» con
  el Llavero clásico (con la firma «ad hoc» el de protección de datos da
  -34018).
- **Web**: la página de empresas trata de usted (dueño, 2026-10-07;
  `sin-jerga.test.ts` lo vigila, salvo la maqueta del panel, que espeja la
  app, y el lema de la marca); los pasos de «Cómo funciona» ruedan en vertical al bajar
  (≥1024 px, sin GSAP, `--paso-giro` en `pasos.css`; la órbita no gustó):
  siguen al dedo entre dos pasos y se quedan quietos media pista en cada
  uno (`giroDe` en `paso-foco.ts`; ni continuo ni a saltos, 2026-10-07);
  el mapa del panel dibujado va redondeado como la lista;
  «Qué resuelve» en su rojo; términos y privacidad con la isla y el pie
  «Ya Viene Términos/Privacidad».

## Verificación
Mientras se trabaja (dueño, 2026-10-06), cada cambio corre solo sus
pruebas: la roja→verde nueva y las del archivo o la suite que toca, más
`flutter analyze` / `typecheck` / `tsc`. Lo de abajo entero (suites
completas, Playwright, presupuesto, goldens, prueba de fuego de lo tocado
y builds de entrega) se corre una vez, antes de cada lote a `main`.
- **Web**: `npm run typecheck` + `npm test` + `npm run test:cobertura` +
  Playwright sin pageerror + `node scripts/presupuesto.mjs`. Antes de
  Playwright: `lsof -ti tcp:4174 | xargs -r kill -9` (un servidor viejo
  sirve una build vieja y las pruebas mienten). Dev en el puerto **8091**;
  la E2E corre contra su propia build en el 4174.
- **Flutter**: `flutter analyze --fatal-infos lib test` y `flutter test` en
  el paquete tocado (y en los que dependen de `ya_viene_core` si se toca el
  core); goldens sin regenerar.
- **Backend**: `npm test` + `npx tsc --noEmit`; si cambia el contrato,
  `npm run contrato:actualizar` y `tool/sincronizar-contrato.sh` en la app.
- Lo tocado desde el último lote pasa además por su prueba de fuego.

## Trampas del entorno
- Bash reinicia el `cwd` si el comando trae `cd`: encadenar en una línea.
  `sleep` en primer plano está bloqueado: `python3 -c "import
  time;time.sleep(N)"`. Timeouts: `flutter test` ≥ 300 s, APK ~900 s, iOS
  ~1800 s; una build cortada no es una build fallida.
- Panel del navegador oculto congela las animaciones CSS (leer lo computado
  con `transition='none'`). La landing intercepta el scroll (`scrollTo` /
  `scrollIntoView` no mueven `scrollY` en el panel; en Playwright sí).
  `preview_start` con `name:` falla (levantar Vite a mano). `computer zoom`
  no sirve: usar `read_page`, el texto o `getBoundingClientRect`.
- Con varios simuladores de iOS encendidos hay que nombrar uno (UDID).
