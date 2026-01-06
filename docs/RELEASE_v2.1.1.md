# Scrapitor 2.1.1 Release Notes

**Release Date:** January 6, 2026

---

## Overview

A minor release focused on visual polish and documentation improvements. No functional changes to the launcher, server, or parser.

---

## What's Changed

### Visual

- **New ASCII Art Banner** — Upgraded from figlet-style text to bold block-character art for improved terminal presence

| Version | Banner Style |
|---------|--------------|
| 2.1.0 | `____` figlet text |
| 2.1.1 | `███████╗` block characters |

**Before (2.1.0):**
```
   ____                        _ _
  / ___|  ___ _ __ __ _ _ __  (_) |_ ___  _ __
  \___ \ / __| '__/ _` | '_ \ | | __/ _ \| '__|
   ___) | (__| | | (_| | |_) || | || (_) | |
  |____/ \___|_|  \__,_| .__/ |_|\__\___/|_|
                       |_|
```

**After (2.1.1):**
```
███████╗ ██████╗██████╗  █████╗ ██████╗ ██╗████████╗ ██████╗ ██████╗
██╔════╝██╔════╝██╔══██╗██╔══██╗██╔══██╗██║╚══██╔══╝██╔═══██╗██╔══██╗
███████╗██║     ██████╔╝███████║██████╔╝██║   ██║   ██║   ██║██████╔╝
╚════██║██║     ██╔══██╗██╔══██║██╔═══╝ ██║   ██║   ██║   ██║██╔══██╗
███████║╚██████╗██║  ██║██║  ██║██║     ██║   ██║   ╚██████╔╝██║  ██║
╚══════╝ ╚═════╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝     ╚═╝   ╚═╝    ╚═════╝ ╚═╝  ╚═╝
```

### Documentation

- **README Overhaul** — Complete rewrite with improved structure and accuracy
  - Added Mermaid architecture diagram with styled nodes
  - Consolidated installation instructions (Windows/macOS/Linux)
  - Added terminal preview showing full launcher output
  - Expanded API reference with all endpoints documented
  - Streamlined troubleshooting table
  - Updated project structure tree

---

## Technical Notes

- Compact banner (for narrow terminals <60 chars) unchanged
- No changes to `run.bat`, `run_proxy.ps1`, or PowerShell modules
- No changes to server or parser behavior
- Fully backward compatible with 2.1.0

---

## Full Changelog

`v2.1.0...v2.1.1`