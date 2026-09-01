# Plan de estética — de "bien hecho" a talla mundial

App: `app_pasajero`. Alcance: `app_pasajero/lib/**` + el tema compartido en
`ya_viene_core/lib/core/theme/**` + la pantalla de arranque nativa de iOS.

Origen: auditoría estética del 2026-08-31. El diagnóstico corto es que los
cimientos son de talla mundial y las paredes las levantaron tres albañiles
distintos. **El trabajo grande no es diseñar nada nuevo: es aplicar el
sistema de diseño que ya está escrito y darle voz a la app.**

---

## Reglas de la casa (valen para las seis fases)

1. **Una rama por fase**, sacada de `prueba`. Nada se fusiona a `main`.
   Nombre: `estetica-fN-<slug>`.
2. **Cada fase cierra compilando las dos plataformas**: APK a
   `~/Desktop/APKs/YaViene-Pasajero.apk` **y** iOS instalado y arrancado en
   el simulador. No se da por cerrada una fase con una sola plataforma.
3. **Cada fase cierra en verde**: `flutter analyze` sin avisos nuevos y
   `flutter test` completo (hoy 171 pruebas) pasando.
4. **El logo no se toca.** Ni el dibujo, ni el color, ni las proporciones.
5. **Archivos congelados para trabajo estético.** Si un cambio de estética
   necesita abrir uno de estos, el cambio está mal planteado y se replantea:
   - `features/notifications/presentation/providers/proximity_alerts_provider.dart`
     (histéresis 1000/1500 m y anclas geográficas)
   - `features/map/presentation/providers/map_tour_provider.dart`
     (máquina de estados y persistencia de la guía)
   - `features/map/data/services/realtime_service.dart` (socket, backoff)
   - `features/map/presentation/widgets/map_bus_animator.dart` y el `Ticker`
     de buses en `map_widget.dart:102-133,858-898`
   Cambiar *cómo se ve* un aviso o un paso de la guía se hace en su widget,
   nunca en su proveedor.
6. **Lista de intocables estéticos** — ya están en 9/10 y tocarlos empeora.
   Ver §"Congelado" al final. Si una fase parece exigir tocar algo de esa
   lista, se para y se replantea.
7. **Radio de impacto del tema compartido.** `ya_viene_core` lo consumen tres
   apps:
   - `app_control` toma **solo `AppColors`** y tiene su propio `ThemeData`
     (`app_control/lib/core/theme/app_theme.dart:2,16-37`). Cambiar
     `textTheme` no lo afecta; **cambiar el valor de un color sí**.
   - `app_conductor/lib/main.dart:37` usa `AppTheme.lightTheme` entero, así
     que sí cambia de tipografía. Es demo, no se trabaja en él, pero **sus
     pruebas tienen que seguir pasando**.
   - Añadir tokens nuevos es seguro. Cambiar el valor de uno existente
     requiere revisar las tres apps.

---

## Fase 0 — Red de seguridad (1 día)

**Por qué va primero.** Las fases 2 y 3 tocan 78 estilos de texto y ~40
radios repartidos por 40 archivos. Hoy hay 30 archivos de prueba y **cero
`matchesGoldenFile`**: las pruebas verifican comportamiento, no píxeles. Sin
red, la migración es a ciegas y un `letterSpacing` perdido no lo caza nadie.

- Goldens de las pantallas clave, en su estado de reposo y en el que
  importa: splash, login (los tres pasos), onboarding, mapa con la píldora,
  selector (vista principal + lista de rutas), hoja de distancia (metros,
  kilómetros, sin ubicación, con aviso activo), drawer abierto, avisos
  (lleno y vacío), guía (un paso con hueco).
- Los goldens se generan **antes** de tocar nada: son la foto del "antes".
- Añadir al `README` cómo regenerarlos (`flutter test --update-goldens`) y
  la regla: **un golden solo se actualiza cuando el cambio visual es
  intencional y se dice en el commit por qué.**

**Hecho cuando:** los goldens existen, pasan, y un `letterSpacing` cambiado
a mano hace fallar la prueba.

---

## Fase 1 — Ganancias sueltas (1-2 días)

Todo lo que no choca con la migración y se ve el primer día. Riesgo cero en
histéresis, guía y socket.

| # | Qué | Dónde |
|---|---|---|
| 1 | **Arranque de iOS.** Hoy es el storyboard por defecto de Flutter: blanco puro y corte duro al `#0B1628` del splash. Android tiene tres niveles de cuidado (`drawable/`, `drawable-v21/`, `values-v31/styles.xml`) y iOS ninguno | `ios/Runner/Base.lproj/LaunchScreen.storyboard:19,22,35` y `ios/Runner/Assets.xcassets/LaunchImage.imageset/` (**sin un solo PNG**) |
| 2 | **Una sola familia de iconos.** 71 usos, 44 iconos distintos, 10 fuera de la familia `_rounded`. El peor caso es la píldora de estado, que vive *siempre* sobre el mapa y es 100 % sharp | `location_status_chip.dart:35,42,51,60,103,116,127,158,167,175`; `onboarding_screen.dart:155,167`; `map_guide_copy.dart:134` |
| 3 | **Una sola asa.** Extraer un widget compartido con el comportamiento bueno (56→44 × 5, `Color.lerp` al plegarse). Hoy se ven una detrás de otra y son distintas | `eta_bottom_sheet.dart:387-417` (se queda como referencia) vs `route_selector_sheet.dart:1080-1094` (se elimina) |
| 4 | **El login deja de saltar.** Los pasos email→contraseña→perfil son `if (_step == …)` con `setState` y cero animación en 850 líneas. Es la primera pantalla después del splash | `login_screen.dart:401,452` |
| 5 | **Filo solo donde se ve.** `Border.all` en una hoja anclada abajo dibuja hairlines verticales bajando por los bordes de pantalla | `eta_bottom_sheet.dart:368-380`, `route_selector_sheet.dart:424-432` |
| 6 | **Menús del sistema en español.** `locale: es_CO` sin `flutter_localizations` ni delegates: copiar/pegar, tooltips y selección de texto salen en inglés | `main.dart:129` + `pubspec.yaml` |
| 7 | **Copy sin marca de plataforma.** "Si Android te pide permiso…" en un iPhone. Y `:126` promete *cuánto falta* (tiempo) cuando la hoja entrega metros | `map_guide_copy.dart:126,141,147` — **solo el texto, no la máquina de estados** |

**Hecho cuando:** el arranque de iOS encadena sin corte, no queda ningún
icono fuera de `_rounded`, hay una sola clase de asa en el árbol, y la guía
no nombra Android en iOS.

---

## Fase 2 — Cimientos (1-2 días)

El sistema existe y la app no lo usa. Antes de migrar hay que terminarlo y
ponerle candado.

**Estado hoy, medido:**

- `AppSpacing`: **0 usos** en `app_pasajero/lib/**`
- `AppTextStyles`: **3 usos** (todos en `eta_bottom_sheet.dart:705,712,718`)
  contra **78 `TextStyle(` inline**
- `AppRadius`: 6 usos contra ~40 `circular(…)` literales
- **20 tamaños de fuente** distintos; **14 letter-spacings**; **14 radios**,
  con `circular(99)` y `circular(999)` conviviendo como "píldora"
- Pesos: w800 en **34** sitios, w700 18, w600 12, w500 12, w200 1. **w400 va
  en el bundle (`pubspec.yaml:63-77`) y no se usa nunca**

**Trabajo:**

1. **Escala tipográfica.** Reducir los 20 tamaños a ~8 roles con nombre
   (display, título, subtítulo, cuerpo, cuerpo fuerte, etiqueta, pie, dato).
   Cada rol fija tamaño, peso, `height` y `letterSpacing` — se acabaron los
   14 letter-spacings sueltos.
2. **Rebajar el volumen.** w800 pasa a ser la excepción (el número héroe, el
   botón principal), no la norma. Los cuerpos de texto bajan a w400/w500,
   que es para lo que se está pagando el peso en el bundle.
3. **Escala de radios.** Los 14 literales caen en los 6 de `AppRadius`.
   `999` es *el* pill; `99` desaparece.
4. **Conectar el tema.** `AppTheme.lightTheme` fija `fontFamily` pero
   **nunca `textTheme`**, así que `Theme.of(context).textTheme` devuelve
   Material, no lo nuestro (`ya_viene_core/lib/core/theme/app_theme.dart:177-185`).
   Se conecta.
5. **Candado.** Regla de lint / comprobación en CI que falle ante un
   `TextStyle(` con `fontSize` literal o un `circular(<número>)` nuevo fuera
   del tema. `analysis_options.yaml` ya lleva reglas propias, encaja.

**Hecho cuando:** el tema entrega tipografía, existe el candado, y los
goldens de la Fase 0 **siguen pasando sin actualizarse** (la fase 2 define,
no migra).

---

## Fase 3 — Migración (4-6 días)

La parte grande. Archivo por archivo, en este orden, un commit por archivo,
goldens revisados en cada paso.

1. `shared/widgets/**`, `core/widgets/**` (lo que usan todos)
2. `eta_bottom_sheet.dart`, `route_selector_sheet.dart`, `search_pill_bar.dart`,
   `location_status_chip.dart` (el mapa, que es la app)
3. `login_screen.dart`, `onboarding_screen.dart`, `splash_screen.dart`
4. `app_drawer.dart`, `notifications_screen.dart`, `map_tour_overlay.dart`

**Regla dura:** la migración es **visualmente neutra salvo donde el
diagnóstico dice lo contrario** (el volumen de los pesos, y `99`→`999`). Si
un golden cambia por otro motivo, es un error de migración, no una mejora.

**Hecho cuando:** `AppSpacing` pasa de 0 a uso generalizado, los
`TextStyle(` inline con `fontSize` bajan a ~0, y el candado de la Fase 2 no
tiene nada que bloquear.

---

## Fase 4 — Darle voz (3-4 días)

Lo primero que mira Apple y hoy no existe.

- **VoiceOver.** `Semantics`/`semanticLabel` aparecen **9 veces y todas en un
  archivo** (`search_pill_bar.dart:86,122,226`). Los otros ~62 archivos de
  UI: cero. El número héroe se lee como texto suelto sin unidad
  (`eta_bottom_sheet.dart:660-770`). Pantalla por pantalla, en el mismo orden
  de la Fase 3, con lectura real en el simulador — no solo el árbol.
- **Dynamic Type.** Cero `textScaler` en toda la app y alturas fijas con
  texto dentro: `search_pill_bar.dart:61` (60), `login_screen.dart:513` (56),
  `eta_bottom_sheet.dart:537,866`, `onboarding_screen.dart:178`. A tamaños
  grandes revienta.
- **Contraste del número héroe.** `etaNumber` w200 a 64 px teñido con
  `warning #D97706` sobre arena: trazo finísimo en color medio
  (`eta_bottom_sheet.dart:712,781-785`).
- **Movimiento reducido.** Solo **3 de 15** archivos animados lo consultan.
  Faltan el pulso del halo (`map_widget.dart:962`, `Timer.periodic` de 900 ms
  sin consultar nada), el drawer (`app_drawer.dart:34-36`) y la guía
  (`map_tour_overlay.dart:48`).

**Hecho cuando:** las cinco pantallas principales se recorren enteras con
VoiceOver sin quedarse mudas ni leer basura, y con el texto en el tamaño
más grande de iOS no se corta nada.

---

## Fase 5 — Obsesión (abierto, después de la presentación)

Sin fecha. Se abre cuando las cuatro anteriores estén cerradas.

- **iPad y horizontal.** `main.dart:31-33` bloquea vertical y no hay nada
  para pantalla grande. Es la fase más cara de todas.
- **Indicadores de carga propios.** 7 `CircularProgressIndicator` de Material
  sin tocar, incluido el del splash, encima de nuestra propia identidad
  (`splash_screen.dart:87`, `login_screen.dart:549,668`,
  `route_selector_sheet.dart:576,943`, +2).

---

## Descartado a propósito

No son olvidos: son decisiones tomadas.

- **Modo oscuro.** Los buses se usan de día. `theme` y `darkTheme` se quedan
  siendo el mismo objeto y `themeMode` clavado en claro
  (`main.dart:125-127`). Esto le quita a la Fase 3 su examen final, así que
  el examen pasa a ser el candado de lint de la Fase 2 y los goldens de la
  Fase 0: si un color o un tamaño vuelve a escribirse a mano, lo caza el
  análisis, no una pantalla oscura rota.
- **Estilo de mapa propio.** Seguimos con CARTO voyager
  (`map_widget.dart:1026-1027`). Funciona y ya tiene red de seguridad si se
  cae (`:209`, timeout de 7 s → placeholder).
- **Minutos en vez de metros.** La hoja seguirá diciendo "850 m de ti"
  (`eta_bottom_sheet.dart:772-777`). La distancia es lo que el backend puede
  garantizar hoy sin inventarse un tiempo que no sabe.

---

## Congelado — no se toca

Salió 9/10 en la auditoría. Tocarlo empeora. Si una fase parece necesitarlo,
se para y se replantea.

- **Filo en vez de sombra en las hojas** — `eta_bottom_sheet.dart:368-380`,
  `route_selector_sheet.dart:424-432`. Sobre un mapa de colores impredecibles
  el filo recorta y la sombra no. (La Fase 1 solo quita el filo de los lados
  que quedan fuera de pantalla; el de arriba se queda.)
- **El asa que engorda y se oscurece al plegarse** — `eta_bottom_sheet.dart:387-417`.
  Es el mejor detalle de la app, y en la Fase 1 es el que gana.
- **`layoutBuilder` alineado arriba en el `AnimatedSwitcher`** — `eta_bottom_sheet.dart:441-460`.
- **Descarte con el dedo del selector** — `route_selector_sheet.dart:397-441`.
  `FractionalTranslation` sobre fracción del alto propio: arranca exacto en
  el primer fotograma sin esperar a que alguien mida.
- **Inset del indicador de inicio DENTRO de la hoja** — `route_selector_sheet.dart:441-445`.
- **Empuje lateral entre vistas del selector** — `route_selector_sheet.dart:461-470`.
- **Splash: `InkHero` + `LiveRouteBackdrop` + `ScreenEntrance`** — `splash_screen.dart`.
- **`ScreenEntrance`: un ticker para todo el grupo, curvas memorizadas** —
  `entrance.dart:69-96`.
- **Spotlight de la guía** — `map_tour_overlay.dart:500-537`. `saveLayer` +
  `BlendMode.clear` + blur + gradiente. Nivel producto real.
- **La X de limpiar en gris, no en rojo** — `search_pill_bar.dart:250-270`.
  Y `primaryAccessible` a 12 px en `:181-186`.
- **La arena compartida** entre login, onboarding, selector y hoja.
- **El logo.**

---

## Calendario

| Fase | Días | Se puede parar aquí y ya se ve mejor |
|---|---|---|
| 0 · Red de seguridad | 1 | no (invisible, pero es el seguro) |
| 1 · Ganancias sueltas | 1-2 | **sí** |
| 2 · Cimientos | 1-2 | no (define, no migra) |
| 3 · Migración | 4-6 | **sí, y es el salto grande** |
| 4 · Voz | 3-4 | **sí** |
| 5 · Obsesión | abierto | — |

**Fases 0-4: entre dos y tres semanas de trabajo enfocado.** La Fase 1 sola
ya cambia la primera impresión; la Fase 3 es donde la app deja de parecer
hecha por tres manos distintas.
