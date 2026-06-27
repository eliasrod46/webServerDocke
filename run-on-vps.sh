#!/usr/bin/env bash
# Copiá y pegá ESTE BLOQUE COMPLETO en la consola root del VPS (vps-5939725-x):
#
# cd /opt/webServer && git pull origin main && bash fix-casaos.sh
#
# O en una sola línea sin git:
# curl -fsSL https://raw.githubusercontent.com/eliasrod46/webServerDocke/main/fix-casaos.sh | bash
#
# Después de migrar apps v1 en la UI, para start/stop por CLI:
# bash /opt/webServer/docker-apps-helper.sh list
# bash /opt/webServer/docker-apps-helper.sh start NOMBRE_CONTENEDOR

echo "Ejecutá en el VPS como root:"
echo "  cd /opt/webServer && git pull origin main && bash fix-casaos.sh"
