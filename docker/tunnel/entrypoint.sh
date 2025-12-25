#!/bin/sh
set -eu

PORT="${PROXY_PORT:-5000}"
TARGET_HOST="${TARGET_HOST:-proxy}"
TARGET_URL="${TARGET_URL:-http://${TARGET_HOST}:${PORT}}"

FLAGS="${CLOUDFLARED_FLAGS:-}"
if [ -z "$FLAGS" ]; then
  # Match the PowerShell default: avoid HA + forced QUIC; keep info logs so URL is printed.
  FLAGS="--edge-ip-version 4 --loglevel info"
fi

STATE_DIR="${STATE_DIR:-/workspace/app/var/state}"
TUNNEL_URL_FILE="${TUNNEL_URL_FILE:-${STATE_DIR}/tunnel_url.txt}"

mkdir -p "$STATE_DIR"
rm -f "$TUNNEL_URL_FILE" || true

echo "[tunnel] Starting cloudflared quick tunnel -> ${TARGET_URL}" >&2
echo "[tunnel] Writing detected URL to: ${TUNNEL_URL_FILE}" >&2
echo "[tunnel] Flags: ${FLAGS}" >&2

# Stream logs to stdout, and when the first trycloudflare URL appears, persist it for the UI (/tunnel).
/usr/local/bin/cloudflared tunnel --no-autoupdate $FLAGS --url "$TARGET_URL" 2>&1 | while IFS= read -r line; do
  printf '%s\n' "$line"

  if [ ! -s "$TUNNEL_URL_FILE" ]; then
    url="$(printf '%s\n' "$line" | grep -Eo 'https://[A-Za-z0-9-]+\.trycloudflare\.com' | head -n1 || true)"
    if [ -n "$url" ]; then
      printf '%s' "$url" > "$TUNNEL_URL_FILE"
      printf '%s\n' "[tunnel] Detected trycloudflare URL: $url" >&2
    fi
  fi
done

