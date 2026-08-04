## Zendure Monitor 1.4.0

### New
- **Dashboard window** 🗺 — open it from the panel: animated energy-flow diagram (sun → SolarFlow → home / grid, flow speed follows power), and every indicator the local API exposes: device temperature, WiFi signal, AC mode and limits, per-pack SOC/temperature/power, battery voltage, estimated runtime, configured SOC range, richer 14-day history with period total and best day.
- **Optional 24/7 collector** (`Scripts/collector/`) — a tiny Python LaunchAgent for an always-on Mac that records production around the clock (SQLite) and serves it back to the app (`/daily`, `/today`), so daily history no longer depends on your Mac being awake. Set its address in Settings → Remote.

### Fixed
- Battery flow sparkline now shows a zero baseline (charge above, discharge below)
- Control tab: anti double-send debounce and an explicit confirmation before applying a 0 W limit
- Network scan now says when no device was found (with a hint to enable the local API)
- Widget: stale data (app closed > 15 min) is dimmed with an age indicator

macOS 14+, signed and notarized. Auto-update via Sparkle.
