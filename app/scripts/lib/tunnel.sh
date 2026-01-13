#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
#  tunnel.sh - Cloudflared tunnel management for Scrapitor
# ═══════════════════════════════════════════════════════════════════════════════

# ── Result Variables ──────────────────────────────────────────────────────────
CLOUDFLARED_PATH=""
CLOUDFLARED_SOURCE=""

# ═══════════════════════════════════════════════════════════════════════════════
#  Detection
# ═══════════════════════════════════════════════════════════════════════════════

# Find cloudflared binary
# Sets: CLOUDFLARED_PATH, CLOUDFLARED_SOURCE
# Returns 0 if found, 1 if not
find_cloudflared() {
    local script_dir="${1:-}"
    
    CLOUDFLARED_PATH=""
    CLOUDFLARED_SOURCE=""
    
    # Check local script directory first
    if [[ -n "$script_dir" ]]; then
        local local_path="${script_dir}/cloudflared"
        if [[ -x "$local_path" ]]; then
            CLOUDFLARED_PATH="$local_path"
            CLOUDFLARED_SOURCE="local"
            return 0
        fi
    fi
    
    # Check PATH
    if command -v cloudflared &>/dev/null; then
        CLOUDFLARED_PATH=$(command -v cloudflared)
        CLOUDFLARED_SOURCE="path"
        return 0
    fi
    
    return 1
}

# Test if cloudflared is installed
test_cloudflared_installed() {
    local script_dir="${1:-}"
    find_cloudflared "$script_dir"
}

# ═══════════════════════════════════════════════════════════════════════════════
#  Installation
# ═══════════════════════════════════════════════════════════════════════════════

# Detect system architecture
get_system_arch() {
    local arch
    arch=$(uname -m)
    
    case "$arch" in
        x86_64|amd64)
            echo "amd64"
            ;;
        aarch64|arm64)
            echo "arm64"
            ;;
        armv7l|armhf)
            echo "arm"
            ;;
        *)
            echo ""
            ;;
    esac
}

# Detect OS type
get_system_os() {
    local os
    os=$(uname -s | tr '[:upper:]' '[:lower:]')
    
    case "$os" in
        linux)
            echo "linux"
            ;;
        darwin)
            echo "darwin"
            ;;
        *)
            echo ""
            ;;
    esac
}

# Check if running in Termux
is_termux() {
    [[ -n "${TERMUX_VERSION:-}" ]] || [[ -d "/data/data/com.termux" ]]
}

# Install cloudflared via Termux package manager
# Returns 0 on success, 1 on failure
install_cloudflared_termux() {
    if command -v pkg &>/dev/null; then
        if pkg install cloudflared -y &>/dev/null; then
            if command -v cloudflared &>/dev/null; then
                CLOUDFLARED_PATH=$(command -v cloudflared)
                CLOUDFLARED_SOURCE="pkg"
                return 0
            fi
        fi
    fi
    return 1
}

# Install cloudflared via direct download
# Returns 0 on success, 1 on failure
install_cloudflared() {
    local target_dir="$1"
    
    # Termux: GitHub binaries are NOT compatible (non-PIE)
    # Must install via pkg instead
    if is_termux; then
        if install_cloudflared_termux; then
            return 0
        fi
        echo "Termux detected. Install cloudflared with: pkg install cloudflared" >&2
        return 1
    fi
    
    local arch
    arch=$(get_system_arch)
    if [[ -z "$arch" ]]; then
        echo "Unsupported architecture: $(uname -m)" >&2
        return 1
    fi
    
    local os
    os=$(get_system_os)
    if [[ -z "$os" ]]; then
        echo "Unsupported OS: $(uname -s)" >&2
        return 1
    fi
    
    local url=""
    local dest="${target_dir}/cloudflared"
    
    if [[ "$os" == "darwin" ]]; then
        # macOS uses .tgz archive
        case "$arch" in
            amd64)
                url="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-darwin-amd64.tgz"
                ;;
            arm64)
                url="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-darwin-arm64.tgz"
                ;;
        esac
        
        if [[ -n "$url" ]]; then
            # Download and extract
            local temp_file
            temp_file=$(mktemp)
            if curl -fsSL "$url" -o "$temp_file" 2>/dev/null; then
                if tar -xzf "$temp_file" -C "$target_dir" cloudflared 2>/dev/null; then
                    chmod +x "$dest"
                    rm -f "$temp_file"
                    CLOUDFLARED_PATH="$dest"
                    CLOUDFLARED_SOURCE="download"
                    return 0
                fi
            fi
            rm -f "$temp_file"
        fi
    else
        # Linux uses direct binary
        url="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-${os}-${arch}"
        
        if curl -fsSL "$url" -o "$dest" 2>/dev/null; then
            chmod +x "$dest"
            CLOUDFLARED_PATH="$dest"
            CLOUDFLARED_SOURCE="download"
            return 0
        fi
    fi
    
    return 1
}

# Try to install via package manager (best effort)
install_cloudflared_via_package_manager() {
    # Try Homebrew (macOS)
    if command -v brew &>/dev/null; then
        if brew install cloudflared &>/dev/null; then
            if command -v cloudflared &>/dev/null; then
                CLOUDFLARED_PATH=$(command -v cloudflared)
                CLOUDFLARED_SOURCE="brew"
                return 0
            fi
        fi
    fi
    
    # Note: apt/dnf require sudo, so we skip automatic installation
    # and fall back to direct download instead
    
    return 1
}

# ═══════════════════════════════════════════════════════════════════════════════
#  Tunnel Operations
# ═══════════════════════════════════════════════════════════════════════════════

# Get cloudflared arguments for quick tunnel
get_cloudflared_args() {
    local port="$1"
    local custom_flags="${2:-}"
    
    local args=("tunnel" "--no-autoupdate")
    
    if [[ -n "$custom_flags" ]]; then
        # Split custom flags by whitespace
        read -ra extra_args <<< "$custom_flags"
        args+=("${extra_args[@]}")
    else
        # Fast defaults: avoid HA + forced QUIC (can delay startup on some networks)
        args+=("--edge-ip-version" "4" "--loglevel" "info")
    fi
    
    args+=("--url" "http://127.0.0.1:${port}")
    
    echo "${args[@]}"
}

# Wait for tunnel URL to appear in logs
# Returns 0 on success (URL found), 1 on timeout/failure
# Sets: TUNNEL_URL
TUNNEL_URL=""

wait_for_tunnel_url() {
    local log_out="$1"
    local log_err="$2"
    local timeout_seconds="${3:-120}"
    local process_pid="${4:-}"
    
    TUNNEL_URL=""
    
    local start_time
    start_time=$(date +%s)
    local end_time=$((start_time + timeout_seconds))
    
    local url_pattern='https://[A-Za-z0-9-]+\.trycloudflare\.com'
    
    while (( $(date +%s) < end_time )); do
        # Check if process died
        if [[ -n "$process_pid" ]] && ! kill -0 "$process_pid" 2>/dev/null; then
            return 1
        fi
        
        # Check stdout log
        if [[ -f "$log_out" ]] && [[ -s "$log_out" ]]; then
            local url
            url=$(grep -oE "$url_pattern" "$log_out" 2>/dev/null | head -n1)
            if [[ -n "$url" ]]; then
                TUNNEL_URL="$url"
                return 0
            fi
        fi
        
        # Check stderr log
        if [[ -f "$log_err" ]] && [[ -s "$log_err" ]]; then
            local url
            url=$(grep -oE "$url_pattern" "$log_err" 2>/dev/null | head -n1)
            if [[ -n "$url" ]]; then
                TUNNEL_URL="$url"
                return 0
            fi
        fi
        
        sleep 0.3
    done
    
    return 1
}

# Save tunnel URL to file
save_tunnel_url() {
    local path="$1"
    local url="$2"
    
    printf '%s' "$url" > "$path" 2>/dev/null || return 1
    return 0
}
