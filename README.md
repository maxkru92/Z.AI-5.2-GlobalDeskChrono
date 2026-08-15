# Z.AI-5.2-GlobalDeskChrono

### Powered by KruppCapital

A production-ready macOS desktop dashboard application for global market session monitoring, built with **SwiftUI** and native Apple frameworks. Zero external dependencies.

> **REGULATORY COMPLIANCE:** This application is strictly a time/session monitoring tool. It does NOT provide investment advice, order execution, broker connectivity, or live market prices.

---

## Features

### NTP-Synchronized Clock Engine
- Standalone NTPv4 client using Apple's Network framework (NWConnection)
- Queries pool.ntp.org, time.apple.com, time.cloudflare.com with automatic failover
- Computes clock offset via the standard ((T2-T1)+(T3-T4))/2 formula
- Resyncs every 5 minutes; falls back to system clock if all servers unreachable

### Dynamic User-Time Base
- Auto-detects the user's local macOS system timezone as the absolute anchor reference
- All calculations, alerts, and countdowns recalculate relative to local timezone
- Daylight Saving Time (DST) handled automatically via Foundation TimeZone (IANA identifiers)

### Session Engine
- Hardcoded exact opening, closing, and lunch-break schedules for 14 major global exchanges
- Verified trading hours as of 2025-2026

| Exchange | Timezone | Open | Close | Lunch | DST |
|---|---|---|---|---|---|
| Tokyo (JPX) | Asia/Tokyo | 09:00 | 15:30 | 11:30-12:30 | No |
| Hong Kong (HKEX) | Asia/Hong_Kong | 09:30 | 16:00 | 12:00-13:00 | No |
| Frankfurt (Xetra) | Europe/Berlin | 09:00 | 17:30 | - | Yes |
| London (LSE) | Europe/London | 08:00 | 16:30 | - | Yes |
| New York (NYSE) | America/New_York | 09:30 | 16:00 | - | Yes |

### Modular Interface

**Multi-Clock Grid View:**
- Visual + and - buttons to dynamically add, customize, or delete exchange clocks
- Default setup on first launch: ASIA (Tokyo/HK combined), Frankfurt, London, New York

**24-Hour Chrono Dial View:**
- Single comprehensive 24-hour analog clock face
- Global market sessions visualized as overlapping colored arcs (pie wedges)
- Supports all themes (Vintage, Modern, Digital)
- Toggle specific market arcs on/off to declutter the face

### Institutional Status Workflow
- Linear Session Progress Sliders - gray when closed, illuminate and fill when active
- Global Macro Day Tracker - 24h timeline showing the global liquidity wave (Asia -> Europe -> US)
- Dynamic Status Text Overlays - e.g. LONDON OVERLAP ACTIVE, US PRE-MARKET OPEN

### Smart Alarms and Audio Pipeline

**Cascading Alerts** (pre-configured for every default session clock):
- Pre-Alarm 1 (T-15min): Amber visual pulse + subtle warning click
- Pre-Alarm 2 (T-5min): Faster pulse + discrete sonar ping
- Opening Alarm (T-0): Sonar ping (or NYSE Bell for New York)

**NYSE Opening Bell Integration:**
- Loads nyse_bell.mp3 from app bundle if present
- Fallback: synthetic resonant metallic bell using additive synthesis (7 inharmonic partials + mechanical strike noise + triple clang)

**Automated Economic Calendar Scraper:**
- Fetches high-impact economic news events from api.forex-calendar.pro (free tier)
- Filter by Country/Currency, Impact Level, and Sector
- Configurable audio-visual alerts X minutes prior to filtered events

### Theme Engine

| Theme | Style | Typography |
|---|---|---|
| Vintage Chrono | Skeuomorphic, patinaed, radial gradient rings | Serif |
| Modern Minimalist | Clean flat vector, data-dense, negative space | SF Pro Display |
| Digital Matrix | Cyberpunk/Bloomberg terminal, neon grids | Monospace |

**Dynamic Pulsing System:**
- Red glowing pulse during final 15 minutes of US Session (Power Hour close)
- Amber/purple pulsing 5 minutes prior to high-impact economic news releases

### Window Mechanics
- Native macOS Always on Top (Float) via NSWindow.level
- Adjustable window opacity (30%-100%)
- Compact Menu Bar extra status mode

---

## Requirements

- macOS 14.0+ (Sonoma / Sequoia)
- Xcode 15.0+
- Swift 5.9+

## Installation

1. Clone the repository
2. Open Xcode, create a new macOS App project (SwiftUI)
3. Copy all .swift files from GlobalDeskChrono/ into the project
4. Add GlobalDeskChrono.entitlements with:
   - com.apple.security.app-sandbox = true
   - com.apple.security.network.client = true
5. (Optional) Add nyse_bell.mp3 to Resources/
6. Build and Run

See docs/ProjectStructure.md for complete setup instructions.

---

## Architecture

```
Engine Layer:
- NTPClockSync.swift           NTPv4 client (Network framework)
- SessionEngine.swift          Session state/progress/overlap calculations
- AlarmManager.swift           Cascading alarm system (1 Hz polling)
- AudioEngine.swift            AVAudioEngine pipeline, synthetic bell synthesis
- EconomicCalendarService.swift Economic calendar fetcher + filter

View Layer:
- GlobalDeskChronoApp.swift    @main entry, AppModel, ContentView
- MultiClockGridView.swift     Grid with +/- buttons
- ChronoDialView.swift         24h analog dial (Canvas-based)
- StatusPanelView.swift        Progress sliders, macro tracker, status banners
- EconomicCalendarView.swift   Filter dashboard
- SettingsView.swift           Settings + About (KruppCapital attribution)
- ThemeEngine.swift            3 themes, pulsing borders, glow, grid backgrounds
```

---

## Keyboard Shortcuts

| Shortcut | Action |
|---|---|
| Cmd+F | Toggle Always on Top |
| Cmd+Shift+R | Reset clocks to defaults |
| Cmd+1 | Vintage Chrono theme |
| Cmd+2 | Modern Minimalist theme |
| Cmd+3 | Digital Matrix theme |

---

Copyright 2024-2026 KruppCapital. All rights reserved.
