FROM python:3.11-slim AS base

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PROXY_PORT=5000

RUN apt-get update -y && \
    apt-get install -y --no-install-recommends ca-certificates curl jq && \
    rm -rf /var/lib/apt/lists/*

# Install cloudflared (linux-amd64)
ARG TARGETARCH
RUN set -eux; \
    arch="${TARGETARCH:-amd64}"; \
    case "$arch" in \
      amd64)  url="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64" ;; \
      arm64)  url="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64" ;; \
      arm)    url="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm" ;; \
      *)      url="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64" ;; \
    esac; \
    curl -fsSL -o /usr/local/bin/cloudflared "$url"; \
    chmod +x /usr/local/bin/cloudflared; \
    /usr/local/bin/cloudflared --version || true

WORKDIR /app

# Copy requirements and install first for better layer caching
COPY app/requirements.txt /app/requirements.txt
RUN python -m pip install --upgrade pip setuptools wheel && \
    pip install -r /app/requirements.txt

# Copy application code
COPY app /app

# Ensure runtime dirs exist
RUN mkdir -p /app/var/logs /app/var/state

# Copy docker entrypoint
COPY app/scripts/docker_entrypoint.sh /usr/local/bin/docker_entrypoint.sh
RUN chmod +x /usr/local/bin/docker_entrypoint.sh

EXPOSE 5000

HEALTHCHECK --interval=10s --timeout=3s --retries=10 \
  CMD curl -fsS http://127.0.0.1:${PROXY_PORT}/health || exit 1

ENTRYPOINT ["/usr/local/bin/docker_entrypoint.sh"]


