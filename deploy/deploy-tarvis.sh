#!/usr/bin/env bash
# ==============================================================================
# ChargeBridge Backend Deployment Script for Server: tarvis
# ==============================================================================
set -euo pipefail

echo "=========================================="
echo " Deploying ChargeBridge Backend on tarvis "
echo "=========================================="

# Check for docker and docker-compose
command -v docker >/dev/null 2>&1 || { echo "Error: docker is not installed on tarvis."; exit 1; }

# Ensure data and uploads volume folders exist
mkdir -p data uploads

env_file:
  - path: ../backend/.env
    required: false
  - path: ../.env
    required: false
  - path: ./.env
    required: false

# Check if .env exists, if not copy example
if [ ! -f .env ]; then
    echo "Creating .env from template..."
    cat <<EOF > .env
APP_ENV=production
DB_PATH=/app/data/chargebridge.db
UPLOAD_DIR=/app/uploads
CORS_ORIGINS=*
JWT_SECRET=$(openssl rand -hex 32 2>/dev/null || echo "chargebridge-secure-random-jwt-secret-key-32chars")
ACCESS_TOKEN_MINUTES=15
REFRESH_TOKEN_DAYS=30
COMMISSION_PERCENT=12
RAZORPAY_KEY_ID=
RAZORPAY_KEY_SECRET=
RAZORPAY_WEBHOOK_SECRET=
GEMINI_API_KEY=
SENTRY_DSN=
SMTP_HOST=
SMTP_USER=
SMTP_PASSWORD=
EOF
    echo ".env created. Please edit .env with your Razorpay/Gemini credentials if needed."
fi

# Build and start container with docker compose
echo "Starting backend container with docker compose..."
docker compose -f deploy/docker-compose.tarvis.yml up -d --build

# Wait for container to be healthy
echo "Waiting for backend healthcheck..."
sleep 5
for i in {1..10}; do
    if docker exec chargebridge-backend curl -sf http://localhost:8000/health >/dev/null 2>&1; then
        echo "Backend is healthy and running!"
        break
    fi
    echo "Waiting for service to become healthy ($i/10)..."
    sleep 3
done

# Run database seed if tables are empty
echo "Checking database seed..."
docker exec chargebridge-backend python seed.py || true

echo "=========================================="
echo " Backend deployed successfully on tarvis! "
echo " API running at: http://$(hostname -I | awk '{print $1}'):8000"
echo " Docs at: http://$(hostname -I | awk '{print $1}'):8000/docs"
echo "=========================================="

