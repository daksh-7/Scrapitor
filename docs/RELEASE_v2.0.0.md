# Scrapitor v2.0.0

**Release Date:** December 26, 2025

A major release featuring a complete frontend rewrite to Svelte 5, SillyTavern export functionality, and significant performance improvements.

---

## New Features

### Complete Frontend Rewrite to Svelte 5
- Migrated from vanilla HTML/JS/CSS to a modern **Svelte 5 SPA with TypeScript**
- Added reactive state management with Svelte 5 runes (stores for logs, parser, UI)
- Implemented typed API client with full type definitions
- Created 11 reusable UI components:
  - `Modal`, `ConfirmModal` — dialogs and confirmations
  - `Section`, `MetricCard` — layout and stats display
  - `TagChip`, `LogItem` — interactive list elements
  - `Sidebar`, `Topbar` — navigation components
  - `Icon`, `Notification` — utilities
- Added client-side routing (Dashboard, Parser, Activity pages)
- Automatic log prefetching for instant loading

### SillyTavern Export
- New `/export-sillytavern` API endpoint supporting **chara_card_v3** spec
- Two export modes:
  - **From Parser:** Parse JSON logs with your current tag settings
  - **From TXT:** Export from existing parsed TXT files
- Multi-select export from the Activity page
- Exported JSON includes: `name`, `description`, `scenario`, `first_mes`

### Dashboard Redesign
- Merged Overview and Setup pages into a unified **Dashboard**
- Added **Quick Start** guide with step-by-step JanitorAI setup instructions
- Configuration cards for endpoints:
  - Model Name Preset
  - Cloudflare Endpoint (public URL)
  - Local Endpoint
- Metrics grid showing:
  - Total requests since startup
  - All log files in folder
  - Parsed texts (all versions)
  - Server port

### JSON Syntax Highlighting
- Raw JSON logs now display with syntax-colored:
  - Keys (property names)
  - String values
  - Numbers
  - Booleans (`true`/`false`)
  - `null` values

### Inline Renaming for Parsed Files
- Rename TXT exports directly from the Activity modal
- Complements the existing JSON log renaming feature

---

## Performance Improvements

- **O(1) metadata lookup** using indexed Map (`itemsByName`) instead of O(n) array search
- Optimized Svelte reactivity with `$derived` computations
- **Log prefetching** — first 5 logs loaded in background for instant access
- Reduced bundle size by removing legacy static assets

---

## DevOps / Infrastructure

- **Reimplemented Docker** configuration with proper multi-container setup
- Separate tunnel container (`docker/tunnel/`) with improved entrypoint script
- Overhauled PowerShell launcher script (`run_proxy.ps1`) — cleaner, more maintainable
- Updated `.dockerignore` and `.gitignore` for the new project structure

---

## Cleanup

- Removed YAML configuration support (simplified to JSON only)
- Removed redundant code blocks in parser
- Cleaned up unused icon definitions and animations
- Removed legacy HTML templates (`base.html`, `index.html`) and static JS/CSS files

---

## Bug Fixes

- Fixed 400 client error bug when making requests
- Fixed sidebar layout issues
- Improved responsiveness and accessibility in Sidebar component

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

