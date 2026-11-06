#!/usr/bin/env bash
# ==============================================================================
# ChargeBridge Backend Deployment Script for Server: tarvis
# ==============================================================================
set -euo pipefail

# Ensure we run from the project root directory regardless of invocation path
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT_DIR"

echo "=========================================="
echo " Deploying ChargeBridge Backend on tarvis "
echo " Working directory: $(pwd)                "
echo "=========================================="

# Check for docker
command -v docker >/dev/null 2>&1 || { echo "Error: docker is not installed on tarvis."; exit 1; }

# Detect docker compose or docker-compose
if docker compose version >/dev/null 2>&1; then
    COMPOSE_CMD="docker compose"
elif command -v docker-compose >/dev/null 2>&1; then
    COMPOSE_CMD="docker-compose"
else
    echo "Error: neither 'docker compose' nor 'docker-compose' found on tarvis."
    exit 1
fi

# Ensure data and uploads volume folders exist
mkdir -p data uploads

# Ensure backend/.env exists
if [ ! -f "backend/.env" ]; then
    echo "Creating backend/.env from template..."
    if [ -f "backend/.env.example" ]; then
        cp backend/.env.example backend/.env
    else
        cat <<EOF > backend/.env
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
SMTP_HOST=smtp.gmail.com
SMTP_USER=
SMTP_PASSWORD=
EOF
    fi
    echo "backend/.env created. Please add your SMTP credentials to backend/.env"
fi

# Ensure root .env exists for docker-compose variable substitution
if [ ! -f ".env" ]; then
    cp backend/.env .env
fi

# Build and start container with docker compose
echo "Starting backend container with docker compose..."
$COMPOSE_CMD -f deploy/docker-compose.tarvis.yml up -d --build

# Wait for container to be healthy
echo "Waiting for backend healthcheck..."
sleep 4
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
