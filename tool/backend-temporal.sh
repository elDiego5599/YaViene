# Levanta un backend de usar y tirar con una empresa, una ruta y un bus, y
# deja en el entorno con qué entrar. Se carga con `source` desde
# `prueba-socket-panel.sh` (T8.6) y `e2e-panel.sh`; no se corre solo.
#
# Deja definidas: url, usuario, contrasena, clave_api, empresa y token.
#
# Nada de esto toca el backend vivo ni su base: arranca uno aparte, en un
# puerto propio y sobre una base temporal que se borra al salir. El usuario
# y la contraseña del panel se inventan en cada corrida y mueren con ella:
# la cuenta de prueba del dueño no entra aquí ni en la CI.
#
# El backend se busca al lado de este repo; YAVIENE_BACKEND lo cambia.
# PUERTO_HTTP y PUERTO_MQTT cambian los puertos.

raiz="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
backend="${YAVIENE_BACKEND:-$raiz/../YaVieneBackend}"

if [ ! -d "$backend" ]; then
  echo "No está el backend en $backend" >&2
  exit 2
fi

puerto_http="${PUERTO_HTTP:-3411}"
puerto_mqtt="${PUERTO_MQTT:-8911}"
base="$(mktemp -d)/panel.db"
url="http://127.0.0.1:$puerto_http"

# Secretos de usar y tirar. `openssl rand` viene con macOS y con los runners
# de GitHub; la contraseña pasa de los 12 caracteres que exige el script de
# alta. No se imprimen: sólo viajan a este backend temporal.
clave_api="$(openssl rand -hex 16)"
jwt="$(openssl rand -hex 32)"
usuario="panel-$(openssl rand -hex 4)"
contrasena="$(openssl rand -hex 16)"
empresa="EMP-PRUEBA"

pid=""
limpiar() {
  [ -n "$pid" ] && kill "$pid" 2>/dev/null || true
  rm -rf "$(dirname "$base")"
}
trap limpiar EXIT

# Un backend de una corrida anterior que siguiera vivo contestaría por este
# puerto con SU base: el de ahora no podría ni levantarse y la prueba se
# haría contra datos ajenos sin avisar. Mejor negarse a empezar.
if command -v lsof >/dev/null 2>&1 && lsof -ti "tcp:$puerto_http" >/dev/null 2>&1; then
  echo "El puerto $puerto_http está ocupado; libéralo antes de correr esto" >&2
  exit 2
fi

# `exec` es lo que hace que $! sea el node y no el subshell que lo envuelve:
# sin eso, al salir se mataba la cáscara y el backend quedaba suelto en el
# puerto, que es justo lo que revisa el bloque de arriba.
(
  cd "$backend"
  exec env \
    YA_VIENE_DB_PATH="$base" \
    HTTP_PORT="$puerto_http" \
    MQTT_PORT="$puerto_mqtt" \
    JWT_SECRET="$jwt" \
    ADMIN_API_KEY="$clave_api" \
    YA_VIENE_FLOTA_DEMO=0 \
    MQTT_DEBUG_LOGS=false \
    node --import tsx src/index.ts
) >/dev/null 2>&1 &
pid=$!

# Esperar a que conteste, sin `sleep` a ciegas.
for _ in $(seq 1 150); do
  if curl -fsS "$url/api/ready" >/dev/null 2>&1; then break; fi
  sleep 0.2
done
if ! curl -fsS "$url/api/ready" >/dev/null 2>&1; then
  echo "El backend temporal no arrancó en 30 s" >&2
  exit 1
fi

# El backend abre la base la primera vez que alguien se la pide, no al
# arrancar: `/api/ready` contesta con el archivo todavía sin crear, y el
# script de alta se encontraba una base vacía. Una lectura pública cualquiera
# la abre y con ella crea las tablas.
curl -fsS "$url/api/companies" >/dev/null

# La cuenta se crea escribiendo en la base, no por HTTP: el limitador del
# admin deja 20 altas por minuto y esto no es lo que se está probando.
# La contraseña va por CLAVE_PANEL y «-» en su sitio: el script ya no la
# acepta como argumento (quedaría a la vista en `ps`, P3-3).
(cd "$backend" && YA_VIENE_DB_PATH="$base" CLAVE_PANEL="$contrasena" \
  node scripts/crear-admin-empresa.mjs "$empresa" "$usuario" - "Empresa de prueba") >/dev/null

token="$(curl -fsS -X POST "$url/api/admin/login" \
  -H 'Content-Type: application/json' \
  -d "{\"username\":\"$usuario\",\"password\":\"$contrasena\",\"apiKey\":\"$clave_api\"}" \
  | python3 -c 'import json,sys; print(json.load(sys.stdin)["token"])')"

# La flota demo va apagada (sus doce buses son de otra empresa y ensucian el
# log), así que la empresa empieza sin buses y `fleet:batch` llegaría vacío.
# Uno basta para lo que se prueba: que el panel entra con su token y recibe
# la flota de su empresa. Va en una ruta del catálogo de la empresa (P1-2:
# una ruta ajena da 404), y la empresa nueva empieza sin ninguna. R-901
# porque el id de ruta es único entre empresas: R-101 ya es de otra (409).
curl -fsS -X POST "$url/api/fleet/routes" \
  -H 'Content-Type: application/json' \
  -H "Authorization: Bearer $token" \
  -d '{"routeId":"R-901","name":"Ruta de prueba"}' >/dev/null
curl -fsS -X POST "$url/api/fleet/buses" \
  -H 'Content-Type: application/json' \
  -H "Authorization: Bearer $token" \
  -d '{"placa":"ABC123","routeId":"R-901","interno":"1"}' >/dev/null
