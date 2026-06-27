#!/usr/bin/env bash
# Reparación CasaOS en el HOST del VPS (no dentro de contenedroweb).
# Ejecutar como root: sudo bash fix-casaos.sh
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log()  { echo -e "${GREEN}[casaos-fix]${NC} $*"; }
warn() { echo -e "${YELLOW}[casaos-fix]${NC} $*"; }
err()  { echo -e "${RED}[casaos-fix]${NC} $*" >&2; }

if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  err "Ejecutá como root: sudo bash fix-casaos.sh"
  exit 1
fi

# --- Fase 1: Diagnóstico ---
log "=== Fase 1: Diagnóstico ==="
docker version || true
casaos -v 2>/dev/null || casaos-cli -v 2>/dev/null || warn "casaos-cli no encontrado"
ss -tlnp | grep -E ':8181\b' || warn "CasaOS no escucha en 8181"
log "Últimos logs casaos-app-management:"
journalctl -u casaos-app-management -n 30 --no-pager 2>/dev/null || warn "servicio casaos-app-management no encontrado"

API_ERROR=$(journalctl -u casaos-app-management -n 100 --no-pager 2>/dev/null | grep -c "client version.*too old" || true)
if [[ "$API_ERROR" -gt 0 ]]; then
  warn "Detectada incompatibilidad Docker API (client too old)"
fi

# --- Fase 2: Fix Docker API ---
log "=== Fase 2: Fix Docker API ==="
mkdir -p /etc/systemd/system/docker.service.d
cat > /etc/systemd/system/docker.service.d/override.conf <<'EOF'
[Service]
Environment=DOCKER_MIN_API_VERSION=1.24
EOF
log "Creado /etc/systemd/system/docker.service.d/override.conf"
systemctl daemon-reload
systemctl restart docker
sleep 3
if ! docker ps >/dev/null 2>&1; then
  err "Docker no responde tras el reinicio"
  exit 1
fi
log "Docker OK: $(systemctl show docker | grep DOCKER_MIN_API || echo 'override aplicado')"

# --- Fase 3: Reiniciar CasaOS ---
log "=== Fase 3: Reiniciar servicios CasaOS ==="
for svc in casaos-app-management casaos casaos-gateway casaos-message-bus casaos-user-service casaos-local-storage; do
  if systemctl list-unit-files | grep -q "^${svc}.service"; then
    systemctl restart "$svc" && log "  reiniciado: $svc" || warn "  falló: $svc"
  fi
done

sleep 2
log "Logs post-reinicio:"
journalctl -u casaos-app-management -n 15 --no-pager 2>/dev/null || true

# --- Fase 4: Actualizar CasaOS ---
log "=== Fase 4: Actualizar CasaOS (script oficial) ==="
if curl -fsSL https://get.casaos.io | bash; then
  log "Instalador CasaOS completado"
else
  warn "Instalador falló o fue interrumpido; continuando con verificación"
fi

systemctl restart docker
sleep 2
for svc in casaos-app-management casaos casaos-gateway casaos-message-bus casaos-user-service; do
  systemctl restart "$svc" 2>/dev/null || true
done

# --- Fase 5: Apps antiguas v1 ---
log "=== Fase 5: Apps antiguas (v1) ==="
warn "Las apps en 'Aplicación antigua (por reconstruir)' deben migrarse a v2 desde la UI."
warn "En CasaOS: menú ... de cada app → Reconstruir/Rebuild"
echo ""
log "Contenedores Docker actuales:"
docker ps -a --format 'table {{.Names}}\t{{.Status}}\t{{.Image}}' | head -40
echo ""

# Helper: gestionar contenedores v1 por CLI mientras se migran
migrate_helper="$(dirname "$0")/docker-apps-helper.sh"
if [[ -f "$migrate_helper" ]]; then
  log "Helper docker disponible: bash docker-apps-helper.sh {list|start|stop} [nombre]"
fi

log "Contenedores detenidos (candidatos a 'docker start'):"
docker ps -a --filter status=exited --format '  {{.Names}}' | head -20 || true
echo ""
log "Si una app aparece en CasaOS pero no en docker ps -a, desinstalala desde la UI."

# --- Fase 6: Verificación ---
log "=== Fase 6: Verificación ==="
CASAOS_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:8181/ 2>/dev/null || echo "000")
log "CasaOS local :8181 → HTTP $CASAOS_CODE"

V1_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:8181/v1/container 2>/dev/null || echo "000")
log "API /v1/container (sin token) → HTTP $V1_CODE (esperado: 401)"

API_ERR_AFTER=$(journalctl -u casaos-app-management -n 50 --no-pager 2>/dev/null | grep -c "client version.*too old" || true)
if [[ "$API_ERR_AFTER" -eq 0 ]]; then
  log "Sin errores de API incompatible en logs recientes"
else
  warn "Aún hay errores de API incompatible; revisá: journalctl -u casaos-app-management -f"
fi

if docker ps --filter name=contenedroweb --format '{{.Names}}' 2>/dev/null | grep -q contenedroweb; then
  NGINX_ERR=$(docker logs contenedroweb --tail 10 2>&1 | grep -c "host.docker.internal could not be resolved" || true)
  if [[ "$NGINX_ERR" -eq 0 ]]; then
    log "Nginx contenedroweb: sin errores host.docker.internal"
  else
    warn "Nginx aún tiene errores host.docker.internal; revisá docker logs contenedroweb"
  fi
fi

log "=== Listo ==="
log "Abrí https://gestionvps.eliasrodriguezdev.com.ar y hacé Ctrl+Shift+R"
log "Reconstruí cada app antigua desde la UI para poder iniciar/parar."
