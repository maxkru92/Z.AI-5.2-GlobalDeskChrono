# Global Desk Chrono — Project Structure & Setup Guide
### Powered by KruppCapital

A standalone macOS desktop dashboard application for global market session monitoring, built with SwiftUI and native Apple frameworks.

---

## 1. Directory Structure

```
GlobalDeskChrono/
├── GlobalDeskChrono/
│   ├── GlobalDeskChronoApp.swift          # @main entry, AppModel, ContentView, TopToolbar
│   ├── Models.swift                       # ExchangeSession, DashboardClock, EconomicEvent, etc.
│   ├── NTPClockSync.swift                 # NTPv4 client (Network framework, no dependencies)
│   ├── SessionEngine.swift                # Session state/progress/overlap calculations
│   ├── AlarmManager.swift                 # Cascading alarm system (T-15m/T-5m/T-0)
│   ├── AudioEngine.swift                  # AVAudioEngine pipeline, NYSE bell + synthetic fallback
│   ├── EconomicCalendarService.swift       # Economic calendar fetcher (forex-calendar.pro API)
│   ├── ThemeEngine.swift                  # ThemePalette, pulsing borders, glow, grid backgrounds
│   ├── MultiClockGridView.swift           # Multi-clock grid with +/- buttons, add/remove sheet
│   ├── ChronoDialView.swift               # 24-hour analog dial with session arcs (Canvas-based)
│   ├── StatusPanelView.swift              # Progress sliders, macro day tracker, status banners
│   ├── EconomicCalendarView.swift         # Filter dashboard (currency/impact/sector/lead-time)
│   ├── SettingsView.swift                 # Settings tabs: General, Theme, Alarms, NTP, About
│   ├── Assets.xcassets/
│   │   ├── AppIcon.appiconset/
│   │   └── AccentColor.colorset/
│   ├── Resources/
│   │   └── nyse_bell.mp3                  # NYSE Opening Bell audio (optional)
│   ├── GlobalDeskChrono.entitlements      # App Sandbox + network client
│   └── Info.plist                         # App metadata
└── docs/
    └── ProjectStructure.md               # This file
```

---

## 2. Xcode Project Setup

### Step 1: Create the Project
1. Open Xcode -> File -> New -> Project
2. Select **macOS** -> **App**
3. Product Name: `GlobalDeskChrono`
4. Organization Identifier: `com.kruppcapital`
5. Interface: **SwiftUI**
6. Language: **Swift**
7. Minimum Deployments: **macOS 14.0** (Sonoma)

### Step 2: Add Source Files
Copy all `.swift` files into the project navigator. Ensure each file is added to the app target.

### Step 3: Configure Entitlements
The `GlobalDeskChrono.entitlements` file is included in the repository. It contains:
- `com.apple.security.app-sandbox` = true
- `com.apple.security.network.client` = true (required for NTP and economic calendar API)

### Step 4: Configure Info.plist
Add the following key:
- `NSUserNotificationsUsageDescription` = "Global Desk Chrono sends session opening and economic event alerts."

### Step 5: Build & Run
1. Select the `GlobalDeskChrono` target
2. Build (Cmd+B) then Run (Cmd+R)
3. The app will launch, detect your local timezone, sync with NTP, and populate 4 default clocks

---

## 3. All Code Fixes Applied

All 5 fixes from the original documentation have been applied in this repository:

1. **`import UserNotifications`** added to `AlarmManager.swift`
2. **`.sheet` modifier** for `EconomicCalendarView` added to `ContentView` in `GlobalDeskChronoApp.swift`
3. **Theme palette** — all views now use `appModel.palette` directly instead of `@Environment(\.themePalette)` for reactive theme updates
4. **`@Environment(\.openSettings)`** used in `TopToolbarView` instead of `NSApp.sendAction`
5. **`AVAudioSession`** calls removed from `AudioEngine.swift` (unnecessary on macOS)

---

## 4. Asset Pipeline

### NYSE Opening Bell Audio (`nyse_bell.mp3`)

**Purpose:** Authentic mechanical bell sound for the New York Session opening alarm.

**Installation:**
1. Name the file exactly `nyse_bell.mp3`
2. Drag it into the Xcode project navigator under `Resources/`
3. Ensure "Add to target: GlobalDeskChrono" is checked
4. If absent, the synthetic bell is used automatically

**Audio format recommendations:**
- Format: MP3 or CAF (AAC)
- Sample rate: 44100 Hz
- Duration: 3-5 seconds

### App Icon
Create a 1024x1024 master icon and add it to `Assets.xcassets/AppIcon.appiconset/`.

---

## 5. Architecture Overview

### Engine Layer

| Component | Responsibility | Dependencies |
|---|---|---|
| `NTPClockSync` | UDP NTPv4 client; computes clock offset vs. system clock | Network framework |
| `SessionEngine` | Session state, progress, overlaps, countdowns | NTPClockSync |
| `AlarmManager` | 1 Hz timer polling; triggers cascading alarms | SessionEngine, AudioEngine, NTPClockSync |
| `AudioEngine` | Sound playback; synthetic bell/ping/click synthesis | AVFoundation |
| `EconomicCalendarService` | Fetches & filters economic events; background refresh | URLSession |

### State Management
- `AppModel` (`@Observable`): Central state hub
- Injected via `.environment(appModel)`
- Views access state via `@Environment(AppModel.self)`
- 1 Hz `Timer` updates `currentTime`, driving all UI updates

### Session Schedule (Hardcoded)

| Exchange | Timezone | Open | Close | Lunch | DST |
|---|---|---|---|---|---|
| Tokyo (JPX) | Asia/Tokyo | 09:00 | 15:30 | 11:30-12:30 | No |
| Hong Kong (HKEX) | Asia/Hong_Kong | 09:30 | 16:00 | 12:00-13:00 | No |
| Frankfurt (Xetra) | Europe/Berlin | 09:00 | 17:30 | - | Yes |
| London (LSE) | Europe/London | 08:00 | 16:30 | - | Yes |
| New York (NYSE) | America/New_York | 09:30 | 16:00 | - | Yes |

DST handled automatically by Foundation's `TimeZone` using IANA timezone identifiers.

### NTP Synchronization
- Protocol: NTPv4 (RFC 5905) via raw UDP using `NWConnection`
- Servers: `pool.ntp.org` -> `time.apple.com` -> `time.cloudflare.com` (failover chain)
- Offset formula: `offset = ((T2 - T1) + (T3 - T4)) / 2`
- Resync interval: every 5 minutes
- Query timeout: 5 seconds per server
- Falls back to system clock if all servers unreachable

### Economic Calendar API
- Primary: `https://api.forex-calendar.pro/events/upcoming` (free tier: 100 req/15 min)
- Refresh: every 5 minutes (background worker)
- Fallback: Mock data with NFP, CPI, ECB, GDP, BoJ events
- Filters: Currency, Impact Level, Sector, Lead Time (1-60 min)

---

## 6. Keyboard Shortcuts

| Shortcut | Action |
|---|---|
| Cmd+F | Toggle Always on Top |
| Cmd+Shift+R | Reset clocks to defaults |
| Cmd+1 | Vintage Chrono theme |
| Cmd+2 | Modern Minimalist theme |
| Cmd+3 | Digital Matrix theme |

---

## 7. Regulatory Compliance

This application is strictly a **time/session monitoring tool**. It does NOT provide:
- Investment advice
- Order execution
- Broker connectivity
- Live market prices

The "Powered by KruppCapital" attribution is displayed in the About tab and the main toolbar.

---

## 8. Additional Exchange Schedules

14 pre-defined exchanges available via the "+" button:

| Exchange | Timezone | Open | Close | Lunch |
|---|---|---|---|---|
| Tokyo (TSE/JPX) | Asia/Tokyo | 09:00 | 15:30 | 11:30-12:30 |
| Hong Kong (HKEX) | Asia/Hong_Kong | 09:30 | 16:00 | 12:00-13:00 |
| Shanghai (SSE) | Asia/Shanghai | 09:30 | 15:00 | 11:30-13:00 |
| Seoul (KRX) | Asia/Seoul | 09:00 | 15:30 | - |
| Sydney (ASX) | Australia/Sydney | 10:00 | 16:00 | - |
| Singapore (SGX) | Asia/Singapore | 09:00 | 17:00 | - |
| Frankfurt (Xetra) | Europe/Berlin | 09:00 | 17:30 | - |
| Paris (Euronext) | Europe/Paris | 09:00 | 17:30 | - |
| Amsterdam (Euronext) | Europe/Amsterdam | 09:00 | 17:30 | - |
| London (LSE) | Europe/London | 08:00 | 16:30 | - |
| New York (NYSE) | America/New_York | 09:30 | 16:00 | - |
| Chicago (CME) | America/Chicago | 08:30 | 15:00 | - |
| Toronto (TSX) | America/Toronto | 09:30 | 16:00 | - |
| Bombay (BSE/NSE) | Asia/Kolkata | 09:15 | 15:30 | - |

---

(c) 2024-2026 KruppCapital. All rights reserved.
