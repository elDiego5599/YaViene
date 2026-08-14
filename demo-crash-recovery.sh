#!/bin/bash
# demo-crash-recovery.sh — Beat de caos para la demo:
#   1) Mata el backend en vivo (SIGTERM, SIGKILL de respaldo)
#   2) Lo reinicia con el MISMO entorno y la MISMA base de datos
#   3) Verifica que el stack se recupera SOLO:
#      - /api/ready responde
#      - los simuladores de buses se reconectan solos (MQTT + login)
#      - las posiciones vuelven a ser frescas por el socket
#
# Uso: ./demo-crash-recovery.sh
# Ensayado contra el backend en vivo (PID de dist/index.js en :3000).

set -u

BACKEND_DIR="$HOME/YaViene/YaVieneBackend"
HEALTH_URL="http://localhost:3000/api/ready"
LOG_FILE=/tmp/yaviene-backend.log
ENV_FILE=/tmp/yaviene-backend-env.env

find_pid() {
  lsof -ti :3000 2>/dev/null | head -1
}

snapshot_env() {
  local pid="$1"
  : > "$ENV_FILE"
  chmod 600 "$ENV_FILE"
  ps eww -p "$pid" 2>/dev/null | tr ' ' '\n' | \
    grep -E '^(JWT_SECRET|ADMIN_API_KEY|DEMO_MODE|YA_VIENE|HTTP_|MQTT_|NODE_ENV)=' >> "$ENV_FILE"
  if [ ! -s "$ENV_FILE" ]; then
    echo "  (sin env del proceso: usando local.env)"
    if [ -f "$BACKEND_DIR/local.env" ]; then
      grep -E '^(JWT_SECRET|ADMIN_API_KEY|DEMO_MODE)=' "$BACKEND_DIR/local.env" >> "$ENV_FILE"
    fi
  fi
  echo "  env capturado: $(wc -l < "$ENV_FILE") variables"
}

wait_ready() {
  local deadline=$((SECONDS + 20))
  while [ $SECONDS -lt $deadline ]; do
    if curl -sf --max-time 2 "$HEALTH_URL" > /dev/null 2>&1; then
      return 0
    fi
    sleep 0.5
  done
  return 1
}

echo "== Demo Chaos: matando el backend =="
PID=$(find_pid)
if [ -z "$PID" ]; then
  echo "ERROR: no hay backend en :3000 — no hay nada que matar."
  exit 1
fi
echo "  backend: PID $PID ($(ps -p "$PID" -o command= | cut -c1-60))"
snapshot_env "$PID"

kill "$PID"
for _ in $(seq 1 20); do
  [ -z "$(find_pid)" ] && break
  sleep 0.5
done
if [ -n "$(find_pid)" ]; then
  echo "  no murió con SIGTERM, SIGKILL de respaldo"
  kill -9 "$PID"
  sleep 1
fi
echo "  puerto 3000 liberado: $([ -z "$(find_pid)" ] && echo SÍ || echo NO)"

echo "== Demo Chaos: reiniciando con el mismo entorno =="
cd "$BACKEND_DIR" || exit 1
env $(tr '\n' ' ' < "$ENV_FILE") nohup node dist/index.js >> "$LOG_FILE" 2>&1 &
NEW_PID=$!
echo "  nuevo backend: PID $NEW_PID (log: $LOG_FILE)"

if wait_ready; then
  echo "  /api/ready OK"
else
  echo "  ERROR: el backend no arrancó — revisa $LOG_FILE"
  exit 1
fi

echo "== Verificando auto-recuperación de los simuladores =="
node -e '
const { io } = require("socket.io-client");
const s = io("http://localhost:3000", { path: "/ws", transports: ["websocket"], reconnection: true, reconnectionDelay: 500 });
const seen = {};
const timer = setTimeout(() => {
  const ok = Object.keys(seen).length > 0 && Object.values(seen).every((v) => v.freshnessSec < 60);
  console.log("  buses en vivo tras el reinicio:", JSON.stringify(seen));
  console.log(ok ? "  AUTO-RECUPERACIÓN: SÍ — el stack se arregló solo" : "  AUTO-RECUPERACIÓN: NO — revisar simuladores");
  process.exit(ok ? 0 : 2);
}, 25000);
s.on("connect", () => { s.emit("subscribe:route", "R-106"); });
s.on("bus:position", (p) => { seen[p.busId] = { freshnessSec: Math.round((Date.now() - new Date(p.timestamp).getTime())/1000) }; });
s.on("positions:batch", (b) => { if (b.buses) for (const x of b.buses) seen[x.busId] = { freshnessSec: Math.round((Date.now() - new Date(x.timestamp).getTime())/1000) }; });
' || exit $?

echo "== Listo: el beat de caos dura ~20 s y termina con el stack recuperado =="