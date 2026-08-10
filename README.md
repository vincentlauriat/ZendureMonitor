# Zendure Monitor

[![Release](https://img.shields.io/github/v/release/vincentlauriat/ZendureMonitor)](https://github.com/vincentlauriat/ZendureMonitor/releases)
![Platform](https://img.shields.io/badge/platform-macOS%2014%2B-blue)
![License](https://img.shields.io/badge/license-MIT-green)

A tiny macOS menu bar app that shows the **live solar production of a Zendure SolarFlow battery** — local-first (on your LAN: no cloud account, no broker, no credentials), with an **optional Zendure Cloud mode** for when the local API isn't reachable.

```
☀️ 842 W          ← in your menu bar, refreshed every 5 s
```

Click the icon for the details: battery state of charge, charge/discharge power, per-pack SOC/temperature, output to home, grid input, per-MPPT PV input, and today's solar energy.

New in 1.12: an **energy history window** (up to 365 days) — daily kWh bar charts per device with per-device metric lists (solar, home, battery charge/discharge…), lifetime totals, and a local disk cache so past days are only fetched once. Data comes from the private API of the Zendure mobile app (main-account credentials, Keychain-only storage, fully separate from the Cloud Key path); works in both local and cloud modes.

New in 1.11: **automatic local ⇄ cloud switching** (opt-in — the app moves to Cloud mode by itself when the SolarFlow stops answering locally, typically away from home, and comes back to local as soon as it answers again, with an explicit "bascule auto" note in the connection footer) and **collapsible, configurable panel cards** (click a card header to collapse it to one line with its key value — Juicy style — and toggle each card on/off in Settings → Display).

New in 1.10.3: a **Home consumption card** in the menu bar panel — with a Smart CT configured it shows the house's total draw (grid + SolarFlow output, the SolarFlow's own AC charging deducted) with a per-source breakdown; without a CT it shows the measurable part only. 1.10.4 makes the card honest when the meter is **out of reach** (the CT is LAN-only — typically away from home in Cloud mode): the value is clearly marked "via SolarFlow only, partial" instead of suggesting no meter is configured.

New in 1.10: an optional **Zendure Cloud mode** (real-time MQTT through Zendure's servers, configured with the app's *Authorization Cloud Key* stored in the Keychain — read-only, and the local API remains the default), **Smart CT support** (the SmartMeter3CT is polled on the LAN, giving the flow diagram the home's real grid draw and total consumption), a **redesigned energy-flow diagram** (aligned diamond layout, per-pack SOC chips, an explicit grid→home arc that is measured with the CT and honestly marked "not measured" without it), a **connection footer** in the panel (local primary / local fallback / cloud), and reorganized Settings with a **Network** tab.

New in 1.9: the **Sun window v3** — describe each of your panel arrays (peak power, azimuth, tilt) and the window shows an animated **sky dome** (the sun's real path over the day, both solstice arcs, today's measured production placed where the sun stood, and each array's aiming direction with its live incidence gap), a **solar compass** with true iso-incidence loops, a per-array breakdown (clear-sky output, incidence, best hour, potential for the day) and richer ephemerides (twilights, golden hours, day-length delta to the second, next solstice or equinox). Azimuth and tilt are **adjustable straight from the window** with two sliders per array — the dome, the compass and the output follow the gesture — and the whole thing fits **on one screen, no scrolling**.

New in 1.7: a **large widget** (the 14-day production histogram right on your desktop), **local weather in the Sun window** (Open-Meteo cloud cover and sunshine forecast, with a cloud-adjusted production estimate using the Kasten–Czeplak model), and a **redesigned Sun window** — hero chart plus three compact columns (ephemeris, weather, yield), no scrolling.

In 1.6: **daily solar split** — how much of today's production went straight to the home vs into the battery (AC charging deducted), plus the grid total, shown in both the panel and the dashboard; offline resilience (the panel keeps the last values, dimmed with their age, instead of going blank), a smarter VPN fallback (no more 5 s primary-host timeout on every poll when away), and day counters that roll over at local midnight.

In 1.5: a redesigned panel (header with icon actions, period selector 15 min / day / 14 days, peak & vs-yesterday stats), a **hub-centric energy-flow diagram** (SolarFlow at the center; panels, batteries, public grid, home and the off-grid outlet as peripherals — links animate only when energy actually flows, with live wattage), a dedicated **Sun window** (local NOAA ephemerides, sun path overlaid with today's production, clear-sky theoretical output), **savings estimates** (configurable €/kWh and g CO₂/kWh), extra opt-in notifications (battery full, unexpected grid draw, production record), an upfront **permissions check** (local network / location / notifications), unit tests and a GitHub Actions CI.

New in 1.4: a **dashboard window** and an optional **24/7 collector** (`Scripts/collector/`) for an always-on Mac, so daily history no longer depends on this Mac's uptime.

New in 1.3: a **macOS widget** (small/medium), a **battery control tab** (AC mode, output/charge limits via `POST /properties/write`) and **CSV export** of the production history.

Options: choose what the menu bar shows (solar W, battery %, home W — or icon only), launch at login, low-battery notification with a configurable threshold, theme override (auto/dark/light), and an optional fallback host for remote access over a VPN. UI localized in **French and English**.

## Screenshots

| Light | Dark |
|:---:|:---:|
| ![Panel, light theme](docs/panel-light.png) | ![Panel, dark theme](docs/panel-dark.png) |

**Dashboard window** — hub-centric animated energy-flow diagram and every indicator the local API exposes:

![Dashboard](docs/dashboard.png)

**Sun window** — an animated sky dome (the sun's real path, the solstice arcs, today's production and where each panel array is aimed), a solar compass, a per-array breakdown with **azimuth and tilt sliders** that re-aim an array live, local ephemerides (NOAA algorithm, nothing leaves the Mac), the clear-sky theoretical output and the local weather (Open-Meteo) with a cloud-adjusted forecast — everything on one screen:

![Sun window](docs/sun.png)

## Supported hardware

Tested on a **SolarFlow 2400 Pro**. Any Zendure device that ships the local zenSDK REST API should work: SolarFlow 2400 AC / AC+ / AC Pro, 800 (Pro/Plus), 1600 AC+, 3000 Mix AC+, 4000 Mix.

## Install

1. Download the latest `ZendureMonitor-x.y.z.dmg` from [Releases](https://github.com/vincentlauriat/ZendureMonitor/releases) (signed & notarized).
2. Drag **ZendureMonitor.app** to `/Applications` and launch it.
3. Accept the **local network** permission prompt (required to reach the battery).
4. Click the ☀️ icon → *Réglages…* → *Rechercher sur le réseau* (or type the device IP) → *Tester la connexion*.

Updates are delivered in-app via [Sparkle](https://sparkle-project.org).

> **If discovery finds nothing:** the local API may be disabled on your unit. In the Zendure mobile app, add a **HEMS** integration and then quit it — this is the documented way to persistently enable the local API.

## Documentation

- **[User guide — Français](docs/guide/fr/)** · **[English](docs/guide/en/)** — installation, first setup, every window explained, widgets, battery control, remote access, FAQ & troubleshooting ([index](docs/guide/README.md))
- **[Project wiki](https://github.com/vincentlauriat/ZendureMonitor/wiki)** — same guide, browsable online
- **[Landing page](https://vincentlauriat.github.io/ZendureMonitor/)** — overview with screenshots

## How it works — the full technical story

### 1. The local zenSDK API

Recent Zendure firmwares embed a plain HTTP server on **port 80** of the device (official docs: [Zendure/zenSDK](https://github.com/Zendure/zenSDK)). No authentication is required on the local network for reads. The app polls a single endpoint:

```
GET http://<device>/properties/report
```

which returns everything in one JSON document:

```json
{
  "timestamp": 1785801130,
  "sn": "EEB4AEXXXXXXXXX",
  "product": "solarFlow2400Pro",
  "properties": {
    "solarInputPower": 842,      // total PV input (W)
    "solarPower1": 420,          // per-MPPT input, channels 1…6 (W)
    "solarPower2": 422,
    "electricLevel": 76,         // average state of charge (%)
    "outputHomePower": 410,      // AC output to the home (W)
    "gridInputPower": 0,         // AC drawn from the grid (W)
    "packInputPower": 0,         // battery discharge (W)
    "outputPackPower": 432,      // battery charge (W)
    "acMode": 2, "inverseMaxPower": 1500, "...": "…"
  },
  "packData": [
    { "sn": "…", "socLevel": 76, "maxTemp": 3081, "totalVol": 4840, "power": 0 }
  ]
}
```

Field reference: [zenSDK `en_properties.md`](https://github.com/Zendure/zenSDK/blob/main/docs/en_properties.md). The parser (`Sources/DeviceState.swift`) is deliberately tolerant: it accepts the payload with or without the `properties` nesting (older firmwares return it flat) and numbers as Int, Double or String.

Writing is possible too (`POST /properties/write` with `{"sn": …, "properties": {"acMode": 2}}`) but this app is strictly **read-only**.

### 2. The optional Cloud mode (1.10)

When the local API isn't reachable (device offline on the LAN, or you're away without a VPN), the app can read the same data through Zendure's servers. The protocol is the one used by Zendure's own Home Assistant integration: the **Authorization Cloud Key** copied from the mobile app is base64 for `<apiUrl>.<appKey>`; a SHA1-signed `POST /api/ha/deviceList` returns the account's devices plus **MQTT credentials**; the app then subscribes to `/{productKey}/{deviceKey}/#` (both topic forms) and merges the device's partial `properties/report` messages, with a `getAll` safety poll every 60 s. The MQTT client is a dependency-free MQTT 3.1.1 implementation on Network.framework (`Sources/Cloud/`). The key lives in the **macOS Keychain**, the raw token never leaves the Mac, and cloud mode is **read-only** — the control tab stays local-only. `Scripts/cloud-probe.swift` is a CLI probe that dumps every topic and key the cloud publishes for your account.

**Smart CT:** the SmartMeter3CT is *not* exposed by the cloud's HA endpoint — but it answers on the LAN like any zenSDK device (`GET /properties/report` → per-phase and total apparent power at the panel). The app polls it directly (Settings → Network, with Bonjour detection) in both modes, which is what turns the flow diagram's grid→home arc into a measured value and yields the home's total consumption.

### 3. Device discovery — a firmware quirk worth knowing

The zenSDK docs say devices advertise over mDNS/Bonjour as **`_zendure._tcp`**. In practice, a SolarFlow 2400 Pro (firmware as of mid-2026) advertises under the generic **`_http._tcp`** type instead, with an instance name of:

```
Zendure-<product>-<serialNumber>     e.g. Zendure-solarFlow2400Pro-EEB4AEXXXXXXXXX
```

resolving to `Zendure-<product>-<serial>.local:80`. The app therefore browses **both** service types and keeps `_http._tcp` results only when the instance name starts with `Zendure` (`Sources/Discovery.swift`). You can verify from a terminal:

```bash
dns-sd -B _http._tcp local.        # look for a Zendure-* instance
curl http://Zendure-<…>.local/properties/report | jq .properties.solarInputPower
```

### 4. App architecture

Pure Swift / SwiftUI, no third-party dependency besides Sparkle. Generated with [XcodeGen](https://github.com/yonaskolb/XcodeGen) from `project.yml`.

```
Sources/
  ZendureMonitorApp.swift   @main — MenuBarExtra (LSUIElement agent app), Settings scene,
                            dashboard & Sun windows, shared Dock activation policy
  Components/               reusable card/gauge/sparkline views (Swift Charts), the energy-flow
                            diagram and the Sun card — shared design language with MacInside
  Monitor.swift             @MainActor ObservableObject: async polling loop (2–60 s, URLSession,
                            5 s timeout), local/cloud data source switch, daily curve/peak
                            persistence, savings, notifications
  Cloud/                    optional cloud mode: Cloud Key decoding, SHA1-signed deviceList,
                            dependency-free MQTT 3.1.1 client (Network.framework), partial-report
                            merging, Keychain storage — read-only by design
  DeviceState.swift         zenSDK payload model + tolerant JSONSerialization parser
  SmartCT.swift             SmartMeter3CT local report (per-phase + total grid draw)
  Discovery.swift           Bonjour browser (_zendure._tcp + _http._tcp) resolving hostnames
  MenuView.swift            dropdown panel (header with icon actions, cards, period selector)
  DashboardView.swift       dashboard window (flow diagram + full indicator cards)
  SunView.swift             Sun window (sky dome, solar compass, per-array orientation with
                            live azimuth/tilt sliders, ephemerides, twilights, yield, weather)
  SettingsView.swift        tabs: device (local/cloud source), display, sun, notifications,
                            control, network (Smart CT, fallback host, collector), general
  LocationFetcher.swift     one-shot CoreLocation fix to prefill the sun position
  PermissionsStatus.swift   upfront permissions check (local network, location, notifications)
  Shared/                   Format, SunCalc (NOAA ephemerides, twilights, solstices),
                            SolarGeometry (panel arrays, incidence, clear-sky output),
                            widget snapshot — also compiled into tests
  Updater.swift             Sparkle SPUStandardUpdaterController wiring
Tests/                      unit tests (parser, SunCalc, SolarGeometry, Format) — CI on every PR
```

Design choices:

- **`MenuBarExtra` with `.window` style** — the label is plain `Text` with an interpolated SF Symbol, so the menu bar shows live wattage (`☀️ 842 W`, `— W` when unconfigured).
- **Polling, not push.** The device has no local push channel; a 5 s `GET` of a ~2 KB JSON is negligible for both sides. The loop is a cancellable `Task` that restarts when host or interval changes.
- **Stale-data policy:** on errors the last reading stays visible (with a warning row) for 60 s, then the display falls back to "no data" — avoids flapping on a single missed poll.
- **Privacy/entitlements:** `NSLocalNetworkUsageDescription` + `NSBonjourServices` (macOS local-network privacy), `NSAllowsLocalNetworking` for cleartext HTTP to `.local` hosts. IP literals are ATS-exempt.

### 5. Release & auto-update pipeline

`Scripts/release.sh <version>` produces a distributable DMG:

1. `xcodegen generate` + `xcodebuild -configuration Release` (unsigned — signing is done manually because post-build `com.apple.provenance` xattrs break `codesign --force` in place).
2. Stage with `ditto --norsrc --noextattr --noacl`, then **Developer ID** sign deepest-first (Sparkle's `Autoupdate`, XPC services, `Updater.app`, the framework, then the app) with Hardened Runtime + secure timestamp (with retries — Apple's timestamp server is flaky).
3. `hdiutil` DMG (app + `/Applications` alias), **notarized** with `notarytool` and **stapled**.
4. The DMG is EdDSA-signed with Sparkle's `sign_update`; `appcast.xml` (served from this repo's `main` branch, referenced by `SUFeedURL`) points to the GitHub release asset, so installed apps self-update.

Independent verification after each release:

```bash
spctl -a -t exec -vv ZendureMonitor.app   # accepted, source=Notarized Developer ID
xcrun stapler validate ZendureMonitor-<v>.dmg
codesign --verify --deep --strict ZendureMonitor.app
```

## Remote access (away from home)

The zenSDK API only exists on your LAN, and it has **no authentication** — so **never port-forward the device's port 80 to the internet**. The safe pattern is a VPN into your home network:

1. Run [Tailscale](https://tailscale.com) (or WireGuard) on a machine that stays home (a Mac, a NAS, a Raspberry Pi, a router) and enable **subnet routing** for your LAN (e.g. `192.168.68.0/24`), or use the Zendure's IP through the tunnel.
2. Install Tailscale on your Mac; when away, the SolarFlow's LAN IP stays reachable through the tunnel.
3. In Zendure Monitor → *Réglages* → *Accès distant*, set the reachable address as **fallback host**. The app polls the primary (local) address first and switches to the fallback automatically when the primary doesn't answer.

Alternative for Home Assistant users: keep HA as the single LAN client of the device (e.g. [Zendure-HA-zenSDK](https://github.com/Gielz1986/Zendure-HA-zenSDK)) and access HA remotely; this app remains the local, zero-dependency companion.

## Build from source

```bash
brew install xcodegen
git clone https://github.com/vincentlauriat/ZendureMonitor.git && cd ZendureMonitor
xcodegen generate
xcodebuild -project ZendureMonitor.xcodeproj -scheme ZendureMonitor \
  -configuration Debug build CODE_SIGNING_ALLOWED=NO -derivedDataPath build
codesign --force --deep -s - build/Build/Products/Debug/ZendureMonitor.app
open build/Build/Products/Debug/ZendureMonitor.app
```

## Roadmap

- [x] v1.0 — live production in the menu bar, local zenSDK polling, Bonjour discovery, Sparkle auto-update
- [x] v1.1 — trend graphs: metric cards with sparklines (solar, home, battery flow) and a battery ring gauge
- [x] v1.2 — menu bar display options, launch at login, low-battery alert, today's energy counter, per-pack details, VPN fallback host
- [x] v1.3 — macOS widget (App Group snapshot), battery control tab (`POST /properties/write`), CSV export of the history
- [x] v1.4 — dashboard window with animated energy-flow diagram; optional 24/7 collector (LaunchAgent + SQLite + JSON API) feeding complete history
- [x] v1.2 — multi-day production history (daily kWh bar chart)
- [x] v1.5 — hub-centric flow diagram (batteries, grid, home, off-grid outlet as peripherals), Sun window (local ephemerides + production overlay + theoretical output), Juicy-style panel with period selector and stats, savings estimates (€/CO₂), extra opt-in notifications, permissions check, unit tests + GitHub Actions CI
- [x] v1.6 — daily solar split (direct/stored + grid total) in panel & dashboard, offline resilience (stale values kept & dimmed), sticky VPN fallback, local-midnight day rollover, colored header actions, EnergyMath unit tests
- [x] v1.7 — large widget (14-day histogram), weather in the Sun window (Open-Meteo, cloud-adjusted forecast), redesigned Sun window, extracted & tested DailyAccumulator
- [x] v1.8 — outage alerts: device-unreachable notification, zero-production-in-daylight notification, ⚠️ menu bar offline state (tested OutageWatchdog)
- [x] v1.9 — Sun window v3: per-array orientations with live azimuth/tilt sliders, animated sky dome, solar compass with iso-incidence loops, twilights & seasons, atmospheric transmittance in the yield model, one-screen layout (tested SolarGeometry)
- [x] v1.10 — optional Zendure Cloud mode (Cloud Key → signed deviceList → real-time MQTT, Keychain, read-only), Smart CT support (real grid draw + home total consumption on the LAN), redesigned energy-flow diagram (aligned diamond, measured grid→home arc, per-pack chips), connection footer, Network settings tab (tested Cloud layer + Smart CT parser)
- [x] v1.10.3 — home consumption card in the menu bar panel (total = measured grid draw + SolarFlow output, per-source breakdown, honest fallback without a Smart CT)
- [x] v1.10.4 — distinct UI state for an unreachable Smart CT (LAN-only meter, e.g. remote Cloud mode): partial value clearly flagged in the panel card and dashboard caption
- [x] v1.11 — automatic local ⇄ cloud switching (failure-streak detection, 60 s local probe to come back, "bascule auto" footer note) and collapsible/configurable panel cards (per-card collapse with key value, per-card visibility toggles)
- [x] v1.11.1 — clearer Cloud-mode MQTT diagnostics: session-takeover detection (one real-time session per Cloud Key), SUBACK refusal surfaced, malformed device-list entries filtered
- [x] v1.12 — energy history window: daily kWh bars over 7/30/90/365 days per device, per-device metric lists, lifetime totals, local disk cache, HTTP debug log (private Zendure app API, Keychain credentials, tested request builders/parsers)
- [ ] v1.13 — cloud `outputPower` mapping (~3 s home flow), zenSDK fault/error fields in the dashboard, Chinese localization, reorderable cards, widget refresh button (AppIntents), grid-draw daily history from the Smart CT
- [ ] v2.0 — off-peak/peak-hours optimizer (local scheduler via `POST /properties/write`)

## Acknowledgements

- [Zendure/zenSDK](https://github.com/Zendure/zenSDK) — official local API documentation
- [Gielz1986/Zendure-HA-zenSDK](https://github.com/Gielz1986/Zendure-HA-zenSDK) — Home Assistant integration that proved the local-first approach
- [Sparkle](https://sparkle-project.org) — macOS app update framework

## License

MIT — see [LICENSE](LICENSE).
