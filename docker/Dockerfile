# Stage 1: Build frontend
FROM node:20-alpine AS frontend-builder

WORKDIR /frontend

# Install dependencies first (better caching)
COPY frontend/package.json frontend/package-lock.json* ./
RUN npm ci --silent 2>/dev/null || npm install --silent

# Copy source and build
COPY frontend/ ./
RUN npm run build


# Stage 2: Python runtime
FROM python:3.11-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /workspace

# Install Python deps first (better layer caching)
COPY app/requirements.txt app/requirements.txt
RUN python -m pip install --upgrade pip setuptools wheel && \
    python -m pip install -r app/requirements.txt

# App source
COPY app app

# Copy built frontend from Stage 1
# Vite outputs to ../app/static/dist relative to frontend/, which is /app/static/dist in the container
COPY --from=frontend-builder /app/static/dist app/static/dist

EXPOSE 5000

# Healthcheck is used by docker-compose depends_on: condition: service_healthy
HEALTHCHECK --interval=5s --timeout=3s --start-period=10s --retries=30 \
  CMD python -c "import os, urllib.request; p=os.environ.get('PROXY_PORT','5000'); urllib.request.urlopen('http://127.0.0.1:{}/health'.format(p), timeout=2).read()"

CMD ["python", "-m", "app.server"]
