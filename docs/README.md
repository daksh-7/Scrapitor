# scrapitor

Local JanitorAI proxy and structured log parser with a dashboard. It launches a Flask gateway that proxies JanitorAI traffic to OpenRouter, automatically saves every request as a JSON log, and can convert those logs into clean character sheets (TXT) using a rule-driven parser. Run it via the **Windows launcher (`run.bat`) (recommended)** or via Docker Compose.

If you prefer the shortest path, jump to [Installation](#installation) or [Casual Usage](#casual-usage).

## Table of Contents

- [Features](#features)
- [Directory Structure](#directory-structure)
- [Installation](#installation)
- [Casual Usage](#casual-usage)
- [Usage in Janitor](#usage-in-janitor)
- [How It Works](#how-it-works)
- [Docker (Alternative)](#docker-alternative)
- [Installation (Manual)](#installation-manual)
- [Web Dashboard](#web-dashboard)
- [Parser (Rules and CLI)](#parser-rules-and-cli)
- [Parser Usage (In-Depth)](#parser-usage-in-depth)
- [API Usage](#api-usage)
- [HTTP Endpoints](#http-endpoints)
- [Configuration](#configuration)
- [Troubleshooting](#troubleshooting)
- [Development](#development)
- [Notes](#notes)

## Features

- Proxy Gateway: Drop-in `/chat/completions`-style endpoint at `/openrouter-cc` forwarding to OpenRouter with streaming support.
- One-Click Tunnel (Docker or Windows): Brings up a Cloudflare quick tunnel (`cloudflared`) and exposes a public URL; the dashboard reads it from `app/var/state/tunnel_url.txt` (also available at `GET /tunnel`).
- Request Capture: Captures (scrapes) JanitorAI request payloads into portable JSON logs for repeatable processing and auditing.
- Sophisticated Parsing: Rule-driven, tag-aware extraction with include/omit and strip options; ideal for producing clean character sheets.
- Full Customization: Include-only (whitelist) or omit (blacklist) modes, tag detection from logs, add-your-own tags, and chip-based toggling.
- Versioned Exports: Every write is versioned (`.vN.txt`) with a version picker for quick navigation and comparisons.
- Web Dashboard: Modern Svelte 5 SPA with reactive state management. View recent activity, copy endpoints, manage parser settings, detect tags, write outputs, and rename logs/exports inline.


## Directory Structure

```
Scrapitor/
├── app/                          # Flask backend
│   ├── parser/                   # Parser logic
│   │   ├── __init__.py
│   │   └── parser.py
│   ├── scripts/                  # Launcher scripts
│   │   ├── docker_entrypoint.sh
│   │   └── run_proxy.ps1
│   ├── static/
│   │   ├── assets/               # Favicons, logos, manifest
│   │   └── dist/                 # Svelte build output (generated)
│   ├── __init__.py
│   ├── requirements.txt
│   └── server.py
│
├── frontend/                     # Svelte 5 SPA source
│   ├── src/
│   │   ├── lib/
│   │   │   ├── api/              # Typed API client (client.ts, types.ts)
│   │   │   ├── components/       # Reusable UI components (11 components)
│   │   │   └── stores/           # Svelte 5 runes state (logs, parser, ui)
│   │   ├── routes/               # Page components (Overview, Parser, Activity)
│   │   ├── App.svelte            # Root component with layout & routing
│   │   ├── main.ts               # Entry point
│   │   └── app.css               # Global design system & utilities
│   ├── public/assets/            # Static assets (logo)
│   ├── index.html                # SPA entry HTML with Geist font
│   ├── package.json
│   ├── vite.config.ts
│   └── tsconfig.json
│
├── docker/
│   ├── Dockerfile
│   └── tunnel/
│       ├── Dockerfile
│       └── entrypoint.sh
│
├── docs/
│   └── README.md
│
├── docker-compose.yml
├── .dockerignore
├── .gitignore
└── run.bat                       # Windows launcher
```

Runtime directories are created under `Scrapitor/app/var/`:

- Logs: `app/var/logs/` (JSON logs) and `app/var/logs/parsed/<json_stem>/` (TXT exports)
- State: `app/var/state/` (e.g., `tunnel_url.txt`, `parser_settings.json`)


## Installation

1) Download the repository:

- Option A: Download ZIP from GitHub: `https://github.com/daksh-7/Scrapitor` → Code → Download ZIP → Unzip anywhere.
- Option B: Clone via Git:

```powershell
winget install git.git
git clone https://github.com/daksh-7/Scrapitor
```

2) Install prerequisites:

- PowerShell 7 (`pwsh`). Install with:

```powershell
winget install --id Microsoft.PowerShell -e --accept-package-agreements --accept-source-agreements
```

- Python 3.10+ in PATH. Download for Windows: https://www.python.org/downloads/ (During setup, enable "Add python.exe to PATH").
- Optionally Node.js 18+ to rebuild the frontend.

3) Run the launcher:

- Double-click `Scrapitor\run.bat`.

The launcher will:

- Create a local virtual environment `Scrapitor/app/.venv` and install `requirements.txt`.
- Build the Svelte frontend if Node.js is available and the build is missing or outdated.
- Start the Flask server on the configured port (default 5000) and verify health.
- Install or download `cloudflared` if needed, start a tunnel, and print the public URL.
- Print both the dashboard URLs (local and Cloudflare) in the console.

Copy the "JanitorAI API URL" shown in the console or the UI (it ends with `/openrouter-cc`). You will use it in JanitorAI's proxy settings.

**Alternative**: If you prefer Docker, see [Docker (Alternative)](#docker-alternative).


## Casual Usage

1) Start scrapitor:

- Option A (recommended): Download ZIP from `https://github.com/daksh-7/Scrapitor`, unzip, then run `Scrapitor\run.bat`.
- Option B (Docker alternative): `docker compose up --build` then open `http://localhost:5000/` (or `http://localhost:<PROXY_PORT>/` if you changed `PROXY_PORT`).

2) In the dashboard "Setup" section, copy the "Cloudflare Endpoint" and the "Model Name Preset".
3) Follow the steps in [Usage in Janitor](#usage-in-janitor) to wire JanitorAI to your Cloudflare endpoint.
4) Send a message in JanitorAI; your request appears in "Activity".
5) Optionally open "Parser", choose Default or Custom, and click "Write" to export a TXT version.


## Usage in Janitor

Use these six steps inside JanitorAI's UI (exactly as shown in the app):

- Initiate a chat with the desired character on JanitorAI.
- Click "using proxy"; under "proxy", add a configuration and name it anything.
- For model name, paste: `mistralai/devstral-2512:free`
- Paste the Cloudflare URL (copied above) under "Proxy URL."
- Enter your OpenRouter API key in the "API Key" section. If you don't have an OpenRouter API Key, follow these steps:
  - Log in to [openrouter.ai](https://openrouter.ai).
  - Click your profile picture (top-right) and open "Keys".
  - Click "Create API Key".
  - Copy the key.
- Click "Save changes" then "Save Settings" and refresh the page.
- Enter any sample message (e.g., "hi"); the app will then receive the model data.


## How It Works

- The Flask app exposes `/openrouter-cc` and an alias `/chat/completions`. POST your OpenAI-style chat payload here.
- Authorization: If you set `OPENROUTER_API_KEY`, the server uses it; otherwise the client's `Authorization` header is forwarded.
- Logging: Each request payload is saved to `var/logs/<timestamp>.json` (old files are pruned by a rolling limit).
- Parsing: On each saved log (and on demand), the parser writes a TXT export per character, versioned as `<Character Name>.vN.txt`.
- Tunnel: `cloudflared` publishes a public URL; the dashboard displays both local and public endpoints.
- Frontend: A Svelte 5 SPA with TypeScript, compiled to static assets served by Flask. Features reactive state management, component-based architecture, and automatic log prefetching.


## Docker (Alternative)

Cross-platform alternative using Docker. Use this if you prefer containerized deployment or are on macOS/Linux.

Prerequisites:

- Docker Desktop installed and running.

Run with Docker Compose:

```
docker compose up --build
```

This starts **two containers**:

- **`proxy`**: runs the Flask server (`python -m app.server`).
- **`tunnel`**: runs `cloudflared tunnel --url http://proxy:$PROXY_PORT`, detects the first `*.trycloudflare.com` URL from logs, and writes it to `app/var/state/tunnel_url.txt` (so the UI can display it via `GET /tunnel`).

Proxy only (no public tunnel):

```
docker compose up --build proxy
```

Manual Docker compose commands:

```
docker compose down
docker compose up
```

After launch, copy the Cloudflare endpoint shown and proceed to [Usage in Janitor](#usage-in-janitor).

Useful commands:

```
docker compose logs -f tunnel
docker compose logs -f proxy
```

Environment variables (use a `.env` file at the repo root, or set them in your shell):

- `PROXY_PORT`: Flask port (default `5000`)
- `OPENROUTER_API_KEY`: optional server-side key (otherwise the client `Authorization` header is forwarded)
- `ALLOW_SERVER_API_KEY`: set `true` to allow using `OPENROUTER_API_KEY` server-side (default `false`)
- `CLOUDFLARED_FLAGS`: extra cloudflared flags (default is `--edge-ip-version 4 --loglevel info`)


## Installation (Manual)

If you prefer not to use the Windows launcher:

Prerequisites

- Python 3.10+ in PATH
- Node.js 18+ (to build the frontend)
- `cloudflared` installed (for a public URL) or use local only

Setup

```bash
cd Scrapitor

# Backend
python -m venv app\.venv
app\.venv\Scripts\pip install --upgrade pip
app\.venv\Scripts\pip install -r app\requirements.txt

# Frontend (requires Node.js)
cd frontend
npm install
npm run build
cd ..

# Run
app\.venv\Scripts\python -m app.server
```

Cloudflare tunnel (in another terminal):

```
cloudflared tunnel --no-autoupdate --url http://127.0.0.1:5000
```

On macOS/Linux, adjust venv paths accordingly:

```bash
python3 -m venv app/.venv
source app/.venv/bin/activate
pip install -r app/requirements.txt

cd frontend && npm install && npm run build && cd ..

python -m app.server
cloudflared tunnel --no-autoupdate --url http://127.0.0.1:5000
```


## Web Dashboard

The dashboard is a Svelte 5 Single Page Application with TypeScript:

- **Overview**: Shows total requests, log count, parsed file count, and server port.
- **Setup**: Copy the Model Name Preset and your Cloudflare/Local endpoints.
- **Parser**: Choose Default (no filtering) or Custom (Include/Exclude tags), auto-detect tags from logs, and write outputs.
- **Activity**: Browse recent logs, open raw JSON, rename files, and view/rename parsed TXT versions. Features automatic prefetching of recent logs for instant loading.


## Parser (Rules and CLI)

The parser is designed for Janitor/character logs and implements these rules:

1) Replace literal `\n` with real newlines.
2) Drop JSON/role metadata; parse text only.
3) Remove tag blocks matching an omit list (case-insensitive). In custom include mode, keep only specified tags.
4) From the first system message, pick the first non-skipped tag as the character name; include its content. Omit user messages; include the first assistant message under "First Message".
5) Include `<Scenario>…</Scenario>` from the first system message if present (subject to the same filters).
6) Save as `<Character Name>.txt` (server uses a per-request version suffix like `.v3.txt`).

CLI usage (`Scrapitor/app/parser/parser.py`):

```
# Default parse (no removals), auto-writes next to each JSON
python app/parser/parser.py path/to/log.json

# Omit tags (blacklist)
python app/parser/parser.py --preset custom --omit-tags scenario,system path/to/log.json

# Include only selected tags (whitelist)
python app/parser/parser.py --preset custom --include-tags persona,scenario path/to/log.json

# Remove only tag markers (keep inner content)
python app/parser/parser.py --preset custom --strip-tags scenario path/to/log.json

# Control outputs
python app/parser/parser.py --output-dir out --suffix v1 path/to/log.json
```

Filtering is case-insensitive. The server exposes this functionality through the dashboard, persists settings, and runs the parser automatically on new logs.


## Parser Usage (In-Depth)

This section describes the full parser workflow and UI dynamics in the dashboard.

- Modes: Use Default to write character content, Scenario (if present), and First Message without filtering. Use Custom to control which tags are written (Include set) or omitted (Exclude set). If Include has any tags, the output contains only those sections; otherwise Exclude removes listed tags.
- Settings Persistence: Parser settings are saved under `app/var/state/parser_settings.json` and reapplied on next launch.
- Tag Chips: Each tag appears as a chip in the Parser panel. Click to toggle Include ↔ Exclude. "Select All" toggles all chips to Include; "Clear All" sets all to Exclude. You can also add new tags via the input and Add button.
- Tag Detection: "Detect Tags (Latest)" scans the latest log to discover tags. "Detect Tags (From Logs…)" lets you pick one or more logs to detect tags from. Detected tags are merged into chips.
- Tag Hover Highlighting: Hovering a tag chip highlights matching logs in the Activity list. If a tag only appears in a subset of the current detection scope, only those logs are highlighted; otherwise all logs remain unhighlighted. This helps identify logs where the tag is exclusive.
- Writing Outputs (Write): Click "Write" to open options. "Write Latest" writes a parsed TXT for the most recent JSON log. "Custom Selection…" allows selecting multiple logs from Activity and then "Write Selected".
- Write Logic: Each write uses your current Parser settings. In Include mode, only explicitly included items are written (e.g., include `first_message` to emit the First Message; include `scenario` to emit Scenario). In Exclude mode (default behavior if Include is empty), everything is written except omitted tags. The character's name is taken from the first non-skipped tag in the first system message.
- Version Control for TXT: Every time a log is written, the server stores the resulting TXT under `var/logs/parsed/<json_stem>/` and appends a version suffix like `.v3.txt`. The latest version is surfaced in the UI.
- TXT Navigation: In Activity, each log row shows a "TXT" button. Click it to open a version picker modal listing all parsed TXT files for that log, with size and modified time. Click a version to preview its contents.
- Renaming Logs: Click the pencil icon next to a log name to rename its underlying JSON (and move the corresponding parsed directory to match the new name). Inline edit appears in place; Cancel or Save.
- Renaming TXT Versions: In the TXT version picker modal, click the pencil icon next to a TXT entry to rename the parsed file inline.


## API Usage

Quick examples using curl.

Basic non-streaming request against local server:

```bash
curl -sS \
  -H 'Content-Type: application/json' \
  -H 'Authorization: Bearer <OPENROUTER_API_KEY>' \
  -d '{
        "model": "mistralai/devstral-2512:free",
        "messages": [ {"role": "user", "content": "hi"} ],
        "stream": false
      }' \
  http://localhost:5000/openrouter-cc
```

Server-Sent Events (streaming) response:

```bash
curl -sS -N \
  -H 'Content-Type: application/json' \
  -H 'Authorization: Bearer <OPENROUTER_API_KEY>' \
  -d '{
        "model": "mistralai/devstral-2512:free",
        "messages": [ {"role": "user", "content": "hi"} ],
        "stream": true
      }' \
  http://localhost:5000/openrouter-cc
```

Notes:

- If `OPENROUTER_API_KEY` is not set on the server, include a valid `Authorization: Bearer ...` header from the client.
- The server automatically logs each request and (by default) writes a parsed TXT version according to current parser settings.

## HTTP Endpoints

- `GET /openrouter-cc`: Health/info for the proxy route.
- `POST /openrouter-cc`: OpenAI-style chat payloads; streams if `stream=true`.
- `POST /chat/completions`: Alias to `/openrouter-cc`.
- `GET /models`: Minimal compatibility list.
- `GET|POST /param`: View/update generation defaults (`temperature`, `top_p`, `top_k`, `max_tokens`).
- `GET /logs`: List recent JSON logs.
- `GET /logs/<name>`: Retrieve a raw log.
- `GET /logs/<name>/parsed`: List TXT versions for a log.
- `GET /logs/<name>/parsed/<file>`: Read a TXT version.
- `POST /logs/<name>/rename`: Rename a JSON log (and moves its parsed folder).
- `POST /logs/<name>/parsed/rename`: Rename a TXT export.
- `GET /parser-settings` | `POST /parser-settings`: Get/set parser mode and tag lists.
- `POST /parser-rewrite`: Rewrite latest/all or selected logs with current settings.
- `GET /parser-tags`: Detect tags from latest or selected logs.
- `GET /tunnel`: Cloudflare public URL (if available).
- `GET /health`: Basic health and port.


## Configuration

Configuration is done via environment variables. Set them in your shell, a `.env` file at the repo root (for Docker Compose), or via your deployment platform.

Environment variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `PROXY_PORT` | `5000` | Port for the Flask server |
| `OPENROUTER_URL` | `https://openrouter.ai/api/v1/chat/completions` | Upstream API URL |
| `OPENROUTER_API_KEY` | *(empty)* | Optional server-side key; if unset, client `Authorization` is forwarded |
| `ALLOW_SERVER_API_KEY` | `false` | Set `true` to allow using `OPENROUTER_API_KEY` server-side |
| `ALLOWED_ORIGINS` | `*` | CSV of CORS origins |
| `LOG_DIR` | `var/logs` | Log directory |
| `MAX_LOG_FILES` | `1000` | Max number of JSON logs to keep |
| `LOG_LEVEL` | `INFO` | Python logging level |
| `CONNECT_TIMEOUT` | `5.0` | Upstream connection timeout (seconds) |
| `READ_TIMEOUT` | `300.0` | Upstream read timeout (seconds) |


## Troubleshooting

- No Cloudflare URL appears:
  - Docker: check `docker compose logs -f tunnel` and ensure your network/firewall allows outbound connections.
  - Windows launcher: ensure `cloudflared` is installed and not blocked by firewall. The launcher can install it via `winget` or download the latest release.
- Script exits with "PowerShell 7 is required": Install PowerShell 7 with the winget command above, then re-run `run.bat`.
- Port already in use: Set `PROXY_PORT` to a free port, or stop the conflicting process.
- 502 from OpenRouter: Verify your `Authorization` is present in the request or set `OPENROUTER_API_KEY` on the server.
- CORS/Browser errors: The server is permissive by default; ensure your client is calling the Cloudflare URL as shown in the UI.
- Parser output missing fields: Adjust Include/Exclude tags or use "Detect Tags" to discover available tags, then "Write" again.
- TryCloudflare URL shows an NGINX error page:
  - In your browser, enable Secure DNS/DoH and choose Cloudflare (1.1.1.1).
  - Or set DNS on Windows: Control Panel > Network and Internet > Network and Sharing Center > Change adapter settings > right-click your active adapter > Properties > select "Internet Protocol Version 4 (TCP/IPv4)" > Properties > choose "Use the following DNS server addresses" and set Preferred DNS server to 1.1.1.1 and Alternate DNS server to 8.8.8.8 > OK.
  - Optional: also set IPv6 DNS to 2606:4700:4700::1111 and 2001:4860:4860::8888.
  - Finally, run `ipconfig /flushdns` in an elevated Command Prompt.
- Frontend not loading: Run `cd frontend && npm install && npm run build` to rebuild the Svelte app, then restart the server.


## Development

### Backend

```bash
cd Scrapitor
python -m venv app\.venv
app\.venv\Scripts\pip install -r app\requirements.txt
app\.venv\Scripts\python -m app.server
```

### Frontend

The dashboard is built with **Svelte 5**, **TypeScript**, and **Vite**:

```bash
cd frontend

# Install dependencies
npm install

# Development server with hot reload (runs on port 5173, proxies API to Flask)
npm run dev

# Production build (outputs to ../app/static/dist/)
npm run build

# Type check
npm run check
```

**Architecture:**

| Directory | Purpose |
|-----------|---------|
| `src/lib/api/` | Typed API client (`client.ts`, `types.ts`, `index.ts`) |
| `src/lib/stores/` | Svelte 5 runes state: `logsStore` (log data/cache), `parserStore` (tag settings), `uiStore` (endpoints/notifications) |
| `src/lib/components/` | 11 reusable components: `Icon`, `Modal`, `ConfirmModal`, `Section`, `MetricCard`, `TagChip`, `LogItem`, `Sidebar`, `Topbar`, `Notification` |
| `src/routes/` | Page components: `Overview` (dashboard/endpoints), `Parser` (tag filtering), `Activity` (log browser) |
| `src/App.svelte` | Root component with layout, polling, and client-side routing |
| `src/app.css` | Design system with CSS variables, utility classes, modal styles, and animations |


## Notes

- scrapitor is not affiliated with JanitorAI or OpenRouter.
- Cloudflare tunnels expose a public URL; treat it like any internet-facing service.
- Important: This project is for educational and personal use only. Always respect platform Terms of Service and creator rights. Before downloading, exporting, or distributing any character card or derivative content, you must mandatorily first obtain permission from the character/bot creator and consult JanitorAI moderators as applicable.
