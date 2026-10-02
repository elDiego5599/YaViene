#!/usr/bin/env bash
# La prueba de punta a punta del panel: la app de escritorio de verdad,
# compilada y abierta en su ventana, contra un backend de verdad. Entra con
# usuario y contraseña, ve la flota, agrega un bus, lo borra y sale.
#
#   tool/e2e-panel.sh            # en el Mac
#   tool/e2e-panel.sh windows    # en Windows (Git Bash)
#
# El backend lo levanta `backend-temporal.sh` (base, puertos y cuenta de usar
# y tirar; el vivo no se toca). Puertos propios por omisión para poder
# correrla junto a `prueba-socket-panel.sh`.
set -euo pipefail

export PUERTO_HTTP="${PUERTO_HTTP:-3412}"
export PUERTO_MQTT="${PUERTO_MQTT:-8912}"
source "$(dirname "$0")/backend-temporal.sh"

cd "$raiz/app_control"
flutter test integration_test/panel_e2e_test.dart -d "${1:-macos}" \
  --dart-define=BACKEND_URL="$url" \
  --dart-define=E2E_USUARIO="$usuario" \
  --dart-define=E2E_CLAVE="$contrasena"
