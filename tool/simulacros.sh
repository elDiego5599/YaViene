#!/usr/bin/env bash
# Simulacros b y d de T10.5, cronometrados, contra un backend de usar y tirar.
#
#   tool/simulacros.sh
#
# b: el backend se reinicia (SIGTERM, como launchd) y el pasajero y el panel
#    vuelven solos a recibir posiciones, sin volver a pedir nada.
# d: se cambia la contraseña de un admin con el panel abierto y el panel sale
#    en un minuto como mucho (la revisión de producción, sin acortar).
#
# Cada prueba arranca su backend (`ya_viene_pruebas/lib/backend_temporal.dart`)
# en puertos libres, con base y secretos temporales: el vivo, su base y el
# túnel no se tocan. El backend se busca al lado de este repo; YAVIENE_BACKEND
# lo cambia. Tarda algo más de un minuto, por el d.
set -euo pipefail

raiz="$(cd "$(dirname "$0")/.." && pwd)"
export YAVIENE_SIMULACROS=1

(cd "$raiz/app_pasajero" && flutter test test/simulacros_test.dart)
(cd "$raiz/app_control" && flutter test test/simulacros_test.dart)
