# ZendureMonitor 2.0.0

## New — SunRoad: your home under its sun, in real 3D

The biggest visual evolution since 1.0, inspired by the Helios card for Home Assistant — but in native 3D (SceneKit, zero dependencies). The orange sun button now opens **SunRoad**, which **replaces the Sun window**:

- **Your real neighborhood**: building footprints and roads from OpenStreetMap, with real heights when the map knows them and road widths by class. **Your house is auto-detected and highlighted** — or pick it yourself: click any building in the scene and its footprint becomes the exact center.
- **The sun as a real light**: the day's arc (NOAA ephemerides, computed locally) with hourly markers, and the sun as a directional light — **the neighbors' shadows sweep across your panels** through the day.
- **Your panel arrays in 3D**, at their true azimuth and tilt — and the sidebar's **orientation sliders re-aim them live in the scene**.
- **Live energy**: animated flow beads paced by the measured watts (panels → house, grid → house, house ↔ battery) and a **production ribbon along the sun's arc** — one bar per quarter hour, where the sun actually stood.
- **±48 h timeline**: scrub two days back or forward; sun, shadows, sky and arc follow. Real **cloud cover veils the light** (Open-Meteo).
- **The Sun window's analytics live on** in a collapsible sidebar: ephemerides, twilights and golden hours, clear-sky output with estimated efficiency, weather, and the 14-day production histogram. Per-layer visibility checkboxes (buildings, roads, arc, panels, compass ring, energy) and a clean banner-hide mode.

The neighborhood is fetched once from the public Overpass API and cached locally; without network the scene degrades gracefully. Nothing else leaves your Mac.

## Also in this release

- **History window** (since 1.12, first Sparkle release carrying it for 1.11 users): daily energy from Zendure's servers over up to 365 days, per-device metric lists, lifetime totals, local cache — plus a fix hiding account devices with no energy history (e.g. the SmartMeter) and a debug card now behind a checkbox.
- **Wake recovery**: after closing the lid, the Cloud session now recovers by itself — failed reconnects retry every 15 s, silent half-dead MQTT sockets are detected via a ping timeout, and the app proactively restarts its connections a few seconds after wake.

---

Auto-update via Sparkle: the app offers this update by itself. Manual download below.
