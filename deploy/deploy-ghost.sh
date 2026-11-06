#!/usr/bin/env bash
# ==============================================================================
# ChargeBridge Frontend Deployment Script for Server: ghost (Port 4001)
# Web server: Caddy (No Nginx)
# Target for Cloudflare Tunnel: http://localhost:4001
# ==============================================================================
set -euo pipefail

echo "=========================================="
echo " Starting ChargeBridge Frontend on ghost "
echo " Port: 4001 (Cloudflare Tunnel target)    "
echo " Web Server: Caddy (No Nginx)             "
echo "=========================================="

command -v docker >/dev/null 2>&1 || { echo "Error: docker is not installed on ghost."; exit 1; }

# Verify deploy/web directory exists
if [ ! -d "deploy/web" ] || [ ! -f "deploy/web/index.html" ]; then
    echo "Error: deploy/web/index.html not found."
    echo "Please ensure you have pulled the repository or built Flutter Web."
    exit 1
fi

# Launch Caddy container on port 4001
echo "Starting Caddy container on port 4001..."
docker compose -f deploy/docker-compose.ghost.yml up -d

echo "=========================================="
echo " Frontend is up and running on ghost!     "
echo " Local URL: http://localhost:4001         "
echo "                                          "
echo " In your Cloudflare Tunnel config, set:   "
echo "   Service URL: http://localhost:4001     "
echo "=========================================="
