# Scrapitor 2.2.0 Release Notes

**Release Date:** January 7, 2026

---

## Overview

This release makes the WebUI fully mobile-compatible with a responsive design that adapts to any screen size. Also includes a fix for character card export naming.

---

## What's Changed

### Mobile-First Responsive WebUI

The entire frontend has been redesigned to work seamlessly on mobile devices:

- **Bottom Navigation Bar** — New `MobileNav` component provides touch-friendly navigation on screens under 768px
  - Fixed bottom position with safe area support for notched devices
  - Active state indicator with accent color
  - Smooth tap feedback animations

- **Collapsible Sidebar** — Desktop sidebar transforms into an overlay drawer on mobile
  - Slide-in animation from left edge
  - Backdrop overlay for context preservation
  - Touch-friendly close interactions

- **Responsive Components** — All UI components now adapt to viewport size:
  - `Topbar` — Hamburger menu on mobile, full navigation on desktop
  - `MetricCard` — Stacked layout on narrow screens
  - `LogItem` — Optimized touch targets and spacing
  - `Modal` / `ConfirmModal` — Full-screen on mobile, centered on desktop
  - `Section` — Adjusted padding and margins
  - `TagChip` — Touch-friendly sizing

- **Responsive Routes** — All page layouts optimized:
  - `Overview` — Cards stack vertically on mobile
  - `Parser` — Simplified controls layout
  - `Activity` — Scrollable log list with better touch handling

- **CSS Improvements** — New responsive utilities in `app.css`:
  - CSS custom properties for mobile nav height and safe areas
  - Media query breakpoints at 767px for mobile/desktop split
  - Touch-optimized tap highlights and interactions
  - Viewport meta tag with `viewport-fit=cover` for edge-to-edge display

### Bug Fixes

- **Character Export Naming** — Fixed issue where exported character cards were named "[Name]'s Persona" instead of just "[Name]"
  - Now correctly extracts character name from persona-style tags
  - Example: `<Lily's Persona>` now exports as "Lily"

---

## Technical Notes

- Mobile breakpoint: 767px (≤767px = mobile, >767px = desktop)
- Safe area CSS variables support iOS notch and Android gesture navigation
- No breaking changes to backend or API
- Fully backward compatible with existing data

---

## Full Changelog

`v2.1.1...v2.2.0`
