#!/usr/bin/env bash
# Gestión temporal de contenedores mientras las apps v1 de CasaOS no responden en la UI.
# Uso: sudo bash docker-apps-helper.sh list|start|stop|restart NOMBRE
set -euo pipefail

cmd="${1:-list}"
name="${2:-}"

case "$cmd" in
  list)
    docker ps -a --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
    ;;
  start|stop|restart)
    [[ -n "$name" ]] || { echo "Uso: $0 $cmd NOMBRE_CONTENEDOR"; exit 1; }
    docker "$cmd" "$name"
    docker ps -a --filter "name=^${name}$" --format '{{.Names}}: {{.Status}}'
    ;;
  *)
    echo "Uso: $0 {list|start|stop|restart} [nombre]"
    exit 1
    ;;
esac
