# ZendureMonitor 1.12.0

## New — Energy history window (up to 365 days)

A new **History window** (purple clock icon in the panel header) charts your daily energy, straight from Zendure's servers:

- **Daily kWh bar charts** over 7 / 30 / 90 / 365 days, one card per device, plus **lifetime totals**.
- **Per-device metric lists**: each source (SolarFlow Hub, Hyper…) exposes its own fields — solar, home, battery charge/discharge, grid, AC/DC output… The picker only offers what your device actually reports, and remembers the choice per device.
- **Local disk cache**: past days are immutable, so they are fetched once and cached — only today is re-downloaded. A full first 365-day load takes about a minute; after that, refreshes are instant.
- **Debug card**: the last HTTP exchanges with Zendure's API (password redacted), expandable and copyable — handy if something goes wrong.

### How it connects

The history comes from the **private API of the Zendure mobile app** (the only known path to historical data). It requires your **main Zendure account** e-mail and password — the Authorization Cloud Key is not enough. Credentials are stored **only in the macOS Keychain**, on a path fully separate from the Cloud Key, and the requests are throttled to go easy on Zendure's servers. Works in both local and cloud connection modes.

*Heads-up: this API is not contractual — field names and units (assumed Wh) come from community observations (FHEM Zendure module, solarflow-statuspage).*

---

Auto-update via Sparkle: the app offers this update by itself. Manual download below.
