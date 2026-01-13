#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
#  Scrapitor Launcher (Linux/macOS)
# ═══════════════════════════════════════════════════════════════════════════════

set -euo pipefail

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# ── Silent git update (if available) ──────────────────────────────────────────
if command -v git &>/dev/null && [[ -d ".git" ]]; then
    git fetch --all --tags --prune &>/dev/null || true
    git pull --rebase --autostash &>/dev/null || true
fi

# ── Check bash version ────────────────────────────────────────────────────────
# Bash 4.0+ recommended for associative arrays, but we'll work with 3.2+ (macOS default)
BASH_MAJOR="${BASH_VERSINFO[0]:-0}"
if (( BASH_MAJOR < 3 )); then
    echo ""
    echo "  ════════════════════════════════════════════════════════════"
    echo ""
    echo "    Bash 3.0+ is required but version $BASH_VERSION found."
    echo ""
    echo "    Please upgrade your bash installation."
    echo ""
    echo "  ════════════════════════════════════════════════════════════"
    echo ""
    exit 1
fi

# ── Launch Scrapitor ──────────────────────────────────────────────────────────
PROXY_SCRIPT="$SCRIPT_DIR/app/scripts/run_proxy.sh"

if [[ ! -f "$PROXY_SCRIPT" ]]; then
    echo ""
    echo "  Error: run_proxy.sh not found at: $PROXY_SCRIPT"
    echo ""
    exit 1
fi

# Make sure the script is executable
chmod +x "$PROXY_SCRIPT" 2>/dev/null || true

# Execute the main script
exec bash "$PROXY_SCRIPT"
