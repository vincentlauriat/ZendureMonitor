# Zendure Monitor

[![Release](https://img.shields.io/github/v/release/vincentlauriat/ZendureMonitor)](https://github.com/vincentlauriat/ZendureMonitor/releases)
![Platform](https://img.shields.io/badge/platform-macOS%2014%2B-blue)
![License](https://img.shields.io/badge/license-MIT-green)

A tiny macOS menu bar app that shows the **live solar production of a Zendure SolarFlow battery** — 100% local, no Zendure cloud account, no MQTT broker, no credentials.

```
☀️ 842 W          ← in your menu bar, refreshed every 5 s
```

Click the icon for the details: battery state of charge, charge/discharge power, per-pack SOC/temperature, output to home, grid input, per-MPPT PV input, and today's solar energy.

Options: choose what the menu bar shows (solar W, battery %, home W — or icon only), launch at login, low-battery notification with a configurable threshold, and an optional fallback host for remote access over a VPN.

## Supported hardware

Tested on a **SolarFlow 2400 Pro**. Any Zendure device that ships the local zenSDK REST API should work: SolarFlow 2400 AC / AC+ / AC Pro, 800 (Pro/Plus), 1600 AC+, 3000 Mix AC+, 4000 Mix.

## Install

1. Download the latest `ZendureMonitor-x.y.z.dmg` from [Releases](https://github.com/vincentlauriat/ZendureMonitor/releases) (signed & notarized).
2. Drag **ZendureMonitor.app** to `/Applications` and launch it.
3. Accept the **local network** permission prompt (required to reach the battery).
4. Click the ☀️ icon → *Réglages…* → *Rechercher sur le réseau* (or type the device IP) → *Tester la connexion*.

Updates are delivered in-app via [Sparkle](https://sparkle-project.org).

> **If discovery finds nothing:** the local API may be disabled on your unit. In the Zendure mobile app, add a **HEMS** integration and then quit it — this is the documented way to persistently enable the local API.

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

### 2. Device discovery — a firmware quirk worth knowing

The zenSDK docs say devices advertise over mDNS/Bonjour as **`_zendure._tcp`**. In practice, a SolarFlow 2400 Pro (firmware as of mid-2026) advertises under the generic **`_http._tcp`** type instead, with an instance name of:

```
Zendure-<product>-<serialNumber>     e.g. Zendure-solarFlow2400Pro-EEB4AEXXXXXXXXX
```

resolving to `Zendure-<product>-<serial>.local:80`. The app therefore browses **both** service types and keeps `_http._tcp` results only when the instance name starts with `Zendure` (`Sources/Discovery.swift`). You can verify from a terminal:

```bash
dns-sd -B _http._tcp local.        # look for a Zendure-* instance
curl http://Zendure-<…>.local/properties/report | jq .properties.solarInputPower
```

### 3. App architecture

Pure Swift / SwiftUI, no third-party dependency besides Sparkle. Generated with [XcodeGen](https://github.com/yonaskolb/XcodeGen) from `project.yml`.

```
Sources/
  ZendureMonitorApp.swift   @main — MenuBarExtra (LSUIElement agent app) + Settings scene
  Components/               reusable card/gauge/sparkline views (Swift Charts), shared
                            design language with the MacInside app
  Monitor.swift             @MainActor ObservableObject: async polling loop (2–60 s,
                            URLSession, 5 s timeout), UserDefaults persistence, W/kW formatting
  DeviceState.swift         zenSDK payload model + tolerant JSONSerialization parser
  Discovery.swift           Bonjour browser (_zendure._tcp + _http._tcp) resolving hostnames
  MenuView.swift            dropdown panel (production, SOC, flows, per-MPPT detail)
  SettingsView.swift        host/IP, poll interval, network scan, connection test
  Updater.swift             Sparkle SPUStandardUpdaterController wiring
```

Design choices:

- **`MenuBarExtra` with `.window` style** — the label is plain `Text` with an interpolated SF Symbol, so the menu bar shows live wattage (`☀️ 842 W`, `— W` when unconfigured).
- **Polling, not push.** The device has no local push channel; a 5 s `GET` of a ~2 KB JSON is negligible for both sides. The loop is a cancellable `Task` that restarts when host or interval changes.
- **Stale-data policy:** on errors the last reading stays visible (with a warning row) for 60 s, then the display falls back to "no data" — avoids flapping on a single missed poll.
- **Privacy/entitlements:** `NSLocalNetworkUsageDescription` + `NSBonjourServices` (macOS local-network privacy), `NSAllowsLocalNetworking` for cleartext HTTP to `.local` hosts. IP literals are ATS-exempt.

### 4. Release & auto-update pipeline

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
- [ ] Multi-day production history charts

## Acknowledgements

- [Zendure/zenSDK](https://github.com/Zendure/zenSDK) — official local API documentation
- [Gielz1986/Zendure-HA-zenSDK](https://github.com/Gielz1986/Zendure-HA-zenSDK) — Home Assistant integration that proved the local-first approach
- [Sparkle](https://sparkle-project.org) — macOS app update framework

## License

MIT — see [LICENSE](LICENSE).
