#!/usr/bin/env bash
# Trinquete de cobertura de los tres paquetes Flutter (T8.7).
#
# Corre `flutter test --coverage` en cada uno y compara el porcentaje de
# líneas cubiertas con su umbral. Los umbrales son la cobertura del día que
# se puso, redondeada hacia abajo, y sólo suben: quien los baje tiene que
# decir en el commit por qué.
#
# El núcleo va más bajo que las apps a propósito: buena parte de lo que
# exporta son piezas de interfaz que se prueban montadas dentro del panel y
# del pasajero, y esas líneas se le apuntan a quien las monta.
#
# Uso: tool/cobertura.sh            (corre las pruebas y revisa)
#      tool/cobertura.sh --sin-correr  (revisa el lcov que ya haya)
set -euo pipefail

cd "$(dirname "$0")/.."

PAQUETES=(ya_viene_core app_control app_pasajero)
UMBRALES=(42 69 73)
# El pasajero se mide como lo mide la CI: sin las pruebas de oro, que solo
# corren en el Mac donde se tomaron las fotos. Midiendo con ellas da 74,06 %
# y sin ellas 73,93 %; el umbral es el de la CI, que es quien manda.
EXTRA=("" "" "--exclude-tags goldens")

correr=1
[[ "${1:-}" == "--sin-correr" ]] && correr=0

fallos=0
printf '%-16s %8s %8s %s\n' paquete cubierto umbral resultado
for i in "${!PAQUETES[@]}"; do
  paquete="${PAQUETES[$i]}"
  umbral="${UMBRALES[$i]}"
  if [[ $correr -eq 1 ]]; then
    # shellcheck disable=SC2086
    (cd "$paquete" && flutter test --coverage ${EXTRA[$i]} >/dev/null)
  fi
  lcov="$paquete/coverage/lcov.info"
  if [[ ! -f "$lcov" ]]; then
    echo "falta $lcov: corre sin --sin-correr" >&2
    exit 1
  fi
  # LF = líneas medibles del archivo, LH = líneas alcanzadas. El porcentaje
  # es el de todo el paquete, no el de cada archivo: un archivo nuevo sin
  # pruebas baja el total y el trinquete lo caza.
  pct=$(awk -F: '
    /^LF:/ { total += $2 }
    /^LH:/ { hit += $2 }
    END { if (total == 0) { print "0.00" } else { printf "%.2f", 100 * hit / total } }
  ' "$lcov")
  if awk -v p="$pct" -v u="$umbral" 'BEGIN { exit !(p + 0 < u + 0) }'; then
    printf '%-16s %7s%% %7s%% BAJÓ\n' "$paquete" "$pct" "$umbral"
    fallos=$((fallos + 1))
  else
    printf '%-16s %7s%% %7s%% ok\n' "$paquete" "$pct" "$umbral"
  fi
done

if [[ $fallos -gt 0 ]]; then
  echo
  echo "La cobertura bajó en $fallos paquete(s). O se cubren las líneas nuevas," >&2
  echo "o se baja el umbral en este mismo archivo diciendo por qué." >&2
  exit 1
fi
