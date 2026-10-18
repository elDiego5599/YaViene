#!/usr/bin/env bash
# Compila el panel para el navegador y deja al lado la CSP con que se sirve.
#
#   tool/compilar-panel-web.sh https://api.ejemplo.co
#   tool/compilar-panel-web.sh --base-href /panel/ https://api.ejemplo.co
#
# Con `--base-href /panel/` la build es la que sirve el backend en /panel/,
# en el mismo origen que la API (`YA_VIENE_PANEL_WEB`, ver
# YaVieneBackend/src/api/panel_web.ts). La API es entonces ese mismo
# origen: en connect-src ya la cubre 'self', y su wss va explícito porque
# no todos los Safari cuentan ws/wss dentro de 'self'.
#
# Deja `app_control/build/web` y, dentro, `csp.txt`: la cabecera
# Content-Security-Policy que el servidor del panel tiene que mandar. Se
# probó entera en Chromium contra un backend temporal (2026-10-08): entrar,
# recargar, el socket, salir, el enlace directo y el WhatsApp, sin un solo
# bloqueo.
#
#   tool/compilar-panel-web.sh --csp <API>        solo escribe la CSP
#   tool/compilar-panel-web.sh --revisar <dir>    solo revisa una build
#
# Por qué cada cosa:
# - `--no-web-resources-cdn`: si no, CanvasKit se baja de www.gstatic.com y
#   con esta CSP la pantalla queda en blanco. `--revisar` lo comprueba en la
#   build y falla si no.
# - `'wasm-unsafe-eval'`: CanvasKit es WebAssembly; sin él no arranca. No
#   hace falta `'unsafe-eval'`.
# - `style-src 'unsafe-inline'`: Flutter mete dos `<style>` armados en el
#   navegador (`style_manager.dart` del motor), y su texto cambia con el
#   navegador —Safari, Firefox, Edge y el autocompletar suman reglas—. Unos
#   hashes medidos en Chromium dejarían sin esas reglas a los demás: el
#   cursor y la selección de los campos ocultos se verían. El nonce de
#   Flutter (`nonce` en `flutter_bootstrap.js`) pide un servidor que lo
#   genere en cada respuesta; uno estático no puede. Los scripts sí van
#   sin nada inline.
# - `fonts.gstatic.com`: las etiquetas del mapa (barrios, municipios, el
#   río) caen a Roboto y Noto, que Flutter web baja de ahí; sin él el mapa
#   sale sin un nombre.
# - `*.cartocdn.com`: el estilo, las teselas y los glifos del mapa.
set -euo pipefail

raiz="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

uso() {
  echo "Uso: $0 [--base-href /ruta/] <API> | --csp <API> | --revisar <dir>" >&2
  exit 2
}

# La API va en la CSP como origen: esquema, host y puerto, nada más.
# https siempre; http solo para localhost, que es como se prueba.
csp() {
  local api="$1" ws
  if [[ "$api" =~ ^https://[a-z0-9.-]+(:[0-9]+)?$ ]]; then
    ws="wss://${api#https://}"
  elif [[ "$api" =~ ^http://(localhost|127\.0\.0\.1)(:[0-9]+)?$ ]]; then
    ws="ws://${api#http://}"
  else
    echo "«${api}» no es un origen: https://host[:puerto], sin barra ni ruta" >&2
    exit 2
  fi
  printf '%s' \
    "default-src 'self'; " \
    "script-src 'self' 'wasm-unsafe-eval'; " \
    "style-src 'self' 'unsafe-inline'; " \
    "img-src 'self' data: blob: https://*.cartocdn.com; " \
    "font-src 'self' data: https://fonts.gstatic.com; " \
    "connect-src 'self' $api $ws https://*.cartocdn.com https://fonts.gstatic.com; " \
    "worker-src 'self' blob:; " \
    "object-src 'none'; base-uri 'self'; form-action 'none'; " \
    "frame-ancestors 'none'"
  echo
}

# Que la build traiga su CanvasKit y no lo pida a gstatic.
revisar() {
  local dir="$1"
  if [ ! -f "$dir/canvaskit/canvaskit.wasm" ] ||
    ! tr -d ' ' < "$dir/flutter_bootstrap.js" 2>/dev/null |
      python3 -c 'import sys; sys.exit(0 if "\"useLocalCanvasKit\":true" in sys.stdin.read() else 1)'; then
    echo "La build de $dir pide CanvasKit a gstatic: falta --no-web-resources-cdn" >&2
    exit 1
  fi
}

base=/
if [ "${1:-}" = --base-href ]; then
  [ $# -eq 3 ] || uso
  # Lo que pide `flutter build web --base-href`: empieza y termina en «/».
  if [[ ! "$2" =~ ^/([a-z0-9_-]+/)*$ ]]; then
    echo "--base-href «$2» tiene que ser /, o /ruta/ con barra al principio y al final" >&2
    exit 2
  fi
  base="$2"
  shift 2
  [[ "$1" != -* ]] || uso
fi

case "${1:-}" in
  --csp) [ $# -eq 2 ] || uso; csp "$2" ;;
  --revisar) [ $# -eq 2 ] || uso; revisar "$2" ;;
  -*|'') uso ;;
  *)
    [ $# -eq 1 ] || uso
    politica="$(csp "$1")"
    cd "$raiz/app_control"
    flutter build web --release --no-web-resources-cdn --no-wasm-dry-run \
      --base-href "$base" --dart-define=BACKEND_URL="$1"
    revisar build/web
    echo "$politica" > build/web/csp.txt
    echo "CSP en app_control/build/web/csp.txt"
    ;;
esac
