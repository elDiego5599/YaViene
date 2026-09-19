#!/usr/bin/env bash
# Trae el contrato del backend: las respuestas REST y los eventos de socket
# que genera tests/contrato.test.ts en YaVieneBackend. Las pruebas de las
# apps los leen de ya_viene_core/test/fixtures/contrato/.
#
#   tool/sincronizar-contrato.sh              copia los del backend aquí
#   tool/sincronizar-contrato.sh --comprobar  solo dice si hay diferencias
#
# El backend se busca al lado de este repo; YAVIENE_BACKEND lo cambia.
set -euo pipefail

raiz="$(cd "$(dirname "$0")/.." && pwd)"
backend="${YAVIENE_BACKEND:-$raiz/../YaVieneBackend}"
origen="$backend/tests/fixtures/contrato"
destino="$raiz/ya_viene_core/test/fixtures/contrato"

if [ ! -d "$origen" ]; then
  echo "No está el contrato del backend en $origen" >&2
  exit 2
fi

case "${1:-}" in
  --comprobar)
    if diff -r "$origen" "$destino" >/dev/null 2>&1; then
      echo "El contrato de las apps es el del backend."
    else
      echo "El contrato cambió en el backend: corre tool/sincronizar-contrato.sh" >&2
      diff -rq "$origen" "$destino" >&2 || true
      exit 1
    fi
    ;;
  "")
    rm -rf "$destino"
    mkdir -p "$destino"
    cp "$origen"/*.json "$destino"/
    echo "Copiados $(ls "$destino" | wc -l | tr -d ' ') archivos a $destino"
    ;;
  *)
    echo "Uso: $0 [--comprobar]" >&2
    exit 2
    ;;
esac
