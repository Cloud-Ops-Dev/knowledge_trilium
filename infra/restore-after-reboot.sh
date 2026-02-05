#!/bin/bash
# Post-reboot restore script for Vikunja + TriliumNext
# Created after podman system reset wiped all containers
# Run this after rebooting to free port 3011
#
# Usage: ./restore-after-reboot.sh

set -e

# Fix D-Bus address if needed (rootless podman requirement)
export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u)/bus"

echo "=== Post-Reboot Restore: Vikunja + TriliumNext ==="
echo ""

# -------------------------------------------------------
# Phase 1: Restore Vikunja
# -------------------------------------------------------
echo "--- Phase 1: Restoring Vikunja ---"

VIKUNJA_SCRIPT="/home/clayton/IDE/workstation/vikunja/scripts/podman-start.sh"
if [ ! -f "$VIKUNJA_SCRIPT" ]; then
    echo "ERROR: Vikunja start script not found at $VIKUNJA_SCRIPT"
    exit 1
fi

bash "$VIKUNJA_SCRIPT"

echo ""
echo "Verifying Vikunja..."
sleep 3
if curl -sf http://localhost:48060/api/v1/info | jq -e .version > /dev/null 2>&1; then
    echo "Vikunja is UP: $(curl -s http://localhost:48060/api/v1/info | jq -r .version)"
else
    echo "WARNING: Vikunja health check failed. It may still be starting up."
    echo "Check manually: curl -s http://localhost:48060/api/v1/info | jq ."
fi

echo ""

# -------------------------------------------------------
# Phase 2: Restore TriliumNext on port 3011
# -------------------------------------------------------
echo "--- Phase 2: Restoring TriliumNext ---"

# Check if port 3011 is free (should be after reboot)
if ss -tlnp | grep -q ':3011 '; then
    echo "ERROR: Port 3011 is still in use!"
    echo "Something is occupying port 3011. Check with: ss -tlnp | grep 3011"
    echo ""
    echo "Falling back to port 3012..."
    TRILIUM_PORT=3012
else
    TRILIUM_PORT=3011
fi

TRILIUM_DATA="/home/clayton/IDE/containers/trilium"
if [ ! -d "$TRILIUM_DATA" ]; then
    echo "ERROR: Trilium data directory not found at $TRILIUM_DATA"
    exit 1
fi

echo "Creating TriliumNext container on port ${TRILIUM_PORT}..."
podman run -d \
    --name trilium \
    --restart unless-stopped \
    -p 0.0.0.0:${TRILIUM_PORT}:8080 \
    -v ${TRILIUM_DATA}:/home/node/trilium-data:Z \
    -e TRILIUM_DATA_DIR=/home/node/trilium-data \
    docker.io/triliumnext/notes:latest

echo ""
echo "Waiting for TriliumNext to start..."
sleep 5

if curl -sf http://localhost:${TRILIUM_PORT}/ > /dev/null 2>&1; then
    echo "TriliumNext is UP on port ${TRILIUM_PORT}"
else
    echo "TriliumNext may still be starting. Check: curl -s http://localhost:${TRILIUM_PORT}/"
fi

echo ""

# -------------------------------------------------------
# Summary
# -------------------------------------------------------
echo "=== Restore Complete ==="
echo ""
podman ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
echo ""
echo "Next steps:"
echo "  1. Open TriliumNext: http://localhost:${TRILIUM_PORT}/"
echo "  2. Set up password on first access"
echo "  3. Generate ETAPI token: Options > ETAPI in web UI"
echo "  4. Export token: export TRILIUM_API_TOKEN=<token>"
echo "  5. Bootstrap OpenClaw root note:"
echo "     cd /home/clayton/IDE/openclaw/projects/knowledge_trilium"
echo "     node tools/trilium-etapi.mjs ensure-openclaw-root"
echo ""
echo "Access from laptop (via Tailscale):"
echo "  Vikunja:    http://100.123.87.32:48060/"
echo "  TriliumNext: http://100.123.87.32:${TRILIUM_PORT}/"
