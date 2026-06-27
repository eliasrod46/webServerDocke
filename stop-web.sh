#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR"
CONTAINER_NAME="contenedroweb"

BACKEND_NETWORKS=(
  "ofipro-backend_default"
  "gestoreconomico-backend_default"
  "ecommerce-backend_internal"
)

cd "$PROJECT_DIR"

if docker inspect "$CONTAINER_NAME" >/dev/null 2>&1; then
  echo "Desconectando redes de backends..."
  for net in "${BACKEND_NETWORKS[@]}"; do
    if docker network inspect "$net" >/dev/null 2>&1; then
      if docker network disconnect "$net" "$CONTAINER_NAME" 2>/dev/null; then
        echo "  OK: desconectado de $net"
      else
        echo "  INFO: no estaba conectado a $net"
      fi
    fi
  done
else
  echo "Contenedor $CONTAINER_NAME no está corriendo, se omite desconexión de redes."
fi

echo "Deteniendo stack web..."
docker compose down

echo
echo "Verificando contenedores del stack:"
remaining="$(docker ps -a --filter "name=contenedroweb" --filter "name=certbot" --format '{{.Names}}' 2>/dev/null || true)"
if [[ -z "$remaining" ]]; then
  echo "  OK: ningún contenedor del stack activo."
else
  echo "  WARN: aún quedan contenedores:"
  echo "$remaining" | sed 's/^/    /'
fi
