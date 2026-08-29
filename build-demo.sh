#!/bin/bash
# ═══════════════════════════════════════════════════════════
#  Ya Viene — build-demo.sh (COMPILAR E INSTALAR)
#  Deja lista la demo en un solo comando:
#   1. Comprueba que el backend responda en la URL que se va a compilar
#   2. Compila la APK del pasajero (release) y la instala en el teléfono
#   3. Compila el panel de control (macOS) y lo instala en /Applications
#
#  Uso:
#    ./build-demo.sh
#    ./build-demo.sh --backend-url=https://otro-tunel   # si la URL cambió
#    ./build-demo.sh --solo-pasajero                    # solo la APK
#    ./build-demo.sh --solo-panel                       # solo el panel
#    ./build-demo.sh --sin-instalar                     # compilar y no instalar
#    ./build-demo.sh --sin-verificar                    # no exigir backend vivo
#
#  Después: ./check-demo.sh   (comprueba que la demo esté viva)
# ═══════════════════════════════════════════════════════════
set -uo pipefail

# `BACKEND_URL` es constante de compilación (`String.fromEnvironment`): queda
# grabada en el binario. Por eso la URL se decide aquí y no en la app, y por
# eso cambiarla obliga a volver a correr este script y a reinstalar. Misma
# URL por defecto que check-demo.sh, para que los dos hablen del mismo sitio.
BACKEND_URL="${BACKEND_URL:-https://ya-viene-backend.fly.dev}"
HACER_PASAJERO=1
HACER_PANEL=1
INSTALAR=1
VERIFICAR=1

for arg in "$@"; do
  case "$arg" in
    --backend-url=*) BACKEND_URL="${arg#--backend-url=}" ;;
    --solo-pasajero) HACER_PANEL=0 ;;
    --solo-panel)    HACER_PASAJERO=0 ;;
    --sin-instalar)  INSTALAR=0 ;;
    --sin-verificar) VERIFICAR=0 ;;
    -h|--help)       sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Parámetro desconocido: $arg"; echo "Prueba: $0 --help"; exit 2 ;;
  esac
done

RAIZ="$(cd "$(dirname "$0")" && pwd)"
APK_DESTINO="$HOME/Desktop/APKs/YaViene-Pasajero.apk"
PANEL_DESTINO="/Applications/Ya Viene Control.app"
ADB="$HOME/Library/Android/sdk/platform-tools/adb"
FALLOS=0

ok()   { echo "  ✔ $1"; }
bad()  { FALLOS=$((FALLOS+1)); echo "  ✗ $1"; }
aviso(){ echo "  ! $1"; }

echo "══════════════════════════════════════════════"
echo "  COMPILAR LA DEMO — $(date '+%H:%M:%S')"
echo "  Backend que quedará grabado: $BACKEND_URL"
echo "══════════════════════════════════════════════"

# ── 0. Herramientas ───────────────────────────────────────────
command -v flutter >/dev/null || { echo "No encuentro 'flutter' en el PATH."; exit 2; }

# ── 1. El backend contesta ────────────────────────────────────
# Se comprueba ANTES de compilar: una app compilada contra una URL muerta se
# ve perfecta y no funciona, y son ~10 minutos de build para descubrirlo.
echo ""
echo "▶ [1/3] El backend responde en esa URL..."
if [ "$VERIFICAR" = "0" ]; then
  aviso "Verificación saltada (--sin-verificar)"
elif curl -s --max-time 8 "$BACKEND_URL/api/health" | grep -q '"ok"'; then
  ok "Backend vivo en $BACKEND_URL"
else
  bad "El backend NO responde en $BACKEND_URL"
  bad "  Si es un túnel que se reinició, la URL cambió:"
  bad "    ./build-demo.sh --backend-url=URL_NUEVA"
  bad "  Si está en Fly y dormido:  fly scale count 1 -a ya-viene-backend"
  echo ""
  echo "  Compilar ahora deja las apps apuntando a un sitio muerto. Abortando."
  echo "  (Para compilar de todos modos: --sin-verificar)"
  exit 1
fi

# ── 2. APK del pasajero ───────────────────────────────────────
echo ""
if [ "$HACER_PASAJERO" = "1" ]; then
  echo "▶ [2/3] APK del pasajero (release)..."
  # Sin key.properties el release cae a la llave de debug. Los dos SHA-1 están
  # registrados en Firebase, así que el ingreso con Google sirve igual, pero
  # una APK firmada con la llave de debug no es publicable.
  [ -f "$RAIZ/app_pasajero/android/key.properties" ] \
    || aviso "Sin android/key.properties: se firmará con la llave de debug (no publicable)"

  if (cd "$RAIZ/app_pasajero" && flutter build apk --release \
        --dart-define=BACKEND_URL="$BACKEND_URL" >/dev/null 2>&1); then
    mkdir -p "$(dirname "$APK_DESTINO")"
    cp "$RAIZ/app_pasajero/build/app/outputs/flutter-apk/app-release.apk" "$APK_DESTINO"
    ok "APK en $APK_DESTINO ($(du -h "$APK_DESTINO" | cut -f1))"

    if [ "$INSTALAR" = "1" ]; then
      if [ -x "$ADB" ] && [ -n "$("$ADB" devices | sed '1d' | grep -w device)" ]; then
        if "$ADB" install -r "$APK_DESTINO" >/dev/null 2>&1; then
          ok "Instalada en el dispositivo conectado"
        else
          bad "adb install falló (¿firma distinta a la ya instalada? desinstala primero)"
        fi
      else
        aviso "Sin dispositivo Android conectado: la APK queda en el Escritorio"
      fi
    fi
  else
    bad "Falló la compilación de la APK. Repite sin silenciar para ver el error:"
    bad "  cd app_pasajero && flutter build apk --release --dart-define=BACKEND_URL=$BACKEND_URL"
  fi
else
  echo "▶ [2/3] APK del pasajero — saltada"
fi

# ── 3. Panel de control (macOS) ───────────────────────────────
echo ""
if [ "$HACER_PANEL" = "1" ]; then
  # El panel se usa normalmente en Windows; macOS es la máquina de desarrollo.
  # Se compila para el sistema donde se corra el script.
  case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*) SISTEMA=windows ;;
    Darwin)               SISTEMA=macos ;;
    *)                    SISTEMA=desconocido ;;
  esac
  echo "▶ [3/3] Panel de control ($SISTEMA, release)..."

  if [ "$SISTEMA" = "desconocido" ]; then
    aviso "$(uname -s) no es un sistema donde se use el panel; se salta"
  elif ! (cd "$RAIZ/app_control" && flutter build "$SISTEMA" --release \
            --dart-define=BACKEND_URL="$BACKEND_URL" >/dev/null 2>&1); then
    bad "Falló la compilación del panel. Repite sin silenciar para ver el error:"
    bad "  cd app_control && flutter build $SISTEMA --release --dart-define=BACKEND_URL=$BACKEND_URL"
  elif [ "$SISTEMA" = "windows" ]; then
    # En Windows no hay nada que instalar: el ejecutable y sus DLL viven
    # juntos en la carpeta del bundle y se abre desde ahí (o se copia entera
    # a donde se quiera). Sacar el .exe solo, sin sus DLL, no arranca.
    ORIGEN="$RAIZ/app_control/build/windows/x64/runner/Release"
    ok "Panel compilado en $ORIGEN"
    ok "Se abre con: '$ORIGEN/ya_viene_control.exe'"
    aviso "Para llevarlo a otra máquina hay que copiar la carpeta entera, no solo el .exe"
  else
    ORIGEN="$RAIZ/app_control/build/macos/Build/Products/Release/Ya Viene Control.app"
    ok "Panel compilado"
    if [ "$INSTALAR" = "1" ]; then
      # Si está abierto, copiar encima deja la copia a medias.
      pkill -f "Ya Viene Control.app/Contents/MacOS" >/dev/null 2>&1
      rm -rf "$PANEL_DESTINO"
      if cp -R "$ORIGEN" "$PANEL_DESTINO"; then
        # Va firmado ad-hoc, no notarizado: sin quitar la cuarentena macOS
        # lo bloquea al abrirlo.
        xattr -dr com.apple.quarantine "$PANEL_DESTINO" 2>/dev/null
        ok "Instalado en $PANEL_DESTINO"
      else
        bad "No se pudo copiar a /Applications"
      fi
    else
      ok "Sin instalar: queda en $ORIGEN"
    fi
  fi
else
  echo "▶ [3/3] Panel de control — saltado"
fi

# ── Resumen ───────────────────────────────────────────────────
echo ""
echo "══════════════════════════════════════════════"
if [ "$FALLOS" = "0" ]; then
  echo "  ✔ TODO COMPILADO contra $BACKEND_URL"
else
  echo "  ✗ $FALLOS paso(s) fallaron — revisa lo de arriba"
fi
echo "══════════════════════════════════════════════"
echo ""
echo "  Falta arrancar los buses, en la misma máquina que el backend:"
echo "    cd YaVieneBackend && bash scripts/demo-buses.sh"
echo "  Y comprobar que todo esté vivo:  ./check-demo.sh"
exit "$([ "$FALLOS" = "0" ] && echo 0 || echo 1)"
