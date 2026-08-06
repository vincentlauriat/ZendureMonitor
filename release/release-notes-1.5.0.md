## Zendure Monitor 1.5.0

### New
- **Hub-centric energy-flow diagram** — the SolarFlow sits at the center; solar panels, batteries, public grid, home and the off-grid outlet (`gridOffPower`, newly parsed) are peripherals. Links animate only when energy actually flows, in the real direction, with live wattage on each link.
- **Sun window** — sunrise, sunset, solar noon, day length, elevation and azimuth computed locally (NOAA algorithm, nothing leaves your Mac); the sun's path overlaid with today's production curve; clear-sky theoretical output and estimated efficiency from your panels' peak power. Position can be filled from the Mac's location (one-shot, optional).
- **Redesigned panel** — header with the app name, last update time and icon actions (dashboard, Sun window, settings, updates/quit menu); period selector on the main chart (15 min / day / 14 days); daily peak and vs-yesterday stats under the histogram. Double-click any chart to open the dashboard.
- **Savings estimates** — configurable kWh price and CO₂ factor; today's savings and 14-day totals in the dashboard.
- **Extra opt-in notifications** — battery full, unexpected grid draw while solar produces, daily production record.
- **Upfront permissions check** — a Permissions section in Settings shows the local network / location / notifications status with shortcuts to System Settings, and the panel warns when something the app needs is blocked (including the local-network TCC denial, which macOS otherwise causes to fail silently).

### Improved
- Settings reorganized: a dedicated Sun tab, refresh interval with the device settings, a slimmer General tab.
- The app now appears in the Dock and Cmd-Tab while the dashboard or Sun window is open.

### Under the hood
- Unit tests (parser, sun ephemerides, formatting) and a GitHub Actions CI running build + tests on every PR.
