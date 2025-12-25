FROM alpine:3.20

ARG TARGETARCH

ENV PROXY_PORT=5000 \
    STATE_DIR=/workspace/app/var/state \
    TUNNEL_URL_FILE=/workspace/app/var/state/tunnel_url.txt

RUN apk add --no-cache ca-certificates curl

# Install cloudflared (arch-aware when BuildKit provides TARGETARCH; defaults to amd64)
RUN set -eux; \
    arch="${TARGETARCH:-amd64}"; \
    case "$arch" in \
      amd64) url="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64" ;; \
      arm64) url="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64" ;; \
      arm)   url="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm" ;; \
      *) echo "Unsupported TARGETARCH=$arch" >&2; exit 1 ;; \
    esac; \
    curl -fsSL "$url" -o /usr/local/bin/cloudflared; \
    chmod +x /usr/local/bin/cloudflared; \
    cloudflared --version

COPY docker/tunnel/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]

