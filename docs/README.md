# scrapitor

Local JanitorAI proxy and structured log parser with a dashboard. It launches a Flask gateway that proxies JanitorAI traffic to OpenRouter, automatically saves every request as a JSON log, and can convert those logs into clean character sheets (TXT) using a rule-driven parser. A one-click Windows launcher provisions a Cloudflare tunnel for easy external access.

If you prefer the shortest path, jump to [Casual Usage](#casual-usage).

## Table of Contents

- [Features](#features)
- [Directory Structure](#directory-structure)
- [Installation](#installation)
- [Casual Usage](#casual-usage)
- [Usage in Janitor](#usage-in-janitor)
- [How It Works](#how-it-works)
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
- One-Click Tunnel: PowerShell script auto-installs dependencies and brings up a Cloudflare tunnel; exposes a public URL.
- Request Capture: Captures (scrapes) JanitorAI request payloads into portable JSON logs for repeatable processing and auditing.
- Sophisticated Parsing: Rule-driven, tag-aware extraction with include/omit and strip options; ideal for producing clean character sheets.
- Full Customization: Include-only (whitelist) or omit (blacklist) modes, tag detection from logs, add-your-own tags, and chip-based toggling.
- Versioned Exports: Every write is versioned (`.vN.txt`) with a version picker for quick navigation and comparisons.
- Web Dashboard: View recent activity, copy endpoints, manage parser settings, detect tags, write outputs, and rename logs/exports inline.


## Directory Structure

```
./
└── Scrapitor
    ├── app
    │   ├── parser
    │   │   ├── __init__.py
    │   │   └── parser.py
    │   ├── scripts
    │   │   └── run_proxy.ps1
    │   ├── static
    │   │   ├── css
    │   │   │   └── app.css
    │   │   └── js
    │   │       └── app.js
    │   ├── templates
    │   │   ├── base.html
    │   │   └── index.html
    │   ├── __init__.py
    │   ├── requirements.txt
    │   └── server.py
    ├── docker
    │   └── Dockerfile
    ├── docker-compose.yml
    ├── .gitignore
    └── run.bat
```

Runtime directories are created under `Scrapitor/app/var/`:

- Logs: `Scrapitor/app/var/logs/` (JSON logs) and `Scrapitor/app/var/logs/parsed/<json_stem>/` (TXT exports)
- State: `Scrapitor/app/var/state/` (e.g., `tunnel_url.txt`, `parser_settings.json`)


## Installation

1) Download the repository:

- Option A: Download ZIP from GitHub: `https://github.com/daksh-7/Scrapitor` → Code → Download ZIP → Unzip anywhere.
- Option B: Clone via Git:

```powershell
winget install git.git
git clone https://github.com/daksh-7/Scrapitor
```

2) Prerequisites on Windows:

- PowerShell 7 (`pwsh`). If you don't have it, install with:

```powershell
winget install --id Microsoft.PowerShell -e --accept-package-agreements --accept-source-agreements
```

- Python 3.10+ in PATH. Download for Windows: https://www.python.org/downloads/ (During setup, enable "Add python.exe to PATH").

3) Run the launcher:

- Double-click `Scrapitor\run.bat`.

The launcher will:

- Create a local virtual environment `Scrapitor/app/.venv` and install `requirements.txt`.
- Start the Flask server on the configured port (default 5000) and verify health.
- Install or download `cloudflared` if needed, start a tunnel, and print the public URL.
- Open both the dashboard (local and Cloudflare) in your browser.

Copy the “JanitorAI API URL” shown in the console or the UI (it ends with `/openrouter-cc`). You will use it in JanitorAI’s proxy settings.


## Docker (Installation and Usage)

Fastest cross-platform path with Docker.

Prerequisites:

- Docker Desktop installed and running.

Run with Docker Compose:

```
docker compose up --build
```

What happens:

- Builds the image using `docker/Dockerfile`.
- Starts the Flask server inside the container and launches a Cloudflare tunnel using `cloudflared`.
- Persists runtime data under `app/var/` on your host so the dashboard can read `tunnel_url.txt` and data is kept across restarts.
- Provides a TryCloudflare URL; it is also saved to `app/var/state/tunnel_url.txt`.

Manual Docker compose commands:

```
docker compose up --build
docker compose down
docker compose up
```

After launch, copy the Cloudflare endpoint shown and proceed to [Usage in Janitor](#usage-in-janitor).


### Directory Structure additions for Docker

```
./
└── Scrapitor
    ├── app
    ├── docker
    │   └── Dockerfile
    ├── docker-compose.yml
    └── run.bat
```


## Casual Usage

If you just want to use scrapitor with JanitorAI quickly, start with one of these two options:

- Option A (no Git needed): Download ZIP from `https://github.com/daksh-7/Scrapitor`, unzip, then run `Scrapitor\run.bat`.
- Option B (with Git): If you don’t have Git, install it: `winget install git.git`. Then `git clone https://github.com/daksh-7/Scrapitor` and run `Scrapitor\run.bat`.

After launch, wait until “SUCCESS! Proxy is running”.
2) In the dashboard “Setup” section, copy the “Cloudflare Endpoint” and the “Model Name Preset”.
3) Follow the steps in [Usage in Janitor](#usage-in-janitor) to wire JanitorAI to your Cloudflare endpoint.
4) Send a message in JanitorAI; your request appears in “Activity”.
5) Optionally open “Parser”, choose Default or Custom, and click “Write” to export a TXT version.


## Usage in Janitor

Use these six steps inside JanitorAI’s UI (exactly as shown in the app):

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
- Authorization: If you set `OPENROUTER_API_KEY`, the server uses it; otherwise the client’s `Authorization` header is forwarded.
- Logging: Each request payload is saved to `var/logs/<timestamp>.json` (old files are pruned by a rolling limit).
- Parsing: On each saved log (and on demand), the parser writes a TXT export per character, versioned as `<Character Name>.vN.txt`.
- Tunnel: `cloudflared` publishes a public URL; the dashboard displays both local and public endpoints.


## Installation (Manual)

If you prefer not to use the Windows launcher:

Prerequisites

- Python 3.10+ in PATH
- `cloudflared` installed (for a public URL) or use local only

Setup

```
cd Scrapitor/app
python -m venv .venv
.venv\Scripts\pip install --upgrade pip
.venv\Scripts\pip install -r requirements.txt
.venv\Scripts\python -m app.server
```

Cloudflare tunnel (in another terminal):

```
cloudflared tunnel --no-autoupdate --url http://127.0.0.1:5000
```

On macOS/Linux, adjust venv paths accordingly, for example:

```
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
python -m app.server
cloudflared tunnel --no-autoupdate --url http://127.0.0.1:5000
```


## Web Dashboard

- Overview: Shows total requests and the server port.
- Setup: Copy the Model Name Preset and your Cloudflare/Local endpoints.
- Parser: Choose Default (no filtering) or Custom (Include/Exclude tags), auto-detect tags from logs, and write outputs.
- Activity: Browse recent logs, open raw JSON, rename files, and view/rename parsed TXT versions.


## Parser (Rules and CLI)

The parser is designed for Janitor/character logs and implements these rules:

1) Replace literal `\n` with real newlines.
2) Drop JSON/role metadata; parse text only.
3) Remove tag blocks matching an omit list (case-insensitive). In custom include mode, keep only specified tags.
4) From the first system message, pick the first non-skipped tag as the character name; include its content. Omit user messages; include the first assistant message under “First Message”.
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
- Tag Chips: Each tag appears as a chip in the Parser panel. Click to toggle Include ↔ Exclude. “Select All” toggles all chips to Include; “Clear All” sets all to Exclude. You can also add new tags via the input and Add button.
- Tag Detection: “Detect Tags (Latest)” scans the latest log to discover tags. “Detect Tags (From Logs…)” lets you pick one or more logs to detect tags from. Detected tags are merged into chips.
- Tag Hover Highlighting: Hovering a tag chip highlights matching logs in the Activity list. If a tag only appears in a subset of the current detection scope, only those logs are highlighted; otherwise all logs remain unhighlighted. This helps identify logs where the tag is exclusive.
- Writing Outputs (Write): Click “Write” to open options. “Write Latest” writes a parsed TXT for the most recent JSON log. “Custom Selection…” allows selecting multiple logs from Activity and then “Write Selected”.
- Write Logic: Each write uses your current Parser settings. In Include mode, only explicitly included items are written (e.g., include `first_message` to emit the First Message; include `scenario` to emit Scenario). In Exclude mode (default behavior if Include is empty), everything is written except omitted tags. The character’s name is taken from the first non-skipped tag in the first system message.
- Version Control for TXT: Every time a log is written, the server stores the resulting TXT under `var/logs/parsed/<json_stem>/` and appends a version suffix like `.v3.txt`. The latest version is surfaced in the UI.
- TXT Navigation: In Activity, each log row shows a “TXT” button. Click it to open a version picker modal listing all parsed TXT files for that log, with size and modified time. Click a version to preview its contents.
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

You can configure via environment variables or an optional `config.yaml` in `Scrapitor/app/`.

Environment variables (selected):

- `PROXY_PORT`: Port for the Flask server (default 5000).
- `OPENROUTER_URL`: Upstream URL (default `https://openrouter.ai/api/v1/chat/completions`).
- `OPENROUTER_API_KEY`: Optional server-side key; if unset, client `Authorization` is forwarded.
- `ALLOWED_ORIGINS`: CSV of CORS origins (defaults to `*`).
- `LOG_DIR`: Log directory (default `var/logs`).
- `MAX_LOG_FILES`: Max number of JSON logs to keep (default 1000).
- `LOG_LEVEL`: Python logging level (default `INFO`).
- `CONNECT_TIMEOUT`, `READ_TIMEOUT`: Upstream timeouts.

Example `config.yaml`:

```yaml
server:
  port: 5000
  allowed_origins: ["*"]
  connect_timeout: 5.0
  read_timeout: 300.0
openrouter:
  url: https://openrouter.ai/api/v1/chat/completions
  api_key: ""   # optional; otherwise forward client Authorization
  defaults:
    temperature: 1.0
    top_p: 1.0
    top_k: 0
    max_tokens: 1024
logging:
  directory: var/logs
  max_files: 1000
  level: INFO
parser:
  mode: default          # default | custom
  include_tags: []
  exclude_tags: []
security:
  max_messages: 50
  max_model_length: 100
  validate_requests: true
```


## Troubleshooting

- No Cloudflare URL appears: Ensure `cloudflared` is installed and not blocked by firewall. The launcher can install it via `winget` or download the latest release.
- Script exits with "PowerShell 7 is required": Install PowerShell 7 with the winget command above, then re-run `run.bat`.
- Port already in use: Set `PROXY_PORT` to a free port, or stop the conflicting process.
- 502 from OpenRouter: Verify your `Authorization` is present in the request or set `OPENROUTER_API_KEY` on the server.
- CORS/Browser errors: The server is permissive by default; ensure your client is calling the Cloudflare URL as shown in the UI.
- Parser output missing fields: Adjust Include/Exclude tags or use “Detect Tags” to discover available tags, then “Write” again.
- TryCloudflare URL shows an NGINX error page:
  - In your browser, enable Secure DNS/DoH and choose Cloudflare (1.1.1.1).
  - Or set DNS on Windows: Control Panel > Network and Internet > Network and Sharing Center > Change adapter settings > right-click your active adapter > Properties > select “Internet Protocol Version 4 (TCP/IPv4)” > Properties > choose “Use the following DNS server addresses” and set Preferred DNS server to 1.1.1.1 and Alternate DNS server to 8.8.8.8 > OK.
  - Optional: also set IPv6 DNS to 2606:4700:4700::1111 and 2001:4860:4860::8888.
  - Finally, run `ipconfig /flushdns` in an elevated Command Prompt.


## Development

- Run locally without the launcher:

```
cd Scrapitor/app
python -m venv .venv && .venv\Scripts\pip install -r requirements.txt
.venv\Scripts\python -m app.server
```

- Code layout: Flask app under `app/`, static assets in `app/static/`, templates in `app/templates/`, parser in `app/parser/`.
- UI endpoints live at `/` and poll the JSON API described above.


## Notes

- scrapitor is not affiliated with JanitorAI or OpenRouter.
- Cloudflare tunnels expose a public URL; treat it like any internet-facing service.
- Important: This project is for educational and personal use only. Always respect platform Terms of Service and creator rights. Before downloading, exporting, or distributing any character card or derivative content, you must mandatorily first obtain permission from the character/bot creator and consult JanitorAI moderators as applicable.
