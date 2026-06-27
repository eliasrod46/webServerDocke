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

echo "Levantando stack web..."
docker compose up -d --build

echo "Esperando contenedor $CONTAINER_NAME..."
for _ in $(seq 1 30); do
  if docker inspect "$CONTAINER_NAME" >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

if ! docker inspect "$CONTAINER_NAME" >/dev/null 2>&1; then
  echo "ERROR: no se encontró el contenedor $CONTAINER_NAME"
  exit 1
fi

echo "Conectando redes de backends disponibles..."
for net in "${BACKEND_NETWORKS[@]}"; do
  if docker network inspect "$net" >/dev/null 2>&1; then
    if docker network connect "$net" "$CONTAINER_NAME" 2>/dev/null; then
      echo "  OK: conectado a $net"
    else
      echo "  INFO: ya conectado a $net"
    fi
  else
    echo "  WARN: red $net no disponible, se omite"
  fi
done

echo
echo "Estado del contenedor web:"
docker ps --filter "name=$CONTAINER_NAME"
echo
echo "Últimos logs de nginx:"
docker logs "$CONTAINER_NAME" --tail 5
