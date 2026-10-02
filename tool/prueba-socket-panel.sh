#!/usr/bin/env bash
# Corre la prueba de socket del panel contra un backend de usar y tirar
# (T8.6). Sin ella, `app_control/test/socket_fleet_test.dart` se salta sola
# —no tiene con qué entrar— y la única pieza que habla con el servidor de
# verdad se queda sin probar.
#
#   tool/prueba-socket-panel.sh
#
# El backend lo levanta `backend-temporal.sh` (base, puertos y cuenta de usar
# y tirar; el vivo no se toca).
set -euo pipefail

source "$(dirname "$0")/backend-temporal.sh"

cd "$raiz/app_control"
flutter test test/socket_fleet_test.dart \
  --dart-define=BACKEND_URL="$url" \
  --dart-define=ADMIN_API_KEY="$clave_api" \
  --dart-define=ADMIN_USERNAME="$usuario" \
  --dart-define=ADMIN_PASSWORD="$contrasena"
