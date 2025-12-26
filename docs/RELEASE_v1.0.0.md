# Scrapitor v1.0.0

**Release Date:** September 16, 2025

The initial release of Scrapitor — a local JanitorAI proxy and structured log parser with a web dashboard.

---

## Features

### Proxy Gateway
- Drop-in `/chat/completions`-style endpoint at `/openrouter-cc`
- Forwards requests to OpenRouter with full streaming support
- Supports client-side or server-side API key configuration

### One-Click Cloudflare Tunnel
- Automatic public URL via `cloudflared` quick tunnel
- Tunnel URL displayed in dashboard and available at `GET /tunnel`
- Works with both Windows launcher and Docker

### Request Capture
- Captures JanitorAI request payloads into portable JSON logs
- Automatic timestamped log files in `app/var/logs/`
- Rolling log limit with automatic pruning (configurable via `MAX_LOG_FILES`)

### Parser System
- Rule-driven, tag-aware extraction for clean character sheets
- **Default mode:** Write all content without filtering
- **Custom mode:** Include-only (whitelist) or omit (blacklist) tags
- Tag detection from logs
- Versioned exports (`.v1.txt`, `.v2.txt`, etc.) with version navigation
- Untagged content support for cards without creator-chosen tags

### Web Dashboard
- View recent activity and request logs
- Copy endpoints (Cloudflare and local)
- Parser settings with tag chips for Include/Exclude toggling
- Inline renaming for JSON logs
- Delete logs and parsed files
- Caching for improved performance

### Windows Launcher (`run.bat`)
- Creates virtual environment and installs dependencies
- Builds Svelte frontend if Node.js is available
- Starts Flask server and Cloudflare tunnel
- Prints dashboard URLs (local and public)
- Auto-updates `cloudflared` if needed

### Docker Support
- Docker Compose with two containers:
  - `proxy` — Flask server
  - `tunnel` — Cloudflare tunnel with URL detection
- Cross-platform alternative for macOS/Linux users

---

## Configuration

Environment variables for customization:

| Variable | Default | Description |
|----------|---------|-------------|
| `PROXY_PORT` | `5000` | Flask server port |
| `OPENROUTER_URL` | OpenRouter API | Upstream API URL |
| `OPENROUTER_API_KEY` | *(empty)* | Optional server-side key |
| `MAX_LOG_FILES` | `1000` | Max JSON logs to keep |
| `LOG_LEVEL` | `INFO` | Python logging level |

---

## Bug Fixes (Included in v1)

- Fixed DNS poisoning vulnerability
- Critical security fixes
- Fixed tag detection
- Fixed inline renaming
- Improved caching
- DNS resolution grace period
- Silent crash recovery
- Window crash on `run.bat` opening
- Path fixes for Windows
- Auto-update fixes for `cloudflared`

---

## Installation

### Windows (Recommended)
1. Download ZIP from [GitHub](https://github.com/daksh-7/Scrapitor) or clone:
   ```powershell
   git clone https://github.com/daksh-7/Scrapitor
   ```
2. Run `Scrapitor\run.bat`

### Docker
```bash
docker compose up --build
```

---

## Links

- [Documentation](https://github.com/daksh-7/Scrapitor/blob/main/docs/README.md)
- [Report Issues](https://github.com/daksh-7/Scrapitor/issues)

