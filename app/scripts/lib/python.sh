#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
#  python.sh - Python environment management for Scrapitor
# ═══════════════════════════════════════════════════════════════════════════════

# ── Result Variables (set by find_usable_python) ──────────────────────────────
PYTHON_PATH=""
PYTHON_SOURCE=""
PYTHON_VERSION=""

# ═══════════════════════════════════════════════════════════════════════════════
#  Python Detection
# ═══════════════════════════════════════════════════════════════════════════════

# Test if a Python executable works
test_python_path() {
    local python_exe="$1"
    
    if [[ ! -x "$python_exe" ]] && ! command -v "$python_exe" &>/dev/null; then
        return 1
    fi
    
    local version
    version=$("$python_exe" -c "import sys;print(sys.version)" 2>/dev/null)
    local exit_code=$?
    
    if [[ $exit_code -eq 0 ]] && [[ -n "$version" ]]; then
        return 0
    fi
    return 1
}

# Get Python version string (e.g., "3.12")
get_python_version() {
    local python_exe="$1"
    
    local version
    version=$("$python_exe" -c "import sys;print(f'{sys.version_info.major}.{sys.version_info.minor}')" 2>/dev/null)
    
    if [[ -n "$version" ]]; then
        echo "$version"
    else
        echo "unknown"
    fi
}

# Check if Python version is at least 3.10
check_python_minimum_version() {
    local python_exe="$1"
    local min_major="${2:-3}"
    local min_minor="${3:-10}"
    
    local result
    result=$("$python_exe" -c "import sys; print('ok' if sys.version_info >= ($min_major, $min_minor) else 'fail')" 2>/dev/null)
    
    [[ "$result" == "ok" ]]
}

# Find a usable Python installation
# Sets: PYTHON_PATH, PYTHON_SOURCE, PYTHON_VERSION
find_usable_python() {
    local venv_python="${1:-}"
    
    PYTHON_PATH=""
    PYTHON_SOURCE=""
    PYTHON_VERSION=""
    
    # Prefer existing venv
    if [[ -n "$venv_python" ]] && [[ -x "$venv_python" ]]; then
        if test_python_path "$venv_python"; then
            PYTHON_PATH="$venv_python"
            PYTHON_SOURCE="venv"
            PYTHON_VERSION=$(get_python_version "$venv_python")
            return 0
        fi
    fi
    
    # Try python3 first (most Linux systems)
    if command -v python3 &>/dev/null; then
        local py3_path
        py3_path=$(command -v python3)
        if test_python_path "$py3_path" && check_python_minimum_version "$py3_path"; then
            PYTHON_PATH="$py3_path"
            PYTHON_SOURCE="path"
            PYTHON_VERSION=$(get_python_version "$py3_path")
            return 0
        fi
    fi
    
    # Try python (might be python3 on some systems)
    if command -v python &>/dev/null; then
        local py_path
        py_path=$(command -v python)
        if test_python_path "$py_path" && check_python_minimum_version "$py_path"; then
            PYTHON_PATH="$py_path"
            PYTHON_SOURCE="path"
            PYTHON_VERSION=$(get_python_version "$py_path")
            return 0
        fi
    fi
    
    # Not found
    return 1
}

# ═══════════════════════════════════════════════════════════════════════════════
#  Virtual Environment Management
# ═══════════════════════════════════════════════════════════════════════════════

# Check if venv exists and is valid
test_venv_exists() {
    local venv_path="$1"
    local venv_python="${venv_path}/bin/python"
    
    [[ -x "$venv_python" ]]
}

# Create a new virtual environment
# Returns 0 on success, 1 on failure
create_python_venv() {
    local venv_path="$1"
    local python_path="$2"
    
    local output
    output=$("$python_path" -m venv "$venv_path" 2>&1)
    local exit_code=$?
    
    if [[ $exit_code -ne 0 ]]; then
        echo "$output" >&2
        return 1
    fi
    
    local venv_python="${venv_path}/bin/python"
    if [[ ! -x "$venv_python" ]]; then
        echo "Virtual environment created but python not found at expected location" >&2
        return 1
    fi
    
    return 0
}

# ═══════════════════════════════════════════════════════════════════════════════
#  Dependency Installation
# ═══════════════════════════════════════════════════════════════════════════════

# Result variables for install_python_dependencies
DEP_INSTALLED_PACKAGES=0
DEP_ALREADY_UP_TO_DATE=false
DEP_ERROR=""

# Install Python dependencies from requirements.txt
# Sets: DEP_INSTALLED_PACKAGES, DEP_ALREADY_UP_TO_DATE, DEP_ERROR
# Returns 0 on success, 1 on failure
install_python_dependencies() {
    local python_exe="$1"
    local requirements_path="$2"
    local upgrade_pip="${3:-false}"
    
    DEP_INSTALLED_PACKAGES=0
    DEP_ALREADY_UP_TO_DATE=false
    DEP_ERROR=""
    
    # Upgrade pip if requested
    if [[ "$upgrade_pip" == "true" ]]; then
        "$python_exe" -m pip install --disable-pip-version-check --no-color --upgrade pip setuptools wheel &>/dev/null || true
    fi
    
    # Install requirements
    local pip_output
    pip_output=$("$python_exe" -m pip install --disable-pip-version-check --no-color -r "$requirements_path" 2>&1)
    local exit_code=$?
    
    if [[ $exit_code -ne 0 ]]; then
        DEP_ERROR="$pip_output"
        return 1
    fi
    
    # Parse output for installed packages
    if echo "$pip_output" | grep -q "Successfully installed"; then
        # Count installed packages
        local pkg_line
        pkg_line=$(echo "$pip_output" | grep "Successfully installed" | head -n1)
        # Remove "Successfully installed " prefix and count packages
        pkg_line="${pkg_line#*Successfully installed }"
        DEP_INSTALLED_PACKAGES=$(echo "$pkg_line" | wc -w)
    else
        DEP_ALREADY_UP_TO_DATE=true
    fi
    
    return 0
}
