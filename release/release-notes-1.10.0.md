# ZendureMonitor 1.10.0

## New — a Cloud mode, and the real picture of your home's energy

Until now the app had one way to reach the battery: its local zenSDK API. When the SolarFlow dropped off the LAN (it happens — mid-incident is exactly when you want data), the app went blind. 1.10 adds a second path and makes the flow diagram tell the whole truth.

- **Zendure Cloud mode** — Settings → Device now has a data-source switch: **Local API** (unchanged, still the default and the recommendation) or **Zendure Cloud**. Paste your *Authorization Cloud Key* from the Zendure mobile app (Profile → Authorization Cloud Key, main account), and the app receives the device's reports in **real time over MQTT** — from anywhere, no VPN. The key decodes locally into the API endpoint and app key, is stored in the **macOS Keychain**, and the raw token never leaves your Mac. Cloud mode is **read-only**: the control tab is disabled there on purpose. Everything else — history, daily energy, outage alerts, widgets — works identically in both modes.
- **Smart CT support** — if a Zendure SmartMeter3CT sits in your electrical panel, the app now polls it **directly on your LAN** (the Zendure cloud does not relay its readings) and the energy-flow diagram gains what no SolarFlow field can provide: the **home's real grid draw** and its **total consumption**. Settings → Network detects the meter over Bonjour. Away from home, the arc honestly falls back to "not measured" rather than freezing a stale number.
- **Energy-flow diagram, redesigned** — a strictly aligned diamond: panels on top, SolarFlow at the center, the battery gauge *exactly* underneath (nodes are now anchored by their circle centers, which fixes the old misalignment), grid left, home right. Per-pack SOC chips under the aggregate gauge, pulsing halos on active nodes matching the Sun window's animation language, the off-grid outlet only appears while it actually delivers, and the grid→home flow is drawn explicitly — measured and animated with the Smart CT, grey with a "not measured" tag without it.
- **Connection footer** — the bottom of the menu panel now always tells you how the data arrives: *local — primary host*, *local — fallback host*, or *Zendure Cloud*, with a green/orange dot for the last poll's outcome.
- **Settings reorganized** — the overloaded Device tab slims down to the data source and refresh rate; a new **Network** tab groups the Smart CT, the VPN fallback host and the 24/7 collector; help texts got shorter everywhere.

## Under the hood

- New `Sources/Cloud/` layer, ported from a protocol validated against the real service: Cloud Key decoding, SHA1-signed `deviceList` call, a dependency-free **MQTT 3.1.1 client on Network.framework**, partial-report merging with unit conversions, and a reconnection path that re-runs the full login (MQTT credentials expire).
- The cloud feed plugs into the existing poll loop as a pull adapter — the watchdog, accumulator, notifications and widget pipeline are untouched, and stale cloud data (> 3 min) surfaces through the normal error path.
- `Scripts/cloud-probe.swift`: a CLI probe that lists the account's devices and dumps every MQTT topic and key the cloud publishes — the tool that established what the cloud does (and does not) expose.
- **83 tests, all green** (Cloud Key, request signing, MQTT packet round-trips, report merging, unit conversions, Smart CT parsing — several against payloads captured from the real installation).
- Full French and English localization for every new surface.

---

Auto-update via Sparkle: the app offers this update by itself. Manual download below.
