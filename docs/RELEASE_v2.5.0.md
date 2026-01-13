# Scrapitor 2.5.0 Release Notes

**Release Date:** January 13, 2026

---

## Overview

This release adds native Linux, macOS, and Termux (Android) support with a fully-featured bash launcher that mirrors all functionality of the Windows PowerShell scripts. Run Scrapitor anywhere with a single command.

---

## What's Changed

### Native Linux/macOS Launcher

A complete bash-based launcher system that provides feature parity with the Windows PowerShell implementation:

- **One-Command Startup** — Run `./run.sh` to launch everything automatically
  - Creates virtual environment and installs Python dependencies
  - Downloads cloudflared binary if not installed (architecture-aware)
  - Builds frontend if Node.js is available and sources changed
  - Starts Flask server and Cloudflare tunnel
  - Interactive TUI with live status and Q to quit

- **Modular Architecture** — Clean separation of concerns in `app/scripts/lib/`:
  - `ui.sh` — Terminal UI with colors, spinners, banners, and Unicode detection
  - `config.sh` — Configuration management and `.env` file loading
  - `python.sh` — Python detection, venv creation, pip dependency installation
  - `process.sh` — Process lifecycle management and health checks
  - `tunnel.sh` — Cloudflared detection, installation, and URL extraction

- **Cross-Platform Compatibility** — Works on:
  - Linux (Ubuntu, Debian, Fedora, Arch, etc.)
  - macOS (Intel and Apple Silicon)
  - Windows Subsystem for Linux (WSL)
  - Termux on Android

### Termux (Android) Support

Run Scrapitor directly on your Android device:

- **Automatic Detection** — Script detects Termux environment and shows helpful tips
- **Wake-Lock Reminder** — Prompts to run `termux-wake-lock` to prevent background killing
- **ARM64 Cloudflared** — Downloads correct binary for Android ARM64 devices
- **LAN IP Detection** — Uses Android's `getprop` to find WiFi IP address
- **Process Management** — Falls back to `netstat` when `lsof`/`ss` unavailable

Quick start:
```bash
pkg install python git curl
git clone https://github.com/daksh-7/Scrapitor && cd Scrapitor
./run.sh
```

### macOS Compatibility Fixes

Several fixes to ensure scripts work on macOS's default bash 3.2:

- **Bash 3.2 Compatible** — Removed `${var,,}` syntax (bash 4+ only)
  - Uses `tr '[:upper:]' '[:lower:]'` for case conversion
- **Portable grep** — Replaced `grep -P` (Perl regex) with `awk` pipelines
  - macOS BSD grep doesn't support `-P` flag
- **Process Detection** — Added `netstat` fallback for port detection
  - Works when `lsof`, `fuser`, and `ss` are unavailable

### Improved Process Management

More robust and safer process handling:

- **Specific Process Matching** — Tightened patterns to avoid killing unrelated processes
  - Cloudflared pattern now includes `tunnel` command and exact port
  - Flask pattern now matches `.venv/bin/python` specifically
- **Graceful Cleanup** — Guards against uninitialized variables on early signals
- **Array-Based Arguments** — Cloudflared args now use proper bash arrays
  - Fixes word-splitting issues with custom `CLOUDFLARED_FLAGS`

### Dependency Checks

Early validation with helpful error messages:

- **curl Required** — Script checks for curl at startup with install instructions
  - Shows platform-specific install commands (apt, dnf, brew, pkg)
- **Python 3.10+** — Validates minimum Python version before proceeding

---

## New Files

| File | Description |
|------|-------------|
| `run.sh` | Entry point launcher for Linux/macOS/Termux |
| `app/scripts/run_proxy.sh` | Main orchestrator (bash equivalent of `run_proxy.ps1`) |
| `app/scripts/lib/ui.sh` | Terminal UI components |
| `app/scripts/lib/config.sh` | Configuration and .env loading |
| `app/scripts/lib/python.sh` | Python/venv management |
| `app/scripts/lib/process.sh` | Process lifecycle and health checks |
| `app/scripts/lib/tunnel.sh` | Cloudflared management |

---

## Technical Notes

- Minimum bash version: 3.2 (macOS default)
- Minimum Python version: 3.10
- Supported architectures: amd64, arm64, armv7
- Cloudflared auto-download from GitHub releases
- No breaking changes to backend, API, or data formats
- Windows PowerShell scripts unchanged and fully supported

---

## Documentation Updates

- Added "Quick Start (Linux/macOS)" section to README
- Added "Quick Start (Termux/Android)" section to README
- Added detailed "Termux (Android)" installation guide
- Added Termux-specific troubleshooting entries
- Updated project structure to show new bash scripts

---

## Full Changelog

`v2.2.0...v2.5.0`
