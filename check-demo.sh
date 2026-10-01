#!/bin/bash
# ═══════════════════════════════════════════════════════════
#  Ya Viene — check-demo.sh (PRE-VUELO)
#  Revisa en unos 20 segundos lo que el tablero del día pide (T10.3):
#
#   Servidor
#   1. El túnel responde /api/ready (base y broker listos, no solo el proceso)
#   2. Los buses de R-106 publican y llegan frescos por el socket, lo mismo
#      que ve la app (la flota demo vive dentro del backend)
#   3. La base guarda posiciones de R-106 de hace menos de 15 s
#
#   Este Mac (solo macOS; nada aquí cambia nada, todo es leer)
#   4. Los cuatro servicios de launchd cargados: backend y túnel corriendo,
#      rotación de logs y respaldo con su última salida en 0
#   5. Enchufado a la corriente
#   6. Sin dormirse: `sleep 0` en pmset o un caffeinate que lo impida
#   7. Copia de la base de hace menos de 2 h (el respaldo corre cada hora)
#   8. Logs por debajo de 50 MB (se rotan de madrugada al pasar de 10)
#
#  Uso:
#    ./check-demo.sh
#    ./check-demo.sh --url=https://otro-tunel   # si la URL cambió
#    ./check-demo.sh --sin-mac                  # solo el servidor (otro equipo)
#    ./check-demo.sh --solo-mac                 # solo este Mac
#
#  Para las pruebas (`ya_viene_pruebas/test/check_demo_test.dart`), estas
#  variables cambian dónde mira: URL, DB, RESPALDOS y LOGS.
#  Sale con 0 si todo está bien, 1 si algo falla y 2 si se llamó mal.
# ═══════════════════════════════════════════════════════════
set -uo pipefail

# El backend corre en el portátil y sale por un túnel de ngrok con dominio
# reservado: el nombre no cambia entre reinicios.
URL="${URL:-https://occupy-shed-squatter.ngrok-free.dev}"
SERVIDOR=1
MAC=1
[ "$(uname)" = "Darwin" ] || MAC=0
for arg in "$@"; do
  case "$arg" in
    --url=*) URL="${arg#--url=}" ;;
    --sin-mac) MAC=0 ;;
    --solo-mac) SERVIDOR=0 ;;
    *) echo "Parámetro desconocido: $arg"; exit 2 ;;
  esac
done

BACKEND_DIR=""
for candidate in "$(dirname "$0")/YaVieneBackend" "$(dirname "$0")/../YaVieneBackend"; do
  if [ -d "$candidate" ]; then BACKEND_DIR="$(cd "$candidate" && pwd)"; break; fi
done
if [ -z "$BACKEND_DIR" ]; then
  echo "No encuentro la carpeta YaVieneBackend (¿moviste el script?)"
  exit 2
fi
DB="${DB:-$BACKEND_DIR/data/yaviene.db}"
RESPALDOS="${RESPALDOS:-$(dirname "$DB")/backups}"
LOGS="${LOGS:-$HOME/Library/Logs/YaViene}"
RUTA="R-106"
PASS=0
FAIL=0

ok()  { PASS=$((PASS+1)); echo "  ✔ $1"; }
bad() { FAIL=$((FAIL+1)); echo "  ✗ $1"; }

echo "══════════════════════════════════════════════"
echo "  PRE-VUELO DE LA DEMO — $(date '+%H:%M:%S')"
[ "$SERVIDOR" = "1" ] && echo "  URL del túnel: $URL"
echo "══════════════════════════════════════════════"

servidor() {
  echo ""
  echo "▶ Backend listo vía el túnel (/api/ready)..."
  if curl -sf --max-time 8 "$URL/api/ready" >/dev/null; then
    ok "Backend listo: base y broker contestan"
  else
    bad "El túnel o el backend NO están listos ($URL/api/ready)."
    bad "  Mira backend.log y ngrok.log en $LOGS; el runbook dice qué hacer."
    return
  fi

  echo ""
  echo "▶ Buses publicando (socket $RUTA, lo mismo que ve la app)..."
  # Solo cuentan los que llegan mientras se escucha: la foto inicial
  # (`positions:batch`) puede traer posiciones viejas de la base.
  local buses
  buses="$(cd "$BACKEND_DIR" && node -e '
    const io = require("socket.io-client");
    const [url, ruta] = process.argv.slice(1);
    const s = io(url, { transports: ["websocket"], path: "/ws" });
    const vistos = new Set();
    s.on("connect", () => s.emit("subscribe:route", ruta));
    s.on("positions:update", (d) => { for (const b of d.buses || []) vistos.add(b.busId); });
    s.on("bus:position", (b) => { if (b) vistos.add(b.busId); });
    setTimeout(() => { console.log([...vistos].sort().join(" ")); process.exit(0); }, 7000);
  ' "$URL" "$RUTA" 2>/dev/null)"
  local cuantos
  cuantos="$(echo "$buses" | wc -w | tr -d " ")"
  if [ "$cuantos" -ge 2 ]; then
    ok "Buses publicando en $RUTA: $buses"
  else
    bad "Solo se ven $cuantos bus(es) en $RUTA (${buses:-ninguno}); se esperan 2."
    bad "  La flota demo arranca con el backend: busca [FLOTA] en backend.log."
  fi

  echo ""
  echo "▶ Base de datos fresca..."
  if [ ! -f "$DB" ]; then
    bad "No existe $DB (¿está corriendo el backend?)"
    return
  fi
  local filas
  filas="$(sqlite3 -readonly "$DB" "SELECT bus_id, timestamp FROM positions WHERE route_id='$RUTA';" 2>/dev/null)"
  if [ -z "$filas" ]; then
    bad "La base no tiene posiciones de $RUTA."
    return
  fi
  local ahora bus ts edad
  ahora="$(date +%s)"
  while IFS='|' read -r bus ts; do
    edad=$(( ahora - ts / 1000 ))
    if [ "$edad" -gt 15 ]; then
      bad "Bus $bus: última posición en la base hace ${edad} s (se espera < 15 s)"
    else
      ok "Bus $bus: posición en la base hace ${edad} s"
    fi
  done <<< "$filas"
}

este_mac() {
  echo ""
  echo "▶ Servicios de launchd..."
  local s info
  for s in backend ngrok rotar-logs respaldo; do
    if ! info="$(launchctl print "gui/$(id -u)/com.yaviene.$s" 2>/dev/null)"; then
      bad "com.yaviene.$s no está cargado (runbook: «Que el Mac se levante solo»)"
      continue
    fi
    case "$s" in
      backend|ngrok)
        if [[ "$info" == *"state = running"* ]]; then
          ok "com.yaviene.$s corriendo"
        else
          bad "com.yaviene.$s cargado pero NO corriendo"
        fi ;;
      *)
        # Los de intervalo pasan casi todo el tiempo parados: lo que dice si
        # van bien es cómo terminó la última corrida.
        if [[ "$info" == *"last exit code = 0"* || "$info" == *"(never exited)"* ]]; then
          ok "com.yaviene.$s: última corrida sin error"
        else
          bad "com.yaviene.$s: la última corrida falló (mira $LOGS)"
        fi ;;
    esac
  done

  echo ""
  echo "▶ Energía..."
  if [[ "$(pmset -g batt | head -1)" == *"AC Power"* ]]; then
    ok "Enchufado a la corriente"
  else
    bad "El Mac va con batería: macOS duerme disco y red aunque el proceso viva."
  fi
  local dormir
  dormir="$(pmset -g | awk '$1 == "sleep" { print $2 }')"
  if [ "${dormir:-1}" = "0" ]; then
    ok "pmset: sleep 0"
  elif pmset -g assertions | awk '$1 == "PreventUserIdleSystemSleep" && $2 == "1" { f = 1 } END { exit !f }'; then
    ok "No se duerme: algo lo impide (caffeinate) aunque pmset diga sleep ${dormir}"
  else
    bad "El Mac se puede dormir (sleep ${dormir}): sudo pmset -a sleep 0, o caffeinate -dis"
  fi

  echo ""
  echo "▶ Respaldo de la base..."
  local copia
  copia="$(find "$RESPALDOS" -maxdepth 1 -name 'yaviene-*.db' -mmin -120 2>/dev/null | head -1)"
  if [ -n "$copia" ]; then
    ok "Copia reciente: $(basename "$copia")"
  else
    bad "No hay copia de menos de 2 h en $RESPALDOS (mira respaldo.log)"
  fi

  echo ""
  echo "▶ Logs..."
  local grandes
  grandes="$(find "$LOGS" -maxdepth 1 -name '*.log' -size +50M 2>/dev/null)"
  if [ -n "$grandes" ]; then
    bad "Logs de más de 50 MB (¿falla la rotación?): $(echo "$grandes" | xargs -n1 basename | tr '\n' ' ')"
  else
    ok "Logs por debajo de 50 MB"
  fi
}

[ "$SERVIDOR" = "1" ] && servidor
[ "$MAC" = "1" ] && este_mac

echo ""
echo "══════════════════════════════════════════════"
if [ "$FAIL" = "0" ]; then
  echo "  ✔ PRE-VUELO COMPLETO: $PASS chequeos bien"
else
  echo "  ✗ $FAIL chequeo(s) fallaron — revisa lo de arriba antes de empezar"
fi
echo "══════════════════════════════════════════════"
echo ""
echo "  (A mano: abrir el panel y ver «En línea», abrir el pasajero y ver"
echo "   los buses moverse, y probar antes el punto de acceso del teléfono.)"
[ "$FAIL" = "0" ]
