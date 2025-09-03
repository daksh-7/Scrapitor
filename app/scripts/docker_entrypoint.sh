#!/bin/sh
set -eu

log() {
  printf "%s\n" "$*"
}

APP_DIR="/app"
VAR_DIR="$APP_DIR/var"
STATE_DIR="$VAR_DIR/state"
LOGS_DIR="$VAR_DIR/logs"
mkdir -p "$STATE_DIR" "$LOGS_DIR"

# Resolve port from env or config.yaml
PORT="${PROXY_PORT:-}"
if [ -z "${PORT}" ] && [ -f "$APP_DIR/config.yaml" ]; then
  # Look for port under server: block
  port_line=$(awk '/^[[:space:]]*server:[[:space:]]*$/{flag=1;next} flag && /^[[:space:]]*port:[[:space:]]*[0-9]+/{print;flag=0}' "$APP_DIR/config.yaml" 2>/dev/null || true)
  if [ -n "$port_line" ]; then
    PORT=$(printf "%s" "$port_line" | sed -E 's/.*port:[[:space:]]*([0-9]+).*/\1/')
  fi
fi
if [ -z "${PORT}" ]; then PORT=5000; fi
export PROXY_PORT="$PORT"

HEALTH_TIMEOUT="${HEALTH_TIMEOUT:-30}"
TUNNEL_TIMEOUT="${TUNNEL_TIMEOUT:-120}"

export PYTHONUNBUFFERED=1
export QUIET_LOGS=1
FLASK_LOG="/tmp/flask.log"
python -m server >"$FLASK_LOG" 2>&1 &
FLASK_PID=$!

# Wait for health
start_ts=$(date +%s)
while :; do
  if curl -fsS "http://127.0.0.1:$PORT/health" >/dev/null 2>&1 || curl -fsS "http://localhost:$PORT/health" >/dev/null 2>&1; then
    break
  fi
  now=$(date +%s)
  elapsed=$(( now - start_ts ))
  if [ "$elapsed" -ge "$HEALTH_TIMEOUT" ]; then
    log "ERROR: Flask failed health within ${HEALTH_TIMEOUT}s"
    if [ -f "$FLASK_LOG" ]; then
      log "flask log (last 200 lines):"
      tail -n 200 "$FLASK_LOG" || true
    fi
    kill "$FLASK_PID" 2>/dev/null || true
    wait "$FLASK_PID" 2>/dev/null || true
    exit 1
  fi
  sleep 1
done

CF_LOG="/tmp/cloudflared.log"
# Truncate the log file but keep the same path for tail -F stability
: > "$CF_LOG"
# Force IPv4 + HTTP/2 which is often more reliable behind NAT/WSL and corporate networks
CLOUDFLARED_FLAGS=${CLOUDFLARED_FLAGS:-"--edge-ip-version 4 --protocol quic --ha-connections 2 --loglevel info"}
cloudflared tunnel --no-autoupdate $CLOUDFLARED_FLAGS --url "http://127.0.0.1:$PORT" >"$CF_LOG" 2>&1 &
CF_PID=$!
# Do not mirror cloudflared output to stdout; keep logs quiet unless troubleshooting

cleanup() {
  log "Stopping services..."
  kill "$CF_PID" 2>/dev/null || true
  kill "$FLASK_PID" 2>/dev/null || true
  wait "$CF_PID" 2>/dev/null || true
  wait "$FLASK_PID" 2>/dev/null || true
  rm -f "$CF_LOG" 2>/dev/null || true
  rm -f "$FLASK_LOG" 2>/dev/null || true
  rm -f "$STATE_DIR/tunnel_url.txt" 2>/dev/null || true
}
trap cleanup INT TERM

# Wait for tunnel URL to appear in logs
URL=""
RESTARTED=0
start_ts=$(date +%s)
while :; do
  # If cloudflared exited unexpectedly, restart it once while waiting
  if ! kill -0 "$CF_PID" 2>/dev/null; then
    log "cloudflared exited; restarting..."
    : > "$CF_LOG"
    cloudflared tunnel --no-autoupdate $CLOUDFLARED_FLAGS --url "http://127.0.0.1:$PORT" >"$CF_LOG" 2>&1 &
    CF_PID=$!
  fi
  if [ -f "$CF_LOG" ]; then
    URL=$(grep -a -oE 'https://[A-Za-z0-9-]+\.trycloudflare\.com' "$CF_LOG" 2>/dev/null | head -n1 || true)
  fi
  if [ -n "$URL" ]; then
    # Publish ASAP so UI and users can copy while verification continues
    printf "%s" "$URL" > "$STATE_DIR/tunnel_url.txt"
    # Print URLs immediately before verification
    log ""
    log "Cloudflare URL: $URL"
    log "JanitorAI API URL: $URL/openrouter-cc"
    log "(Verification in background; URL may take a few seconds to become reachable)"
    # Verify DNS/HTTP by hitting /health or root
    ok=0
    i=0
    while [ $i -lt 40 ]; do
      if curl -fsS "$URL/health" >/dev/null 2>&1 || curl -fsS "$URL" >/dev/null 2>&1; then
        ok=1; break
      fi
      i=$(( i + 1 ))
      sleep 0.5
    done
    if [ "$ok" -eq 1 ]; then
      break
    else
      if [ "$RESTARTED" -eq 0 ]; then
        # Restart cloudflared once if initial URL fails verification
        kill "$CF_PID" 2>/dev/null || true
        sleep 0.2
        : > "$CF_LOG"
        cloudflared tunnel --no-autoupdate $CLOUDFLARED_FLAGS --url "http://127.0.0.1:$PORT" >"$CF_LOG" 2>&1 &
        CF_PID=$!
        RESTARTED=1
        URL=""
        start_ts=$(date +%s)
        continue
      fi
      URL=""
    fi
  fi

  now=$(date +%s)
  elapsed=$(( now - start_ts ))
  if [ "$elapsed" -ge "$TUNNEL_TIMEOUT" ]; then
    log "ERROR: Could not get tunnel URL within ${TUNNEL_TIMEOUT}s"
    if [ -f "$CF_LOG" ]; then
      log "cloudflared log (last 200 lines):"
      tail -n 200 "$CF_LOG" || true
    fi
    cleanup
    exit 1
  fi
  sleep 1
done

# Persist URL for UI and host scripts
printf "%s" "$URL" > "$STATE_DIR/tunnel_url.txt"

log ""
log "SUCCESS! Proxy is running"
log ""
log "JanitorAI API URL: $URL/openrouter-cc"
log "Dashboard URL (Cloudflare): $URL"
log "Dashboard URL (Local): http://localhost:$PORT"
log ""
log "Press Ctrl+C to stop the server when finished"

# Keep running until any child exits
while :; do
  if ! kill -0 "$FLASK_PID" 2>/dev/null; then
    log "ERROR: Flask process exited"
    cleanup
    exit 1
  fi
  if ! kill -0 "$CF_PID" 2>/dev/null; then
    log "ERROR: cloudflared process exited"
    cleanup
    exit 1
  fi
  sleep 1
done


