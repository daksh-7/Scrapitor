#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
#  config.sh - Configuration management for Scrapitor
# ═══════════════════════════════════════════════════════════════════════════════

# ── Configuration Variables ───────────────────────────────────────────────────
# These will be set by get_scrapitor_config()

# Paths
CONFIG_APP_ROOT=""
CONFIG_REPO_ROOT=""
CONFIG_VAR_DIR=""
CONFIG_LOGS_DIR=""
CONFIG_STATE_DIR=""
CONFIG_VENV_PATH=""
CONFIG_VENV_PYTHON=""
CONFIG_PID_FILE=""
CONFIG_TUNNEL_URL_FILE=""
CONFIG_FRONTEND_DIR=""
CONFIG_SPA_DIST_DIR=""

# Settings
CONFIG_PORT=5000
CONFIG_TUNNEL_TIMEOUT=120
CONFIG_HEALTH_TIMEOUT=30
CONFIG_VERBOSE=false
CONFIG_AUTO_INSTALL=true
CONFIG_ATTACH_CONSOLE=true

# State
_CONFIG_LOADED=false
_ENV_LOADED=false

# ═══════════════════════════════════════════════════════════════════════════════
#  .env File Loading
# ═══════════════════════════════════════════════════════════════════════════════

load_dotenv() {
    local repo_root="$1"
    
    if [[ "$_ENV_LOADED" == "true" ]]; then
        return 0
    fi
    
    local env_file="${repo_root}/.env"
    if [[ ! -f "$env_file" ]]; then
        return 0
    fi
    
    while IFS= read -r line || [[ -n "$line" ]]; do
        # Trim whitespace
        line="${line#"${line%%[![:space:]]*}"}"
        line="${line%"${line##*[![:space:]]}"}"
        
        # Skip empty lines and comments
        [[ -z "$line" ]] && continue
        [[ "$line" =~ ^# ]] && continue
        
        # Parse KEY=VALUE
        if [[ "$line" =~ ^([A-Za-z_][A-Za-z0-9_]*)=(.*)$ ]]; then
            local key="${BASH_REMATCH[1]}"
            local value="${BASH_REMATCH[2]}"
            
            # Trim whitespace from value
            value="${value#"${value%%[![:space:]]*}"}"
            value="${value%"${value##*[![:space:]]}"}"
            
            # Remove surrounding quotes if present
            if [[ "$value" =~ ^\"(.*)\"$ ]] || [[ "$value" =~ ^\'(.*)\'$ ]]; then
                value="${BASH_REMATCH[1]}"
            fi
            
            # Only set if not already defined (env vars take precedence)
            if [[ -z "${!key:-}" ]]; then
                export "$key=$value"
            fi
        fi
    done < "$env_file"
    
    _ENV_LOADED=true
}

# ═══════════════════════════════════════════════════════════════════════════════
#  Environment Variable Helpers
# ═══════════════════════════════════════════════════════════════════════════════

# Get environment variable with default
get_env() {
    local name="$1"
    local default="${2:-}"
    echo "${!name:-$default}"
}

# Get boolean environment variable
get_env_bool() {
    local name="$1"
    local default="${2:-false}"
    local value="${!name:-$default}"
    
    # Convert to lowercase (bash 3.2 compatible)
    local value_lower
    value_lower=$(printf '%s' "$value" | tr '[:upper:]' '[:lower:]')
    
    case "$value_lower" in
        1|true|yes|on) echo "true" ;;
        *) echo "false" ;;
    esac
}

# Get integer environment variable
get_env_int() {
    local name="$1"
    local default="${2:-0}"
    local value="${!name:-$default}"
    
    # Validate it's an integer
    if [[ "$value" =~ ^[0-9]+$ ]]; then
        echo "$value"
    else
        echo "$default"
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
#  Configuration Loading
# ═══════════════════════════════════════════════════════════════════════════════

get_scrapitor_config() {
    local app_root="$1"
    local repo_root="$2"
    
    if [[ "$_CONFIG_LOADED" == "true" ]]; then
        return 0
    fi
    
    # Load .env file first (env vars still take precedence)
    load_dotenv "$repo_root"
    
    # Load from environment variables
    CONFIG_PORT=$(get_env_int "PROXY_PORT" 5000)
    CONFIG_TUNNEL_TIMEOUT=$(get_env_int "TUNNEL_TIMEOUT" 120)
    CONFIG_HEALTH_TIMEOUT=$(get_env_int "HEALTH_TIMEOUT" 30)
    CONFIG_VERBOSE=$(get_env_bool "SCRAPITOR_VERBOSE" "false")
    CONFIG_AUTO_INSTALL=$(get_env_bool "SCRAPITOR_AUTO_INSTALL" "true")
    
    # Compute paths
    CONFIG_APP_ROOT="$app_root"
    CONFIG_REPO_ROOT="$repo_root"
    CONFIG_VAR_DIR="${app_root}/var"
    CONFIG_LOGS_DIR="${CONFIG_VAR_DIR}/logs"
    CONFIG_STATE_DIR="${CONFIG_VAR_DIR}/state"
    CONFIG_VENV_PATH="${app_root}/.venv"
    CONFIG_VENV_PYTHON="${CONFIG_VENV_PATH}/bin/python"
    CONFIG_PID_FILE="${CONFIG_STATE_DIR}/pids.txt"
    CONFIG_TUNNEL_URL_FILE="${CONFIG_STATE_DIR}/tunnel_url.txt"
    CONFIG_FRONTEND_DIR="${repo_root}/frontend"
    CONFIG_SPA_DIST_DIR="${app_root}/static/dist"
    
    _CONFIG_LOADED=true
}

# ═══════════════════════════════════════════════════════════════════════════════
#  Directory Initialization
# ═══════════════════════════════════════════════════════════════════════════════

init_directories() {
    mkdir -p "$CONFIG_VAR_DIR" 2>/dev/null || true
    mkdir -p "$CONFIG_LOGS_DIR" 2>/dev/null || true
    mkdir -p "$CONFIG_STATE_DIR" 2>/dev/null || true
}

# ═══════════════════════════════════════════════════════════════════════════════
#  Runtime Environment Setup
# ═══════════════════════════════════════════════════════════════════════════════

set_runtime_environment() {
    # Ensure Flask uses the same port
    export PROXY_PORT="$CONFIG_PORT"
    
    # Unbuffered Python output
    export PYTHONUNBUFFERED="1"
}
