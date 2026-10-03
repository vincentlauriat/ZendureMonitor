# PRD — Zendure Monitor

**Product:** Zendure Monitor — macOS menu bar app for the Zendure SolarFlow solar battery
**Documented version:** 2.2.0 (build 22) — shipped state as of 2026-08-13
**Author:** Vincent Lauriat · **Repository:** [github.com/vincentlauriat/ZendureMonitor](https://github.com/vincentlauriat/ZendureMonitor) (MIT, public)
**Status:** product in production, publicly distributed, 22 versions shipped
**Last updated:** 2026-08-14

> This PRD is **retroactive and forward-looking**: it formalizes the product as it is actually shipped (§1–§10) and frames what comes next (§11–§14). It is the reference for scope arbitration; `PLAN.md` carries the execution breakdown, `TODOS.md` the progress, `MEMORY.md` the state and lived decisions.

---

## 1. Executive summary

Zendure Monitor displays the **live solar production** of a Zendure SolarFlow battery in the macOS menu bar, and gives one-click access to the full state of the installation: battery charge, energy flows, household consumption, history, and a 3D scene of the sun over the neighborhood.

Its value proposition fits in one word: **local-first**. The app reads the zenSDK API exposed by the device on the local network — no account, no broker, no credentials, no dependency on third-party infrastructure. Cloud mode exists, but as an *optional fallback*, never as a prerequisite.

The product is mature: 46 Swift files, 113 green unit tests, GitHub Actions CI, Developer ID–signed and notarized DMG, Sparkle auto-update, a 12-page FR/EN user guide, a public landing page.

---

## 2. Context and problem

### 2.1 The user problem

A SolarFlow owner has the Zendure mobile app. For daily use from a workstation, it has three shortcomings:

| Friction | Consequence |
|---|---|
| It lives on the phone | Checking production means pulling out the phone, unlocking, opening the app, waiting |
| It goes through the Zendure cloud | Latency, dependency on a third-party service, household data transiting through remote servers |
| It is designed for control, not for monitoring | No ambient display, no notion of "glancing at it while I work" |

The real need is not "one more app": it is a **permanent ambient display**, at zero cognitive cost, on the screen where the user already spends their day.

### 2.2 The technical opportunity

Recent Zendure firmwares embed an HTTP server on port 80 (`GET /properties/report`), officially documented by [Zendure/zenSDK](https://github.com/Zendure/zenSDK), which returns **the whole device state in a single JSON**, with no authentication on the LAN. The community Home Assistant integration proved the viability of this route. It makes a 100% local product possible, with no account and no secret to manage.

### 2.3 Existing alternatives

- **Zendure mobile app** — official, complete, but cloud-only and mobile-only.
- **Home Assistant + zenSDK integration** — powerful, but requires running and maintaining an HA instance. Oversized for "seeing your production".
- **Nothing on macOS.** That is the niche.

---

## 3. Vision and guiding principles

> **Seeing your solar production should cost zero gestures.**

Five principles settle the product's trade-offs. They are non-negotiable: any feature that would violate one is rejected, regardless of its appeal.

**P1 — Local first.** The default path requires no account, no key, no internet. The cloud is an explicit, opt-in fallback.

**P2 — Read-only by default.** The app drives a real home battery. Writing (`POST /properties/write`) exists but is confined to a dedicated Control tab, **local only**, never reachable from Cloud mode.

**P3 — Data honesty.** A value that is not measured is never made up nor silently replaced by zero. This is the product's most structuring principle — it has produced three visible decisions:
- without a Smart CT, the grid→home arc is explicitly marked "non mesuré" (not measured);
- in the Sankey, the unmeasured grid draw keeps a **hatched band of fixed thickness, off-scale** (a proportional width would invent a figure, omitting it would assert zero);
- the hub imbalance is drawn as a gray ribbon named "Pertes & conversion" (Losses & conversion), never silently absorbed.

**P4 — No superfluous dependency.** Pure Swift/SwiftUI. A single third-party dependency: Sparkle (updates). The MQTT client is written on Network.framework rather than imported.

**P5 — A view that compiles is not a view that works.** Every graphical view is **rendered and looked at** before being declared done. A lesson paid for three times (field editor blown apart inside a `Form`, hatching degenerating into slabs in the Sankey, overlapping labels) — code review does not catch these defects.

---

## 4. Target users

### Primary persona — "the equipped owner"

Has owned a SolarFlow for a short time, works on a Mac, wants to know at all times what their installation is producing and whether their battery is charging. Technically comfortable (can read an IP), but **does not want to administer a server**. Installs a DMG and it works.

*What they expect:* a number in the menu bar, a panel that answers "where is my energy going right now?", and nothing to maintain.

### Secondary persona — "the optimizer"

Same profile, one notch further: has added a Smart Meter 3CT, knows the azimuth of their panels, wants to understand the gap between expected and actual production, and arbitrate their usage. They are the one who uses SunRoad, History and the forecast curves.

### Tertiary persona — "the nomadic user"

On the road, wants to keep an eye on their installation. Addressed through two paths: backup host via VPN (Tailscale), or automatic switch to Cloud mode.

### Explicit non-targets

- Windows/Linux users (macOS only, native `MenuBarExtra`).
- Heterogeneous multi-inverter installations / professional use.
- Users looking for a complete home automation system — Home Assistant does that better.

---

## 5. Scope

### 5.1 What the product is

A local **visualization companion** for a home SolarFlow installation, on macOS 14+.

### 5.2 What the product is not

| Out of scope | Why |
|---|---|
| A server / a home automation integration | HA occupies that ground; the app is the complementary thin client |
| An automated control system | Writes to a real battery → any automation requires explicit validation (see v2.4) |
| A cross-platform app | The core of the product *is* the native macOS integration |
| A service exposed on the internet | The zenSDK API has **no authentication** — port forwarding is explicitly discouraged in the docs |
| A multi-account / SaaS product | Single-user, single-installation, single-Mac |

---

## 6. Functional requirements

Status: **L** = shipped · **P** = planned · **E** = exploratory.

### 6.1 Ambient display (menu bar) — core of the product

| ID | Requirement | Status |
|---|---|---|
| F-01 | Display live solar production (W) in the menu bar, refreshed every 5 s (2–60 s configurable) | L |
| F-02 | Choose what is displayed: solar W, battery %, home W, or icon only | L |
| F-03 | Explicit "no data" state (`— W`) when not configured | L |
| F-04 | ⚠️ "offline" icon when the device is unreachable | L |
| F-05 | Keep the last value for 60 s on poll failure (grayed out + age), rather than flickering | L |

### 6.2 Dropdown panel

| ID | Requirement | Status |
|---|---|---|
| F-10 | Cards: production, battery (SOC + per pack: SOC/temperature/voltage), flow, home consumption, history, savings | L |
| F-11 | Period selector 15 min / day / 14 days, with peak and comparison to yesterday | L |
| F-12 | Solar breakdown of the day: direct to home vs stored (grid charge deducted) + grid total | L |
| F-13 | Cards collapsible on click (one-line summary) and individually enable/disable-able | L |
| F-14 | Connection footer showing the actual source: local / local fallback / cloud / auto switch | L |
| F-15 | Cards reorderable by drag and drop | P (v2.3) |

### 6.3 Dashboard

| ID | Requirement | Status |
|---|---|---|
| F-20 | Dedicated window with all indicators exposed by the API | L |
| F-21 | **Node diagram**: SolarFlow at the center, panels / batteries / grid / home / off-grid socket around the edge; links animate only when energy flows, watts shown in a pill | L |
| F-22 | **Sankey view**: ribbon width ∝ watts, sources on the left, uses on the right; explicit hub remainder; unmeasured grid draw hatched off-scale | L |
| F-23 | Diagram ⇄ Sankey toggle persisted across sessions | L |
| F-24 | Strictly identical values in both views (single source: `EnergyMath`) | L |
| F-25 | zenSDK state / fault fields (`faultLevel`, `gridState`…) shown in the Device card | P (v2.3) |

### 6.4 SunRoad (3D scene)

| ID | Requirement | Status |
|---|---|---|
| F-30 | Native SceneKit scene: OpenStreetMap neighborhood (extruded buildings + roads), house auto-detected (< 25 m) or designated by click | L |
| F-31 | Sun = real directional light casting real shadows, following the course of the day | L |
| F-32 | Panel fields at their real azimuth/tilt, adjustable live with sliders | L |
| F-33 | Animated flow beads paced by real watts; production ribbon along the solar arc | L |
| F-34 | Continuous home consumption curve on the 24 h circle (15 min stakes, "⌂ n W" badge) | L |
| F-35 | Expected clear-sky production curve, on the ground, on the same base and the same scale as the real bars | L |
| F-36 | ±48 h timeline, cloud cover veiling the light, toggleable layers, wall mode | L |
| F-37 | Sidebar: ephemerides, twilights, theoretical yield, weather, 14-day histogram | L |
| F-38 | Polish: street names, vegetation/water bodies, adjustable neighborhood radius, mirrored cardinal letters | P (v2.3) |

### 6.5 Data sources

| ID | Requirement | Status |
|---|---|---|
| F-40 | **Local (default)**: `GET /properties/report`, tolerant parser (nested or flat, Int/Double/String) | L |
| F-41 | Bonjour discovery on `_zendure._tcp` **and** `_http._tcp` (firmware quirk: `Zendure-<product>-<sn>` instances) | L |
| F-42 | **Cloud (opt-in)**: Cloud Key → SHA1-signed `deviceList` → real-time MQTT, in-house MQTT 3.1.1 client, **read-only** | L |
| F-43 | **Smart Meter 3CT** queried on the LAN in both modes → measured grid draw + total consumption | L |
| F-44 | Backup host (VPN) with remembered fallback and retest of the primary every 2 min | L |
| F-45 | Automatic local ⇄ cloud switch (opt-in): 2 failures → cloud, 60 s local probe → back | L |
| F-46 | Safeguard: reject a Smart CT answering at the SolarFlow's address (explicit error, never silent zeros) | L |
| F-47 | Map the cloud `outputPower` (topic `properties/energy`, ~3 s) to the home flow | P (v2.3) |

### 6.6 History and energy

| ID | Requirement | Status |
|---|---|---|
| F-50 | Multi-day history: kWh bars over 7/30/90/365 days per device, per-source metrics, lifetime totals | L |
| F-51 | Disk cache of past days (immutable, fetched only once) | L |
| F-52 | Hide devices with no real history (full payload but entirely zero ⇒ "no history") | L |
| F-53 | CSV export | L |
| F-54 | Optional 24/7 collector (LaunchAgent + SQLite + JSON API) on an always-on Mac | L |
| F-55 | Grid draw history from the Smart CT | P (v2.3) |

### 6.7 Alerts and notifications (all opt-in)

| ID | Requirement | Status |
|---|---|---|
| F-60 | Low battery (configurable 5–50% threshold) | L |
| F-61 | Device unreachable beyond N minutes (default ON, 10 min) | L |
| F-62 | Zero production in broad daylight (default ON, 30 min, solar elevation > 20°) | L |
| F-63 | Battery full, unexpected grid draw, production record | L |

### 6.8 Widgets and system integration

| ID | Requirement | Status |
|---|---|---|
| F-70 | Small / medium (live state) and large (14-day histogram) widgets via App Group | L |
| F-71 | Launch at login (`SMAppService`) | L |
| F-72 | Upfront permission checks (local network, location, notifications) | L |
| F-73 | Widget refresh button (AppIntents) | P (v2.3) |

### 6.9 Control (local only, read-write)

| ID | Requirement | Status |
|---|---|---|
| F-80 | Control tab: AC mode, output/charge limits via `POST /properties/write` | L |
| F-81 | Unavailable in Cloud mode (consistent with P2) | L |
| F-82 | Off-peak / peak hours optimizer (local scheduler) | P (v2.4) |

### 6.10 Settings and localization

| ID | Requirement | Status |
|---|---|---|
| F-90 | Tabbed settings: device, display, sun, notifications, control, network, general | L |
| F-91 | UI localized in French / English | L |
| F-92 | Auto / dark / light theme | L |
| F-93 | Savings estimates (€/kWh and g CO₂/kWh configurable) | L |
| F-94 | Chinese localization | P (v2.3) |

---

## 7. Non-functional requirements

### 7.1 Performance

- **Polling, not push**: the device exposes no local push channel. A ~2 KB `GET` every 5 s is negligible on both sides. The loop is a cancellable `Task`, restarted when the host or the interval changes; 800 ms debounce on settings changes.
- 5 s timeout per request; in VPN fallback, no 5 s timeout on the primary at every poll (remembered fallback).
- SunRoad must stay smooth when dragging the orientation sliders — **validated in real conditions on a Debug build** (the worst case).

### 7.2 Security and privacy

- **No data leaves the Mac** on the default path. Ephemerides are computed locally (NOAA algorithm), not fetched from a service.
- External network outputs, all optional and declared: Open-Meteo (weather), Overpass/OSM (neighborhood, disk-cached), Zendure servers (Cloud mode, History).
- **Secrets in the macOS keychain only**: Cloud Key, mobile app account credentials (stored separately). Raw tokens are never written to disk in clear text.
- Cloud mode is **read-only by construction**.
- **Never expose the device's port 80 on the internet** — the zenSDK API has no authentication. VPN (Tailscale/WireGuard with subnet routing) is the only documented remote access scheme.
- `NSLocalNetworkUsageDescription` + `NSBonjourServices`; `NSAllowsLocalNetworking` for cleartext HTTP to `.local` hosts.

### 7.3 Reliability

- **Stale data policy**: on error, the last reading stays visible with a warning for 60 s, then switches to "no data". Avoids flickering on an isolated missed poll.
- Day rollover at **local midnight** (not UTC).
- Recovery after sleep: shared rescheduling of MQTT and HTTP reconnections, PINGRESP timeout (half-dead socket), observation of `NSWorkspace.didWakeNotification`.
- Explicit MQTT diagnostics: SUBACK codes interpreted, session takeover detection ("only one real-time session per Cloud Key"), malformed `deviceList` entries filtered out.

### 7.4 Quality and distribution

| Requirement | Current level |
|---|---|
| Unit tests on all pure logic (parsers, ephemerides, solar geometry, energy calculations, watchdog, geo projection) | 113 green tests |
| CI on every PR | GitHub Actions |
| System target | macOS 14+ |
| Signing | Developer ID (`KFLACS69T9`), Hardened Runtime, secure timestamp |
| Notarization | `notarytool` + stapling, independent verification (`spctl`, `stapler validate`) after every release |
| Updates | Sparkle 2.9.1, appcast served from `main`, EdDSA-signed DMG |
| Documentation | Complete technical README, FR+EN user guide (12 pages), wiki, landing page |

**Non-negotiable release constraints** (learned the hard way):
1. The GitHub release is created **before** the appcast push — the reverse order exposes Sparkle clients to a 404.
2. The Sparkle EdDSA key is **never** regenerated (it would break auto-update for all installed users).
3. `Info.plist` is generated by XcodeGen from `project.yml` — never edit it directly.
4. Never leave an ad hoc–signed Debug build running as the daily-driver app: macOS silently invalidates the local network permission on every rebuild.

---

## 8. Architecture

Pure Swift / SwiftUI, project generated by XcodeGen from `project.yml`. Agent application (`LSUIElement`) with `MenuBarExtra` in `.window` style. 46 source files.

```
Sources/
  ZendureMonitorApp.swift   @main — MenuBarExtra, scènes Réglages / Dashboard / SunRoad / Historique
  Monitor.swift             @MainActor — boucle de poll, bascule de source, persistance, notifications
  DeviceState.swift         modèle zenSDK + parser tolérant (+ garde-fou de signature)
  SmartCT.swift             rapport local du SmartMeter3CT (par phase + total)
  Discovery.swift           navigateur Bonjour (_zendure._tcp + _http._tcp)
  Cloud/                    Cloud Key, deviceList signé, MQTT 3.1.1 maison, trousseau, API app mobile,
                            service d'historique — lecture seule par conception
  SunRoad/                  scène SceneKit, Overpass/OSM, projection géo, barre latérale
  Components/               cartes, jauges, sparklines, schéma de flux, Sankey — langage visuel partagé
                            avec MacInside
  Shared/                   Format, SunCalc (NOAA), SolarGeometry, EnergyMath, DailyAccumulator,
                            OutageWatchdog, WidgetSnapshot — logique pure, compilée dans les tests
Tests/                      13 suites, 113 tests
```

**Structuring choices:**
- The menu bar label is a `Text` with an interpolated SF symbol — this is what makes it possible to display a live value.
- All computational logic lives in `Shared/`, with no dependency on the UI or the network: this is the testable surface.
- `EnergyMath` is the **single source** of derived quantities (`gridToHome`, `homeTotal`, solar breakdown) — panel, diagram and Sankey all draw from it, which structurally rules out any divergence between views.
- Azimuth convention fixed everywhere: **0° = north, 90° = east, 180° = south, 270° = west**. Many solar tools use south = 0 — a silent conversion would skew the incidence without visibly breaking anything.

---

## 9. Data sources

| Source | Protocol | Role | Optional |
|---|---|---|---|
| SolarFlow (LAN) | HTTP `GET /properties/report`, port 80 | Default path: entire state in one JSON | No — it is the product |
| SolarFlow (LAN) | HTTP `POST /properties/write` | Control tab, local only | Yes |
| SmartMeter 3CT (LAN) | HTTP `GET /properties/report` | Real grid draw → measured arc, total home consumption | Yes |
| Zendure Cloud | SHA1-signed `deviceList` → MQTT `mqtteu.zen-iot.com:1883` | Fallback when the LAN is unreachable | Yes, opt-in |
| Mobile app private API | HTTP (Blade-Auth, tdengine endpoints) | Long-term history (up to 365 days) | Yes, opt-in |
| Open-Meteo | HTTPS | Cloud cover, adjusted forecast (Kasten–Czeplak) | Yes |
| Overpass / OpenStreetMap | HTTPS | Neighborhood buildings and roads (disk cache) | Yes |
| 24/7 collector | Local JSON HTTP | History independent of the Mac being on | Yes |

**Yield model** (`SolarGeometry`): 85% direct × cos(incidence) × Meinel transmittance (0.7^(air mass^0.678), normalized to 1 at zenith) + 15% diffuse × sin(elevation) × (1+cos tilt)/2, all × 0.9 for losses. The transmittance is essential: without it, a west-facing façade reported 323 W at sunset instead of 30 W. Validated against real data: actual ≤ forecast + 4% at most.

---

## 10. Key user journeys

**UJ-1 — First installation (goal: < 2 minutes).** Download the DMG → drag into /Applications → launch → accept the local network permission → Settings → "Rechercher sur le réseau" (Search the network) → test the connection. *Known friction point:* if discovery finds nothing, the local API may be disabled on the unit — the documented workaround is to add a HEMS integration in the mobile app and then quit it.

**UJ-2 — Daily glance (goal: zero clicks).** The value is already in the menu bar.

**UJ-3 — "Where is my energy going?"** Click the icon → Flow card; for detail, open the dashboard → diagram or Sankey depending on whether you are after the topology or the breakdown.

**UJ-4 — Optimize panel orientation.** SunRoad → azimuth/tilt sliders → the 3D scene, incidence and yield follow the gesture; the gap between the expected curve and the real bars reads on the same scale.

**UJ-5 — Check from outside.** Either VPN (Tailscale, subnet routing) + backup host, or automatic switch to the Cloud. Accepted limitation: since the Smart CT is LAN-only, home consumption is marked "partielle" (partial) remotely.

---

## 11. Success metrics

Personal product turned public — the metrics are qualitative and operational rather than commercial.

| Metric | Target |
|---|---|
| Time from launch to first displayed value | < 2 min |
| Display availability (fresh value present when the LAN is healthy) | > 99% of the Mac's uptime |
| Made-up value or silent zero displayed to the user | **0 occurrences** (P3) |
| Green tests on `main` | 100%, on every PR |
| Notarized and independently verified releases | 100% |
| Regressions reported by external users | to be handled as a patch within 48 h (precedent: v1.11.1) |
| Doc coverage: every visible feature documented in the FR **and** EN guide | 100% |

---

## 12. Roadmap

### Shipped (v1.0 → v2.2)

| Version | Major contribution |
|---|---|
| 1.0–1.2 | Live production in the menu bar, Bonjour discovery, Sparkle, charts, display options, multi-day history |
| 1.3–1.4 | macOS widget, Control tab, CSV export, dashboard, 24/7 collector |
| 1.5–1.6 | Hub-centered flow diagram, Sun window, savings, notifications, tests + CI, solar breakdown, offline resilience |
| 1.7–1.9 | Large widget, weather, outage alerts, Sun window v3 (celestial dome, compass, adjustable orientations) |
| 1.10–1.12 | Cloud mode, Smart CT, Home consumption card, auto switch, collapsible cards, History window |
| 2.0–2.2 | **SunRoad** (3D neighborhood, real shadows), consumption/forecast curves, **Sankey view** of the flow |

### v2.3 — Consolidation *(next)*

SunRoad polish (street names, vegetation, adjustable radius, mirrored cardinal letters), `outputPower` mapping in Cloud mode, zenSDK fault fields in the dashboard, Chinese localization, reorderable cards, widget refresh button, grid draw history from the Smart CT.

### v2.4 — Off-peak / peak hours optimizer

Local scheduler driving the battery via `POST /properties/write` according to tariff windows. **A break with principle**: it is the first feature that writes autonomously to real hardware. It requires a dedicated plan, validated before any line of code, and probably a "proposal to confirm" safeguard rather than silent automation.

### Exploratory (not committed)

First-class multi-device support (a user with two SolarFlows already exists); export to Home Assistant or Prometheus; companion iOS app (would contradict the macOS-native positioning — to be decided, not assumed).

---

## 13. Risks and dependencies

| Risk | Impact | Mitigation |
|---|---|---|
| **Non-contractual zenSDK API** — Zendure may change or disable it via firmware | Critical: it is the default path | Deliberately tolerant parser; Cloud mode is already the fallback; zenSDK repository monitoring |
| **Mobile app private API** (History) — undocumented, unstable | History breaks | Isolated, optional feature; degraded failure, never blocking |
| **Firmware quirks** (Bonjour under `_http._tcp`, local API disabled by default) | Discovery fails on first launch | Both service types are browsed; HEMS workaround documented in the README and the guide |
| **Local network TCC invalidated** on app replacement | Silently failing poll, very hard to diagnose | `lsregister -f` after installation; detection banner in the app; ban on running a Debug build daily |
| **MQTT session takeover** — only one real-time session per Cloud Key | Reconnection loop in Cloud mode if HA/ioBroker uses the same key | Detected and explained to the user (v1.11.1) |
| **Overpass throttling** | Empty SunRoad neighborhood | Disk cache by coordinates, fallback to the neighboring cache |
| **Bus factor = 1** | Project continuity | MIT-licensed and public code; decisions and pitfalls recorded in `MEMORY.md` |
| **Test hardware base = a single unit** (SolarFlow 2400 Pro) | Regressions invisible on other models | Tolerant parser; user feedback handled via quick patches |

---

## 14. Open questions

1. ~~**Multi-device**~~ — **settled on 2026-10-03** (Vincent himself added a 2nd SolarFlow): aggregation becomes first-class — one installation summed everywhere, a "Appareils" (Devices) card for the detail, totals flagged partial when a device is missing, commands always targeted at a specific device.
2. **v2.4 and autonomous writes** — how far can the optimizer go without confirmation? Principle P2 (read-only by default) requires an explicit arbitration before any development.
3. **Is the 24/7 collector sustainable?** It requires an always-on Mac and has already caused incidents (TCC, sleep of [Mac-collecteur]). History via the mobile API partially overlaps it — should it be deprecated?
4. **Localization scope** — Chinese is planned for v2.3; on what signal of real demand?

---

## Appendices

- **External references:** [Zendure/zenSDK](https://github.com/Zendure/zenSDK) (`docs/en_properties.md`) · [Gielz1986/Zendure-HA-zenSDK](https://github.com/Gielz1986/Zendure-HA-zenSDK) · [Sparkle](https://sparkle-project.org) · [Open-Meteo](https://open-meteo.com) · [Overpass API](https://overpass-api.de)
- **Project documents:** `README.md` (technical, public) · `PLAN.md` (execution breakdown) · `TODOS.md` (progress) · `MEMORY.md` (state, decisions, pitfalls) · `CHANGES.md` (log) · `docs/guide/` (FR/EN user guide)
- **Reference hardware:** SolarFlow 2400 Pro + SmartMeter 3CT. Expected compatible models: SolarFlow 2400 AC / AC+ / AC Pro, 800 (Pro/Plus), 1600 AC+, 3000 Mix AC+, 4000 Mix.
