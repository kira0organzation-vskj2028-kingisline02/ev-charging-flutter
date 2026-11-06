# ChargeBridge Backend Dockerfile
FROM python:3.11-slim

# Prevent Python from writing .pyc and buffer stdout/stderr
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    APP_ENV=production

WORKDIR /app

# Install system dependencies (curl for container healthcheck)
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    sqlite3 \
    && rm -rf /var/lib/apt/lists/*

# Install python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code and migrations
COPY app/ ./app/
COPY migrations/ ./migrations/
COPY seed.py .

# Create volume directories for sqlite db and uploads
RUN mkdir -p /app/data /app/uploads

# Set default persistent volume paths
ENV DB_PATH=/app/data/chargebridge.db \
    UPLOAD_DIR=/app/uploads

EXPOSE 8000

# Health check using the /health endpoint
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

# Start Uvicorn with proxy headers enabled for reverse proxy support
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", "--proxy-headers", "--forwarded-allow-ips=*"]

