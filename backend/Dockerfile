# ChargeBridge Backend Dockerfile
FROM python:3.11-slim

# Prevent Python from writing .pyc and buffer stdout/stderr
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    APP_ENV=production

WORKDIR /app

# Install python dependencies
# Note: python:3.11-slim includes SQLite in stdlib; wheels are downloaded directly without needing apt packages.
COPY requirements.txt .
RUN pip install --no-cache-dir --default-timeout=100 -r requirements.txt

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

# Health check using Python's built-in urllib (no external curl package needed)
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
    CMD python3 -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/health', timeout=4)" || exit 1

# Start Uvicorn with proxy headers enabled for reverse proxy support
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", "--proxy-headers", "--forwarded-allow-ips=*"]

