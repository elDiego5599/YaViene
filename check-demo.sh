#!/bin/bash
# ═══════════════════════════════════════════════════════════
#  Ya Viene — check-demo.sh (PRE-VUELO)
#  Verifica en 20 segundos que todo lo crítico de la demo esté vivo:
#   1. El túnel responde /api/health
#   2. Los dos buses demo (B-042, B-055) están publicando y sus
#      posiciones llegan frescas por el socket (lo mismo que ve la app)
#   3. La base de datos está recibiendo posiciones
#
#  Uso:
#    ./check-demo.sh
#    ./check-demo.sh --url=https://otro-tunel     # si la URL cambió
# ═══════════════════════════════════════════════════════════
set -uo pipefail

# El backend ya no vive detrás de un túnel que cambia de nombre en cada
# arranque: está desplegado en Fly con una URL fija.
URL="${URL:-https://ya-viene-backend.fly.dev}"
for arg in "$@"; do
  case "$arg" in
    --url=*) URL="${arg#--url=}" ;;
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
PASS=0
FAIL=0

ok()   { PASS=$((PASS+1)); echo "  ✔ $1"; }
bad()  { FAIL=$((FAIL+1)); echo "  ✗ $1"; }

echo "══════════════════════════════════════════════"
echo "  PRE-VUELO DE LA DEMO — $(date '+%H:%M:%S')"
echo "  URL del túnel: $URL"
echo "══════════════════════════════════════════════"

# ── 1. Salud del backend vía el túnel ─────────────────────────
echo ""
echo "▶ [1/3] Backend alcanzable vía el túnel..."
if HEALTH="$(curl -s --max-time 8 "$URL/api/health")" && echo "$HEALTH" | grep -q '"ok"'; then
  UPTIME="$(echo "$HEALTH" | grep -o '"uptime":[0-9.]*' | cut -d: -f2 | cut -d. -f1)"
  ok "Backend OK (uptime ${UPTIME}s)"
else
  bad "El túnel NO responde. Si el túnel se reinició, la URL cambió:"
  bad "  reconstruye todo con: ./build-demo.sh --backend-url=URL_NUEVA"
  echo ""
  echo "Resultado: $FAIL fallo(s), $PASS ok"
  exit 1
fi

# ── 2. Los buses demo publicando por el socket ────────────────
echo ""
echo "▶ [2/3] Buses demo publicando (socket R-106, lo mismo que ve la app)..."
PROBE=$(
  cd "$BACKEND_DIR" && node -e '
    const io = require("socket.io-client");
    const url = process.argv[1];
    const s = io(url, { transports: ["websocket"], path: "/ws" });
    const seen = new Map();
    s.on("connect", () => s.emit("subscribe:route", "R-106"));
    s.on("positions:update", (d) => { for (const b of d.buses || []) seen.set(b.busId, Date.now()); });
    s.on("bus:position", (b) => { if (b) seen.set(b.busId, Date.now()); });
    setTimeout(() => {
      console.log(JSON.stringify({ buses: [...seen.entries()] }));
      process.exit(0);
    }, 7000);
  ' "$URL"
)
if [ -z "$PROBE" ]; then
  bad "No se pudo conectar al socket."
else
  BUSES="$(echo "$PROBE" | node -e 'const d=JSON.parse(require("fs").readFileSync(0));console.log(d.buses.map(([id])=>id).join(", "))')"
  COUNT="$(echo "$PROBE" | node -e 'const d=JSON.parse(require("fs").readFileSync(0));console.log(d.buses.length)')"
  if [ "$COUNT" -ge 2 ]; then
    ok "Buses publicando: $BUSES"
  else
    bad "Solo se ven $COUNT bus(es): $BUSES (se esperan B-042 y B-055)."
    bad "  Arráncalos en la máquina del backend, que sobrevivan a la terminal:"
    bad "    cd YaVieneBackend && bash scripts/demo-buses.sh --fondo"
  fi
fi

# ── 3. Base de datos recibiendo posiciones ────────────────────
echo ""
echo "▶ [3/3] Base de datos fresca..."
DB="$BACKEND_DIR/data/yaviene.db"
if [ -f "$DB" ]; then
  STALE=0
  while IFS='|' read -r BUSID TS; do
    AGE=$(( ($(date +%s) - TS/1000) ))
    if [ "$AGE" -gt 15 ]; then
      bad "Bús $BUSID: última posición hace ${AGE}s (se espera <15s)"
      STALE=1
    else
      ok "Bús $BUSID: posición hace ${AGE}s"
    fi
  done <<< "$(sqlite3 "$DB" "SELECT bus_id, timestamp FROM positions WHERE route_id='R-106';" 2>/dev/null)"
  [ "$STALE" = "0" ] && ok "DB recibiendo posiciones en tiempo real"
else
  bad "No existe $DB (¿está corriendo el backend?)"
fi

# ── Resumen ───────────────────────────────────────────────────
echo ""
echo "══════════════════════════════════════════════"
if [ "$FAIL" = "0" ]; then
  echo "  ✔ PRE-VUELO COMPLETO: todo listo para la demo"
else
  echo "  ✗ $FAIL chequeo(s) fallaron — revisa lo de arriba antes de empezar"
fi
echo "══════════════════════════════════════════════"
echo ""
echo "  (No automatizables: abre el panel y confirma 'En línea', y"
echo "   abre el pasajero y confirma que ves los 2 buses moviéndose.)"
exit "$([ "$FAIL" = "0" ] && echo 0 || echo 1)"